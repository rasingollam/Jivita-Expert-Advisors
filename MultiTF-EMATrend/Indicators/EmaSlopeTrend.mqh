//+------------------------------------------------------------------+
//|                                                EmaSlopeTrend.mqh |
//|                           Copyright 2025, Jivita Expert Advisors |
//|                                            by Malinda Rasingolla |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita Expert Advisors"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CEmaSlopeTrend class                                             |
//| Calculates EMA slope trends across multiple timeframes           |
//+------------------------------------------------------------------+
class CEmaSlopeTrend
{
private:
   // Parameters
   int               m_ema_period_higher;
   int               m_ema_period_lower;
   ENUM_TIMEFRAMES   m_higher_timeframe;
   ENUM_TIMEFRAMES   m_lower_timeframe;
   int               m_slope_window;
   int               m_atr_period;
   double            m_atr_multiplier;
   
   // Indicator handles
   int               m_ema_higher_handle;
   int               m_ema_lower_handle;
   int               m_atr_higher_handle;  // Separate ATR handle for higher timeframe
   int               m_atr_lower_handle;   // Separate ATR handle for lower timeframe
   
   // Previous trend states
   int               m_prev_trend_high;
   int               m_prev_trend_low;
   
   // Signal tracking
   int               m_last_plotted_signal_type; // -1 = none, 0 = buy, 1 = sell
   int               m_arrow_counter;
   bool              m_draw_arrows;
   color             m_buy_arrow_color;
   color             m_sell_arrow_color;
   int               m_arrow_size;
   
   // Internal buffers
   double            m_higher_ema_buffer[];
   double            m_lower_ema_buffer[];
   double            m_atr_higher_buffer[];  // ATR buffer for higher timeframe
   double            m_atr_lower_buffer[];   // ATR buffer for lower timeframe
   
   // Draw an arrow on the chart
   bool              DrawBuySellArrow(const string name, datetime time, double price, 
                                    bool isBuy, color arrowColor, int size);
   
public:
                     CEmaSlopeTrend();
                     ~CEmaSlopeTrend();
   
   // Initialize with parameters
   bool              Init(int ema_period_higher, int ema_period_lower, 
                        ENUM_TIMEFRAMES higher_timeframe, ENUM_TIMEFRAMES lower_timeframe,
                        int slope_window, int atr_period, double atr_multiplier);
   
   // Configure arrow settings
   void              ConfigureArrows(bool drawArrows, color buyColor, color sellColor, int arrowSize);
   
   // Calculate trend values for specific bar
   bool              Calculate(int bar, datetime time,
                             double &ema_higher, double &ema_lower,
                             int &color_higher, int &color_lower,
                             double &dot_higher, double &dot_lower,
                             int &dot_higher_color, int &dot_lower_color);
   
   // Check for trend alignment and draw arrows if needed
   void              CheckTrendAlignment();
   
