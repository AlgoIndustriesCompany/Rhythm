//#include <Calendar\Calendar.mqh>
#include <Graphics\Graphic.mqh>
#include <Canvas\Canvas.mqh>
#include <Control_Trade_Sessions.mqh>

//#define CALENDAR_FILENAME "Calendar.bin"
//#property tester_file CALENDAR_FILENAME
//CALENDAR Calendar;

#define _Ask    SymbolInfoDouble(_Symbol,SYMBOL_ASK)
#define _Bid    SymbolInfoDouble(_Symbol,SYMBOL_BID)
// Aggregator
double SL[5][2], TF[46000][700][6], aggregatorHH[46000], aggregatorLL[46000];
int SLIndex[2];
const int maxAggregatedCandles = 700;
int minuteChecker[46000], TFAdditionalShift[46000], TFTrend[46000];
int TFMinutesElapsed[46000];
int timeframeBars[];
bool initialized = false;

// Context variables
const int maxPOICount = 40;
int strSyncTfs[], trendSyncTfs[], trendTfs[], premiumDiscTfs[], poiTfs[], counterPoiTfs[];
int lastStructure = 0, lastStructureBosIndex = 0;

// Position variables
const double initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
const double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
const int volumeDigits = (int) -log10(minVolume), tickDigits = (int) SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
const double pipsDelta = pow(10, tickDigits - 1);
double posSizeDelta = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
const double symbolTradeFreezeLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
const double symbolTradeStopsLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * _Point;
const int maxCandlesForSweepRange = 80, maxCandlesToFindLimit = 20, maxCandlesForSwingToBreak = 20;
const int orderMagicNumber = 1;
double dayInitialBalance;

// Timeframe and time variables
MqlDateTime structTime;
int tfs[], tradeIntervals[10][2][2], additionalTimeframe, entryTfs[];
string hourIntervals[];
bool OperationsAllowed = false;

// Analytics variables
int orderIndex = 0, invalidOrderIndex = 0;

enum orderInvalidationReason {
   INVALID_PIPS = 1,
   NOT_ENOUGH_MARGIN = 2,
   VOLUME_LIMIT_REACHED = 3,
   MAX_VOLUME_REACHED = 4,
   MIN_VOLUME_REACHED = 5,
   DAILY_LOSS_REACHED = 6
};
   
struct Order {
   ulong ticket;
   datetime formationTime;
   datetime fillTime;
   datetime TPTime;
   datetime SLTime;
   datetime limitCandleTime;
   double limit;
   double stopLoss;
   double takeProfit;
   double profit;
   int win;
   bool buy;
   int timeframe;
};
Order orders[];

struct Position {
   ulong ticket;
   string SLText;
   string TPText;
};
Position openedPositions[];

struct invalidOrder {
   int id; // invalid order identifier consists of: "limit * 10^tickDigits" + "stopLoss * 10^tickDigits"
   orderInvalidationReason code;
};
invalidOrder invalidOrders[];

struct Chart {
   string name;
   string curve1Name;
   string XName;
   string YName;
   double X[];
   double Y1[];
};

// Visualization variables
const bool visual = (MQLInfoInteger(MQL_VISUAL_MODE) || !MQLInfoInteger(MQL_TESTER)) ? true : false;
const bool live = !MQLInfoInteger(MQL_TESTER);
const bool demoVersion = MQLInfoInteger(MQL_LICENSE_TYPE) == LICENSE_DEMO ? true : false;
const bool crypto = SymbolInfoInteger(_Symbol,SYMBOL_SECTOR) == SECTOR_CURRENCY_CRYPTO ? true : false;
const int terminalDPI = TerminalInfoInteger(TERMINAL_SCREEN_DPI);
const double DPIMultiplier = terminalDPI / 96.0;
CCanvas trendWindow, analyticsWindow;

