#ifndef __MANUAL_TRADING_GUARDIAN_TRADE_ARM__
#define __MANUAL_TRADING_GUARDIAN_TRADE_ARM__

#include "Guardian_Toggles.mqh"
#include "Guardian_TradingWindows.mqh"

const string GuardianArmForexFactoryButton = "GuardianArmForexFactory";
const string GuardianArmTurningPointButton = "GuardianArmTurningPoint";
const string GuardianArmBothSidesButton = "GuardianArmBothSides";
const string GuardianArmBuildOrNotButton = "GuardianArmBuildOrNot";
const string GuardianArmDoublesButton = "GuardianArmDoubles";
const string GuardianArmLegAndKneeButton = "GuardianArmLegAndKnee";
const string GuardianArmTailBodyButton = "GuardianArmTailBody";
const string GuardianArmTradeButton = "GuardianArmTrade";
const string GuardianArmMoveHandle = "GuardianArmMoveHandle";

const int GuardianArmHeaderYDistance = 232;
int GuardianArmXDistance = 12;
int GuardianArmYOffset = 0;
bool GuardianArmPositionLoaded = false;

bool GuardianForexFactoryChecked = false;
bool GuardianTurningPointChecked = false;
bool GuardianBothSidesChecked = false;
bool GuardianBuildOrNotChecked = false;
string GuardianSelectedAbsoluteEntry = "";
bool GuardianTradeArmed = false;
string GuardianArmedSymbol = "";
datetime GuardianArmExpiresAt = 0;

const int GuardianArmTradeLeadMinutes = 5;

string GuardianArmExpiryKey(
   string symbol
)
{
   return "ManualTradingGuardian.Arm.Expiry." + symbol;
}

string GuardianArmPositionKey(string axis)
{
   return "ManualTradingGuardian.Checklist." +
          IntegerToString(ChartID()) + "." + axis;
}

void GuardianLoadArmPosition()
{
   if(GuardianArmPositionLoaded)
      return;

   GuardianArmPositionLoaded = true;
   double stored = 0.0;

   if(GlobalVariableGet(GuardianArmPositionKey("X"), stored))
      GuardianArmXDistance = (int)stored;

   if(GlobalVariableGet(GuardianArmPositionKey("Y"), stored))
      GuardianArmYOffset = (int)stored;
}

string GuardianArmOrderKey(
   string symbol
)
{
   return "ManualTradingGuardian.Arm.Order." + symbol;
}

string GuardianArmAbsoluteEntryKey(
   string symbol
)
{
   return "ManualTradingGuardian.Arm.AbsoluteEntry." + symbol;
}

string GuardianPositionAbsoluteEntryKey(
   string symbol,
   ulong positionID
)
{
   return (
      "ManualTradingGuardian.Position.AbsoluteEntry." +
      symbol + "." +
      IntegerToString((long)positionID)
   );
}

int GuardianAbsoluteEntryCode(
   string entryType
)
{
   if(entryType == "DOUBLES")
      return 1;

   if(entryType == "LEG & KNEE")
      return 2;

   if(entryType == "TAILBODY")
      return 3;

   return 0;
}

string GuardianAbsoluteEntryName(
   double entryCode
)
{
   if((int)entryCode == 1)
      return "DOUBLES";

   if((int)entryCode == 2)
      return "LEG & KNEE";

   if((int)entryCode == 3)
      return "TAILBODY";

   return "";
}

bool GuardianGetSharedArmExpiry(
   string symbol,
   datetime &expiresAt
)
{
   double storedExpiry = 0.0;

   if(!GlobalVariableGet(GuardianArmExpiryKey(symbol), storedExpiry))
      return false;

   expiresAt = (datetime)storedExpiry;

   if(TimeCurrent() < expiresAt)
      return true;

   GlobalVariableDel(GuardianArmExpiryKey(symbol));
   return false;
}

bool GuardianChecklistComplete()
{
   return (
      GuardianForexFactoryChecked &&
      GuardianTurningPointChecked &&
      GuardianBothSidesChecked &&
      GuardianBuildOrNotChecked &&
      GuardianSelectedAbsoluteEntry != ""
   );
}

