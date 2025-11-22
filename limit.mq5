//+------------------------------------------------------------------+
//|  Daily Trade Limit EA with Major News Block                      |
//|  Features:                                                       |
//|   - Stops trading after N losing trades per day                  |
//|   - Blocks trading until 12:45 UTC                               |
//|   - Blocks trading after 16:40 UTC                               |
//|   - Blocks trading if daily equity drawdown >= X%                |
//|   - Blocks trading ± newsWindowMinutes around any HIGH-impact    |
//|     economic calendar event (all countries)                      |
//|   - On-chart status panel                                        |
//|   - Alerts (popup, push)                                         |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade Trade;

// ----------------- User Inputs -----------------
input int    maxLosingTrades         = 3;        // Max losing trades per day
input double maxDailyDrawdownPercent = 20.0;     // Daily equity drawdown %
input bool   enableAlerts            = true;     // Enable alerts
input bool   enablePopup             = true;     // Popup alert()
input bool   enablePush              = true;     // Push notification
input int    newsWindowMinutes       = 10;       // Block X minutes before and after high-impact news
// -------------------------------------------------

// Global variable names
string gv_nextAllowed = "DL_NEXT_ALLOWED_TIME";
string gv_lastAlerted = "DL_LAST_ALERTED_TIME";

// -------------------------------------------------
// Unique global name (per date)
// -------------------------------------------------
string EquityGlobalName(int y,int m,int d)
{
   return StringFormat("DL_EQ_%04d%02d%02d", y, m, d);
}

// -------------------------------------------------
datetime getNextAllowedTime()
{
   if(GlobalVariableCheck(gv_nextAllowed))
      return (datetime)GlobalVariableGet(gv_nextAllowed);
   return 0;
}

void setNextAllowedTime(datetime t)
{
   GlobalVariableSet(gv_nextAllowed, (double)t);
}

datetime getLastAlertedTime()
{
   if(GlobalVariableCheck(gv_lastAlerted))
      return (datetime)GlobalVariableGet(gv_lastAlerted);
   return 0;
}

void setLastAlertedTime(datetime t)
{
   GlobalVariableSet(gv_lastAlerted, (double)t);
}

// -------------------------------------------------
// Today 12:45 UTC
// -------------------------------------------------
datetime TodayAt1245()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   dt.hour = 12;
   dt.min  = 45;
   dt.sec  = 0;

   return StructToTime(dt);
}

// -------------------------------------------------
// Tomorrow 12:45 UTC
// -------------------------------------------------
datetime Tomorrow1245()
{
   datetime t = TimeCurrent() + 86400;
   MqlDateTime dt;
   TimeToStruct(t, dt);

   dt.hour = 12;
   dt.min  = 45;
   dt.sec  = 0;

   return StructToTime(dt);
}

// -------------------------------------------------
// Count today's losing trades ONLY
// -------------------------------------------------
int countTodayLosingTrades()
{
   int total = 0;

   // Start of today's date
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      if(dealTime < todayStart)
         continue;

      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      // Only consider closing deals (entry out)
      if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT && entryType != DEAL_ENTRY_OUT_BY)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      // Losing trade
      if(profit < 0.0)
         total++;
   }

   return total;
}

// -------------------------------------------------
// Start-of-day equity storage
// -------------------------------------------------
double getStartEquityToday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string gvName = EquityGlobalName(dt.year, dt.mon, dt.day);

   if(GlobalVariableCheck(gvName))
      return GlobalVariableGet(gvName);

   return 0.0;
}

void setStartEquityToday(double equity)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string gvName = EquityGlobalName(dt.year, dt.mon, dt.day);

   GlobalVariableSet(gvName, equity);
}

// -------------------------------------------------
double calcDrawdownPercent(double startEquity,double currentEquity)
{
   if(startEquity <= 0.0) return 0.0;
   return ((startEquity - currentEquity) / startEquity) * 100.0;
}

// -------------------------------------------------
void sendBlockAlert(const string msg)
{
   if(!enableAlerts) return;

   datetime nowt = TimeCurrent();
   datetime last = getLastAlertedTime();

   if(last != 0 && (nowt - last) < 60)
      return;

   setLastAlertedTime(nowt);

   if(enablePopup) Alert(msg);
   if(enablePush)  SendNotification(msg);
}

