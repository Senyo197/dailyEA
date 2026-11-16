#ifndef __MANUAL_TRADING_GUARDIAN_TRADING_WINDOWS__
#define __MANUAL_TRADING_GUARDIAN_TRADING_WINDOWS__

#include "Guardian_Toggles.mqh"
#include "Guardian_Time.mqh"

//==================================================
// ENTRY WINDOWS
//==================================================

// Window 1
input int Window1StartHour   = 6;
input int Window1StartMinute = 50;
input int Window1EndHour     = 7;
input int Window1EndMinute   = 30;

// Window 2
input int Window2StartHour   = 9;
input int Window2StartMinute = 50;
input int Window2EndHour     = 10;
input int Window2EndMinute   = 30;

// Window 3
input int Window3StartHour   = 12;
input int Window3StartMinute = 50;
input int Window3EndHour     = 13;
input int Window3EndMinute   = 50;

// Window 4
input int Window4StartHour   = 16;
input int Window4StartMinute = 50;
input int Window4EndHour     = 17;
input int Window4EndMinute   = 30;

// Window 5
input int Window5StartHour   = 21;
input int Window5StartMinute = 50;
input int Window5EndHour     = 23;
input int Window5EndMinute   = 30;

// High-impact economic calendar releases that occur inside an
// entry window keep that window closed until this delay expires.
input int  HighImpactNewsDelayMinutes = 10;

// GMT+0 entries separated by semicolons:
// 2026.11.16 17:00|SEC Chair speech;2026.11.17 13:30|Other release
input string ManualHighImpactNewsGMT = "";

// MT5 publishes US bank holidays under their individual holiday names.
input string USBankHolidayNameMarkers =
   "BANK HOLIDAY,NEW YEAR,MARTIN LUTHER KING,WASHINGTON'S BIRTHDAY,"
   "PRESIDENTS DAY,MEMORIAL DAY,JUNETEENTH,INDEPENDENCE DAY,LABOR DAY,"
   "COLUMBUS DAY,INDIGENOUS PEOPLES DAY,VETERANS DAY,THANKSGIVING DAY,"
   "CHRISTMAS DAY";

// Window 3 can use a longer delay before the New York session begins.
input int NewYorkSessionStartHour = 14;
input int NewYorkSessionStartMinute = 30;
input int HighImpactNewsDelayBeforeNewYorkMinutes = 20;

// Each marker is matched anywhere in the broker symbol name.
input string USIndexSymbolMarkers = "NAS,NASDAQ,USTEC,US100,NDX,NQ100,TECH100,US500,SPX500,SPX,US30,DJ30,DOW,US2000,RUSSELL,RTY";

const int GuardianNewsCacheRefreshSeconds = 300;

datetime GuardianNewsCacheDay = 0;
datetime GuardianNewsCacheUpdatedAt = 0;
bool GuardianNewsCacheLoaded = false;
bool GuardianNewsCacheRefreshFailed = false;
MqlCalendarValue GuardianHighImpactNews[];

struct GuardianManualHighImpactEvent
{
   datetime releaseGMT;
   string name;
};