bool GuardianGetArmTradeWindowBounds(
   datetime when,
   string symbol,
   datetime &windowStart,
   datetime &windowEnd,
   int &windowNumber
)
{
   windowNumber = 0;

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

      // A US congressional or presidential election day permits only
      // Windows 1 and 2, including their five-minute ARM lead-in.
      if(
         i >= 2 &&
         GuardianUSCongressAndPresidentialElectionDayActive(when)
      )
      {
         continue;
      }

      if(
         when >= starts[i] - (GuardianArmTradeLeadMinutes * 60) &&
         when <= ends[i]
      )
      {
         windowStart = starts[i];
         windowEnd = ends[i];
          windowNumber = i + 1;
         return true;
      }
   }

   return false;
}

bool GuardianArmRequiredForWindow(int windowNumber)
{
   if(windowNumber == 1)
      return RequireArmTradeWindow1;
   if(windowNumber == 2)
      return RequireArmTradeWindow2;
   if(windowNumber == 3)
      return RequireArmTradeWindow3;
   if(windowNumber == 4)
      return RequireArmTradeWindow4;
   if(windowNumber == 5)
      return RequireArmTradeWindow5;

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
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, GuardianArmXDistance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDistance + GuardianArmYOffset);
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

void GuardianSetArmMoveHandle()
{
   if(ObjectFind(0, GuardianArmMoveHandle) < 0)
   {
      if(!ObjectCreate(0, GuardianArmMoveHandle, OBJ_BUTTON, 0, 0, 0))
         return;

      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_XDISTANCE, GuardianArmXDistance);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_YDISTANCE,
                       GuardianArmHeaderYDistance + GuardianArmYOffset);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_XSIZE, 240);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_YSIZE, 22);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_SELECTED, true);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_BACK, false);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_HIDDEN, true);
   }

   ObjectSetString(0, GuardianArmMoveHandle, OBJPROP_TEXT, "DRAG CHECKLIST HERE");
   ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_STATE, false);
}

void GuardianHandleArmDrag(string objectName)
{
   if(objectName != GuardianArmMoveHandle ||
      ObjectFind(0, GuardianArmMoveHandle) < 0)
      return;

   int x = (int)ObjectGetInteger(0, GuardianArmMoveHandle, OBJPROP_XDISTANCE);
   int y = (int)ObjectGetInteger(0, GuardianArmMoveHandle, OBJPROP_YDISTANCE);
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   GuardianArmXDistance = MathMax(0, x);
   if(chartWidth > 240)
      GuardianArmXDistance = MathMin(GuardianArmXDistance, chartWidth - 240);

   GuardianArmYOffset = MathMax(-22, y - GuardianArmHeaderYDistance);
   if(chartHeight > 254)
      GuardianArmYOffset = MathMin(GuardianArmYOffset, chartHeight - 254);

   ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_XDISTANCE, GuardianArmXDistance);
   ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_YDISTANCE,
                    GuardianArmHeaderYDistance + GuardianArmYOffset);
   GlobalVariableSet(GuardianArmPositionKey("X"), (double)GuardianArmXDistance);
   GlobalVariableSet(GuardianArmPositionKey("Y"), (double)GuardianArmYOffset);

   GuardianUpdateArmTradeControls();
   ChartRedraw(0);
}

void GuardianClearExpiredTradeArm()
{
   datetime sharedExpiry = 0;

   GuardianGetSharedArmExpiry(_Symbol, sharedExpiry);

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
      GuardianBuildOrNotChecked = false;
      GuardianSelectedAbsoluteEntry = "";

      Print("GUARDIAN: ARM TRADE CONFIRMATION EXPIRED");
   }
}

