#ifndef __MANUAL_TRADING_GUARDIAN_TIME__
#define __MANUAL_TRADING_GUARDIAN_TIME__

//==================================================
// CURRENT GMT+0 / UTC TIME
//==================================================

datetime GuardianGMTNow()
{
   return TimeGMT();
}

//==================================================
// CURRENT BROKER / TRADE-SERVER TIME
//
// Used only when interacting with MT5 history APIs,
// because MT5 stores deal/position timestamps in
// trade-server time.
//
// Trading rules themselves use GMT+0.
//==================================================

datetime GuardianServerNow()
{
   datetime serverTime = TimeTradeServer();

   if(serverTime <= 0)
      serverTime = TimeCurrent();

   return serverTime;
}

//==================================================
// BROKER SERVER OFFSET FROM GMT+0
//
// Example:
// Broker = GMT+2
// Offset = +7200
//
// This is ONLY used to translate MT5 historical
// timestamps into GMT+0.
//==================================================

int GuardianServerGMTOffsetSeconds()
{
   return (int)(
      GuardianServerNow() -
      GuardianGMTNow()
   );
}

//==================================================
// CONVERT BROKER/SERVER TIME -> GMT+0
//==================================================

datetime GuardianServerToGMT(
   datetime serverTime
)
{
   return
      serverTime -
      GuardianServerGMTOffsetSeconds();
}

//==================================================
// CONVERT GMT+0 -> BROKER/SERVER TIME
//
// Needed when passing a GMT boundary to
// HistorySelect(), because MT5 expects
// trade-server timestamps.
//==================================================

datetime GuardianGMTToServer(
   datetime gmtTime
)
{
   return
      gmtTime +
      GuardianServerGMTOffsetSeconds();
}

//==================================================
// GET START OF CURRENT GMT+0 DAY
//==================================================

datetime GuardianGMTTodayStart()
{
   MqlDateTime t;

   TimeToStruct(
      GuardianGMTNow(),
      t
   );

   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;

   return StructToTime(t);
}

//==================================================
// GET START OF CURRENT GMT+0 WEEK
//
// Monday = first day of week
//==================================================

datetime GuardianGMTWeekStart()
{
   MqlDateTime t;

   TimeToStruct(
      GuardianGMTNow(),
      t
   );

   int daysFromMonday =
      (t.day_of_week + 6) % 7;

   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;

   datetime today =
      StructToTime(t);

   return
      today -
      (daysFromMonday * 86400);
}

//==================================================
// GET START OF CURRENT DAY
//
// Returns SERVER TIME equivalent of GMT midnight.
//
// Use this for HistorySelect().
//==================================================

datetime GuardianTodayStart()
{
   return GuardianGMTToServer(
      GuardianGMTTodayStart()
   );
}

//==================================================
// GET START OF CURRENT WEEK
//
// Returns SERVER TIME equivalent of GMT Monday 00:00.
//
// Use this for HistorySelect().
//==================================================

datetime GuardianWeekStart()
{
   return GuardianGMTToServer(
      GuardianGMTWeekStart()
   );
}

//==================================================
// GET MINUTES FROM MIDNIGHT
//
// IMPORTANT:
// 'when' must already be in GMT+0 if the result
// is being used for trading-window decisions.
//==================================================

int GuardianMinutesOfDay(
   datetime when
)
{
   MqlDateTime t;

   TimeToStruct(
      when,
      t
   );

   return
      (t.hour * 60) +
      t.min;
}

#endif