// -------------------------------------------------
// On-chart status panel
// -------------------------------------------------
// Added optional extra line parameter (default empty)
void updateStatusPanel(bool allowed, int tradesToday, double startEq,
                       double curEq, double dd, datetime nextAllowed, string extra = "")
{
   string name = "DL_STATUS_PANEL";
   long chart = ChartID();

   string nextTxt = (nextAllowed > 0)
      ? TimeToString(nextAllowed, TIME_DATE | TIME_MINUTES)
      : "N/A";

   string txt = StringFormat(
      "DailyLimitEA\nAllowed: %s\nLosing trades today: %d / %d\nStart Equity: %.2f\nEquity: %.2f\nDrawdown: %.2f%%\nNext Allowed: %s",
      allowed ? "YES" : "NO",
      tradesToday, maxLosingTrades,
      startEq, curEq, dd,
      nextTxt
   );

   if(StringLen(extra) > 0)
      txt = StringFormat("%s\n%s", txt, extra);

   if(ObjectFind(chart, name) < 0)
   {
      ObjectCreate(chart, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chart, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(chart, name, OBJPROP_YDISTANCE, 10);
      ObjectSetInteger(chart, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(chart, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(chart, name, OBJPROP_BGCOLOR, clrDimGray);
      ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chart, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetString(chart, name, OBJPROP_TEXT, txt);
}

// -------------------------------------------------
// Major news detection (all countries, high-impact)
// Blocks if any HIGH impact calendar event exists within the window
// -------------------------------------------------
bool isMajorNewsBlocked(int minutesBefore=10, int minutesAfter=10)
{
    datetime now = TimeCurrent();
    datetime fromTime = now - minutesBefore * 60;
    datetime toTime   = now + minutesAfter * 60;

    MqlCalendarValue values[];
    int total = CalendarValueHistory(values, fromTime, toTime);

    if(total <= 0)
        return false;

    for(int i = 0; i < total; i++)
    {
        // Load calendar value (MUST NOT use & in MQL5)
        MqlCalendarValue val = values[i];

        // Load event details by ID
        MqlCalendarEvent event;
        if(!CalendarEventById(val.event_id, event))
            continue;

        // High-impact only
        if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;

        // Event time comes from the VALUE object (correct)
        datetime evTime = val.time;

        // If event is within our window → block trading
        if(evTime >= fromTime && evTime <= toTime)
            return true;
    }

    return false;
}


// -------------------------------------------------
// MAIN LOOP
// -------------------------------------------------
void OnTick()
{
   double curEq = AccountInfoDouble(ACCOUNT_EQUITY);

   // Init start-of-day equity if not set
   double startEq = getStartEquityToday();
   if(startEq <= 0.0)
   {
      setStartEquityToday(curEq);
      startEq = curEq;
   }

   double dd = calcDrawdownPercent(startEq, curEq);
   datetime nextAllowed = getNextAllowedTime();

   // Still blocked by time-based nextAllowed?
   if(TimeCurrent() < nextAllowed)
   {
      int losses = countTodayLosingTrades();
      updateStatusPanel(false, losses, startEq, curEq, dd, nextAllowed);
      return;
   }

   // Time-of-day check (>= 12:45 UTC)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool allowedNow =
      (dt.hour > 12) ||
      (dt.hour == 12 && dt.min >= 45);

   if(!allowedNow)
   {
      datetime t1245 = TodayAt1245();
      setNextAllowedTime(t1245);

      sendBlockAlert(
         StringFormat("Trading blocked until %s (before 12:45 UTC).",
         TimeToString(t1245, TIME_DATE | TIME_MINUTES))
      );

      int losses = countTodayLosingTrades();
      updateStatusPanel(false, losses, startEq, curEq, dd, t1245);
      return;
   }

   // Block trading after 16:40 UTC
   bool after1640 =
      (dt.hour > 16) ||
      (dt.hour == 16 && dt.min >= 40);

   if(after1640)
   {
      datetime t = Tomorrow1245();
      setNextAllowedTime(t);

      sendBlockAlert(
         StringFormat("Trading blocked after 16:40 UTC. Next allowed: %s",
         TimeToString(t, TIME_DATE | TIME_MINUTES))
      );

      int losses = countTodayLosingTrades();
      updateStatusPanel(false, losses, startEq, curEq, dd, t);
      return;
   }

   // ---------------------------
   // Check for major news block
   // ---------------------------
   bool newsBlocked = isMajorNewsBlocked(newsWindowMinutes, newsWindowMinutes);
   if(newsBlocked)
   {
      int losses = countTodayLosingTrades();
      // we don't set nextAllowed here; trading will resume automatically after the news window passes
      string extra = "NEWS BLOCK: High-impact economic event nearby (blocked ±" + IntegerToString(newsWindowMinutes) + "m).";
      updateStatusPanel(false, losses, startEq, curEq, dd, nextAllowed, extra);

      sendBlockAlert("Trading blocked due to major economic news (high impact).");
      return;
   }

   // -------------------------------------------------
   // Limit based on LOSING trades only
   // -------------------------------------------------
   int lossesToday = countTodayLosingTrades();

   if(lossesToday >= maxLosingTrades)
   {
      datetime t = Tomorrow1245();
      setNextAllowedTime(t);

      sendBlockAlert(
         StringFormat("Losing trade limit reached (%d). Blocked until %s.",
         lossesToday, TimeToString(t, TIME_DATE | TIME_MINUTES))
      );

      updateStatusPanel(false, lossesToday, startEq, curEq, dd, t);
      return;
   }

   // -------------------------------------------------
   // Drawdown safety
   // -------------------------------------------------
   if(dd >= maxDailyDrawdownPercent)
   {
      datetime t = Tomorrow1245();
      setNextAllowedTime(t);

      sendBlockAlert(
         StringFormat("Drawdown %.2f%% >= %.2f%%. Trading blocked until %s.",
         dd, maxDailyDrawdownPercent, TimeToString(t, TIME_DATE | TIME_MINUTES))
      );

      updateStatusPanel(false, lossesToday, startEq, curEq, dd, t);
      return;
   }

   // Allowed - trading may continue
   updateStatusPanel(true, lossesToday, startEq, curEq, dd, nextAllowed);

   // ---------------------------
   // PLACE YOUR STRATEGY HERE
   // ---------------------------
   // Example:
   // if(entry_condition) Trade.Buy(0.10);
}

// -------------------------------------------------
// Cleanup panel on removal
// -------------------------------------------------
void OnDeinit(const int reason)
{
   long chart = ChartID();
   string name = "DL_STATUS_PANEL";

   if(ObjectFind(chart, name) >= 0)
      ObjectDelete(chart, name);
}
