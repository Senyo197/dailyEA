#ifndef __MANUAL_TRADING_GUARDIAN_STOP_LOSS_AMOUNT__
#define __MANUAL_TRADING_GUARDIAN_STOP_LOSS_AMOUNT__

#include <Trade/Trade.mqh>
#include "Guardian_Toggles.mqh"

ulong GuardianRiskPositionIDs[];
datetime GuardianRiskLastFailureAt[];

string GuardianRiskPositionKey(ulong positionID)
{
   return (
      "ManualTradingGuardian.Risk." +
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "." +
      IntegerToString((long)positionID)
   );
}

bool GuardianShouldLogRiskFailure(ulong positionID)
{
   for(int i = 0; i < ArraySize(GuardianRiskPositionIDs); i++)
   {
      if(GuardianRiskPositionIDs[i] != positionID)
         continue;

      if(TimeCurrent() - GuardianRiskLastFailureAt[i] < 60)
         return false;

      GuardianRiskLastFailureAt[i] = TimeCurrent();
      return true;
   }

   return true;
}

void GuardianTrackPositionRisk(ulong positionID)
{
   if(positionID == 0)
      return;

   for(int i = 0; i < ArraySize(GuardianRiskPositionIDs); i++)
      if(GuardianRiskPositionIDs[i] == positionID)
         return;

   int count = ArraySize(GuardianRiskPositionIDs);
   ArrayResize(GuardianRiskPositionIDs, count + 1);
   ArrayResize(GuardianRiskLastFailureAt, count + 1);
   GuardianRiskPositionIDs[count] = positionID;
   GuardianRiskLastFailureAt[count] = 0;
   GlobalVariableSet(GuardianRiskPositionKey(positionID), 1.0);
}

void GuardianRestoreTrackedPositionRisks()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ulong positionID = (ulong)PositionGetInteger(POSITION_IDENTIFIER);

      if(
         positionID != 0 &&
         GlobalVariableCheck(GuardianRiskPositionKey(positionID))
      )
         GuardianTrackPositionRisk(positionID);
   }
}

bool GuardianSelectPositionByIdentifier(ulong positionID)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0)
         continue;

      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == positionID)
         return true;
   }

   return false;
}

bool GuardianLossAtStop(
   ENUM_ORDER_TYPE orderType,
   string symbol,
   double volume,
   double entryPrice,
   double stopPrice,
   double &loss
)
{
   double profit = 0.0;

   if(!OrderCalcProfit(
         orderType, symbol, volume,
         entryPrice, stopPrice, profit
      ))
      return false;

   loss = MathMax(0.0, -profit);
   return true;
}

