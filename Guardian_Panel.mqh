#ifndef __MANUAL_TRADING_GUARDIAN_PANEL__
#define __MANUAL_TRADING_GUARDIAN_PANEL__

#include <Trade/Trade.mqh>

#include "Guardian_TradingWindows.mqh"
#include "Guardian_History.mqh"
#include "Guardian_Statistics.mqh"
#include "Guardian_Lock.mqh"
#include "Guardian_Orders.mqh"
#include "Guardian_Panel.mqh"

//==================================================
// PANEL
//==================================================

void GuardianUpdatePanel(
   int maxDailyLosses,
   int maxWeeklyLosses
)
{
   int dailyExempt = 0;
   int weeklyExempt = 0;

   int dailyActualSL =
      GuardianDailySLCount(
         dailyExempt
      );

   int weeklyActualSL =
      GuardianWeeklySLCount(
         weeklyExempt
      );

   int dailyNegative =
      GuardianDailyNegativeCloses();

   int weeklyNegative =
      GuardianWeeklyNegativeCloses();

   int dailyCloseSL =
      GuardianNegativeClosesToSL(
         dailyNegative
      );

   int weeklyCloseSL =
      GuardianNegativeClosesToSL(
         weeklyNegative
      );

   int dailyTotalSL =
      dailyActualSL +
      dailyCloseSL;

   int weeklyTotalSL =
      weeklyActualSL +
      weeklyCloseSL;

   int dailyTrades =
      GuardianExecutedTrades(
         GuardianTodayStart()
      );

   int weeklyTrades =
      GuardianExecutedTrades(
         GuardianWeekStart()
      );

   double dailyProfit =
      GuardianRealizedProfit(
         GuardianTodayStart()
      );

   double weeklyProfit =
      GuardianRealizedProfit(
         GuardianWeekStart()
      );

   int openPositions =
      GuardianOpenPositions();

   double floatingProfit =
      GuardianFloatingProfit();

   string dailyStatus =
      "ACTIVE";

   string weeklyStatus =
      "ACTIVE";

   string guardianStatus =
      "ACTIVE";

   if(dailyTotalSL >= maxDailyLosses)
   {
      dailyStatus = "LOCKED";
      guardianStatus = "LOCKED";
   }

   if(weeklyTotalSL >= maxWeeklyLosses)
   {
      weeklyStatus = "LOCKED";
      guardianStatus = "LOCKED";
   }

   if(TradingLockActive)
      guardianStatus = "LOCKED";

   string dailyProfitText =
      DoubleToString(
         dailyProfit,
         2
      );

   string weeklyProfitText =
      DoubleToString(
         weeklyProfit,
         2
      );

   string floatingProfitText =
      DoubleToString(
         floatingProfit,
         2
      );

   string text =
      "MANUAL TRADING GUARDIAN v4.10\n"
      "================================\n"

      "DAILY\n"
      "Executed Trades:       " +
      IntegerToString(
         dailyTrades
      ) +
      "\n"

      "Negative Closes:       " +
      IntegerToString(
         dailyNegative
      ) +
      "\n"

      "Actual SLs:            " +
      IntegerToString(
         dailyActualSL
      ) +
      "\n"

      "Close -> SL:           " +
      IntegerToString(
         dailyCloseSL
      ) +
      "\n"

      "Counted SLs:           " +
      IntegerToString(
         dailyTotalSL
      ) +
      " / " +
      IntegerToString(
         maxDailyLosses
      ) +
      " [" +
      dailyStatus +
      "]\n"

      "Realized Profit:       " +
      dailyProfitText +
      "\n"

      "--------------------------------\n"

      "WEEKLY\n"
      "Executed Trades:       " +
      IntegerToString(
         weeklyTrades
      ) +
      "\n"

      "Negative Closes:       " +
      IntegerToString(
         weeklyNegative
      ) +
      "\n"

      "Actual SLs:            " +
      IntegerToString(
         weeklyActualSL
      ) +
      "\n"

      "Close -> SL:           " +
      IntegerToString(
         weeklyCloseSL
      ) +
      "\n"

      "Counted SLs:           " +
      IntegerToString(
         weeklyTotalSL
      ) +
      " / " +
      IntegerToString(
         maxWeeklyLosses
      ) +
      " [" +
      weeklyStatus +
      "]\n"

      "Realized Profit:       " +
      weeklyProfitText +
      "\n"

      "--------------------------------\n"

      "Open Positions:        " +
      IntegerToString(
         openPositions
      ) +
      "\n"

      "Floating P/L:          " +
      floatingProfitText +
      "\n"

      "--------------------------------\n"

      "Entry Window:          " +
      GuardianEntryWindowStatus() +
      "\n"

      "Weekly Trading:        " +
      GuardianWeeklyTradingStatus() +
      "\n"

      "Guardian:              " +
      guardianStatus;

   Comment(text);
}

#endif