/*
//News visualization
const string newsText = "news ", newsStartText = "news start ", newsEndText = "news end ", newsTimeText = "news time ";
const color newsClr = clrMistyRose, newsBorderClr = clrRed, newsTimeClr = clrRed;
const ENUM_LINE_STYLE newsBorderStyle = STYLE_DASHDOT, newsTimeStyle = STYLE_DOT;

struct newsZone {
   int startPos;
   int endPos;
   datetime newsTimes[];
   datetime start;
   datetime end;
   double low;
   double high;
   newsZone() { endPos=-1; end=0; }
};
 */
 /*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------USER INPUTS----------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
enum YesNo
  {
   No=0,
   Yes=1
  };
  
enum syncTFMode
  {
   none=0, // -
   sM1=1, // M1
   sM2=2, // M2
   sM3=3, // M3
   sM4=4, // M4
   sM5=5, // M5
   sM6=6, // M6
   sM15=15, // M15
   sM30=30, // M30
   sH1=60, // H1
   sH4=240, // H4
   sH12=720, // H12
   sD1=1440, // D1
   sW1=10080 // W1
  };
enum syncMode 
  {
   off=-1, // Off
   oneOf=0, // One of timeframes
   allOf=1 // All of timeframes
  };
enum Mode
  {
   Off=0, // Off
   On=1 // On
  };

/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/

input group           "ENTRY SETTINGS"
enum entrySetupMode 
  {
   sweepBos=1, // Sweep+BOS
   breaker=2, // Breaker
   absorption=3, // Absorption
   btsstb=4, // BuyToSell/SellToBuy
   orderblock=5, // Orderblock
   fvg=6, // FVG
   premdisc=7 // Premium/Discount
  };
input entrySetupMode entrySetup=sweepBos; // Entry setup
input syncTFMode entry1=sM5; // Entry timeframe 1
input syncTFMode entry2=none; // Entry timeframe 2
input syncTFMode entry3=none; // Entry timeframe 3
input syncTFMode additionalTF=sM1; // Break of Structure timeframe (for Sweep+BOS)
enum limitSweepBos 
  {
   limitFlexible=0, // Flexible
   limitBZ=1, // Limit on Breaker Zone
   limitBTSSTB=2, // Limit on Swing (BOS Level)
   limitRC=3 // Limit on Raid Candle
  };
input limitSweepBos LimitMode=limitFlexible; // Entry mode (Sweep+BOS)
enum limitBreaker 
  {
   breakerBody=1, // Limit on breaker body
   breakerFVG=2, // Limit on FVG
   breakerFVGFF=3 // Limit on FVG Fulfill
  };
input limitBreaker limitModeBreaker=breakerBody; // Entry mode (Breaker)
const int maxCandlesToFindSwingForBreakerBos = 6; 
const int breakerMaxCandlesRange = 80;
enum limitAbsorption 
  {
   absorptionBody=1, // Limit on body
   absorptionMarket=2 // Market entry
  };
input limitAbsorption limitModeAbsorption=absorptionBody; // Entry mode (Absorption)
enum limitBtsstbMode 
  {
   btsstbFull=1, // Limit on full BTS/STB
   btsstb50=2, // Limit on 50%
   btsstbMarket=3 // Market entry
  };
input limitBtsstbMode limitModeBtsstb=btsstbFull; // Entry mode (BuyToSell/SellToBuy)
enum orderblockMode 
  {
   orderblockFull=1, // Limit on OB
   orderblock50=2 // Limit on 50%
  };
input orderblockMode limitModeOrderblock=orderblockFull; // Entry mode (Orderblock)
enum FVGMode 
  {
   FVG=1, // Limit on FVG
   FVG50=2, // Limit on 50%
   FVGFF=3 // Limit on FVG FF
  };
input FVGMode limitModeFVG=FVG; // Entry mode (FVG)
enum limitPremdisc 
  {
   premdisc50=1, // Limit on 50%
   premdisc33=2, // Limit on 33%
   premdisc25=3 // Limit on 25%
  };
input limitPremdisc limitModePremdisc=premdisc50; // Entry mode (Premium/Discount)

input group           "STRUCTURE SYNC"
input syncMode structureSyncMode = off; // Mode
input syncTFMode structure1=none; // Timeframe 1
input syncTFMode structure2=none; // Timeframe 2
input syncTFMode structure3=none; // Timeframe 3

input group           "TREND SYNC"
input syncMode trendSyncMode = off; // Mode
input syncTFMode trend1=none; // Timeframe 1
input syncTFMode trend2=none; // Timeframe 2
input syncTFMode trend3=none; // Timeframe 3

input group           "PREMIUM/DISCOUNT"
input syncMode PremDiscMode = off; // Mode
input syncTFMode premdisc1=none; // Timeframe 1
input syncTFMode premdisc2=none; // Timeframe 2
input syncTFMode premdisc3=none; // Timeframe 3
input double premdiscPercent=50; // Premium/Discount %

input group           "HTF CONTEXT"
input syncMode contextMode = off; // Mode
input syncTFMode context1=none; // Timeframe 1
input syncTFMode context2=none; // Timeframe 2
input syncTFMode context3=none; // Timeframe 3
input Mode countOB=Off; // OB
input Mode countFVG=Off; // FVG
input Mode countFF=Off; // FF
input Mode countSweep = Off; // Sweep
input int maxCandlesToCountSweep = 5; // Sweep is counted for _ candles
const double FFPercentage = 100; // % of FVG filled to count as FF
input group           "HTF COUNTER-CONTEXT"
Mode counterContextMode = Off; // Mode
input syncTFMode counterContext1=none; // Timeframe 1
input syncTFMode counterContext2=none; // Timeframe 2
input syncTFMode counterContext3=none; // Timeframe 3
input Mode countCounterOB=Off; // OB
input Mode countCounterFVG=Off; // FVG
input Mode countCounterFF=Off; // FF
input Mode countCounterSweep = Off; // Sweep
input int maxCandlesToCountCounterSweep = 2; // Sweep is counted for _ candles
const double CounterFFPercentage = 100; // % of FVG filled to count as FF
/*
input group           "SKIP NEWS"
enum newsMinImportance {
   low = CALENDAR_IMPORTANCE_MODERATE, // Moderate
   high = CALENDAR_IMPORTANCE_HIGH // High
};
input YesNo skipNews = No; // Skip news
input double skipHoursBeforeNews = 2; // Skip _ hours before red news
input double skipHoursAfterNews = 1; // Skip _ hours after red news
input newsMinImportance importance = high; // Minimum importance of news
*/
input group           "TRADING TIME"
input string tradeHours = "9:00-12:00;15:00-18:00"; // Trade sessions
input YesNo ClosePositionsAtSessionEnd=No; // Close positions at the end of the session
input YesNo tradeInWinterHolidays=No; // Trade in winter holidays

