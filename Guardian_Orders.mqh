#ifndef __MANUAL_TRADING_GUARDIAN_ORDERS__
#define __MANUAL_TRADING_GUARDIAN_ORDERS__

#include <Trade/Trade.mqh>

//==================================================
// DELETE PENDING ORDERS
//==================================================

void GuardianDeletePendingOrders(
   CTrade &trade
)
{
   int total =
      OrdersTotal();

   for(int i = total - 1;
       i >= 0;
       i--)
   {
      ulong ticket =
         OrderGetTicket(i);

      if(ticket == 0)
         continue;

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)
         OrderGetInteger(
            ORDER_TYPE
         );

      bool pending = false;

      switch(type)
      {
         case ORDER_TYPE_BUY_LIMIT:
         case ORDER_TYPE_SELL_LIMIT:
         case ORDER_TYPE_BUY_STOP:
         case ORDER_TYPE_SELL_STOP:
         case ORDER_TYPE_BUY_STOP_LIMIT:
         case ORDER_TYPE_SELL_STOP_LIMIT:

            pending = true;
            break;
      }

      if(!pending)
         continue;

      ResetLastError();

      if(!trade.OrderDelete(ticket))
      {
         Print(
            "GUARDIAN: FAILED TO DELETE PENDING ORDER #",
            ticket,
            " | Retcode=",
            trade.ResultRetcode(),
            " | Description=",
            trade.ResultRetcodeDescription(),
            " | Error=",
            GetLastError()
         );
      }
      else
      {
         Print(
            "GUARDIAN: PENDING ORDER #",
            ticket,
            " DELETED."
         );
      }
   }
}

#endif
