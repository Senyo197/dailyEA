#ifndef __MANUAL_TRADING_GUARDIAN_ENTRY_LIMITS__
#define __MANUAL_TRADING_GUARDIAN_ENTRY_LIMITS__

#include "Guardian_History.mqh"
#include "Guardian_TradingWindows.mqh"

// A symbol is locked for the remainder of an entry window after
// one actual SL or two negative manual closes.
input bool EnforcePairLossLimitPerEntryWindow = true;
input int MaxActualStopLossesPerPairPerEntryWindow = 1;
input int MaxNegativeManualClosesPerPairPerEntryWindow = 2;

// Window 3 permits one manual entry per symbol before the split and
// one from the split onward. Entries exactly at the split use period two.
input int Window3TradeSplitHour = 13;
input int Window3TradeSplitMinute = 50;

bool GuardianBuildEntryWindowBounds(
   datetime when,
   int startHour,
   int startMinute,
   int endHour,
   int endMinute,
   datetime &windowStart,
   datetime &windowEnd
)
{
   MqlDateTime startTime;
   MqlDateTime endTime;

   TimeToStruct(
      when,
      startTime
   );

   endTime = startTime;

   startTime.hour = startHour;
   startTime.min  = startMinute;
   startTime.sec  = 0;

   endTime.hour = endHour;
   endTime.min  = endMinute;
   endTime.sec  = 59;

   windowStart =
      StructToTime(startTime);

   windowEnd =
      StructToTime(endTime);

   return true;
}

bool GuardianGetEntryWindowBounds(
   datetime when,
   datetime &windowStart,
   datetime &windowEnd
)
{
   int currentMinutes =
      GuardianMinutesOfDay(when);

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window1StartHour,
         Window1StartMinute,
         Window1EndHour,
         Window1EndMinute
      ))
   {
      return GuardianBuildEntryWindowBounds(
         when,
         Window1StartHour,
         Window1StartMinute,
         Window1EndHour,
         Window1EndMinute,
         windowStart,
         windowEnd
      );
   }

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window2StartHour,
         Window2StartMinute,
         Window2EndHour,
         Window2EndMinute
      ))
   {
      return GuardianBuildEntryWindowBounds(
         when,
         Window2StartHour,
         Window2StartMinute,
         Window2EndHour,
         Window2EndMinute,
         windowStart,
         windowEnd
      );
   }

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute
      ))
   {
      return GuardianBuildEntryWindowBounds(
         when,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute,
         windowStart,
         windowEnd
      );
   }

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window4StartHour,
         Window4StartMinute,
         Window4EndHour,
         Window4EndMinute
      ))
   {
      return GuardianBuildEntryWindowBounds(
         when,
         Window4StartHour,
         Window4StartMinute,
         Window4EndHour,
         Window4EndMinute,
         windowStart,
         windowEnd
      );
   }

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window5StartHour,
         Window5StartMinute,
         Window5EndHour,
         Window5EndMinute
      ))
   {
      return GuardianBuildEntryWindowBounds(
         when,
         Window5StartHour,
         Window5StartMinute,
         Window5EndHour,
         Window5EndMinute,
         windowStart,
         windowEnd
      );
   }

   return false;
}

bool GuardianGetWindow3TradeSegmentBounds(
   datetime entryTime,
   datetime &segmentStart,
   datetime &segmentEnd
)
{
   int currentMinutes =
      GuardianMinutesOfDay(entryTime);

   if(!GuardianTimeInsideWindow(
         currentMinutes,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute
      ))
   {
      return false;
   }

   int window3StartMinutes =
      (Window3StartHour * 60) +
      Window3StartMinute;

   int window3EndMinutes =
      (Window3EndHour * 60) +
      Window3EndMinute;

   int splitMinutes =
      (Window3TradeSplitHour * 60) +
      Window3TradeSplitMinute;

   if(
      splitMinutes <= window3StartMinutes ||
      splitMinutes > window3EndMinutes
   )
   {
      return false;
   }

   datetime windowStart = 0;
   datetime windowEnd = 0;

   GuardianBuildEntryWindowBounds(
      entryTime,
      Window3StartHour,
      Window3StartMinute,
      Window3EndHour,
      Window3EndMinute,
      windowStart,
      windowEnd
   );

   MqlDateTime splitTime;

   TimeToStruct(entryTime, splitTime);

   splitTime.hour = Window3TradeSplitHour;
   splitTime.min = Window3TradeSplitMinute;
   splitTime.sec = 0;

   datetime splitAt = StructToTime(splitTime);

   if(entryTime < splitAt)
   {
      segmentStart = windowStart;
      segmentEnd = splitAt - 1;
   }
   else
   {
      segmentStart = splitAt;
      segmentEnd = windowEnd;
   }

   return true;
}

