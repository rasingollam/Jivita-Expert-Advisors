//+------------------------------------------------------------------+
//|                                                       utils.mqh |
//|                           Copyright 2025, Jivita Expert Advisors |
//|                                            by Malinda Rasingolla |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita Expert Advisors"
#property version   "1.00"

//+------------------------------------------------------------------+
//| New Bar Detection Class                                          |
//+------------------------------------------------------------------+
class CNewBarDetector
{
private:
   datetime          m_last_bar_time;
   int               m_bar_count;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
public:
                     CNewBarDetector(string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   void              Reset();
   bool              IsNewBar();
   int               GetBarCount() { return m_bar_count; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewBarDetector::CNewBarDetector(string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   m_symbol = symbol == NULL ? Symbol() : symbol;
   m_timeframe = timeframe;
   Reset();
}

//+------------------------------------------------------------------+
//| Reset bar counting                                               |
//+------------------------------------------------------------------+
void CNewBarDetector::Reset()
{
   m_bar_count = 0;
   m_last_bar_time = 0;
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool CNewBarDetector::IsNewBar()
{
   datetime current_bar_time = iTime(m_symbol, m_timeframe, 0);
   
   // If this is a new bar
   if(current_bar_time != m_last_bar_time)
   {
      m_last_bar_time = current_bar_time;
      m_bar_count++;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Timeframe utilities                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Convert timeframe to string with readable name                   |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Trend direction utilities                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Convert trend code to descriptive string                         |
//+------------------------------------------------------------------+
string TrendToString(int trendCode)
{
   switch(trendCode)
   {
      case 0:  return "NEUTRAL";
      case 1:  return "BULLISH";
      case 2:  return "BEARISH";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Convert trend code to color                                      |
//+------------------------------------------------------------------+
color TrendToColor(int trendCode)
{
   switch(trendCode)
   {
      case 0:  return clrGray;    // Neutral
      case 1:  return clrGreen;   // Bullish
      case 2:  return clrRed;     // Bearish
      default: return clrNONE;
   }
}

//+------------------------------------------------------------------+
//| Format price with appropriate digits                             |
//+------------------------------------------------------------------+
string FormatPrice(double price, string symbol = NULL)
{
   if(symbol == NULL) symbol = Symbol();
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}
