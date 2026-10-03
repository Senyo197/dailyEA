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

// High-impact economic calendar releases that occur inside an
// entry window keep that window closed until this delay expires.
input bool BlockHighImpactNewsEntries = true;
input int  HighImpactNewsDelayMinutes = 10;

// Window 3 can use a longer delay before the New York session begins.
input int NewYorkSessionStartHour = 13;
input int NewYorkSessionStartMinute = 30;
input int HighImpactNewsDelayBeforeNewYorkMinutes = 20;

const int GuardianNewsCacheRefreshSeconds = 300;

datetime GuardianNewsCacheDay = 0;
datetime GuardianNewsCacheUpdatedAt = 0;
bool GuardianNewsCacheLoaded = false;
MqlCalendarValue GuardianHighImpactNews[];

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
         (16 * 60) + 30;

      return minutes <= fridayEnd;
   }

   // Saturday
   return false;
}

//==================================================
// HIGH-IMPACT NEWS ENTRY DELAY
//
// The MQL5 economic calendar and TimeCurrent() both
// use trade-server time, so their timestamps can be
// compared directly here.
//==================================================

datetime GuardianCalendarDayStart(
   datetime when
)
{
   MqlDateTime t;

   TimeToStruct(
      when,
      t
   );

   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;

   return StructToTime(t);
}

bool GuardianSameCalendarDay(
   datetime first,
   datetime second
)
{
   MqlDateTime firstTime;
   MqlDateTime secondTime;

   TimeToStruct(
      first,
      firstTime
   );

   TimeToStruct(
      second,
      secondTime
   );

   return (
      firstTime.year == secondTime.year &&
      firstTime.mon  == secondTime.mon &&
      firstTime.day  == secondTime.day
   );
}

bool GuardianTimesShareEntryWindow(
   datetime first,
   datetime second
)
{
   if(!GuardianSameCalendarDay(first, second))
      return false;

   int firstMinutes =
      GuardianMinutesOfDay(first);

   int secondMinutes =
      GuardianMinutesOfDay(second);

   return (
      (GuardianTimeInsideWindow(firstMinutes, Window1StartHour, Window1StartMinute, Window1EndHour, Window1EndMinute) &&
       GuardianTimeInsideWindow(secondMinutes, Window1StartHour, Window1StartMinute, Window1EndHour, Window1EndMinute)) ||
      (GuardianTimeInsideWindow(firstMinutes, Window2StartHour, Window2StartMinute, Window2EndHour, Window2EndMinute) &&
       GuardianTimeInsideWindow(secondMinutes, Window2StartHour, Window2StartMinute, Window2EndHour, Window2EndMinute)) ||
      (GuardianTimeInsideWindow(firstMinutes, Window3StartHour, Window3StartMinute, Window3EndHour, Window3EndMinute) &&
       GuardianTimeInsideWindow(secondMinutes, Window3StartHour, Window3StartMinute, Window3EndHour, Window3EndMinute)) ||
      (GuardianTimeInsideWindow(firstMinutes, Window4StartHour, Window4StartMinute, Window4EndHour, Window4EndMinute) &&
       GuardianTimeInsideWindow(secondMinutes, Window4StartHour, Window4StartMinute, Window4EndHour, Window4EndMinute)) ||
      (GuardianTimeInsideWindow(firstMinutes, Window5StartHour, Window5StartMinute, Window5EndHour, Window5EndMinute) &&
       GuardianTimeInsideWindow(secondMinutes, Window5StartHour, Window5StartMinute, Window5EndHour, Window5EndMinute))
   );
}

int GuardianHighImpactNewsDelayForRelease(
   datetime releaseTime
)
{
   int releaseMinutes =
      GuardianMinutesOfDay(releaseTime);

   int newYorkStartMinutes =
      (NewYorkSessionStartHour * 60) +
      NewYorkSessionStartMinute;

   bool releaseIsInWindow3 =
      GuardianTimeInsideWindow(
         releaseMinutes,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute
      );

   if(
      releaseIsInWindow3 &&
      releaseMinutes < newYorkStartMinutes &&
      HighImpactNewsDelayBeforeNewYorkMinutes > 0
   )
   {
      return HighImpactNewsDelayBeforeNewYorkMinutes;
   }

   return HighImpactNewsDelayMinutes;
}

bool GuardianLoadHighImpactNews(
   datetime when
)
{
   datetime dayStart =
      GuardianCalendarDayStart(when);

   bool cacheIsFresh =
      GuardianNewsCacheLoaded &&
      GuardianNewsCacheDay == dayStart &&
      (when - GuardianNewsCacheUpdatedAt) < GuardianNewsCacheRefreshSeconds;

   if(cacheIsFresh)
      return true;

   MqlCalendarValue values[];

   ResetLastError();

   int valueCount =
      CalendarValueHistory(
         values,
         dayStart,
         dayStart + 86400
      );

   if(valueCount < 0)
   {
      int error = GetLastError();

      Print(
         "GUARDIAN: ECONOMIC CALENDAR UNAVAILABLE | Error=",
         error
      );

      // Keep a previously loaded day cache available if a refresh fails.
      return (
         GuardianNewsCacheLoaded &&
         GuardianNewsCacheDay == dayStart
      );
   }

   ArrayResize(
      GuardianHighImpactNews,
      0
   );

   for(int i = 0;
       i < valueCount;
       i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(values[i].event_id, event))
         continue;

      // A release delay is meaningful only for events with an exact time.
      if(event.time_mode != CALENDAR_TIMEMODE_DATETIME)
         continue;

      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      int newsIndex =
         ArraySize(
            GuardianHighImpactNews
         );

      ArrayResize(
         GuardianHighImpactNews,
         newsIndex + 1
      );

      GuardianHighImpactNews[newsIndex] =
         values[i];
   }

   GuardianNewsCacheDay = dayStart;
   GuardianNewsCacheUpdatedAt = when;
   GuardianNewsCacheLoaded = true;

   return true;
}

bool GuardianHighImpactNewsDelayActive(
   datetime when,
   datetime &newsRelease
)
{
   newsRelease = 0;

   if(!BlockHighImpactNewsEntries)
      return false;

   if(HighImpactNewsDelayMinutes <= 0)
      return false;

   if(!GuardianIsInsideEntryWindow(when))
      return false;

   if(!GuardianLoadHighImpactNews(when))
      return false;

   int total =
      ArraySize(
         GuardianHighImpactNews
      );

   for(int i = 0;
       i < total;
       i++)
   {
      datetime releaseTime =
         GuardianHighImpactNews[i].time;

      if(!GuardianTimesShareEntryWindow(when, releaseTime))
         continue;

      int delayMinutes =
         GuardianHighImpactNewsDelayForRelease(
            releaseTime
         );

      datetime allowedAt =
         releaseTime +
         (delayMinutes * 60);

      if(when < allowedAt)
      {
         newsRelease = releaseTime;
         return true;
      }
   }

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

   datetime newsRelease = 0;

   if(
      GuardianHighImpactNewsDelayActive(
         when,
         newsRelease
      )
   )
   {
      return false;
   }

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

   datetime newsRelease = 0;

   if(
      GuardianHighImpactNewsDelayActive(
         now,
         newsRelease
      )
   )
   {
      return "NEWS WAIT";
   }

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