bool GuardianWindow3TradeLimitExceeded(
   string symbol,
   datetime entryTime
)
{
   datetime segmentStart = 0;
   datetime segmentEnd = 0;

   if(!GuardianGetWindow3TradeSegmentBounds(
         entryTime,
         segmentStart,
         segmentEnd
      ))
   {
      return false;
   }

   ResetLastError();

   if(!HistorySelect(segmentStart, entryTime))
   {
      Print(
         "GUARDIAN: CANNOT VERIFY WINDOW 3 TRADE LIMIT | Error=",
         GetLastError()
      );

      return false;
   }

   int manualEntries = 0;
   int totalDeals = HistoryDealsTotal();

   for(int i = 0;
       i < totalDeals;
       i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);

      if(dealTicket == 0)
         continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != symbol)
         continue;

      long reason = HistoryDealGetInteger(dealTicket, DEAL_REASON);

      if(!GuardianIsManualDealReason(reason))
         continue;

      manualEntries++;

      if(manualEntries > 1)
      {
         Print(
            "GUARDIAN: WINDOW 3 TRADE LIMIT REACHED | Symbol=",
            symbol,
            " | Segment=",
            TimeToString(segmentStart, TIME_DATE | TIME_MINUTES),
            " - ",
            TimeToString(segmentEnd, TIME_MINUTES)
         );

         return true;
      }
   }

   return false;
}

bool GuardianPairLossLimitReached(
   string symbol,
   datetime entryTime
)
{
   if(!EnforcePairLossLimitPerEntryWindow)
      return false;

   datetime windowStart = 0;
   datetime windowEnd = 0;

   if(!GuardianGetEntryWindowBounds(
         entryTime,
         windowStart,
         windowEnd
      ))
   {
      return false;
   }

   ResetLastError();

   if(!HistorySelect(
         windowStart,
         entryTime
      ))
   {
      Print(
         "GUARDIAN: CANNOT VERIFY PAIR LOSS LIMIT | Error=",
         GetLastError()
      );

      return false;
   }

   int totalDeals =
      HistoryDealsTotal();

   int actualStopLosses = 0;
   int negativeManualCloses = 0;

   for(int i = 0;
       i < totalDeals;
       i++)
   {
      ulong dealTicket =
         HistoryDealGetTicket(i);

      if(dealTicket == 0)
         continue;

      long entry =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_ENTRY
         );

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      string dealSymbol =
         HistoryDealGetString(
            dealTicket,
            DEAL_SYMBOL
         );

      if(dealSymbol != symbol)
         continue;

      long reason =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );

      if(
         reason == DEAL_REASON_SL &&
         MaxActualStopLossesPerPairPerEntryWindow > 0
      )
      {
         ulong positionID =
            (ulong)HistoryDealGetInteger(
               dealTicket,
               DEAL_POSITION_ID
            );

         if(
            positionID != 0 &&
            GuardianIsExemptSL(
               dealTicket,
               positionID
            )
         )
         {
            // GuardianIsExemptSL selects a position-specific history range.
            HistorySelect(
               windowStart,
               entryTime
            );

            continue;
         }

         actualStopLosses++;

         if(
            actualStopLosses >=
            MaxActualStopLossesPerPairPerEntryWindow
         )
         {
            Print(
               "GUARDIAN: PAIR LOSS LIMIT REACHED | Symbol=",
               symbol,
               " | Reason=Actual SL | Window=",
               TimeToString(
                  windowStart,
                  TIME_DATE | TIME_MINUTES
               ),
               " - ",
               TimeToString(
                  windowEnd,
                  TIME_MINUTES
               )
            );

            return true;
         }

         continue;
      }

      if(!GuardianIsManualDealReason(reason))
         continue;

      double result =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PROFIT
         )
         +
         HistoryDealGetDouble(
            dealTicket,
            DEAL_SWAP
         )
         +
         HistoryDealGetDouble(
            dealTicket,
            DEAL_COMMISSION
         )
         +
         HistoryDealGetDouble(
            dealTicket,
            DEAL_FEE
         );

      if(result >= 0.0)
         continue;

      negativeManualCloses++;

      if(
         MaxNegativeManualClosesPerPairPerEntryWindow > 0 &&
         negativeManualCloses >=
         MaxNegativeManualClosesPerPairPerEntryWindow
      )
      {
         Print(
            "GUARDIAN: PAIR LOSS LIMIT REACHED | Symbol=",
            symbol,
            " | Reason=Negative Manual Closes | Count=",
            negativeManualCloses,
            " | Window=",
            TimeToString(
               windowStart,
               TIME_DATE | TIME_MINUTES
            ),
            " - ",
            TimeToString(
               windowEnd,
               TIME_MINUTES
            )
         );

         return true;
      }
   }

   return false;
}

#endif