GuardianManualHighImpactEvent GuardianManualHighImpactNews[];
bool GuardianManualHighImpactNewsLoaded = false;
bool GuardianManualHighImpactNewsInputError = false;

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
   datetime when,
   string symbol = ""
)
{
   if(!EnforceTradingWindows)
      return true;

   int currentMinutes =
      GuardianMinutesOfDay(when);

   // ---------------------------------------------
   // WINDOW 1
   // ---------------------------------------------

   if(EnableWindow1 && GuardianTimeInsideWindow(
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

   if(EnableWindow2 && GuardianTimeInsideWindow(
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

   if(EnableWindow3 && GuardianTimeInsideWindow(
         currentMinutes,
         Window3StartHour,
         Window3StartMinute,
         Window3EndHour,
         Window3EndMinute
      ))
   {
      if(GuardianUSCongressAndPresidentialElectionDayActive(when))
         return false;

      return (
         !EnforceUSIndexOnlyWindow3 ||
         GuardianIsUSIndexSymbol(symbol)
      );
   }

   // ---------------------------------------------
   // WINDOW 4
   // ---------------------------------------------

   if(EnableWindow4 && GuardianTimeInsideWindow(
         currentMinutes,
         Window4StartHour,
         Window4StartMinute,
         Window4EndHour,
         Window4EndMinute
      ))
   {
      if(GuardianUSCongressAndPresidentialElectionDayActive(when))
         return false;

      return true;
   }

   // ---------------------------------------------
   // WINDOW 5
   // ---------------------------------------------

   if(EnableWindow5 && GuardianTimeInsideWindow(
         currentMinutes,
         Window5StartHour,
         Window5StartMinute,
         Window5EndHour,
         Window5EndMinute
      ))
   {
      if(GuardianUSCongressAndPresidentialElectionDayActive(when))
         return false;

      return true;
   }

   return false;
}

bool GuardianIsUSIndexSymbol(
   string symbol
)
{
   string symbolName = symbol;

   StringToUpper(symbolName);

   string markers[];
   ushort separator =
      StringGetCharacter(
         ",",
         0
      );

   int total =
      StringSplit(
         USIndexSymbolMarkers,
         separator,
         markers
      );

   for(int i = 0;
       i < total;
       i++)
   {
      string marker = markers[i];

      StringTrimLeft(marker);
      StringTrimRight(marker);
      StringToUpper(marker);

      if(
         StringLen(marker) > 0 &&
         StringFind(symbolName, marker) >= 0
      )
      {
         return true;
      }
   }

   return false;
}

//==================================================
// WEEKLY ENTRY PERIOD
//
// Monday through Friday, subject to the daily windows.
//==================================================

bool GuardianIsInsideWeeklyTradingPeriod(
   datetime when,
   string symbol = ""
)
{
   if(!EnforceWeeklyTradingPeriod)
      return true;

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

   // Monday through Thursday
   if(t.day_of_week >= 1 && t.day_of_week <= 4)
      return true;

   // Friday
   if(t.day_of_week == 5)
   {
      int fridayEnd =
         (17 * 60) + 30;

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

int GuardianLoadUSCalendarDayValues(
   datetime dayStart,
   bool limitToUSDCurrency,
   string checkName,
   MqlCalendarValue &values[]
)
{
   ResetLastError();

   int valueCount;

   if(limitToUSDCurrency)
      valueCount =
         CalendarValueHistory(
            values,
            dayStart,
            dayStart + 86400,
            "US",
            "USD"
         );
   else
      valueCount =
         CalendarValueHistory(
            values,
            dayStart,
            dayStart + 86400,
            "US"
         );

   if(valueCount >= 0)
      return valueCount;

   Print(
      "GUARDIAN: CANNOT CHECK ",
      checkName,
      " | Error=",
      GetLastError()
   );

   return -1;
}

bool GuardianIsUSCongressOrPresidentialElectionEvent(
   MqlCalendarEvent &event
)
{
   MqlCalendarCountry country;

   if(!CalendarCountryById(event.country_id, country))
      return false;

   if(country.code != "US")
      return false;

   string eventName = event.name;

   StringToUpper(eventName);

   return (
      StringFind(eventName, "PRESIDENTIAL ELECTION") >= 0 ||
      StringFind(eventName, "CONGRESSIONAL ELECTION") >= 0 ||
      StringFind(eventName, "CONGRESS ELECTION") >= 0
   );
}

bool GuardianUSCongressAndPresidentialElectionDayActive(
   datetime when
)
{
   if(!RestrictUSCongressAndPresidentialElectionDays)
      return false;

   static datetime cachedDay = 0;
   static bool cacheLoaded = false;
   static bool restrictionActive = false;

   datetime dayStart = GuardianCalendarDayStart(when);

   if(cacheLoaded && cachedDay == dayStart)
      return restrictionActive;

   MqlCalendarValue values[];

   int valueCount = GuardianLoadUSCalendarDayValues(
      dayStart,
      false,
      "US ELECTION DAY",
      values
   );

   if(valueCount < 0)
      return false;

   restrictionActive = false;

   for(int i = 0; i < valueCount; i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(values[i].event_id, event))
         continue;

      if(GuardianIsUSCongressOrPresidentialElectionEvent(event))
      {
         restrictionActive = true;
         break;
      }
   }

   cachedDay = dayStart;
   cacheLoaded = true;

   return restrictionActive;
}

bool GuardianIsCPIOrNFPEvent(
   MqlCalendarEvent &event
)
{
   string eventName = event.name;

   StringToUpper(eventName);

   return (
      StringFind(eventName, "CPI") >= 0 ||
      StringFind(eventName, "NONFARM") >= 0 ||
      StringFind(eventName, "NFP") >= 0
   );
}

bool GuardianIsRateDecisionEvent(
   MqlCalendarEvent &event
)
{
   string eventName = event.name;

   StringToUpper(eventName);

   return StringFind(eventName, "RATE DECISION") >= 0;
}

bool GuardianIsNonFridayWindow5(
   datetime when
)
{
   MqlDateTime dateTime;

   TimeToStruct(when, dateTime);

   if(dateTime.day_of_week == 5)
      return false;

   return GuardianTimeInsideWindow(
      GuardianMinutesOfDay(when),
      Window5StartHour,
      Window5StartMinute,
      Window5EndHour,
      Window5EndMinute
   );
}

bool GuardianIsFOMCMinutesEvent(
   MqlCalendarEvent &event
)
{
   string eventName = event.name;

   StringToUpper(eventName);

   return (
      StringFind(eventName, "FOMC") >= 0 &&
      StringFind(eventName, "MINUTES") >= 0
   );
}

bool GuardianFullDayNewsBlackoutActive(
   datetime when
)
{
   if(!BlockFOMCCPINFPReleaseDays)
      return false;

   static datetime cachedDay = 0;
   static bool cacheLoaded = false;
   static bool unconditionalBlackoutActive = false;
   static bool cpiOrNFPBlackoutActive = false;

   datetime dayStart =
      GuardianCalendarDayStart(when);

   if(!cacheLoaded || cachedDay != dayStart)
   {
      MqlCalendarValue values[];

      int valueCount =
         GuardianLoadUSCalendarDayValues(
            dayStart,
            true,
            "FULL-DAY NEWS BLACKOUT",
            values
         );

      if(valueCount < 0)
         return false;

      unconditionalBlackoutActive = false;
      cpiOrNFPBlackoutActive = false;

      for(int i = 0; i < valueCount; i++)
      {
         MqlCalendarEvent event;

         if(!CalendarEventById(values[i].event_id, event))
            continue;

         if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;

         if(GuardianIsCPIOrNFPEvent(event))
         {
            cpiOrNFPBlackoutActive = true;
            continue;
         }

         if(GuardianIsRateDecisionEvent(event))
            unconditionalBlackoutActive = true;
      }

      cachedDay = dayStart;
      cacheLoaded = true;
   }

   return (
      unconditionalBlackoutActive ||
      (cpiOrNFPBlackoutActive &&
       !(EnableNonFridayCPIOrNFPWindow5Exemption &&
         GuardianIsNonFridayWindow5(when)))
   );
}

bool GuardianIsUSBankHolidayEvent(
   MqlCalendarEvent &event
)
{
   MqlCalendarCountry country;

   if(!CalendarCountryById(event.country_id, country))
      return false;

   if(country.code != "US")
      return false;

   if(event.importance != CALENDAR_IMPORTANCE_NONE)
      return false;

   if(event.type != CALENDAR_TYPE_HOLIDAY)
      return false;

   if(event.sector != CALENDAR_SECTOR_HOLIDAYS)
      return false;

   string eventName = event.name;

   StringToUpper(eventName);

   string markers[];
   ushort separator = StringGetCharacter(",", 0);
   int total = StringSplit(
      USBankHolidayNameMarkers,
      separator,
      markers
   );

   for(int i = 0;
       i < total;
       i++)
   {
      string marker = markers[i];

      StringTrimLeft(marker);
      StringTrimRight(marker);
      StringToUpper(marker);

      if(
         StringLen(marker) > 0 &&
         StringFind(eventName, marker) >= 0
      )
      {
         return true;
      }
   }

   return false;
}

bool GuardianUSBankHolidayBlackoutActive(
   datetime when
)
{
   if(!BlockUSBankHolidays)
      return false;

   static datetime cachedDay = 0;
   static bool cacheLoaded = false;
   static bool blackoutActive = false;

   datetime dayStart =
      GuardianCalendarDayStart(when);

   if(cacheLoaded && cachedDay == dayStart)
      return blackoutActive;

   MqlCalendarValue values[];

   int valueCount =
      GuardianLoadUSCalendarDayValues(
         dayStart,
         false,
         "US BANK HOLIDAY",
         values
      );

   if(valueCount < 0)
      return false;

   blackoutActive = false;

   for(int i = 0;
       i < valueCount;
       i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(values[i].event_id, event))
         continue;

      if(GuardianIsUSBankHolidayEvent(event))
      {
         blackoutActive = true;
         break;
      }
   }

   cachedDay = dayStart;
   cacheLoaded = true;

   return blackoutActive;
}

bool GuardianFOMCMinutesWindowBlockActive(
   datetime when
)
{
   if(!BlockFOMCMinutesAfterWindow2)
      return false;

   int currentMinutes =
      GuardianMinutesOfDay(when);

   int window2EndMinutes =
      (Window2EndHour * 60) +
      Window2EndMinute;

   // Window 2 itself remains available, including its final minute.
   if(currentMinutes <= window2EndMinutes)
      return false;

   static datetime cachedDay = 0;
   static bool cacheLoaded = false;
   static bool blockActive = false;

   datetime dayStart =
      GuardianCalendarDayStart(when);

   if(cacheLoaded && cachedDay == dayStart)
      return blockActive;

   MqlCalendarValue values[];

   int valueCount =
      GuardianLoadUSCalendarDayValues(
         dayStart,
         true,
         "FOMC MINUTES BLOCK",
         values
      );

   if(valueCount < 0)
      return false;

   blockActive = false;

   for(int i = 0;
       i < valueCount;
       i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(values[i].event_id, event))
         continue;

      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      if(GuardianIsFOMCMinutesEvent(event))
      {
         blockActive = true;
         break;
      }
   }

   cachedDay = dayStart;
   cacheLoaded = true;

   return blockActive;
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
      EnableWindow3ExtendedNewsWait &&
      HighImpactNewsDelayBeforeNewYorkMinutes > 0
   )
   {
      return HighImpactNewsDelayBeforeNewYorkMinutes;
   }

   return HighImpactNewsDelayMinutes;
}

void GuardianLoadManualHighImpactNews()
{
   if(GuardianManualHighImpactNewsLoaded)
      return;

   GuardianManualHighImpactNewsLoaded = true;
   GuardianManualHighImpactNewsInputError = false;
   ArrayResize(GuardianManualHighImpactNews, 0);

   if(StringLen(ManualHighImpactNewsGMT) == 0)
      return;

   string records[];
   int recordCount = StringSplit(
      ManualHighImpactNewsGMT,
      StringGetCharacter(";", 0),
      records
   );

   for(int i = 0; i < recordCount; i++)
   {
      string record = records[i];
      StringTrimLeft(record);
      StringTrimRight(record);

      if(StringLen(record) == 0)
         continue;

      int separator = StringFind(record, "|");

      if(separator < 0)
      {
         GuardianManualHighImpactNewsInputError = true;
         Print("GUARDIAN: INVALID MANUAL NEWS ENTRY | ", record,
               " | Expected YYYY.MM.DD HH:MM|Name (GMT+0)");
         continue;
      }

      string timeText = StringSubstr(record, 0, separator);
      string name = StringSubstr(record, separator + 1);
      StringTrimLeft(timeText);
      StringTrimRight(timeText);
      StringTrimLeft(name);
      StringTrimRight(name);

      datetime releaseGMT = StringToTime(timeText);

      if(StringLen(timeText) != 16 ||
         TimeToString(releaseGMT, TIME_DATE | TIME_MINUTES) != timeText ||
         StringLen(name) == 0)
      {
         GuardianManualHighImpactNewsInputError = true;
         Print("GUARDIAN: INVALID MANUAL NEWS ENTRY | ", record,
               " | Expected YYYY.MM.DD HH:MM|Name (GMT+0)");
         continue;
      }

      int index = ArraySize(GuardianManualHighImpactNews);
      ArrayResize(GuardianManualHighImpactNews, index + 1);
      GuardianManualHighImpactNews[index].releaseGMT = releaseGMT;
      GuardianManualHighImpactNews[index].name = name;
   }
}

bool GuardianLoadHighImpactNews(
   datetime when
)
{
   datetime dayStart = GuardianCalendarDayStart(
      GuardianServerToGMT(when)
   );
   datetime serverDayStart = GuardianGMTToServer(dayStart);

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
          serverDayStart,
          serverDayStart + 86400
      );

   if(valueCount < 0)
   {
      GuardianNewsCacheRefreshFailed = true;
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
   GuardianNewsCacheRefreshFailed = false;

   return true;
}

bool GuardianNewsReleaseWaitActive(
   datetime when,
   datetime releaseTime,
   datetime &newsRelease
)
{
   datetime whenGMT = GuardianServerToGMT(when);
   datetime releaseGMT = GuardianServerToGMT(releaseTime);

   if(!GuardianTimesShareEntryWindow(whenGMT, releaseGMT))
      return false;

   datetime allowedAt = releaseTime +
      (GuardianHighImpactNewsDelayForRelease(releaseGMT) * 60);

   if(when >= allowedAt)
      return false;

   newsRelease = releaseTime;
   return true;
}

bool GuardianHighImpactNewsDelayActive(
   datetime when,
   datetime &newsRelease,
   string symbol = ""
)
{
   newsRelease = 0;

   if(!BlockHighImpactNewsEntries)
      return false;

   if(HighImpactNewsDelayMinutes <= 0)
      return false;

   if(!GuardianIsInsideEntryWindow(GuardianServerToGMT(when), symbol))
      return false;

   GuardianLoadManualHighImpactNews();
   bool calendarAvailable = GuardianLoadHighImpactNews(when);

   int total = calendarAvailable ?
      ArraySize(GuardianHighImpactNews) : 0;

   for(int i = 0;
       i < total;
       i++)
   {
      datetime releaseTime =
         GuardianHighImpactNews[i].time;

      if(GuardianNewsReleaseWaitActive(when, releaseTime, newsRelease))
         return true;
   }

   int manualTotal = ArraySize(GuardianManualHighImpactNews);

   for(int i = 0; i < manualTotal; i++)
   {
      datetime releaseTime = GuardianGMTToServer(
         GuardianManualHighImpactNews[i].releaseGMT
      );

      if(GuardianNewsReleaseWaitActive(when, releaseTime, newsRelease))
         return true;
   }

   return false;
}

//==================================================
// COMPLETE ENTRY PERMISSION
//
// Weekly period AND daily window must both be open.
//==================================================

bool GuardianEntryTimeAllowed(
   datetime when,
   string symbol = ""
)
{
   if(!GuardianIsInsideWeeklyTradingPeriod(when, symbol))
      return false;

   if(!GuardianIsInsideEntryWindow(when, symbol))
      return false;

   if(GuardianFullDayNewsBlackoutActive(when))
      return false;

   if(GuardianUSBankHolidayBlackoutActive(when))
      return false;

   if(GuardianFOMCMinutesWindowBlockActive(when))
      return false;

   datetime newsRelease = 0;

   if(
      GuardianHighImpactNewsDelayActive(
         when,
         newsRelease,
         symbol
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

string GuardianEntryWindowStatus(
   string symbol = ""
)
{
   datetime now =
      TimeCurrent();

   if(StringLen(symbol) == 0)
      symbol = _Symbol;

   if(!GuardianIsInsideWeeklyTradingPeriod(now, symbol))
      return "CLOSED";

   if(GuardianFullDayNewsBlackoutActive(now))
      return "EVENT DAY";

   if(GuardianUSBankHolidayBlackoutActive(now))
      return "US BANK HOLIDAY";

   if(GuardianFOMCMinutesWindowBlockActive(now))
      return "FOMC MINUTES";

   if(
      GuardianUSCongressAndPresidentialElectionDayActive(now) &&
      (
         GuardianTimeInsideWindow(
            GuardianMinutesOfDay(now),
            Window3StartHour,
            Window3StartMinute,
            Window3EndHour,
            Window3EndMinute
         ) ||
         GuardianTimeInsideWindow(
            GuardianMinutesOfDay(now),
            Window4StartHour,
            Window4StartMinute,
            Window4EndHour,
            Window4EndMinute
         ) ||
         GuardianTimeInsideWindow(
            GuardianMinutesOfDay(now),
            Window5StartHour,
            Window5StartMinute,
            Window5EndHour,
            Window5EndMinute
         )
      )
   )
   {
      return "US ELECTION: W1-W2 ONLY";
   }

   if(!GuardianIsInsideEntryWindow(now, symbol))
      return "CLOSED";

   datetime newsRelease = 0;

   if(
      GuardianHighImpactNewsDelayActive(
         now,
         newsRelease,
         symbol
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

string GuardianWeeklyTradingStatus(
   string symbol = ""
)
{
   if(StringLen(symbol) == 0)
      symbol = _Symbol;

   if(
      GuardianIsInsideWeeklyTradingPeriod(
         TimeCurrent(),
         symbol
      )
   )
   {
      return "ACTIVE";
   }

   return "CLOSED";
}

#endif
