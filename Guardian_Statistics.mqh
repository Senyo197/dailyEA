#ifndef __MANUAL_TRADING_GUARDIAN_STATISTICS__
#define __MANUAL_TRADING_GUARDIAN_STATISTICS__

#include "Guardian_History.mqh"

//==================================================
// COUNT MANUAL EXECUTED TRADES
//
// Entry:
// CLIENT
// MOBILE
// WEB
//
// DEAL_ENTRY_IN and DEAL_ENTRY_INOUT
//==================================================

int GuardianExecutedTrades(
   datetime fromTime
)
{
   ResetLastError();

   if(!HistorySelect(
         fromTime,
         TimeCurrent()
      ))
   {
      return 0;
   }

   int trades = 0;

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

      long reason =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );

      if(
         !GuardianIsManualDealReason(reason)
      )
      {
         continue;
      }

      trades++;
   }

   return trades;
}

//==================================================
// REALIZED PROFIT
//
// Includes:
// DEAL_PROFIT
// DEAL_SWAP
// DEAL_COMMISSION
// DEAL_FEE
//
// For outgoing deals.
//==================================================

double GuardianRealizedProfit(
   datetime fromTime
)
{
   ResetLastError();

   if(!HistorySelect(
         fromTime,
         TimeCurrent()
      ))
   {
      return 0.0;
   }

   double profit = 0.0;

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
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      profit +=
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PROFIT
         );

      profit +=
         HistoryDealGetDouble(
            dealTicket,
            DEAL_SWAP
         );

      profit +=
         HistoryDealGetDouble(
            dealTicket,
            DEAL_COMMISSION
         );

      profit +=
         HistoryDealGetDouble(
            dealTicket,
            DEAL_FEE
         );
   }

   return profit;
}

//==================================================
// CURRENT OPEN POSITIONS
//==================================================

int GuardianOpenPositions()
{
   return PositionsTotal();
}

//==================================================
// CURRENT FLOATING PROFIT
//==================================================

double GuardianFloatingProfit()
{
   double profit = 0.0;

   int total =
      PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      profit +=
         PositionGetDouble(
            POSITION_PROFIT
         );

      profit +=
         PositionGetDouble(
            POSITION_SWAP
         );
   }

   return profit;
}

#endif
