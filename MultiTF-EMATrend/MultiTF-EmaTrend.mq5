//+------------------------------------------------------------------+
//|                                             MultiTF-EmaTrend.mq5 |
//|                           Copyright 2025, Jivita Expert Advisors |
//|                                            by Malinda Rasingolla |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita Expert Advisors"
#property version   "1.00"

// Include files
#include "Indicators/EmaSlopeTrend.mqh"
#include "Includes/utils.mqh"
#include "Includes/TradeManager.mqh"

// Input parameters
input group                "==== EMA Trend Settings ===="
input int                 EmaPeriodHigher   = 14;         // Higher TF EMA Period
input int                 EmaPeriodLower    = 10;         // Lower TF EMA Period
input ENUM_TIMEFRAMES     HigherTimeframe   = PERIOD_H1;  // Higher Timeframe
input ENUM_TIMEFRAMES     LowerTimeframe    = PERIOD_M15;  // Lower Timeframe
input int                 SlopeWindow       = 5;          // Slope Calculation Window
input int                 AtrPeriod         = 14;         // ATR Period
input double              AtrMultiplier     = 0.1;        // ATR Multiplier for threshold
input bool                EnableComments    = true;       // Enable chart comments

input group                "==== Arrow Settings ===="
input bool                DrawArrows        = true;       // Draw buy/sell arrows
input color               BuyArrowColor     = clrLime;    // Buy arrow color
input color               SellArrowColor    = clrRed;     // Sell arrow color
input int                 ArrowSize         = 1;          // Arrow size

input group                "==== Trading Settings ===="
input bool                EnableTrading      = true;      // Enable live trading
input double              RiskPercent        = 1.0;       // Risk percentage per trade
input double              FixedLotSize       = 0.01;      // Fixed lot size (if risk percent is 0)
input int                 MagicNumber        = 953164;    // Magic number for trades
input bool                TradeOppositeSignal = false;    // Trade opposite direction of signal

input group                "==== Trading Hours ===="
input bool                EnableTimeFilter   = false;     // Restrict trading to specific hours
input int                 TradingStartHour   = 8;         // Trading start hour (0-23)
input int                 TradingStartMinute = 30;        // Trading start minute (0-59)
input int                 TradingEndHour     = 16;        // Trading end hour (0-23)
input int                 TradingEndMinute   = 30;        // Trading end minute (0-59)
input bool                UseServerTime      = true;      // Use server time (true) or local time (false)
input bool                ShowTimeLines      = true;      // Show vertical time lines on chart
input color               TimeLinesColor     = clrDarkGray; // Color for time lines

input group                "==== Risk Management ===="
input bool                UseStopLoss        = true;      // Use ATR-based Stop Loss
input double              SlAtrMultiplier    = 2.0;       // ATR multiplier for Stop Loss
input double              RiskRewardRatio    = 1.0;       // Risk-to-Reward ratio for Take Profit
input int                 RiskAtrPeriod      = 14;        // ATR period for risk calculation
input bool                EnableTrailingStop = false;      // Enable trailing stop functionality
input bool                ShowTrailingStop   = false;      // Show trailing stop trendline

// Global variables
CNewBarDetector newBarDetector;

// EmaSlopeTrend object
CEmaSlopeTrend emaSlopeTrend;

// Trade manager
CTradeManager tradeManager;

// Time filter
CTimeFilter timeFilter;

// Profit tracker
CProfitTracker profitTracker(MagicNumber);

