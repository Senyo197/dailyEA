#property strict
#property version "4.17"

#include <Trade/Trade.mqh>

#include <ManualTradingGuardian/Guardian_Toggles.mqh>
#include <ManualTradingGuardian/Guardian_Time.mqh>
#include <ManualTradingGuardian/Guardian_TradingWindows.mqh>
#include <ManualTradingGuardian/Guardian_History.mqh>
#include <ManualTradingGuardian/Guardian_EntryLimits.mqh>
#include <ManualTradingGuardian/Guardian_TradeArm.mqh>
#include <ManualTradingGuardian/Guardian_Statistics.mqh>
#include <ManualTradingGuardian/Guardian_Lock.mqh>
#include <ManualTradingGuardian/Guardian_Orders.mqh>
#include <ManualTradingGuardian/Guardian_StopLossAmount.mqh>
#include <ManualTradingGuardian/Guardian_Panel.mqh>

CTrade Trade;
datetime GuardianWeeklyAmountLockWeek = 0;

//==================================================
// INPUTS
//==================================================

input int MaxDailyLosses  = 2;
input int MaxWeeklyLosses = 4;
input double MaxWeeklyLossAmount = 50.0;
input double MaxStopLossAmount = 15.0;

//==================================================
// CHECK LOSS LIMITS
//==================================================

void CheckLossLimits()
{
   datetime currentGMTWeek = GuardianGMTWeekStart();

   if(
      GuardianWeeklyAmountLockWeek != 0 &&
      GuardianWeeklyAmountLockWeek != currentGMTWeek
   )
   {
      GuardianWeeklyAmountLockWeek = 0;
      TradingLockActive = false;
      TradingLockTime = 0;
   }

   int dailyExempt = 0;
   int weeklyExempt = 0;

   //================================================
   // ACTUAL SLs
   //================================================

   int dailyActualSL =
      GuardianDailySLCount(
         dailyExempt
      );

   int weeklyActualSL =
      GuardianWeeklySLCount(
         weeklyExempt
      );

   //================================================
   // NEGATIVE MANUAL CLOSES
   //================================================

   int dailyNegative =
      GuardianDailyNegativeCloses();

   int weeklyNegative =
      GuardianWeeklyNegativeCloses();

   //================================================
   // EVERY 2 NEGATIVE CLOSES = 1 SL
   //================================================

   int dailyConvertedSL =
      GuardianNegativeClosesToSL(
         dailyNegative
      );

   int weeklyConvertedSL =
      GuardianNegativeClosesToSL(
         weeklyNegative
      );

   //================================================
   // TOTAL COUNTED SLs
   //================================================

   int dailyLosses =
      dailyActualSL +
      dailyConvertedSL;

   int weeklyLosses =
      weeklyActualSL +
      weeklyConvertedSL;

   //================================================
   // DAILY LIMIT
   //================================================

   if(
      EnableDailyLossLimit &&
      dailyLosses >= MaxDailyLosses
   )
   {
      if(!TradingLockActive)
      {
         TradingLockActive = true;

         TradingLockTime =
            TimeCurrent();

         Print(
            "GUARDIAN: DAILY LOCK ACTIVATED | ",
            "Actual SLs=",
            dailyActualSL,
            " | Negative Closes=",
            dailyNegative,
            " | Converted SLs=",
            dailyConvertedSL,
            " | Total=",
            dailyLosses,
            " | Lock Time=",
            TimeToString(
               TradingLockTime,
               TIME_DATE | TIME_SECONDS
            )
         );
      }
   }

   //================================================
   // WEEKLY LIMIT
   //================================================

   if(
      EnableWeeklyLossLimit &&
      weeklyLosses >= MaxWeeklyLosses
   )
   {
      if(!TradingLockActive)
      {
         TradingLockActive = true;

         TradingLockTime =
            TimeCurrent();

         Print(
            "GUARDIAN: WEEKLY LOCK ACTIVATED | ",
            "Actual SLs=",
            weeklyActualSL,
            " | Negative Closes=",
            weeklyNegative,
            " | Converted SLs=",
            weeklyConvertedSL,
            " | Total=",
            weeklyLosses,
            " | Lock Time=",
            TimeToString(
               TradingLockTime,
               TIME_DATE | TIME_SECONDS
            )
         );
      }
   }

   if(
      EnableWeeklyLossAmountLimit &&
      MaxWeeklyLossAmount > 0.0 &&
      GuardianRealizedProfit(GuardianWeekStart()) <= -MaxWeeklyLossAmount
   )
   {
      GuardianWeeklyAmountLockWeek = currentGMTWeek;

      if(!TradingLockActive)
      {
         TradingLockActive = true;
         TradingLockTime = TimeCurrent();
         Print(
            "GUARDIAN: WEEKLY AMOUNT LOCK ACTIVATED | Net P/L=",
            DoubleToString(
               GuardianRealizedProfit(GuardianWeekStart()),
               2
            ),
            " ", AccountInfoString(ACCOUNT_CURRENCY),
            " | Limit=", DoubleToString(MaxWeeklyLossAmount, 2)
         );
      }
   }
}

