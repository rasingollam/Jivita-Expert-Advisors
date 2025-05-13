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
//| Time Filter and Trading Hours Class                              |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   // Time filter settings
   bool              m_enable_time_filter;
   int               m_trading_start_hour;
   int               m_trading_start_minute;
   int               m_trading_end_hour;
   int               m_trading_end_minute;
   bool              m_use_server_time;
   bool              m_show_time_lines;
   color             m_time_lines_color;
   
   // Time line objects
   string            m_start_time_line;
   string            m_end_time_line;
   int               m_current_day;
   
public:
                     CTimeFilter();
                     ~CTimeFilter();
   
   // Initialize with parameters
   void              Configure(bool enableFilter, int startHour, int startMinute, 
                             int endHour, int endMinute, bool useServerTime, 
                             bool showLines, color lineColor);
   
   // Check if current time is within trading hours
   bool              IsWithinTradingHours();
   
   // Draw or update time lines
   void              UpdateTimeLines(bool forceRedraw = false);
   
   // Clean up time lines
   void              CleanupTimeLines();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimeFilter::CTimeFilter()
{
   m_enable_time_filter = false;
   m_trading_start_hour = 8;
   m_trading_start_minute = 30;
   m_trading_end_hour = 16;
   m_trading_end_minute = 30;
   m_use_server_time = true;
   m_show_time_lines = true;
   m_time_lines_color = clrDarkGray;
   
   m_start_time_line = "TradingStartTime";
   m_end_time_line = "TradingEndTime";
   m_current_day = -1;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimeFilter::~CTimeFilter()
{
   CleanupTimeLines();
}

//+------------------------------------------------------------------+
//| Configure time filter settings                                   |
//+------------------------------------------------------------------+
void CTimeFilter::Configure(bool enableFilter, int startHour, int startMinute, 
                          int endHour, int endMinute, bool useServerTime,
                          bool showLines, color lineColor)
{
   m_enable_time_filter = enableFilter;
   m_trading_start_hour = startHour;
   m_trading_start_minute = startMinute;
   m_trading_end_hour = endHour;
   m_trading_end_minute = endMinute;
   m_use_server_time = useServerTime;
   m_show_time_lines = showLines;
   m_time_lines_color = lineColor;
   
   // Force update of time lines
   m_current_day = -1;
   UpdateTimeLines();
}

//+------------------------------------------------------------------+
//| Check if time is within allowed trading window                   |
//+------------------------------------------------------------------+
bool CTimeFilter::IsWithinTradingHours()
{
   // If time filtering is disabled, always allow trading
   if(!m_enable_time_filter)
      return true;
      
   // Get current time (server or local based on setting)
   datetime currentTime = m_use_server_time ? TimeCurrent() : TimeLocal();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int currentHour = timeStruct.hour;
   int currentMinute = timeStruct.min;
   
   // Convert times to minutes for easier comparison
   int currentTimeInMinutes = currentHour * 60 + currentMinute;
   int startTimeInMinutes = m_trading_start_hour * 60 + m_trading_start_minute;
   int endTimeInMinutes = m_trading_end_hour * 60 + m_trading_end_minute;
   
   // Debug output with all details
   static datetime lastDebugTime = 0;
   if(currentTime - lastDebugTime > 60) // Debug every minute
   {
      lastDebugTime = currentTime;
      bool inTradingHoursSimple = (startTimeInMinutes < endTimeInMinutes) && 
                                (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes);
                                
      bool inTradingHoursOvernight = (startTimeInMinutes > endTimeInMinutes) && 
                                   (currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes <= endTimeInMinutes);
                                   
      Print("Time check - Current: ", FormatTimeHHMM(currentHour, currentMinute), 
           ", Start: ", FormatTimeHHMM(m_trading_start_hour, m_trading_start_minute),
           ", End: ", FormatTimeHHMM(m_trading_end_hour, m_trading_end_minute),
           ", Current min: ", currentTimeInMinutes,
           ", Start min: ", startTimeInMinutes,
           ", End min: ", endTimeInMinutes,
           ", Is overnight: ", (startTimeInMinutes > endTimeInMinutes ? "Yes" : "No"),
           ", Simple check: ", (inTradingHoursSimple ? "In hours" : "Outside hours"),
           ", Overnight check: ", (inTradingHoursOvernight ? "In hours" : "Outside hours"));
   }
   
   // Check if current time is within trading hours
   bool isWithin = false;
   
   if(startTimeInMinutes < endTimeInMinutes)
   {
      // Simple case: Start time is before end time (same day)
      isWithin = (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes);
   }
   else
   {
      // Overnight session case (e.g., 20:00 - 04:00)
      // FIXED: Only true if current time is AFTER start time OR BEFORE end time
      isWithin = (currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes <= endTimeInMinutes);
   }
   
   return isWithin;
}

//+------------------------------------------------------------------+
//| Draw vertical time lines on the chart                            |
//+------------------------------------------------------------------+
void CTimeFilter::UpdateTimeLines(bool forceRedraw = false)
{
   // Debug the entry to this function
   static int callCount = 0;
   callCount++;
   if(callCount % 100 == 0) // Limit debug output frequency
      Print("UpdateTimeLines called ", callCount, " times, time filter enabled: ", m_enable_time_filter);

   // Only draw if enabled
   if(!m_enable_time_filter || !m_show_time_lines)
   {
      // If lines exist but shouldn't be shown, remove them
      if(ObjectFind(0, m_start_time_line) >= 0 || ObjectFind(0, m_end_time_line) >= 0)
      {
         Print("Time filter disabled or lines hidden - removing any existing lines");
         ObjectDelete(0, m_start_time_line);
         ObjectDelete(0, m_end_time_line);
      }
      return;
   }
   
   // Get current date/time
   MqlDateTime now;
   datetime currentTime = m_use_server_time ? TimeCurrent() : TimeLocal();
   TimeToStruct(currentTime, now);
   
   // Always redraw on the first call of the day or if lines don't exist or if forced
   bool needsRedraw = forceRedraw || 
                     (now.day != m_current_day) || 
                     (ObjectFind(0, m_start_time_line) < 0) || 
                     (ObjectFind(0, m_end_time_line) < 0);
   
   // Update current day if changed
   if(now.day != m_current_day)
   {
      Print("Day changed from ", m_current_day, " to ", now.day, " - time lines need redraw");
      m_current_day = now.day;
   }
   
   // Draw or redraw if needed
   if(needsRedraw)
   {
      Print("Redrawing time lines for day ", now.day, 
            " - forceRedraw: ", forceRedraw, 
            ", found start line: ", (ObjectFind(0, m_start_time_line) >= 0),
            ", found end line: ", (ObjectFind(0, m_end_time_line) >= 0));
            
      // Delete old lines to avoid any issues
      ObjectDelete(0, m_start_time_line);
      ObjectDelete(0, m_end_time_line);
      
      // Create datetime for start and end times for TODAY
      MqlDateTime startTime, endTime;
      
      // Copy current date parts
      startTime.year = endTime.year = now.year;
      startTime.mon = endTime.mon = now.mon;
      startTime.day = endTime.day = now.day;
      
      // Set hours and minutes
      startTime.hour = m_trading_start_hour;
      startTime.min = m_trading_start_minute;
      startTime.sec = 0;
      
      endTime.hour = m_trading_end_hour;
      endTime.min = m_trading_end_minute;
      endTime.sec = 0;
      
      // Convert to datetime
      datetime startDateTime = StructToTime(startTime);
      datetime endDateTime = StructToTime(endTime);
      
      // Handle overnight sessions
      bool isOvernightSession = (m_trading_start_hour > m_trading_end_hour || 
                               (m_trading_start_hour == m_trading_end_hour && 
                                m_trading_start_minute > m_trading_end_minute));
                                
      if(isOvernightSession)
      {
         // If end time is earlier than start time, it's the next day
         MqlDateTime nextDayEnd = endTime;
         nextDayEnd.day++; // Move to next day
         endDateTime = StructToTime(nextDayEnd);
         
         Print("Overnight session detected: Start=", 
               TimeToString(startDateTime, TIME_DATE|TIME_MINUTES), 
               ", End=", TimeToString(endDateTime, TIME_DATE|TIME_MINUTES));
      }
      else
      {
         Print("Same-day session: Start=", 
               TimeToString(startDateTime, TIME_DATE|TIME_MINUTES), 
               ", End=", TimeToString(endDateTime, TIME_DATE|TIME_MINUTES));
      }
      
      // Create start time line
      if(!ObjectCreate(0, m_start_time_line, OBJ_VLINE, 0, startDateTime, 0))
      {
         Print("Failed to create start time line! Error code: ", GetLastError());
      }
      
      // Set start time line properties
      ObjectSetInteger(0, m_start_time_line, OBJPROP_COLOR, m_time_lines_color);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_BACK, false);  // Draw on top
      ObjectSetInteger(0, m_start_time_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_ZORDER, 100);  // High Z-order
      ObjectSetString(0, m_start_time_line, OBJPROP_TOOLTIP, "Trading Start: " + 
                     FormatTimeHHMM(m_trading_start_hour, m_trading_start_minute));
      
      // Create end time line
      if(!ObjectCreate(0, m_end_time_line, OBJ_VLINE, 0, endDateTime, 0))
      {
         Print("Failed to create end time line! Error code: ", GetLastError());
      }
      
      // Set end time line properties
      ObjectSetInteger(0, m_end_time_line, OBJPROP_COLOR, m_time_lines_color);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_BACK, false);  // Draw on top
      ObjectSetInteger(0, m_end_time_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_ZORDER, 100);  // High Z-order
      ObjectSetString(0, m_end_time_line, OBJPROP_TOOLTIP, "Trading End: " + 
                     FormatTimeHHMM(m_trading_end_hour, m_trading_end_minute));
      
      ChartRedraw(0); // Force chart redraw
      Print("Trading time lines created for day ", now.day);

      // Add extensive debug output at the end
      Print("Time lines created: ",
            "Start line exists: ", (ObjectFind(0, m_start_time_line) >= 0),
            ", End line exists: ", (ObjectFind(0, m_end_time_line) >= 0));
   }
}

//+------------------------------------------------------------------+
//| Clean up time lines                                              |
//+------------------------------------------------------------------+
void CTimeFilter::CleanupTimeLines()
{
   if(ObjectFind(0, m_start_time_line) >= 0)
      ObjectDelete(0, m_start_time_line);
      
   if(ObjectFind(0, m_end_time_line) >= 0)
      ObjectDelete(0, m_end_time_line);
}

//+------------------------------------------------------------------+
//| Format time as string (HH:MM)                                    |
//+------------------------------------------------------------------+
string FormatTimeHHMM(int hour, int minute)
{
   return (hour < 10 ? "0" : "") + IntegerToString(hour) + ":" + 
          (minute < 10 ? "0" : "") + IntegerToString(minute);
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