// Variables to hold trend values
double emaHigherValue = EMPTY_VALUE;
double emaLowerValue = EMPTY_VALUE;
int colorHigherValue = 0;
int colorLowerValue = 0;
double dotHigherValue = EMPTY_VALUE;
double dotLowerValue = EMPTY_VALUE;
int dotHigherColorValue = 0;
int dotLowerColorValue = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize the EmaSlopeTrend object
   if(!emaSlopeTrend.Init(EmaPeriodHigher, EmaPeriodLower, HigherTimeframe, 
                         LowerTimeframe, SlopeWindow, AtrPeriod, AtrMultiplier))
   {
      Print("Failed to initialize EmaSlopeTrend object");
      return(INIT_FAILED);
   }
   
   // Configure arrow settings
   emaSlopeTrend.ConfigureArrows(DrawArrows, BuyArrowColor, SellArrowColor, ArrowSize);
   
   // Initialize the trade manager
   tradeManager.Init(MagicNumber, EnableTrading, FixedLotSize);
   
   // Configure risk management
   tradeManager.ConfigureRiskManagement(UseStopLoss, SlAtrMultiplier, RiskRewardRatio, RiskAtrPeriod);
   
   // Configure trailing stop
   tradeManager.ConfigureTrailingStop(EnableTrailingStop, ShowTrailingStop);
   
   // Configure risk-based position sizing
   tradeManager.ConfigureRiskBasedSize(RiskPercent);
   
   // Configure time-based trading filter in TradeManager
   tradeManager.ConfigureTimeFilter(EnableTimeFilter, TradingStartHour, TradingStartMinute, 
                                  TradingEndHour, TradingEndMinute, UseServerTime);
   
   // Configure time filter for visualization
   timeFilter.Configure(EnableTimeFilter, TradingStartHour, TradingStartMinute,
                       TradingEndHour, TradingEndMinute, UseServerTime,
                       ShowTimeLines, TimeLinesColor);
   
   // Initialize the bar detector
   newBarDetector.Reset();
   
   // Force time filter lines creation at startup
   timeFilter.CleanupTimeLines();
   timeFilter.UpdateTimeLines(true);
   
   // Pre-calculate trend state using historical data to avoid waiting for SlopeWindow bars
   PreCalculateTrendState();
   
   // Initialize the profit tracker
   if(!profitTracker.Initialize())
   {
      Print("Warning: Failed to initialize profit tracker");
   }
   
   Print("MultiTF-EmaTrend initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Pre-calculate trend state with historical data                   |
//+------------------------------------------------------------------+
void PreCalculateTrendState()
{
   // Calculate how many bars we need for initializing trend calculations
   int barsNeeded = MathMax(SlopeWindow * 2, EmaPeriodHigher * 3); // More than enough
   
   // Process trend values from historical data
   for(int i = barsNeeded; i >= 0; i--)
   {
      // Use the current time for the historical bar
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
      
      // Calculate values for this historical bar
      bool success = emaSlopeTrend.Calculate(i, barTime,
                               emaHigherValue, emaLowerValue,
                               colorHigherValue, colorLowerValue,
                               dotHigherValue, dotLowerValue,
                               dotHigherColorValue, dotLowerColorValue);
                               
      // For the current bar (i=0), check if we have a valid signal
      if(i == 0 && success)
      {
         // Check for trend alignment and draw arrows if needed
         emaSlopeTrend.CheckTrendAlignment();
         
         // Get the current signal type and process it if valid
         int signalType = emaSlopeTrend.GetLastSignalType();
         if(signalType >= 0)
         {
            Print("Initial trend state calculated - Signal detected: ", 
                  (signalType == 0 ? "BUY" : "SELL"));
                  
            // Don't process the trade right now - wait for first tick
            // Otherwise we might get an invalid price
         }
      }
   }
   
   Print("Historical data processed - EA ready to trade from first tick");
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up objects created by the EmaSlopeTrend class
   emaSlopeTrend.CleanupObjects();
   
   // Clean up time lines
   timeFilter.CleanupTimeLines();
   
   // Clear chart comments
   Comment("");
   
   Print("MultiTF-EmaTrend deinitialized");
}

//+------------------------------------------------------------------+
//| Callback function for EmaSlopeTrend signal                       |
//+------------------------------------------------------------------+
void OnEmaTrendSignal(int signalType)
{
   // Check if we're within trading hours
   bool canOpenNewTrades = true;
   
   // Only restrict trading if time filter is enabled
   if(EnableTimeFilter)
   {
      canOpenNewTrades = timeFilter.IsWithinTradingHours();
      
      // Only log rejected signals to reduce log spam
      if(!canOpenNewTrades)
      {
         Print("SIGNAL REJECTED: Outside trading hours (", 
               FormatTimeHHMM(TradingStartHour, TradingStartMinute), "-", 
               FormatTimeHHMM(TradingEndHour, TradingEndMinute), ")");
      }
   }
   
   // If trading opposite signals is enabled, invert the signal type
   int finalSignalType = signalType;
   if(TradeOppositeSignal && signalType >= 0)
   {
      // Invert: 0 = buy becomes 1 = sell, and 1 = sell becomes 0 = buy
      finalSignalType = (signalType == 0) ? 1 : 0;
      Print("Trading opposite direction - original signal: ", 
            (signalType == 0 ? "BUY" : "SELL"), 
            ", reversed to: ", (finalSignalType == 0 ? "BUY" : "SELL"));
   }
   
   // Process trade signal - pass the flag to allow or disallow new positions
   tradeManager.ProcessSignal(finalSignalType, canOpenNewTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastTimeUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   // Only update time lines once per minute to reduce overhead
   if(currentTime - lastTimeUpdate > 60)
   {
      lastTimeUpdate = currentTime;
      timeFilter.UpdateTimeLines();
   }
   
   // Update the trade manager's position tracking
   tradeManager.OnTick();
   
   // Check for a new bar using our utility
   if(!newBarDetector.IsNewBar())
      return;
   
   // We can now trade from the first bar since we pre-calculated the trend state
   // So we'll remove the check for minimum bar count
   
   // Notify trade manager of new bar for trailing stop update
   tradeManager.OnNewBar();
   
   // Calculate current values using the EmaSlopeTrend class
   if(!emaSlopeTrend.Calculate(0, TimeCurrent(),
                            emaHigherValue, emaLowerValue,
                            colorHigherValue, colorLowerValue,
                            dotHigherValue, dotLowerValue,
                            dotHigherColorValue, dotLowerColorValue))
   {
      Print("Failed to calculate EmaSlopeTrend values");
      return;
   }
   
   // Check for trend alignment and draw arrows if needed
   emaSlopeTrend.CheckTrendAlignment();
   
   // Get the current signal type from EmaSlopeTrend class
   int signalType = emaSlopeTrend.GetLastSignalType();
   
   // Process the signal if there is one
   if(signalType >= 0)
   {
      OnEmaTrendSignal(signalType);
   }
   
   // Display info on the chart
   if(EnableComments)
      DisplayInfo();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Reload time lines on chart change events
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      Print("Chart changed - updating time filter lines");
      timeFilter.UpdateTimeLines();
   }
}

//+------------------------------------------------------------------+
//| Display trend information on chart                               |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string higherTrendInfo = "Higher TF (" + TimeframeToString(HigherTimeframe) + ") Trend: ";
   string lowerTrendInfo = "Lower TF (" + TimeframeToString(LowerTimeframe) + ") Trend: ";
   
   // Determine higher timeframe trend using utility function
   higherTrendInfo += TrendToString(colorHigherValue) + " (" + ColorToString(TrendToColor(colorHigherValue)) + ")";
      
   // Determine lower timeframe trend using utility function
   lowerTrendInfo += TrendToString(colorLowerValue) + " (" + ColorToString(TrendToColor(colorLowerValue)) + ")";
   
   // Check for trend change dots on current bar
   string dotInfo = "";
   if(dotHigherValue != EMPTY_VALUE)
      dotInfo += "\nHIGHER TIMEFRAME TREND CHANGE DETECTED!";
   if(dotLowerValue != EMPTY_VALUE)
      dotInfo += "\nLOWER TIMEFRAME TREND CHANGE DETECTED!";
   
   string info = "";
   
   // Assemble and display comment
   info += "\n\n=== MultiTF-EmaTrend Indicator ===\n";
   info += higherTrendInfo + "\n";
   info += lowerTrendInfo;
   info += dotInfo;
   // info += "\n\nEMA Higher: " + FormatPrice(emaHigherValue);
   // info += "\nEMA Lower: " + FormatPrice(emaLowerValue);
   
   // Add trading hours information
   // string timeInfo = "\n\n=== Trading Hours ===";
   
   // if(EnableTimeFilter)
   // {
   //    timeInfo += "\nTrading Hours: " + 
   //               FormatTimeHHMM(TradingStartHour, TradingStartMinute) + " - " +
   //               FormatTimeHHMM(TradingEndHour, TradingEndMinute);
      
   //    bool inTradingHours = timeFilter.IsWithinTradingHours();
   //    string tradingAllowed = inTradingHours ? "OPEN" : "CLOSED";
   //    timeInfo += " [" + tradingAllowed + "]";
   // }
   // else
   // {
   //    timeInfo += "\nTime Filter: DISABLED (trading at all hours)";
   // }
   
   // Current time info
   // MqlDateTime now;
   // datetime currentTime = UseServerTime ? TimeCurrent() : TimeLocal();
   // TimeToStruct(currentTime, now);
   
   // timeInfo += "\nCurrent Time: " + FormatTimeHHMM(now.hour, now.min) + 
   //             " (" + (UseServerTime ? "Server" : "Local") + ")";
   
   // info += timeInfo;
   
   // Add signal direction information
   info += "\n\n=== Trading Settings ===";
   info += "\nSignal Direction: " + (TradeOppositeSignal ? "OPPOSITE (Counter-Trend)" : "NORMAL (Trend-Following)");
   
   // Add the profit information section
   info += profitTracker.GetProfitInfoString();
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Expert event handler for trade transactions                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Update profit tracker with the new transaction
   profitTracker.OnTradeTransaction(trans);
}
