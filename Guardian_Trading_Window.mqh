#ifndef __MANUAL_TRADING_GUARDIAN_TRADING_WINDOWS__
#define __MANUAL_TRADING_GUARDIAN_TRADING_WINDOWS__

#include "Guardian_Time.mqh"

//==================================================
// ENTRY WINDOWS
//==================================================

// Window 1
input int Window1StartHour   = 5;
input int Window1StartMinute = 50;
input int Window1EndHour     = 6;
input int Window1EndMinute   = 30;

// Window 2
input int Window2StartHour   = 8;
input int Window2StartMinute = 50;
input int Window2EndHour     = 9;
input int Window2EndMinute   = 30;

// Window 3
input int Window3StartHour   = 11;
input int Window3StartMinute = 50;
input int Window3EndHour     = 14;
input int Window3EndMinute   = 50;

// Window 4
input int Window4StartHour   = 15;
input int Window4StartMinute = 50;
input int Window4EndHour     = 16;
input int Window4EndMinute   = 30;

// Window 5
input int Window5StartHour   = 20;
input int Window5StartMinute = 50;
input int Window5EndHour     = 22;
input int Window5EndMinute   = 30;

//==================================================
// CHECK TIME INSIDE WINDOW
//==================================================

bool GuardianTimeInsideWindow(
   int currentMinutes,
   int startHour,
   int startMinute,
   int endHour,
   int endMinute
)
{
   int start =
      (startHour * 60) +
      startMinute;

   int end =
      (endHour * 60) +
      endMinute;

   return (
      currentMinutes >= start &&
      currentMinutes <= end
   );
}

//==================================================
// CHECK DAILY ENTRY WINDOW
//==================================================

bool GuardianIsInsideEntryWindow(
   datetime when
)
{
   int currentMinutes =
      GuardianMinutesOfDay(when);

   // ---------------------------------------------
   // WINDOW 1
   // ---------------------------------------------

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window1StartHour,
         Window1StartMinute,
         Window1EndHour,
         Window1EndMinute
      ))
   {
      return true;
   }

   // ---------------------------------------------
   // WINDOW 2
   // ---------------------------------------------

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window2StartHour,
         Window2StartMinute,
         Window2EndHour,
         Window2EndMinute
      ))
   {
      return true;
   }

   // ---------------------------------------------
   // WINDOW 3
   // ---------------------------------------------

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute
      ))
   {
      return true;
   }

   // ---------------------------------------------
   // WINDOW 4
   // ---------------------------------------------

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window4StartHour,
         Window4StartMinute,
         Window4EndHour,
         Window4EndMinute
      ))
   {
      return true;
   }

   // ---------------------------------------------
   // WINDOW 5
   // ---------------------------------------------

   if(GuardianTimeInsideWindow(
         currentMinutes,
         Window5StartHour,
         Window5StartMinute,
         Window5EndHour,
         Window5EndMinute
      ))
   {
      return true;
   }

   return false;
}

//==================================================
// WEEKLY ENTRY PERIOD
//
// Monday 15:50
// THROUGH
// Friday 09:30
//==================================================

bool GuardianIsInsideWeeklyTradingPeriod(
   datetime when
)
{
   MqlDateTime t;

   TimeToStruct(
      when,
      t
   );

   int minutes =
      (t.hour * 60) +
      t.min;

   // Sunday
   if(t.day_of_week == 0)
      return false;

   // Monday
   if(t.day_of_week == 1)
   {
      int mondayStart =
         (15 * 60) + 50;

      return minutes >= mondayStart;
   }

   // Tuesday
   if(t.day_of_week == 2)
      return true;

   // Wednesday
   if(t.day_of_week == 3)
      return true;

   // Thursday
   if(t.day_of_week == 4)
      return true;

   // Friday
   if(t.day_of_week == 5)
   {
      int fridayEnd =
         (9 * 60) + 30;

      return minutes <= fridayEnd;
   }

   // Saturday
   return false;
}

//==================================================
// COMPLETE ENTRY PERMISSION
//
// Weekly period AND daily window must both be open.
//==================================================

bool GuardianEntryTimeAllowed(
   datetime when
)
{
   if(!GuardianIsInsideWeeklyTradingPeriod(when))
      return false;

   if(!GuardianIsInsideEntryWindow(when))
      return false;

   return true;
}

//==================================================
// STATUS TEXT
//==================================================

string GuardianEntryWindowStatus()
{
   datetime now =
      TimeCurrent();

   if(!GuardianIsInsideWeeklyTradingPeriod(now))
      return "CLOSED";

   if(!GuardianIsInsideEntryWindow(now))
      return "CLOSED";

   return "ACTIVE";
}

//==================================================
// WEEKLY STATUS TEXT
//==================================================

string GuardianWeeklyTradingStatus()
{
   if(
      GuardianIsInsideWeeklyTradingPeriod(
         TimeCurrent()
      )
   )
   {
      return "ACTIVE";
   }

   return "CLOSED";
}

#endif