//==================================================
// CHECK NEW MANUAL ENTRY
//==================================================

void GuardianCheckManualEntry(
   ulong dealTicket
)
{
   if(dealTicket == 0)
      return;

   long entry =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_ENTRY
      );

   if(
      entry != DEAL_ENTRY_IN &&
      entry != DEAL_ENTRY_INOUT
   )
   {
      return;
   }

   long reason =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_REASON
      );

   // Only manual trades
   if(
      !GuardianIsManualDealReason(reason)
   )
   {
      return;
   }

   datetime tradeTime =
      (datetime)
      HistoryDealGetInteger(
         dealTicket,
         DEAL_TIME
      );

   string symbol =
      HistoryDealGetString(
         dealTicket,
         DEAL_SYMBOL
      );

   // Each chart instance validates only manual entries for its own symbol.
   if(symbol != _Symbol)
      return;

   ulong orderTicket =
      (ulong)HistoryDealGetInteger(
         dealTicket,
         DEAL_ORDER
      );

   ulong positionID =
      (ulong)HistoryDealGetInteger(
         dealTicket,
         DEAL_POSITION_ID
      );

   bool tradeArmConfirmed =
      GuardianConsumeTradeArm(
         symbol,
         orderTicket,
         positionID,
         tradeTime
      );

   //================================================
   // ENTRY OUTSIDE ALLOWED PERIOD
   //================================================

   datetime newsRelease = 0;

   bool blockedByHighImpactNews =
      GuardianHighImpactNewsDelayActive(
         tradeTime,
         newsRelease,
         symbol
      );

   bool entryTimeAllowed =
      GuardianEntryTimeAllowed(
         tradeTime,
         symbol
      );

   bool entryLimitReached = false;
   bool window3TradeLimitExceeded = false;

   if(entryTimeAllowed)
   {
      entryLimitReached =
         GuardianPairLossLimitReached(
            symbol,
            tradeTime
         );

      window3TradeLimitExceeded =
         GuardianWindow3TradeLimitExceeded(
            symbol,
            tradeTime
         );
   }

   if(
      !tradeArmConfirmed ||
      !entryTimeAllowed ||
      entryLimitReached ||
      window3TradeLimitExceeded
   )
   {
      Print(
         "GUARDIAN: UNAUTHORIZED MANUAL ENTRY | ",
         "Deal=",
         dealTicket,
         " | Position ID=",
         positionID,
         " | Time=",
         TimeToString(
            tradeTime,
            TIME_DATE | TIME_SECONDS
         )
      );

      if(!tradeArmConfirmed)
      {
         Print(
            "GUARDIAN: ARM TRADE CONFIRMATION REQUIRED | Symbol=",
            symbol
         );
      }

      if(blockedByHighImpactNews)
      {
         Print(
            "GUARDIAN: HIGH-IMPACT NEWS ENTRY BLOCK | ",
            "Release=",
            TimeToString(
               newsRelease,
               TIME_DATE | TIME_SECONDS
            ),
            " | Allowed After=",
            TimeToString(
               newsRelease +
               (GuardianHighImpactNewsDelayForRelease(newsRelease) * 60),
               TIME_DATE | TIME_SECONDS
            )
         );
      }

      if(
         positionID != 0 &&
         PositionSelectByTicket(positionID)
      )
      {
         ResetLastError();

         bool closed =
            Trade.PositionClose(
               positionID
            );

         if(!closed)
         {
            Print(
               "GUARDIAN: FAILED TO CLOSE ",
               "UNAUTHORIZED POSITION #",
               positionID,
               " | Retcode=",
               Trade.ResultRetcode(),
               " | Description=",
               Trade.ResultRetcodeDescription(),
               " | Error=",
               GetLastError()
            );
         }
         else
         {
            Print(
               "GUARDIAN: UNAUTHORIZED POSITION ",
               "CLOSE REQUEST SENT | #",
               positionID
            );
         }
      }

      return;
   }

   if(positionID != 0 && !TradingLockActive)
   {
      GuardianTrackPositionRisk(positionID);
      GuardianEnforcePositionStopLossAmount(
         Trade, positionID, MaxStopLossAmount
      );
   }
}

//==================================================
// ENFORCE ENTRY WINDOWS ON RECENT POSITIONS
//==================================================

