#ifndef __MANUAL_TRADING_GUARDIAN_TRADE_ARM__
#define __MANUAL_TRADING_GUARDIAN_TRADE_ARM__

#include "Guardian_Toggles.mqh"
#include "Guardian_TradingWindows.mqh"

const string GuardianArmForexFactoryButton = "GuardianArmForexFactory";
const string GuardianArmTurningPointButton = "GuardianArmTurningPoint";
const string GuardianArmBothSidesButton = "GuardianArmBothSides";
const string GuardianArmTradeButton = "GuardianArmTrade";

bool GuardianForexFactoryChecked = false;
bool GuardianTurningPointChecked = false;
bool GuardianBothSidesChecked = false;
bool GuardianTradeArmed = false;
string GuardianArmedSymbol = "";
datetime GuardianArmExpiresAt = 0;
ulong GuardianPermittedOrderTicket = 0;

const int GuardianArmTradeLeadMinutes = 5;

bool GuardianChecklistComplete()
{
   return (
      GuardianForexFactoryChecked &&
      GuardianTurningPointChecked &&
      GuardianBothSidesChecked
   );
}

bool GuardianGetArmTradeWindowBounds(
   datetime when,
   string symbol,
   datetime &windowStart,
   datetime &windowEnd
)
{
   if(!EnforceTradingWindows)
      return false;

   if(!GuardianIsInsideWeeklyTradingPeriod(when, symbol))
      return false;

   MqlDateTime dateTime;

   TimeToStruct(when, dateTime);

   dateTime.hour = 0;
   dateTime.min = 0;
   dateTime.sec = 0;

   datetime dayStart = StructToTime(dateTime);

   datetime starts[];
   datetime ends[];
   bool enabled[];

   ArrayResize(starts, 5);
   ArrayResize(ends, 5);
   ArrayResize(enabled, 5);

   starts[0] = dayStart + ((Window1StartHour * 60 + Window1StartMinute) * 60);
   ends[0] = dayStart + ((Window1EndHour * 60 + Window1EndMinute) * 60) + 59;
   enabled[0] = EnableWindow1;

   starts[1] = dayStart + ((Window2StartHour * 60 + Window2StartMinute) * 60);
   ends[1] = dayStart + ((Window2EndHour * 60 + Window2EndMinute) * 60) + 59;
   enabled[1] = EnableWindow2;

   starts[2] = dayStart + ((Window3StartHour * 60 + Window3StartMinute) * 60);
   ends[2] = dayStart + ((Window3EndHour * 60 + Window3EndMinute) * 60) + 59;
   enabled[2] = (
      EnableWindow3 &&
      (!EnforceUSIndexOnlyWindow3 || GuardianIsUSIndexSymbol(symbol))
   );

   starts[3] = dayStart + ((Window4StartHour * 60 + Window4StartMinute) * 60);
   ends[3] = dayStart + ((Window4EndHour * 60 + Window4EndMinute) * 60) + 59;
   enabled[3] = EnableWindow4;

   starts[4] = dayStart + ((Window5StartHour * 60 + Window5StartMinute) * 60);
   ends[4] = dayStart + ((Window5EndHour * 60 + Window5EndMinute) * 60) + 59;
   enabled[4] = EnableWindow5;

   for(int i = 0;
       i < ArraySize(starts);
       i++)
   {
      if(!enabled[i])
         continue;

      if(
         when >= starts[i] - (GuardianArmTradeLeadMinutes * 60) &&
         when <= ends[i]
      )
      {
         windowStart = starts[i];
         windowEnd = ends[i];
         return true;
      }
   }

   return false;
}

void GuardianSetArmButton(
   string name,
   string text,
   int yDistance,
   color background
)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void GuardianClearExpiredTradeArm()
{
   if(
      GuardianTradeArmed &&
      TimeCurrent() >= GuardianArmExpiresAt
   )
   {
      GuardianTradeArmed = false;
      GuardianArmedSymbol = "";
      GuardianArmExpiresAt = 0;
      GuardianForexFactoryChecked = false;
      GuardianTurningPointChecked = false;
      GuardianBothSidesChecked = false;

      Print("GUARDIAN: ARM TRADE CONFIRMATION EXPIRED");
   }
}

