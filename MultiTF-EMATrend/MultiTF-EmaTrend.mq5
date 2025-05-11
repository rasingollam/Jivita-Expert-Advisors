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

// Input parameters
input group                "==== EMA Trend Settings ===="
input int                 EmaPeriodHigher   = 50;         // Higher TF EMA Period
input int                 EmaPeriodLower    = 20;         // Lower TF EMA Period
input ENUM_TIMEFRAMES     HigherTimeframe   = PERIOD_H1;  // Higher Timeframe
input ENUM_TIMEFRAMES     LowerTimeframe    = PERIOD_M15;  // Lower Timeframe
input int                 SlopeWindow       = 5;          // Slope Calculation Window
input int                 AtrPeriod         = 14;         // ATR Period
input double              AtrMultiplier     = 0.1;        // ATR Multiplier for threshold
input bool                EnableDebugInfo   = true;       // Show debug info in Experts tab
input bool                EnableComments    = true;       // Enable chart comments

input group                "==== Arrow Settings ===="
input bool                DrawArrows        = true;       // Draw buy/sell arrows
input color               BuyArrowColor     = clrLime;    // Buy arrow color
input color               SellArrowColor    = clrRed;     // Sell arrow color
input int                 ArrowSize         = 1;          // Arrow size

// Global variables
CNewBarDetector newBarDetector;

// EmaSlopeTrend object
CEmaSlopeTrend emaSlopeTrend;

// Current values
double emaHigherValue, emaLowerValue;
int colorHigherValue, colorLowerValue;
double dotHigherValue, dotLowerValue;
int dotHigherColorValue, dotLowerColorValue;

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
   
   // Initialize the bar detector
   newBarDetector.Reset();
   
   Print("MultiTF-EmaTrend initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up objects created by the EmaSlopeTrend class
   emaSlopeTrend.CleanupObjects();
   
   // Clear chart comments
   Comment("");
   
   Print("MultiTF-EmaTrend deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for a new bar using our utility
   if(!newBarDetector.IsNewBar())
      return;
   
   // We need at least a few bars to analyze trends
   if(newBarDetector.GetBarCount() < 5)
      return;
   
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
   
   // Display info on the chart
   if(EnableComments)
      DisplayInfo();
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
   
   // Assemble and display comment
   string info = "=== MultiTF-EmaTrend Indicator ===\n";
   info += higherTrendInfo + "\n";
   info += lowerTrendInfo;
   info += dotInfo;
   info += "\n\nEMA Higher: " + FormatPrice(emaHigherValue);
   info += "\nEMA Lower: " + FormatPrice(emaLowerValue);
   
   Comment(info);
}