   // Clean up any objects created by this class
   void              CleanupObjects();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEmaSlopeTrend::CEmaSlopeTrend()
{
   m_ema_period_higher = 50;
   m_ema_period_lower = 20;
   m_higher_timeframe = PERIOD_H4;
   m_lower_timeframe = PERIOD_H1;
   m_slope_window = 5;
   m_atr_period = 14;
   m_atr_multiplier = 0.5;
   
   m_ema_higher_handle = INVALID_HANDLE;
   m_ema_lower_handle = INVALID_HANDLE;
   m_atr_higher_handle = INVALID_HANDLE;
   m_atr_lower_handle = INVALID_HANDLE;
   
   m_prev_trend_high = -99;
   m_prev_trend_low = -99;
   
   m_last_plotted_signal_type = -1;
   m_arrow_counter = 0;
   m_draw_arrows = true;
   m_buy_arrow_color = clrLime;
   m_sell_arrow_color = clrRed;
   m_arrow_size = 1;
   
   ArraySetAsSeries(m_higher_ema_buffer, true);
   ArraySetAsSeries(m_lower_ema_buffer, true);
   ArraySetAsSeries(m_atr_higher_buffer, true);
   ArraySetAsSeries(m_atr_lower_buffer, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEmaSlopeTrend::~CEmaSlopeTrend()
{
   // Release indicator handles
   if(m_ema_higher_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_higher_handle);
      
   if(m_ema_lower_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_lower_handle);
      
   if(m_atr_higher_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_higher_handle);
      
   if(m_atr_lower_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_lower_handle);
}

//+------------------------------------------------------------------+
//| Initialize with parameters                                       |
//+------------------------------------------------------------------+
bool CEmaSlopeTrend::Init(int ema_period_higher, int ema_period_lower, 
                        ENUM_TIMEFRAMES higher_timeframe, ENUM_TIMEFRAMES lower_timeframe,
                        int slope_window, int atr_period, double atr_multiplier)
{
   // Store parameters
   m_ema_period_higher = ema_period_higher;
   m_ema_period_lower = ema_period_lower;
   m_higher_timeframe = higher_timeframe;
   m_lower_timeframe = lower_timeframe;
   m_slope_window = slope_window;
   m_atr_period = atr_period;
   m_atr_multiplier = atr_multiplier;
   
   // Create indicator handles
   m_ema_higher_handle = iMA(Symbol(), m_higher_timeframe, m_ema_period_higher, 0, MODE_EMA, PRICE_CLOSE);
   m_ema_lower_handle = iMA(Symbol(), m_lower_timeframe, m_ema_period_lower, 0, MODE_EMA, PRICE_CLOSE);
   m_atr_higher_handle = iATR(Symbol(), m_higher_timeframe, m_atr_period);  // ATR for higher timeframe
   m_atr_lower_handle = iATR(Symbol(), m_lower_timeframe, m_atr_period);    // ATR for lower timeframe
   
   // Verify handles
   if(m_ema_higher_handle == INVALID_HANDLE || m_ema_lower_handle == INVALID_HANDLE || 
      m_atr_higher_handle == INVALID_HANDLE || m_atr_lower_handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles in EmaSlopeTrend");
      return false;
   }
   
   // Reset trend states
   m_prev_trend_high = -99;
   m_prev_trend_low = -99;
   
   // Reset signal tracking
   m_last_plotted_signal_type = -1;
   m_arrow_counter = 0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Configure arrow settings                                         |
//+------------------------------------------------------------------+
void CEmaSlopeTrend::ConfigureArrows(bool drawArrows, color buyColor, color sellColor, int arrowSize)
{
   m_draw_arrows = drawArrows;
   m_buy_arrow_color = buyColor;
   m_sell_arrow_color = sellColor;
   m_arrow_size = arrowSize;
}

//+------------------------------------------------------------------+
//| Draw a buy/sell arrow on the chart                               |
//+------------------------------------------------------------------+
bool CEmaSlopeTrend::DrawBuySellArrow(const string name, datetime time, double price, 
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

//+------------------------------------------------------------------+
//| Calculate values for specific bar                                |
//+------------------------------------------------------------------+
bool CEmaSlopeTrend::Calculate(int bar, datetime time,
                             double &ema_higher, double &ema_lower,
                             int &color_higher, int &color_lower,
                             double &dot_higher, double &dot_lower,
                             int &dot_higher_color, int &dot_lower_color)
{
   // Initialize dot values
   dot_higher = EMPTY_VALUE;
   dot_lower = EMPTY_VALUE;
   dot_higher_color = 0;
   dot_lower_color = 0;
   
   // Get higher timeframe EMA
   int higherTFBar = iBarShift(Symbol(), m_higher_timeframe, time);
   if(higherTFBar < 0 || CopyBuffer(m_ema_higher_handle, 0, higherTFBar, 1, m_higher_ema_buffer) <= 0)
   {
      return false;
   }
   
   // Get lower timeframe EMA
   int lowerTFBar = iBarShift(Symbol(), m_lower_timeframe, time);
   if(lowerTFBar < 0 || CopyBuffer(m_ema_lower_handle, 0, lowerTFBar, 1, m_lower_ema_buffer) <= 0)
   {
      return false;
   }
   
   // Store EMA values
   ema_higher = m_higher_ema_buffer[0];
   ema_lower = m_lower_ema_buffer[0];
   
   // We need additional bars for slope calculation
   double higherSlopeBuffer[];
   double lowerSlopeBuffer[];
   
   ArraySetAsSeries(higherSlopeBuffer, true);
   ArraySetAsSeries(lowerSlopeBuffer, true);
   
   // Get EMA values for slope calculation
   if(CopyBuffer(m_ema_higher_handle, 0, higherTFBar, m_slope_window + 1, higherSlopeBuffer) <= 0)
      return false;
      
   if(CopyBuffer(m_ema_lower_handle, 0, lowerTFBar, m_slope_window + 1, lowerSlopeBuffer) <= 0)
      return false;
   
   // Calculate slopes
   double slopeHigh = (higherSlopeBuffer[0] - higherSlopeBuffer[m_slope_window]) / m_slope_window;
   double slopeLow = (lowerSlopeBuffer[0] - lowerSlopeBuffer[m_slope_window]) / m_slope_window;
   
   // Get ATR for each timeframe separately
   if(CopyBuffer(m_atr_higher_handle, 0, higherTFBar, 1, m_atr_higher_buffer) <= 0)
      return false;
      
   if(CopyBuffer(m_atr_lower_handle, 0, lowerTFBar, 1, m_atr_lower_buffer) <= 0)
      return false;
      
   double atrHigher = m_atr_higher_buffer[0];
   double atrLower = m_atr_lower_buffer[0];
   
   // Calculate separate thresholds for each timeframe
   double thresholdHigher = atrHigher * m_atr_multiplier;
   double thresholdLower = atrLower * m_atr_multiplier;
   
   // Debug output
   Print("Higher TF ATR: ", atrHigher, ", Threshold: ", thresholdHigher, ", Slope: ", slopeHigh);
   Print("Lower TF ATR: ", atrLower, ", Threshold: ", thresholdLower, ", Slope: ", slopeLow);
   
   // Determine trend directions using appropriate thresholds
   int trendHigh = 0; // Neutral (gray)
   int trendLow = 0;  // Neutral (gray)
   
   if(slopeHigh > thresholdHigher) trendHigh = 1; // Uptrend (green)
   else if(slopeHigh < -thresholdHigher) trendHigh = 2; // Downtrend (red)
   
   if(slopeLow > thresholdLower) trendLow = 1; // Uptrend (green)
   else if(slopeLow < -thresholdLower) trendLow = 2; // Downtrend (red)
   
   // Store color indices
   color_higher = trendHigh;
   color_lower = trendLow;
   
   // Check for trend changes and mark with dots
   if(m_prev_trend_high != -99 && trendHigh != m_prev_trend_high)
   {
      dot_higher = ema_higher;
      dot_higher_color = trendHigh;
   }
   
   if(m_prev_trend_low != -99 && trendLow != m_prev_trend_low)
   {
      dot_lower = ema_lower;
      dot_lower_color = trendLow;
   }
   
   // Update previous trend states
   m_prev_trend_high = trendHigh;
   m_prev_trend_low = trendLow;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for trend alignment and draw arrows                        |
//+------------------------------------------------------------------+
void CEmaSlopeTrend::CheckTrendAlignment()
{
   // Skip if arrow drawing is disabled
   if(!m_draw_arrows) return;
   
   // Get previous candle close price for signal placement
   double prevClose = iClose(Symbol(), PERIOD_CURRENT, 1);
   datetime prevTime = iTime(Symbol(), PERIOD_CURRENT, 1);
   
   // Check for bullish alignment (both trends are bullish/green)
   if(m_prev_trend_high == 1 && m_prev_trend_low == 1)
   {
      // Only draw if this is a new signal type
      if(m_last_plotted_signal_type != 0)
      {
         // Draw buy arrow at previous candle's close
         string arrowName = "BuyArrow_" + IntegerToString(m_arrow_counter++);
         DrawBuySellArrow(arrowName, prevTime, prevClose, true, m_buy_arrow_color, m_arrow_size);
         Print("Buy signal detected - both trends are bullish");
         
         // Update last plotted signal type
         m_last_plotted_signal_type = 0;  // 0 = buy signal
      }
   }
   // Check for bearish alignment (both trends are bearish/red)
   else if(m_prev_trend_high == 2 && m_prev_trend_low == 2)
   {
      // Only draw if this is a new signal type
      if(m_last_plotted_signal_type != 1)
      {
         // Draw sell arrow at previous candle's close
         string arrowName = "SellArrow_" + IntegerToString(m_arrow_counter++);
         DrawBuySellArrow(arrowName, prevTime, prevClose, false, m_sell_arrow_color, m_arrow_size);
         Print("Sell signal detected - both trends are bearish");
         
         // Update last plotted signal type
         m_last_plotted_signal_type = 1;  // 1 = sell signal
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up any objects created by this class                       |
//+------------------------------------------------------------------+
void CEmaSlopeTrend::CleanupObjects()
{
   // Delete all arrows created by this class
   ObjectsDeleteAll(0, "BuyArrow_");
   ObjectsDeleteAll(0, "SellArrow_");
   
   // Reset signal tracking
   m_last_plotted_signal_type = -1;
}
