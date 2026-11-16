#ifndef __MANUAL_TRADING_GUARDIAN_TOGGLES__
#define __MANUAL_TRADING_GUARDIAN_TOGGLES__

//==================================================
// PANEL DISPLAY
//==================================================

input bool ShowLossAmountsAndRealizedProfitOnPanel = true;

//==================================================
// TRADING SCHEDULE
//==================================================

input bool EnforceWeeklyTradingPeriod = true;
input bool EnforceTradingWindows = true;
input bool EnableWindow1 = true;
input bool EnableWindow2 = true;
input bool EnableWindow3 = false;
input bool EnableWindow4 = true;
input bool EnableWindow5 = true;
input bool EnforceUSIndexOnlyWindow3 = true;
input bool EnableWindow3TradeSplitLimit = true;

//==================================================
// PRE-TRADE CHECKLIST
//==================================================

input bool EnableArmTradeConfirmation = true;
input bool RequireArmTradeWindow1 = true;
input bool RequireArmTradeWindow2 = false;
input bool RequireArmTradeWindow3 = false;
input bool RequireArmTradeWindow4 = false;
input bool RequireArmTradeWindow5 = true;

//==================================================
// CALENDAR RULES
//==================================================

input bool BlockHighImpactNewsEntries = true;
input bool EnableWindow3ExtendedNewsWait = true;
input bool BlockFOMCCPINFPReleaseDays = true;
input bool EnableNonFridayCPIOrNFPWindow5Exemption = true;
input bool BlockFOMCMinutesAfterWindow2 = true;
input bool BlockUSBankHolidays = true;
input bool RestrictUSCongressAndPresidentialElectionDays = true;

//==================================================
// LOSS RULES
//==================================================

input bool EnforcePairLossLimitPerEntryWindow = true;
input bool EnableActualStopLossPairLimit = true;
input bool EnableNegativeManualClosePairLimit = true;
input bool EnableDailyLossLimit = true;
input bool EnableWeeklyLossLimit = true;
input bool EnableWeeklyLossAmountLimit = true;
input bool EnableMaxStopLossAmount = true;

#endif