bool GuardianFindCappedStop(
   ENUM_ORDER_TYPE orderType,
   string symbol,
   double volume,
   double entryPrice,
   double maxLoss,
   double &newStop
)
{
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   if(tickSize <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = (MathMax(stopsLevel, freezeLevel) + 1) * point;
   double closestValid = orderType == ORDER_TYPE_BUY ?
      MathFloor((bid - minDistance) / tickSize) * tickSize :
      MathCeil((ask + minDistance) / tickSize) * tickSize;

   if(closestValid <= 0.0)
      return false;

   double minimumLoss = 0.0;

   if(!GuardianLossAtStop(
         orderType, symbol, volume,
         entryPrice, closestValid, minimumLoss
      ) || minimumLoss > maxLoss)
      return false;

   double direction = orderType == ORDER_TYPE_BUY ? -1.0 : 1.0;
   double nearPrice = entryPrice;
   double farPrice = entryPrice + direction * tickSize;
   double farLoss = 0.0;

   for(int i = 0; i < 60; i++)
   {
      if(farPrice <= 0.0 ||
         !GuardianLossAtStop(
            orderType, symbol, volume,
            entryPrice, farPrice, farLoss
         ))
         return false;

      if(farLoss >= maxLoss)
         break;

      farPrice = entryPrice + (farPrice - entryPrice) * 2.0;
   }

   if(farLoss < maxLoss)
      return false;

   for(int i = 0; i < 50; i++)
   {
      double middle = (nearPrice + farPrice) / 2.0;
      double middleLoss = 0.0;

      if(!GuardianLossAtStop(
            orderType, symbol, volume,
            entryPrice, middle, middleLoss
         ))
         return false;

      if(middleLoss <= maxLoss)
         nearPrice = middle;
      else
         farPrice = middle;
   }

   double rounded = orderType == ORDER_TYPE_BUY ?
      MathCeil(nearPrice / tickSize) * tickSize :
      MathFloor(nearPrice / tickSize) * tickSize;

   newStop = NormalizeDouble(
      rounded,
      (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)
   );

   double finalLoss = 0.0;

   if(!GuardianLossAtStop(
         orderType, symbol, volume,
         entryPrice, newStop, finalLoss
      ) || finalLoss > maxLoss + 0.001)
      return false;

   if(orderType == ORDER_TYPE_BUY)
      return newStop <= closestValid + tickSize * 0.01;

   return newStop >= closestValid - tickSize * 0.01;
}

void GuardianEnforcePositionStopLossAmount(
   CTrade &trade,
   ulong positionID,
   double maxLoss
)
{
   if(!EnableMaxStopLossAmount || maxLoss <= 0.0 ||
      !GuardianSelectPositionByIdentifier(positionID))
      return;

   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   string symbol = PositionGetString(POSITION_SYMBOL);
   long positionType = PositionGetInteger(POSITION_TYPE);
   ENUM_ORDER_TYPE orderType = positionType == POSITION_TYPE_BUY ?
      ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double volume = PositionGetDouble(POSITION_VOLUME);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double existingStop = PositionGetDouble(POSITION_SL);
   double takeProfit = PositionGetDouble(POSITION_TP);

   if(ticket == 0 || volume <= 0.0 || entryPrice <= 0.0)
      return;

   double existingLoss = 0.0;

   if(existingStop > 0.0 &&
      GuardianLossAtStop(
         orderType, symbol, volume,
         entryPrice, existingStop, existingLoss
      ) && existingLoss <= maxLoss)
      return;

   double cappedStop = 0.0;

   if(!GuardianFindCappedStop(
         orderType, symbol, volume,
         entryPrice, maxLoss, cappedStop
      ))
   {
      if(GuardianShouldLogRiskFailure(positionID))
         Print(
            "GUARDIAN: CANNOT SET MAX SL AMOUNT | Position=", ticket,
            " | Symbol=", symbol,
            " | Limit=", DoubleToString(maxLoss, 2),
            " ", AccountInfoString(ACCOUNT_CURRENCY),
            " | Broker stop distance or current price prevents a valid SL"
         );
      return;
   }

   if(
      !trade.PositionModify(ticket, cappedStop, takeProfit) ||
      trade.ResultRetcode() != TRADE_RETCODE_DONE
   )
   {
      if(GuardianShouldLogRiskFailure(positionID))
         Print(
            "GUARDIAN: MAX SL UPDATE FAILED | Position=", ticket,
            " | Retcode=", trade.ResultRetcode(),
            " | ", trade.ResultRetcodeDescription()
         );
      return;
   }

   Print(
      "GUARDIAN: MAX SL APPLIED | Position=", ticket,
      " | SL=", DoubleToString(
         cappedStop,
         (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)
      ),
      " | Max planned loss=", DoubleToString(maxLoss, 2),
      " ", AccountInfoString(ACCOUNT_CURRENCY)
   );
}

void GuardianEnforceTrackedStopLossAmounts(CTrade &trade, double maxLoss)
{
   for(int i = ArraySize(GuardianRiskPositionIDs) - 1; i >= 0; i--)
   {
      ulong positionID = GuardianRiskPositionIDs[i];

      if(!GuardianSelectPositionByIdentifier(positionID))
      {
         int last = ArraySize(GuardianRiskPositionIDs) - 1;
         GlobalVariableDel(GuardianRiskPositionKey(positionID));
         GuardianRiskPositionIDs[i] = GuardianRiskPositionIDs[last];
         GuardianRiskLastFailureAt[i] = GuardianRiskLastFailureAt[last];
         ArrayResize(GuardianRiskPositionIDs, last);
         ArrayResize(GuardianRiskLastFailureAt, last);
         continue;
      }

      GuardianEnforcePositionStopLossAmount(trade, positionID, maxLoss);
   }
}

#endif