void GuardianEnforceEntryWindows()
{
   int total =
      PositionsTotal();

   datetime now =
      TimeCurrent();

   for(int i = total - 1;
       i >= 0;
       i--)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      datetime openTime =
         (datetime)
         PositionGetInteger(
            POSITION_TIME
         );

      // Don't touch positions that existed
      // before this EA started.
      if(openTime < GuardianEAStartTime)
         continue;

      long reason =
         PositionGetInteger(
            POSITION_REASON
         );

      // Only manually opened positions.
      if(
         reason != POSITION_REASON_CLIENT &&
         reason != POSITION_REASON_MOBILE &&
         reason != POSITION_REASON_WEB
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      datetime newsRelease = 0;

      bool blockedByHighImpactNews =
         GuardianHighImpactNewsDelayActive(
            openTime,
            newsRelease,
            symbol
         );

      if(!GuardianEntryTimeAllowed(openTime, symbol))
      {
         Print(
            "GUARDIAN: POSITION OUTSIDE ENTRY WINDOW | ",
            "Ticket=",
            ticket,
            " | OpenTime=",
            TimeToString(
               openTime,
               TIME_DATE | TIME_SECONDS
            ),
            " | Current=",
            TimeToString(
               now,
               TIME_DATE | TIME_SECONDS
            )
         );

         if(blockedByHighImpactNews)
         {
            Print(
               "GUARDIAN: HIGH-IMPACT NEWS ENTRY BLOCK | ",
               "Release=",
               TimeToString(
                  newsRelease,
                  TIME_DATE | TIME_SECONDS
               ),
               " | Allowed After=",
               TimeToString(
                  newsRelease +
                  (GuardianHighImpactNewsDelayForRelease(newsRelease) * 60),
                  TIME_DATE | TIME_SECONDS
               )
            );
         }

         ResetLastError();

         bool closed =
            Trade.PositionClose(
               ticket
            );

         if(!closed)
         {
            Print(
               "GUARDIAN: FAILED TO CLOSE ",
               "OUT-OF-WINDOW POSITION #",
               ticket,
               " | Retcode=",
               Trade.ResultRetcode(),
               " | Description=",
               Trade.ResultRetcodeDescription(),
               " | Error=",
               GetLastError()
            );
         }
      }
   }
}

//==================================================
// ENFORCE LOCK
//==================================================

void EnforceTradingLock()
{
   if(!TradingLockActive)
      return;

   if(TradingLockTime <= 0)
      return;

   //================================================
   // DELETE PENDING ORDERS
   //================================================

   GuardianDeletePendingOrders(
      Trade
   );

   //================================================
   // CLOSE ONLY POSITIONS OPENED
   // AFTER THE LOCK
   //================================================

   GuardianClosePositionsAfterLock(
      Trade,
      TradingLockTime
   );
}

//==================================================
// INIT
//==================================================

int OnInit()
{
   TradingLockActive = false;

   TradingLockTime = 0;

   GuardianEAStartTime =
      TimeCurrent();

   GuardianRestoreTrackedPositionRisks();

   CheckLossLimits();

   //================================================
   // IF EA STARTS WHILE LIMIT IS ALREADY REACHED
   //================================================

   if(TradingLockActive)
   {
      TradingLockTime =
         TimeCurrent();

      Print(
         "GUARDIAN: EA STARTED WHILE ",
         "LIMIT ALREADY REACHED."
      );
   }

   GuardianUpdatePanel(
      MaxDailyLosses,
      MaxWeeklyLosses
   );

   Print(
      "MANUAL TRADING GUARDIAN v4.10 STARTED"
   );

   return INIT_SUCCEEDED;
}

//==================================================
// TICK
//==================================================

void OnTick()
{
   CheckLossLimits();

   if(!TradingLockActive)
      GuardianEnforceTrackedStopLossAmounts(Trade, MaxStopLossAmount);

   //================================================
   // ENFORCE PERMITTED ENTRY WINDOWS
   //================================================

   GuardianEnforceEntryWindows();

   //================================================
   // ENFORCE LOSS LOCK
   //================================================

   EnforceTradingLock();

   GuardianUpdatePanel(
      MaxDailyLosses,
      MaxWeeklyLosses
   );
}

//==================================================
// TRADE TRANSACTION
//==================================================

void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   //================================================
   // ONLY PROCESS NEWLY ADDED DEALS
   //================================================

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket =
         trans.deal;

      if(dealTicket != 0)
      {
         ResetLastError();

         if(
            HistoryDealSelect(
               dealTicket
            )
         )
         {
            GuardianCheckManualEntry(
               dealTicket
            );
         }
      }
   }

   //================================================
   // RECALCULATE IMMEDIATELY
   //================================================

   CheckLossLimits();

   if(!TradingLockActive)
      GuardianEnforceTrackedStopLossAmounts(Trade, MaxStopLossAmount);

   //================================================
   // IMMEDIATELY ENFORCE LOCK
   //================================================

   EnforceTradingLock();

   GuardianUpdatePanel(
      MaxDailyLosses,
      MaxWeeklyLosses
   );
}

//==================================================
// CHART CHECKLIST CONTROLS
//==================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam
)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
      GuardianHandleTradeArmClick(sparam);
}

//==================================================
// DEINIT
//==================================================

void OnDeinit(
   const int reason
)
{
   GuardianDeleteArmTradeControls();
   Comment("");
}