void GuardianUpdateArmTradeControls()
{
   GuardianLoadArmPosition();
   GuardianClearExpiredTradeArm();

   datetime windowStart = 0;
   datetime windowEnd = 0;
   int windowNumber = 0;

   if(!GuardianGetArmTradeWindowBounds(
         TimeCurrent(),
         _Symbol,
         windowStart,
         windowEnd,
         windowNumber
       ))
   {
      GuardianResetTradeArm(true);
      GuardianDeleteArmTradeControls();
      return;
   }

   GuardianSetArmMoveHandle();

   GuardianSetArmButton(
      GuardianArmForexFactoryButton,
      GuardianForexFactoryChecked ?
      "FOREX FACTORY: YES" : "FOREX FACTORY: CHECK",
      206,
      GuardianForexFactoryChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmTurningPointButton,
      GuardianTurningPointChecked ?
      "TURNING POINT: H4+" : "TURNING POINT: CHECK H4+",
      180,
      GuardianTurningPointChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmBothSidesButton,
      GuardianBothSidesChecked ?
      "APPROACH: BOTH SIDES" : "APPROACH: CHECK BOTH SIDES",
      154,
      GuardianBothSidesChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmBuildOrNotButton,
      GuardianBuildOrNotChecked ?
      "45: BUILD OR NOT? YES" : "45: BUILD OR NOT? CHECK",
      128,
      GuardianBuildOrNotChecked ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmDoublesButton,
      "ABS ENTRY: DOUBLES",
      102,
      GuardianSelectedAbsoluteEntry == "DOUBLES" ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmLegAndKneeButton,
      "ABS ENTRY: LEG & KNEE",
      76,
      GuardianSelectedAbsoluteEntry == "LEG & KNEE" ? clrDarkGreen : clrMaroon
   );

   GuardianSetArmButton(
      GuardianArmTailBodyButton,
      "ABS ENTRY: TAILBODY",
      50,
      GuardianSelectedAbsoluteEntry == "TAILBODY" ? clrDarkGreen : clrMaroon
   );

   if(!EnableArmTradeConfirmation || !GuardianArmRequiredForWindow(windowNumber))
   {
      ObjectDelete(0, GuardianArmTradeButton);
      return;
   }

   string armText = "ARM TRADE: COMPLETE";
   color armColor = clrDarkSlateGray;

   datetime sharedExpiry = 0;

   if(
      GuardianTradeArmed ||
      GuardianGetSharedArmExpiry(_Symbol, sharedExpiry)
   )
   {
      armText = "ARMED: " + _Symbol;
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
   ObjectDelete(0, GuardianArmMoveHandle);
   ObjectDelete(0, GuardianArmForexFactoryButton);
   ObjectDelete(0, GuardianArmTurningPointButton);
   ObjectDelete(0, GuardianArmBothSidesButton);
   ObjectDelete(0, GuardianArmBuildOrNotButton);
   ObjectDelete(0, GuardianArmDoublesButton);
   ObjectDelete(0, GuardianArmLegAndKneeButton);
   ObjectDelete(0, GuardianArmTailBodyButton);
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
      GuardianBuildOrNotChecked = false;
      GuardianSelectedAbsoluteEntry = "";
   }
}

