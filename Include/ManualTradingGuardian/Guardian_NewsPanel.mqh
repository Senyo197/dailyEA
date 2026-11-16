#ifndef __MANUAL_TRADING_GUARDIAN_NEWS_PANEL__
#define __MANUAL_TRADING_GUARDIAN_NEWS_PANEL__

#include "Guardian_TradingWindows.mqh"
#include "Guardian_Time.mqh"

struct GuardianPanelNewsEvent
{
   datetime releaseGMT;
   string name;
   string source;
};

datetime GuardianPanelNewsDay = 0;
datetime GuardianPanelNewsUpdatedAt = 0;
string GuardianPanelNewsText = "";

void GuardianAppendPanelNewsEvent(
   GuardianPanelNewsEvent &events[],
   datetime releaseServer,
   string name,
   string source,
   datetime gmtDayStart,
   string symbol
)
{
   datetime releaseGMT = GuardianServerToGMT(releaseServer);

   if(releaseGMT < gmtDayStart || releaseGMT >= gmtDayStart + 86400)
      return;

   if(!GuardianIsInsideWeeklyTradingPeriod(releaseGMT, symbol) ||
      !GuardianIsInsideEntryWindow(releaseGMT, symbol))
      return;

   int index = ArraySize(events);
   ArrayResize(events, index + 1);
   events[index].releaseGMT = releaseGMT;
   events[index].name = name;
   events[index].source = source;
}

string GuardianTodayWindowNewsText(string symbol = "")
{
   if(StringLen(symbol) == 0)
      symbol = _Symbol;

   datetime nowServer = TimeCurrent();
   datetime gmtDayStart = GuardianGMTTodayStart();

   if(GuardianPanelNewsDay == gmtDayStart &&
      nowServer >= GuardianPanelNewsUpdatedAt &&
      nowServer - GuardianPanelNewsUpdatedAt < GuardianNewsCacheRefreshSeconds)
      return GuardianPanelNewsText;

   GuardianPanelNewsEvent events[];
   bool calendarAvailable = GuardianLoadHighImpactNews(nowServer);

   if(calendarAvailable)
   {
      int total = ArraySize(GuardianHighImpactNews);

      for(int i = 0; i < total; i++)
      {
         MqlCalendarEvent event;

         if(!CalendarEventById(GuardianHighImpactNews[i].event_id, event))
            continue;

         GuardianAppendPanelNewsEvent(
            events,
            GuardianHighImpactNews[i].time,
            event.name,
            "MT5",
            gmtDayStart,
            symbol
         );
      }
   }

   GuardianLoadManualHighImpactNews();
   int manualTotal = ArraySize(GuardianManualHighImpactNews);

   for(int i = 0; i < manualTotal; i++)
   {
      GuardianAppendPanelNewsEvent(
         events,
         GuardianGMTToServer(GuardianManualHighImpactNews[i].releaseGMT),
         GuardianManualHighImpactNews[i].name,
         "MANUAL",
         gmtDayStart,
         symbol
      );
   }

   int count = ArraySize(events);

   for(int i = 1; i < count; i++)
   {
      for(int j = i; j > 0 && events[j].releaseGMT < events[j - 1].releaseGMT; j--)
      {
         GuardianPanelNewsEvent earlier = events[j - 1];
         events[j - 1] = events[j];
         events[j] = earlier;
      }
   }

   string result = "HIGH NEWS IN WINDOWS (GMT+0)\n";

   if(!BlockHighImpactNewsEntries)
      result += "News wait rule: OFF\n";

   if(!calendarAvailable)
      result += "MT5 calendar: UNAVAILABLE\n";
   else if(GuardianNewsCacheRefreshFailed)
      result += "MT5 calendar: CACHED (refresh failed)\n";

   if(GuardianManualHighImpactNewsInputError)
      result += "Manual news input: CHECK FORMAT\n";

   if(count == 0)
      result += calendarAvailable ?
         "NONE LISTED (MT5 + MANUAL)\n" :
         "UNKNOWN (MT5 unavailable)\n";

   for(int i = 0; i < count; i++)
   {
      result += TimeToString(events[i].releaseGMT, TIME_MINUTES) +
         " [" + events[i].source + "] " + events[i].name + "\n";
   }

   GuardianPanelNewsDay = gmtDayStart;
   GuardianPanelNewsUpdatedAt = nowServer;
   GuardianPanelNewsText = result;
   return result;
}

#endif
