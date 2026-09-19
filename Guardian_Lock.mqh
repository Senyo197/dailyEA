#ifndef __MANUAL_TRADING_GUARDIAN_LOCK__
#define __MANUAL_TRADING_GUARDIAN_LOCK__

#include <Trade/Trade.mqh>

//==================================================
// GLOBAL TRADING LOCK STATE
//==================================================

bool TradingLockActive = false;

datetime TradingLockTime = 0;

//==================================================
// EA START TIME
//
// Used so the EA doesn't suddenly close old
// positions when it is attached/restarted.
//==================================================

datetime GuardianEAStartTime = 0;

//==================================================
// CLOSE POSITIONS OPENED AFTER LOCK
//==================================================

void GuardianClosePositionsAfterLock(
   CTrade &trade,
   datetime lockTime
)
{
   int total =
      PositionsTotal();

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

      if(openTime < lockTime)
         continue;

      Print(
         "GUARDIAN: NEW POSITION DETECTED AFTER LOCK | ",
         "Ticket=",
         ticket
      );

      ResetLastError();

      bool closed =
         trade.PositionClose(ticket);

      if(!closed)
      {
         Print(
            "GUARDIAN: FAILED TO CLOSE POSITION #",
            ticket,
            " | Retcode=",
            trade.ResultRetcode(),
            " | Description=",
            trade.ResultRetcodeDescription(),
            " | LastError=",
            GetLastError()
         );
      }
      else
      {
         Print(
            "GUARDIAN: CLOSE REQUEST SENT | ",
            "POSITION #",
            ticket
         );
      }
   }
}

#endif
