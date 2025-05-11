//+------------------------------------------------------------------+
//|                                                EmaSlopeTrend.mq5 |
//|                        Copyright 2023, Jivita Expert Advisors     |
//|                                             https://www.jivita.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jivita Expert Advisors"
#property link      "https://www.jivita.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

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
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGreen, clrRed, clrGray
#property indicator_label3  "High EMA Change"
#property indicator_width3  2

#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrGreen, clrRed, clrGray
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
double emaLower[];       // Lower TF EMA values
double colorHigher[];    // Higher TF EMA color index
double colorLower[];     // Lower TF EMA color index
double dotHigher[];      // Dots for higher TF trend changes
double dotLower[];       // Dots for lower TF trend changes

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, emaHigher, INDICATOR_DATA);
   SetIndexBuffer(1, colorHigher, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(2, emaLower, INDICATOR_DATA);
   SetIndexBuffer(3, colorLower, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(4, dotHigher, INDICATOR_DATA);
   SetIndexBuffer(5, dotLower, INDICATOR_DATA);
   
   // Set arrow code for dots (159 is a circle in Wingdings)
   PlotIndexSetInteger(2, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   
   // Set indicator labels
   IndicatorSetString(INDICATOR_SHORTNAME, "Multi-TF EMA Slope Trend");
   
   // Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
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
   
   // Arrays to store temporary EMA values from higher/lower timeframes
   double tempHigher[];
   double tempLower[];
   
   // Resize arrays appropriately
   ArrayResize(tempHigher, rates_total);
   ArrayResize(tempLower, rates_total);
   
   // Calculate EMAs on respective timeframes and copy to our buffer
   for(int i=start; i<rates_total; i++)
   {
      // Get time of the current bar for higher/lower TF synchronization
      datetime currentTime = time[i];
      
      // Calculate EMA on higher timeframe
      int higherTFBar = iBarShift(NULL, HigherTimeframe, currentTime);
      if(higherTFBar >= 0)
      {
         double emaValue = iMA(NULL, HigherTimeframe, EmaPeriodHigher, 0, MODE_EMA, PRICE_CLOSE, higherTFBar);
         tempHigher[i] = emaValue;
      }
      else tempHigher[i] = tempHigher[i-1]; // Keep previous value if bar not found
      
      // Calculate EMA on lower timeframe
      int lowerTFBar = iBarShift(NULL, LowerTimeframe, currentTime);
      if(lowerTFBar >= 0)
      {
         double emaValue = iMA(NULL, LowerTimeframe, EmaPeriodLower, 0, MODE_EMA, PRICE_CLOSE, lowerTFBar);
         tempLower[i] = emaValue;
      }
      else tempLower[i] = tempLower[i-1]; // Keep previous value if bar not found
   }
   
   // Previous trend states to detect changes
   int prevTrendHigh = -99;
   int prevTrendLow = -99;
   
   // Initialize dot buffers
   ArrayInitialize(dotHigher, EMPTY_VALUE);
   ArrayInitialize(dotLower, EMPTY_VALUE);
   
   // Calculate slopes and determine trend colors
   for(int i=start; i<rates_total - SlopeWindow; i++)
   {
      emaHigher[i] = tempHigher[i];
      emaLower[i] = tempLower[i];
      
      // Calculate slopes using the window size
      double slopeHigh = (tempHigher[i] - tempHigher[i + SlopeWindow]) / SlopeWindow;
      double slopeLow = (tempLower[i] - tempLower[i + SlopeWindow]) / SlopeWindow;
      
      // Get ATR value for dynamic threshold
      double atr = iATR(NULL, 0, AtrPeriod, i);
      double threshold = atr * AtrMultiplier;
      
      // Determine trend direction based on slope and threshold
      int trendHigh = 0; // Neutral (gray)
      int trendLow = 0;  // Neutral (gray)
      
      if(slopeHigh > threshold) trendHigh = 1; // Uptrend (green)
      else if(slopeHigh < -threshold) trendHigh = 2; // Downtrend (red)
      
      if(slopeLow > threshold) trendLow = 1; // Uptrend (green)
      else if(slopeLow < -threshold) trendLow = 2; // Downtrend (red)
      
      // Store color indices
      colorHigher[i] = trendHigh;
      colorLower[i] = trendLow;
      
      // Place dots at trend change points (only if we have a previous valid state)
      if(i > 0 && prevTrendHigh != -99 && trendHigh != prevTrendHigh)
      {
         dotHigher[i] = emaHigher[i];
         // Set dot color based on new trend direction
         if(trendHigh == 1) PlotIndexSetInteger(2, PLOT_ARROW_COLOR, clrGreen);
         else if(trendHigh == 2) PlotIndexSetInteger(2, PLOT_ARROW_COLOR, clrRed);
         else PlotIndexSetInteger(2, PLOT_ARROW_COLOR, clrGray);
      }
      
      if(i > 0 && prevTrendLow != -99 && trendLow != prevTrendLow)
      {
         dotLower[i] = emaLower[i];
         // Set dot color based on new trend direction
         if(trendLow == 1) PlotIndexSetInteger(3, PLOT_ARROW_COLOR, clrGreen);
         else if(trendLow == 2) PlotIndexSetInteger(3, PLOT_ARROW_COLOR, clrRed);
         else PlotIndexSetInteger(3, PLOT_ARROW_COLOR, clrGray);
      }
      
      // Update previous trend states
      prevTrendHigh = trendHigh;
      prevTrendLow = trendLow;
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}