void GuardianUpdateArmTradeControls()
{
   if(!EnableArmTradeConfirmation)
   {
      GuardianDeleteArmTradeControls();
      return;
   }

   GuardianClearExpiredTradeArm();

   datetime windowStart = 0;
   datetime windowEnd = 0;

   if(!GuardianGetArmTradeWindowBounds(
         TimeCurrent(),
         _Symbol,
         windowStart,
         windowEnd
      ))
   {
      GuardianResetTradeArm(true);
      GuardianDeleteArmTradeControls();
      return;
   }

   GuardianSetArmButton(
      GuardianArmForexFactoryButton,
      GuardianForexFactoryChecked ?
      "FOREX FACTORY: YES" : "FOREX FACTORY: CHECK",
      102,
      GuardianForexFactoryChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmTurningPointButton,
      GuardianTurningPointChecked ?
      "TURNING POINT: H4+" : "TURNING POINT: CHECK H4+",
      76,
      GuardianTurningPointChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmBothSidesButton,
      GuardianBothSidesChecked ?
      "APPROACH: BOTH SIDES" : "APPROACH: CHECK BOTH SIDES",
      50,
      GuardianBothSidesChecked ? clrDarkGreen : clrMaroon
   );

   string armText = "ARM TRADE: COMPLETE";
   color armColor = clrDarkSlateGray;

   if(GuardianTradeArmed)
   {
      armText = "ARMED: " + GuardianArmedSymbol;
      armColor = clrDarkGreen;
   }
   else if(GuardianChecklistComplete())
   {
      armText = "ARM TRADE";
      armColor = clrBlue;
   }

   GuardianSetArmButton(
      GuardianArmTradeButton,
      armText,
      24,
      armColor
   );
}

void GuardianDeleteArmTradeControls()
{
   ObjectDelete(0, GuardianArmForexFactoryButton);
   ObjectDelete(0, GuardianArmTurningPointButton);
   ObjectDelete(0, GuardianArmBothSidesButton);
   ObjectDelete(0, GuardianArmTradeButton);
}

void GuardianResetTradeArm(
   bool resetChecklist
)
{
   GuardianTradeArmed = false;
   GuardianArmedSymbol = "";
   GuardianArmExpiresAt = 0;

   if(resetChecklist)
   {
      GuardianForexFactoryChecked = false;
      GuardianTurningPointChecked = false;
      GuardianBothSidesChecked = false;
   }
}

void GuardianHandleTradeArmClick(
   string objectName
)
{
   if(!EnableArmTradeConfirmation)
      return;

   GuardianClearExpiredTradeArm();

   if(objectName == GuardianArmForexFactoryButton)
   {
      GuardianForexFactoryChecked = !GuardianForexFactoryChecked;
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmTurningPointButton)
   {
      GuardianTurningPointChecked = !GuardianTurningPointChecked;
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmBothSidesButton)
   {
      GuardianBothSidesChecked = !GuardianBothSidesChecked;
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmTradeButton)
   {
      datetime windowStart = 0;
      datetime windowEnd = 0;

      if(!GuardianGetArmTradeWindowBounds(
            TimeCurrent(),
            _Symbol,
            windowStart,
            windowEnd
         ))
      {
         Print("GUARDIAN: ARM TRADE IS AVAILABLE ONLY FOR AN ACTIVE ENTRY WINDOW");
      }
      else if(GuardianChecklistComplete())
      {
         GuardianTradeArmed = true;
         GuardianArmedSymbol = _Symbol;
         GuardianPermittedOrderTicket = 0;
         GuardianArmExpiresAt = windowEnd;

         Print(
            "GUARDIAN: TRADE ARMED | Symbol=",
            GuardianArmedSymbol,
            " | Expires=",
            TimeToString(
               GuardianArmExpiresAt,
               TIME_DATE | TIME_SECONDS
            )
         );
      }
      else
      {
         Print("GUARDIAN: COMPLETE THE CHECKLIST BEFORE ARMING A TRADE");
      }
   }

   GuardianUpdateArmTradeControls();
}

bool GuardianConsumeTradeArm(
   string symbol,
   ulong orderTicket,
   datetime tradeTime
)
{
   if(!EnableArmTradeConfirmation)
      return true;

   if(!EnforceTradingWindows)
      return true;

   GuardianClearExpiredTradeArm();

   datetime windowStart = 0;
   datetime windowEnd = 0;

   if(!GuardianGetArmTradeWindowBounds(
         tradeTime,
         symbol,
         windowStart,
         windowEnd
      ))
   {
      return false;
   }

   if(
      orderTicket != 0 &&
      orderTicket == GuardianPermittedOrderTicket
   )
   {
      return true;
   }

   if(
      !GuardianTradeArmed ||
      symbol != GuardianArmedSymbol ||
      tradeTime > GuardianArmExpiresAt
   )
   {
      GuardianUpdateArmTradeControls();
      return false;
   }

   GuardianPermittedOrderTicket = orderTicket;
   GuardianResetTradeArm(true);
   GuardianUpdateArmTradeControls();

   Print(
      "GUARDIAN: ARMED TRADE CONFIRMED | Symbol=",
      symbol
   );

   return true;
}

string GuardianTradeArmStatus()
{
   if(!EnableArmTradeConfirmation)
      return "OFF";

   GuardianClearExpiredTradeArm();

   datetime windowStart = 0;
   datetime windowEnd = 0;

   if(!GuardianGetArmTradeWindowBounds(
         TimeCurrent(),
         _Symbol,
         windowStart,
         windowEnd
      ))
   {
      return "WINDOW CLOSED";
   }

   if(GuardianTradeArmed)
      return "ARMED: " + GuardianArmedSymbol;

   return "REQUIRED";
}

#endif
