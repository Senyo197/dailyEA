#ifndef __MANUAL_TRADING_GUARDIAN_HISTORY__
#define __MANUAL_TRADING_GUARDIAN_HISTORY__

#include "Guardian_Time.mqh"

//==================================================
// MANUAL DEAL REASON
//==================================================

bool GuardianIsManualDealReason(
   long reason
)
{
   return (
      reason == DEAL_REASON_CLIENT ||
      reason == DEAL_REASON_MOBILE ||
      reason == DEAL_REASON_WEB
   );
}

//==================================================
// CHECK WHETHER POSITION ID ALREADY EXISTS
//==================================================

bool GuardianPositionIDExists(
   ulong positionID,
   ulong &ids[]
)
{
   int size =
      ArraySize(ids);

   for(int i = 0; i < size; i++)
   {
      if(ids[i] == positionID)
         return true;
   }

   return false;
}

//==================================================
// GET ORIGINAL ENTRY INFORMATION
//==================================================

bool GuardianGetEntryInfoForPosition(
   ulong positionID,
   double &entryPrice,
   ENUM_DEAL_TYPE &positionType
)
{
   entryPrice   = 0.0;
   positionType = WRONG_VALUE;

   if(positionID == 0)
      return false;

   ResetLastError();

   if(!HistorySelectByPosition(positionID))
   {
      Print(
         "GUARDIAN: HistorySelectByPosition failed | ",
         "Position ID=",
         positionID,
         " | Error=",
         GetLastError()
      );

      return false;
   }

   datetime earliest =
      D'2099.12.31 23:59:59';

   bool found = false;

   int totalDeals =
      HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
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
         entry != DEAL_ENTRY_IN &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      datetime dealTime =
         (datetime)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_TIME
         );

      if(dealTime < earliest)
      {
         earliest = dealTime;

         entryPrice =
            HistoryDealGetDouble(
               dealTicket,
               DEAL_PRICE
            );

         positionType =
            (ENUM_DEAL_TYPE)
            HistoryDealGetInteger(
               dealTicket,
               DEAL_TYPE
            );

         found = true;
      }
   }

   return found;
}

//==================================================
// DETERMINE WHETHER SL WAS EXEMPT
//==================================================

bool GuardianIsExemptSL(
   ulong dealTicket,
   ulong positionID
)
{
   double entryPrice = 0.0;

   ENUM_DEAL_TYPE positionType;

   if(!GuardianGetEntryInfoForPosition(
         positionID,
         entryPrice,
         positionType
      ))
   {
      Print(
         "GUARDIAN: Could not determine original entry | ",
         "Position ID=",
         positionID,
         " | SL Deal=",
         dealTicket
      );

      return false;
   }

   double closePrice =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PRICE
      );

   if(
      entryPrice <= 0.0 ||
      closePrice <= 0.0
   )
   {
      return false;
   }

   // BUY
   if(positionType == DEAL_TYPE_BUY)
   {
      if(closePrice >= entryPrice)
      {
         Print(
            "GUARDIAN: BUY SL EXEMPT | ",
            "Position ID=",
            positionID,
            " | Entry=",
            DoubleToString(
               entryPrice,
               _Digits
            ),
            " | Close=",
            DoubleToString(
               closePrice,
               _Digits
            )
         );

         return true;
      }
   }

   // SELL
   if(positionType == DEAL_TYPE_SELL)
   {
      if(closePrice <= entryPrice)
      {
         Print(
            "GUARDIAN: SELL SL EXEMPT | ",
            "Position ID=",
            positionID,
            " | Entry=",
            DoubleToString(
               entryPrice,
               _Digits
            ),
            " | Close=",
            DoubleToString(
               closePrice,
               _Digits
            )
         );

         return true;
      }
   }

   return false;
}

//==================================================
// COUNT REAL STOP-LOSS EVENTS
//==================================================

