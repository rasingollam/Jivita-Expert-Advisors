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
input int                 ArrowOffset       = 10;         // Arrow offset in points

// Global variables
CNewBarDetector newBarDetector;

// EmaSlopeTrend object
CEmaSlopeTrend emaSlopeTrend;

// Current values
double emaHigherValue, emaLowerValue;
int colorHigherValue, colorLowerValue;
double dotHigherValue, dotLowerValue;
int dotHigherColorValue, dotLowerColorValue;

// Previous trends for tracking changes
int prevHigherTrend = -1;
int prevLowerTrend = -1;

// Track the last signal type that was plotted
int lastPlottedSignalType = -1;  // -1 = none, 0 = buy, 1 = sell

// Arrow counter for unique names
int arrowCounter = 0;

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
   
   // Initialize the bar detector
   newBarDetector.Reset();
   
   // Reset arrow counter and signal tracking
   arrowCounter = 0;
   lastPlottedSignalType = -1;
   
   Print("MultiTF-EmaTrend initialized successfully");
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
   
   // Delete all arrows created by this EA
   ObjectsDeleteAll(0, "BuyArrow_");
   ObjectsDeleteAll(0, "SellArrow_");
   
   // Reset signal tracking
   lastPlottedSignalType = -1;
   
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
   if(DrawArrows)
      CheckTrendAlignmentAndDraw();
   
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

//+------------------------------------------------------------------+
//| Check if trends are aligned and draw arrows                      |
//+------------------------------------------------------------------+
void CheckTrendAlignmentAndDraw()
{
   // Skip if we don't have previous values yet
   if(prevHigherTrend == -1 || prevLowerTrend == -1)
   {
      prevHigherTrend = colorHigherValue;
      prevLowerTrend = colorLowerValue;
      return;
   }
   
   // Get previous candle close price for signal placement
   double prevClose = iClose(Symbol(), Period(), 1);
   datetime prevTime = iTime(Symbol(), Period(), 1);
   
   // Check for bullish alignment (both trends are bullish/green)
   if(colorHigherValue == 1 && colorLowerValue == 1)
   {
      // Only draw if we didn't have alignment before AND this is a new signal type
      if((prevHigherTrend != 1 || prevLowerTrend != 1) && lastPlottedSignalType != 0)
      {
         // Draw buy arrow at previous candle's close
         string arrowName = "BuyArrow_" + IntegerToString(arrowCounter++);
         DrawBuySellArrow(arrowName, prevTime, prevClose, true, BuyArrowColor, ArrowSize);
         Print("Buy signal detected - both trends are bullish");
         
         // Update last plotted signal type
         lastPlottedSignalType = 0;  // 0 = buy signal
      }
   }
   // Check for bearish alignment (both trends are bearish/red)
   else if(colorHigherValue == 2 && colorLowerValue == 2)
   {
      // Only draw if we didn't have alignment before AND this is a new signal type
      if((prevHigherTrend != 2 || prevLowerTrend != 2) && lastPlottedSignalType != 1)
      {
         // Draw sell arrow at previous candle's close
         string arrowName = "SellArrow_" + IntegerToString(arrowCounter++);
         DrawBuySellArrow(arrowName, prevTime, prevClose, false, SellArrowColor, ArrowSize);
         Print("Sell signal detected - both trends are bearish");
         
         // Update last plotted signal type
         lastPlottedSignalType = 1;  // 1 = sell signal
      }
   }
   
   // Update previous trend values
   prevHigherTrend = colorHigherValue;
   prevLowerTrend = colorLowerValue;
}

//+------------------------------------------------------------------+
//| Draw a buy/sell arrow on the chart                               |
//+------------------------------------------------------------------+
bool DrawBuySellArrow(const string name, datetime time, double price, 
                     bool isBuy, color arrowColor, int size)
{
   // Create arrow object - use OBJ_ARROW_BUY or OBJ_ARROW_SELL directly
   ENUM_OBJECT arrowType = isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
   
   if(!ObjectCreate(0, name, arrowType, 0, time, price))
   {
      Print("Failed to create arrow object: ", GetLastError());
      return false;
   }
   
   // Set arrow properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, size); 
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   
   // Set anchor point so arrows appear correctly at the close price
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   
   return true;
}
