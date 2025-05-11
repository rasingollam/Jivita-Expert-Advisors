//+------------------------------------------------------------------+
//|                                                EmaSlopeTrend.mq5 |
//|                        Copyright 2023, Jivita Expert Advisors     |
//|                                             https://www.jivita.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jivita Expert Advisors"
#property link      "https://www.jivita.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   4

// Include the EmaSlopeTrend class
#include <Jivita-Expert-Advisors\EmaSlopeTrend.mqh>

// EMA + slope color lines
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray, clrGreen, clrRed
#property indicator_label1  "EMA Higher TF"
#property indicator_width1  2

#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrGray, clrGreen, clrRed
#property indicator_label2  "EMA Lower TF"
#property indicator_width2  2

// Dots on trend change
#property indicator_type3   DRAW_COLOR_ARROW
#property indicator_color3  clrGray, clrGreen, clrRed
#property indicator_label3  "High EMA Change"
#property indicator_width3  2

#property indicator_type4   DRAW_COLOR_ARROW
#property indicator_color4  clrGray, clrGreen, clrRed
#property indicator_label4  "Low EMA Change"
#property indicator_width4  2

// Input parameters
input int                 EmaPeriodHigher   = 50;         // Higher TF EMA Period
input int                 EmaPeriodLower    = 20;         // Lower TF EMA Period
input ENUM_TIMEFRAMES     HigherTimeframe   = PERIOD_H4;  // Higher Timeframe
input ENUM_TIMEFRAMES     LowerTimeframe    = PERIOD_H1;  // Lower Timeframe
input int                 SlopeWindow       = 5;          // Slope Calculation Window
input int                 AtrPeriod         = 14;         // ATR Period
input double              AtrMultiplier     = 0.5;        // ATR Multiplier for threshold

// Indicator buffers
double emaHigher[];      // Higher TF EMA values
double colorHigher[];    // Higher TF EMA color index
double emaLower[];       // Lower TF EMA values
double colorLower[];     // Lower TF EMA color index
double dotHigher[];      // Dots for higher TF trend changes
double dotHigherColor[]; // Color index for higher TF dots
double dotLower[];       // Dots for lower TF trend changes
double dotLowerColor[];  // Color index for lower TF dots

// EmaSlopeTrend object
CEmaSlopeTrend emaSlopeTrend;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize the EmaSlopeTrend object
   if(!emaSlopeTrend.Init(EmaPeriodHigher, EmaPeriodLower, HigherTimeframe, 
                         LowerTimeframe, SlopeWindow, AtrPeriod, AtrMultiplier))
   {
      Print("Error initializing EmaSlopeTrend object");
      return(INIT_FAILED);
   }
   
   // Set indicator buffers
   SetIndexBuffer(0, emaHigher, INDICATOR_DATA);
   SetIndexBuffer(1, colorHigher, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(2, emaLower, INDICATOR_DATA);
   SetIndexBuffer(3, colorLower, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(4, dotHigher, INDICATOR_DATA);
   SetIndexBuffer(5, dotHigherColor, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(6, dotLower, INDICATOR_DATA);
   SetIndexBuffer(7, dotLowerColor, INDICATOR_COLOR_INDEX);
   
   // Set arrow code for dots (159 is a circle in Wingdings)
   PlotIndexSetInteger(2, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   
   // Set indicator labels
   IndicatorSetString(INDICATOR_SHORTNAME, "Multi-TF EMA Slope Trend");
   
   // Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   // Initialize buffers with empty values
   ArrayInitialize(dotHigher, EMPTY_VALUE);
   ArrayInitialize(dotLower, EMPTY_VALUE);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Check for minimum required bars
   int minBars = SlopeWindow + EmaPeriodHigher + EmaPeriodLower + AtrPeriod;
   if(rates_total < minBars) return(0);
   
   // Calculate start position
   int start = prev_calculated == 0 ? rates_total - minBars : prev_calculated - 1;
   if(start < 0) start = 0;
   
   // Process each bar
   for(int i=start; i<rates_total; i++)
   {
      // Calculate trend values using the EmaSlopeTrend class
      double tempEmaHigher, tempEmaLower;
      int tempColorHigher, tempColorLower;
      double tempDotHigher, tempDotLower;
      int tempDotHigherColor, tempDotLowerColor;
      
      if(emaSlopeTrend.Calculate(i, time[i], 
                              tempEmaHigher, tempEmaLower, 
                              tempColorHigher, tempColorLower, 
                              tempDotHigher, tempDotLower,
                              tempDotHigherColor, tempDotLowerColor))
      {
         // Store values in indicator buffers
         emaHigher[i] = tempEmaHigher;
         emaLower[i] = tempEmaLower;
         colorHigher[i] = tempColorHigher;
         colorLower[i] = tempColorLower;
         dotHigher[i] = tempDotHigher;
         dotLower[i] = tempDotLower;
         dotHigherColor[i] = tempDotHigherColor;
         dotLowerColor[i] = tempDotLowerColor;
      }
      else
      {
         // Initialize with empty or previous values
         if(i > 0)
         {
            emaHigher[i] = emaHigher[i-1];
            emaLower[i] = emaLower[i-1];
            colorHigher[i] = colorHigher[i-1];
            colorLower[i] = colorLower[i-1];
         }
         dotHigher[i] = EMPTY_VALUE;
         dotLower[i] = EMPTY_VALUE;
      }
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}
