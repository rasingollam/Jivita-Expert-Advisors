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
double emaLower[];       // Lower TF EMA values
double colorHigher[];    // Higher TF EMA color index
double colorLower[];     // Lower TF EMA color index
double dotHigher[];      // Dots for higher TF trend changes
double dotLower[];       // Dots for lower TF trend changes
double dotHigherColor[]; // Color index for higher TF dots
double dotLowerColor[];  // Color index for lower TF dots

// Indicator handles
int emaHigherHandle;
int emaLowerHandle;
int atrHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create indicator handles
   emaHigherHandle = iMA(NULL, HigherTimeframe, EmaPeriodHigher, 0, MODE_EMA, PRICE_CLOSE);
   emaLowerHandle = iMA(NULL, LowerTimeframe, EmaPeriodLower, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(NULL, 0, AtrPeriod);
   
   if(emaHigherHandle == INVALID_HANDLE || emaLowerHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
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
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(emaHigherHandle);
   IndicatorRelease(emaLowerHandle);
   IndicatorRelease(atrHandle);
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
   
   // Arrays to store temporary EMA values
   double higherEmaBuffer[];
   double lowerEmaBuffer[];
   double atrBuffer[];
   
   // Resize arrays appropriately
   ArraySetAsSeries(higherEmaBuffer, true);
   ArraySetAsSeries(lowerEmaBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   
   // Initialize dot buffers
   ArrayInitialize(dotHigher, EMPTY_VALUE);
   ArrayInitialize(dotLower, EMPTY_VALUE);
   
   // Previous trend states to detect changes
   int prevTrendHigh = -99;
   int prevTrendLow = -99;
   
   // Process all bars
   for(int i=start; i<rates_total; i++)
   {
      // Get higher timeframe EMA value
      datetime currentTime = time[i];
      int higherTFBar = iBarShift(NULL, HigherTimeframe, currentTime);
      
      if(higherTFBar >= 0)
      {
         // Copy EMA data from higher timeframe
         if(CopyBuffer(emaHigherHandle, 0, higherTFBar, 1, higherEmaBuffer) > 0)
         {
            emaHigher[i] = higherEmaBuffer[0];
         }
         else
         {
            emaHigher[i] = i > 0 ? emaHigher[i-1] : 0;
         }
      }
      else
      {
         emaHigher[i] = i > 0 ? emaHigher[i-1] : 0;
      }
      
      // Get lower timeframe EMA value
      int lowerTFBar = iBarShift(NULL, LowerTimeframe, currentTime);
      
      if(lowerTFBar >= 0)
      {
         // Copy EMA data from lower timeframe
         if(CopyBuffer(emaLowerHandle, 0, lowerTFBar, 1, lowerEmaBuffer) > 0)
         {
            emaLower[i] = lowerEmaBuffer[0];
         }
         else
         {
            emaLower[i] = i > 0 ? emaLower[i-1] : 0;
         }
      }
      else
      {
         emaLower[i] = i > 0 ? emaLower[i-1] : 0;
      }
   }
   
   // Calculate slopes and set colors
   for(int i=start; i<rates_total-SlopeWindow; i++)
   {
      // Calculate slopes using the window size
      double slopeHigh = (emaHigher[i] - emaHigher[i + SlopeWindow]) / SlopeWindow;
      double slopeLow = (emaLower[i] - emaLower[i + SlopeWindow]) / SlopeWindow;
      
      // Get ATR value for dynamic threshold
      if(CopyBuffer(atrHandle, 0, i, 1, atrBuffer) <= 0) continue;
      double atr = atrBuffer[0];
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
         dotHigherColor[i] = trendHigh; // Set color index based on new trend
      }
      else
      {
         dotHigher[i] = EMPTY_VALUE;
      }
      
      if(i > 0 && prevTrendLow != -99 && trendLow != prevTrendLow)
      {
         dotLower[i] = emaLower[i];
         dotLowerColor[i] = trendLow; // Set color index based on new trend
      }
      else
      {
         dotLower[i] = EMPTY_VALUE;
      }
      
      // Update previous trend states
      prevTrendHigh = trendHigh;
      prevTrendLow = trendLow;
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}