int GuardianCountSLHits(
   datetime fromTime,
   int &exemptCount
)
{
   exemptCount = 0;

   ResetLastError();

   if(!HistorySelect(
         fromTime,
         TimeCurrent()
      ))
   {
      Print(
         "GUARDIAN: HistorySelect failed. Error=",
         GetLastError()
      );

      return 0;
   }

   ulong countedPositions[];
   ulong exemptPositions[];

   int losses = 0;

   int totalDeals =
      HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket =
         HistoryDealGetTicket(i);

      if(dealTicket == 0)
         continue;

      long entryType =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_ENTRY
         );

      if(
         entryType != DEAL_ENTRY_OUT &&
         entryType != DEAL_ENTRY_OUT_BY &&
         entryType != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      long reason =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );

      // ONLY REAL SL
      if(reason != DEAL_REASON_SL)
         continue;

      ulong positionID =
         (ulong)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_POSITION_ID
         );

      if(positionID == 0)
         continue;

      if(
         GuardianPositionIDExists(
            positionID,
            countedPositions
         )
      )
      {
         continue;
      }

      if(
         GuardianPositionIDExists(
            positionID,
            exemptPositions
         )
      )
      {
         continue;
      }

      bool exempt =
         GuardianIsExemptSL(
            dealTicket,
            positionID
         );

      // Restore selected history.
      HistorySelect(
         fromTime,
         TimeCurrent()
      );

      if(exempt)
      {
         int exemptSize =
            ArraySize(
               exemptPositions
            );

         ArrayResize(
            exemptPositions,
            exemptSize + 1
         );

         exemptPositions[
            exemptSize
         ] = positionID;

         exemptCount++;

         continue;
      }

      int lossSize =
         ArraySize(
            countedPositions
         );

      ArrayResize(
         countedPositions,
         lossSize + 1
      );

      countedPositions[
         lossSize
      ] = positionID;

      losses++;
   }

   return losses;
}

//==================================================
// COUNT NEGATIVE MANUAL CLOSES
//
// Only manual CLIENT / MOBILE / WEB closes.
// Only negative result.
//==================================================

int GuardianCountNegativeManualCloses(
   datetime fromTime
)
{
   ResetLastError();

   if(!HistorySelect(
         fromTime,
         TimeCurrent()
      ))
   {
      Print(
         "GUARDIAN: HistorySelect failed | Error=",
         GetLastError()
      );

      return 0;
   }

   int negativeCloses = 0;

   int totalDeals =
      HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket =
         HistoryDealGetTicket(i);

      if(dealTicket == 0)
         continue;

      long entryType =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_ENTRY
         );

      // Manual close / exit
      if(
         entryType != DEAL_ENTRY_OUT &&
         entryType != DEAL_ENTRY_OUT_BY &&
         entryType != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      long reason =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );

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

      if(result < 0.0)
      {
         negativeCloses++;
      }
   }

   return negativeCloses;
}

//==================================================
// CONVERT NEGATIVE MANUAL CLOSES TO SLs
//
// Every 2 negative closes = 1 SL
//==================================================

int GuardianNegativeClosesToSL(
   int negativeCloses
)
{
   return negativeCloses / 2;
}

//==================================================
// DAILY SL COUNT
//==================================================

int GuardianDailySLCount(
   int &exemptCount
)
{
   return GuardianCountSLHits(
      GuardianTodayStart(),
      exemptCount
   );
}

//==================================================
// WEEKLY SL COUNT
//==================================================

int GuardianWeeklySLCount(
   int &exemptCount
)
{
   return GuardianCountSLHits(
      GuardianWeekStart(),
      exemptCount
   );
}

//==================================================
// DAILY NEGATIVE CLOSES
//==================================================

int GuardianDailyNegativeCloses()
{
   return GuardianCountNegativeManualCloses(
      GuardianTodayStart()
   );
}

//==================================================
// WEEKLY NEGATIVE CLOSES
//==================================================

int GuardianWeeklyNegativeCloses()
{
   return GuardianCountNegativeManualCloses(
      GuardianWeekStart()
   );
}

#endif