input group           "TRADE SETTINGS"
input double Risk = 1; // Risk % per trade
input double RRR = 2; // Risk Reward Ratio
input int PipsFrom = 4; // Min pips for Stoploss
input int PipsTo = 12; // Max pips for Stoploss
input double addPippets = 0.3; // How many pips add to Stoploss
input int LimitExpiresInMinutes = 0; // Limit expires in _ minutes
input int CancelAtRRR = 0; // Cancel order after _R without Return To Origin
input double maxDailyLoss = 4; // Maximum daily loss in %

input group           "EXIT SETTINGS"
input YesNo pdlpdh = No; // Prefer PDL/PDH as take profit level
input Mode partial = Off; // Partial take profit
input double PartialPercent = 50; // Partial %
input double PartialRRR = 1; // Partial RRR
input Mode trail = Off; // Trailing
input double trailPips = 10; // Pips for trailing
input Mode breakeven = Off; // Breakeven
input double BreakevenRRR = 1; // Breakever RRR

input group           "TECHNICAL DETAILS"
input int maxCandlesForSweepToBeValid = 10; // Sweeps are valid for _ candles (for Sweep+BOS setups)
const int maxCandlesToFindStructure = 100; // Max candles without BOS for valid structure (LTF)
const int maxCandlesForStructureIntervals = 200; // Max candles for structure intervals (HTF)
const int MaxCandlesOfRangeWidth = 70; // Maximum range width in candles
const int MaxCandlesToCountRanges = 300; // Maximum range width in candles
const int MinCandlesOfRangeWidth = 2; // Minimum range width in candles
