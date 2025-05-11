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
input ENUM_TIMEFRAMES     HigherTimeframe   = PERIOD_H4;  // Higher Timeframe
input ENUM_TIMEFRAMES     LowerTimeframe    = PERIOD_H1;  // Lower Timeframe
input int                 SlopeWindow       = 5;          // Slope Calculation Window
input int                 AtrPeriod         = 14;         // ATR Period
input double              AtrMultiplier     = 0.1;        // ATR Multiplier for threshold
input bool                EnableDebugInfo   = true;       // Show debug info in Experts tab
input bool                EnableComments    = true;       // Enable chart comments

input group                "==== Arrow Settings ===="
input bool                DrawArrows        = true;       // Draw buy/sell arrows
input color               BuyArrowColor     = clrLime;    // Buy arrow color
input color               SellArrowColor    = clrRed;     // Sell arrow color
input int                 ArrowSize         = 5;          // Arrow size
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
   
   // Reset arrow counter
   arrowCounter = 0;
   
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
   
   // Get the previous candle close price (for arrow placement)
   double prevClose = iClose(Symbol(), Period(), 1);
   datetime prevTime = iTime(Symbol(), Period(), 1);
   
   // Check for bullish alignment (both trends are bullish/green)
   if(colorHigherValue == 1 && colorLowerValue == 1)
   {
      // Only draw if we didn't have alignment before
      if(prevHigherTrend != 1 || prevLowerTrend != 1)
      {
         // Draw buy arrow
         string arrowName = "BuyArrow_" + IntegerToString(arrowCounter++);
         DrawArrow(arrowName, prevTime, prevClose, 233, BuyArrowColor, ArrowSize, ArrowOffset);
         Print("Buy signal detected - both trends are bullish");
      }
   }
   // Check for bearish alignment (both trends are bearish/red)
   else if(colorHigherValue == 2 && colorLowerValue == 2)
   {
      // Only draw if we didn't have alignment before
      if(prevHigherTrend != 2 || prevLowerTrend != 2)
      {
         // Draw sell arrow
         string arrowName = "SellArrow_" + IntegerToString(arrowCounter++);
         DrawArrow(arrowName, prevTime, prevClose, 234, SellArrowColor, ArrowSize, -ArrowOffset);
         Print("Sell signal detected - both trends are bearish");
      }
   }
   
   // Update previous trend values
   prevHigherTrend = colorHigherValue;
   prevLowerTrend = colorLowerValue;
}

//+------------------------------------------------------------------+
//| Draw an arrow on the chart                                       |
//+------------------------------------------------------------------+
bool DrawArrow(const string name, datetime time, double price, 
              int arrowCode, color arrowColor, int size, int verticalOffset = 0)
{
   // Convert offset from points to price
   double offset = verticalOffset * Point();
   
   // Create arrow object
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price + offset))
   {
      Print("Failed to create arrow object: ", GetLastError());
      return false;
   }
   
   // Set arrow properties
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, size);  // Use WIDTH instead of SIZE for thickness
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   
   return true;
}
