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
   
   // Internal buffers
   double            m_higher_ema_buffer[];
   double            m_lower_ema_buffer[];
   double            m_atr_higher_buffer[];  // ATR buffer for higher timeframe
   double            m_atr_lower_buffer[];   // ATR buffer for lower timeframe
   
public:
                     CEmaSlopeTrend();
                     ~CEmaSlopeTrend();
   
   // Initialize with parameters
   bool              Init(int ema_period_higher, int ema_period_lower, 
                        ENUM_TIMEFRAMES higher_timeframe, ENUM_TIMEFRAMES lower_timeframe,
                        int slope_window, int atr_period, double atr_multiplier);
   
   // Calculate trend values for specific bar
   bool              Calculate(int bar, datetime time,
                             double &ema_higher, double &ema_lower,
                             int &color_higher, int &color_lower,
                             double &dot_higher, double &dot_lower,
                             int &dot_higher_color, int &dot_lower_color);
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