void GuardianHandleTradeArmClick(
   string objectName
)
{
   if(objectName == GuardianArmMoveHandle)
   {
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_STATE, false);
      ObjectSetInteger(0, GuardianArmMoveHandle, OBJPROP_SELECTED, true);
      return;
   }

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
   else if(objectName == GuardianArmBuildOrNotButton)
   {
      GuardianBuildOrNotChecked = !GuardianBuildOrNotChecked;
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmDoublesButton)
   {
      GuardianSelectedAbsoluteEntry = "DOUBLES";
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmLegAndKneeButton)
   {
      GuardianSelectedAbsoluteEntry = "LEG & KNEE";
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmTailBodyButton)
   {
      GuardianSelectedAbsoluteEntry = "TAILBODY";
      GuardianResetTradeArm(false);
   }
   else if(objectName == GuardianArmTradeButton)
   {
      if(!EnableArmTradeConfirmation)
         return;

      datetime windowStart = 0;
      datetime windowEnd = 0;
      int windowNumber = 0;

      if(!GuardianGetArmTradeWindowBounds(
            TimeCurrent(),
            _Symbol,
            windowStart,
            windowEnd,
            windowNumber
          ) || !GuardianArmRequiredForWindow(windowNumber))
      {
         Print("GUARDIAN: ARM TRADE IS AVAILABLE ONLY FOR AN ACTIVE ENTRY WINDOW");
      }
      else if(GuardianChecklistComplete())
      {
         GuardianTradeArmed = true;
         GuardianArmedSymbol = _Symbol;
         GuardianArmExpiresAt = windowEnd;

         GlobalVariableSet(
            GuardianArmExpiryKey(GuardianArmedSymbol),
            (double)GuardianArmExpiresAt
         );
         GlobalVariableDel(
            GuardianArmOrderKey(GuardianArmedSymbol)
         );
         GlobalVariableSet(
            GuardianArmAbsoluteEntryKey(GuardianArmedSymbol),
            (double)GuardianAbsoluteEntryCode(
               GuardianSelectedAbsoluteEntry
            )
         );

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
   ulong positionID,
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
   int windowNumber = 0;

   if(!GuardianGetArmTradeWindowBounds(
         tradeTime,
         symbol,
         windowStart,
         windowEnd,
         windowNumber
      ))
   {
      return false;
   }

   if(!GuardianArmRequiredForWindow(windowNumber))
      return true;

   double storedOrder = 0.0;

   if(
      orderTicket != 0 &&
      GlobalVariableGet(GuardianArmOrderKey(symbol), storedOrder) &&
      orderTicket == (ulong)storedOrder
   )
   {
      return true;
   }

   datetime sharedExpiry = 0;

   if(
      !GuardianGetSharedArmExpiry(symbol, sharedExpiry) ||
      tradeTime > sharedExpiry
   )
   {
      GuardianUpdateArmTradeControls();
      return false;
   }


   double entryCode = 0.0;

   if(
      positionID != 0 &&
      GlobalVariableGet(
         GuardianArmAbsoluteEntryKey(symbol),
         entryCode
      ) &&
      GuardianAbsoluteEntryName(entryCode) != ""
   )
   {
      GlobalVariableSet(
         GuardianPositionAbsoluteEntryKey(symbol, positionID),
         entryCode
      );
   }

   GlobalVariableSet(
      GuardianArmOrderKey(symbol),
      (double)orderTicket
   );
   GlobalVariableDel(GuardianArmExpiryKey(symbol));
   GlobalVariableDel(GuardianArmAbsoluteEntryKey(symbol));
   GuardianResetTradeArm(true);
   GuardianUpdateArmTradeControls();

   Print(
      "GUARDIAN: ARMED TRADE CONFIRMED | Symbol=",
      symbol
   );

   return true;
}

string GuardianOpenAbsoluteEntryStatus()
{
   string details = "";
   int taggedPositions = 0;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong positionTicket = PositionGetTicket(i);

      if(positionTicket == 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong positionID = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double entryCode = 0.0;

      if(
         positionID == 0 ||
         !GlobalVariableGet(
            GuardianPositionAbsoluteEntryKey(symbol, positionID),
            entryCode
         )
      )
      {
         continue;
      }

      string entryName = GuardianAbsoluteEntryName(entryCode);

      if(entryName == "")
         continue;

      if(taggedPositions > 0)
         details += "\n";

      details += (
         symbol + ": " +
         entryName +
         " (#" +
         IntegerToString((long)positionID) +
         ")"
      );

      taggedPositions++;
   }

   if(taggedPositions == 0)
      return "NONE";

   return details;
}

string GuardianTradeArmStatus()
{
   if(!EnableArmTradeConfirmation)
      return "OFF";

   GuardianClearExpiredTradeArm();

   datetime windowStart = 0;
   datetime windowEnd = 0;
   int windowNumber = 0;

   if(!GuardianGetArmTradeWindowBounds(
         TimeCurrent(),
         _Symbol,
         windowStart,
         windowEnd,
         windowNumber
      ))
   {
      return "WINDOW CLOSED";
   }

   if(!GuardianArmRequiredForWindow(windowNumber))
      return "OFF (WINDOW " + IntegerToString(windowNumber) + ")";

   datetime sharedExpiry = 0;

   if(
      GuardianTradeArmed ||
      GuardianGetSharedArmExpiry(_Symbol, sharedExpiry)
   )
      return "ARMED: " + _Symbol;

   return "REQUIRED";
}

#endif
