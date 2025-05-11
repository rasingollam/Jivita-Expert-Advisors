//+------------------------------------------------------------------+
//|                                             MultiTF-EmaTrend.mq5 |
//|                        Copyright 2023, Jivita Expert Advisors     |
//|                                             https://www.jivita.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jivita Expert Advisors"
#property link      "https://www.jivita.com"
#property version   "1.00"

// Include the EmaSlopeTrend class directly
#include <Jivita-Expert-Advisors\EmaSlopeTrend.mqh>

// Input parameters
input group                "==== EMA Trend Settings ===="
input int                 EmaPeriodHigher   = 50;         // Higher TF EMA Period
input int                 EmaPeriodLower    = 20;         // Lower TF EMA Period
input ENUM_TIMEFRAMES     HigherTimeframe   = PERIOD_H4;  // Higher Timeframe
input ENUM_TIMEFRAMES     LowerTimeframe    = PERIOD_H1;  // Lower Timeframe
input int                 SlopeWindow       = 5;          // Slope Calculation Window
input double              AtrMultiplier     = 0.5;        // ATR Multiplier
input bool                EnableComments    = true;       // Enable chart comments

// Global variables
int barCount;
datetime lastBarTime;

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
                         LowerTimeframe, SlopeWindow, 14, AtrMultiplier))
   {
      Print("Failed to initialize EmaSlopeTrend object");
      return(INIT_FAILED);
   }
   
   // Other initializations
   barCount = 0;
   lastBarTime = 0;
   
   Print("MultiTF-EmaTrend initialized successfully - Using direct class implementation");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // EmaSlopeTrend object will clean up in its destructor
   
   // Clear chart objects
   Comment("");
   
   Print("MultiTF-EmaTrend deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Wait for a new bar
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   barCount++;
   
   // We need at least a few bars to analyze trends
   if(barCount < 5)
      return;
   
   // Calculate current values directly using the EmaSlopeTrend class
   if(!emaSlopeTrend.Calculate(0, currentBarTime,
                            emaHigherValue, emaLowerValue,
                            colorHigherValue, colorLowerValue,
                            dotHigherValue, dotLowerValue,
                            dotHigherColorValue, dotLowerColorValue))
   {
      Print("Failed to calculate EmaSlopeTrend values");
      return;
   }
   
   // Display info on the chart
   if(EnableComments)
      DisplayInfo();
}

//+------------------------------------------------------------------+
//| Display trend information on chart                               |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string higherTrendInfo = "Higher TF Trend: ";
   string lowerTrendInfo = "Lower TF Trend: ";
   
   // Determine higher timeframe trend
   if(colorHigherValue == 1)
      higherTrendInfo += "BULLISH (Green)";
   else if(colorHigherValue == 2)
      higherTrendInfo += "BEARISH (Red)";
   else
      higherTrendInfo += "NEUTRAL (Gray)";
      
   // Determine lower timeframe trend
   if(colorLowerValue == 1)
      lowerTrendInfo += "BULLISH (Green)";
   else if(colorLowerValue == 2)
      lowerTrendInfo += "BEARISH (Red)";
   else
      lowerTrendInfo += "NEUTRAL (Gray)";
   
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
   info += "\n\nEMA Higher: " + DoubleToString(emaHigherValue, _Digits);
   info += "\nEMA Lower: " + DoubleToString(emaLowerValue, _Digits);
   
   Comment(info);
}
