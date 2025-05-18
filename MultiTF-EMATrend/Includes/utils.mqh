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
   
   // Check if current time is within trading hours
   if(startTimeInMinutes < endTimeInMinutes)
   {
      // Simple case: Start time is before end time (same day)
      return (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes);
   }
   else
   {
      // Overnight session case (e.g., 20:00 - 04:00)
      return (currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes <= endTimeInMinutes);
   }
}

//+------------------------------------------------------------------+
//| Draw vertical time lines on the chart                            |
//+------------------------------------------------------------------+
void CTimeFilter::UpdateTimeLines(bool forceRedraw = false)
{
   // Only draw if enabled
   if(!m_enable_time_filter || !m_show_time_lines)
   {
      // If lines exist but shouldn't be shown, remove them
      if(ObjectFind(0, m_start_time_line) >= 0 || ObjectFind(0, m_end_time_line) >= 0)
      {
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
      m_current_day = now.day;
   }
   
   // Draw or redraw if needed
   if(needsRedraw)
   {
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
      }
      
      // Create start time line
      if(!ObjectCreate(0, m_start_time_line, OBJ_VLINE, 0, startDateTime, 0))
      {
         Print("Failed to create trading start time line");
         return;
      }
      
      // Set start time line properties
      ObjectSetInteger(0, m_start_time_line, OBJPROP_COLOR, m_time_lines_color);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_BACK, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, m_start_time_line, OBJPROP_ZORDER, 100);
      ObjectSetString(0, m_start_time_line, OBJPROP_TOOLTIP, "Trading Start: " + 
                     FormatTimeHHMM(m_trading_start_hour, m_trading_start_minute));
      
      // Create end time line
      if(!ObjectCreate(0, m_end_time_line, OBJ_VLINE, 0, endDateTime, 0))
      {
         Print("Failed to create trading end time line");
         return;
      }
      
      // Set end time line properties
      ObjectSetInteger(0, m_end_time_line, OBJPROP_COLOR, m_time_lines_color);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_BACK, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, m_end_time_line, OBJPROP_ZORDER, 100);
      ObjectSetString(0, m_end_time_line, OBJPROP_TOOLTIP, "Trading End: " + 
                     FormatTimeHHMM(m_trading_end_hour, m_trading_end_minute));
      
      ChartRedraw(0); // Force chart redraw
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

// Add after the other utility classes
//+------------------------------------------------------------------+
//| Profit and Statistics Tracking Class                             |
//+------------------------------------------------------------------+
class CProfitTracker
{
private:
   int               m_magic_number;          // Magic number to track
   string            m_symbol;                // Symbol to track
   bool              m_initialized;           // Whether history has been loaded
   double            m_initial_balance;       // Initial account balance for percentage calculations

   // Performance metrics
   double            m_cumulative_profit;     // Total profit from closed positions
   int               m_total_trades;          // Total number of closed trades
   ulong             m_last_deal_ticket;      // Last processed deal ticket
   
   // Statistics
   int               m_winning_trades;        // Count of winning trades
   int               m_losing_trades;         // Count of losing trades
   double            m_total_profits;         // Sum of all profitable trades
   double            m_total_losses;          // Sum of all losing trades (absolute value)
   
   // Global variable prefix for storing/loading data
   string            m_global_prefix;

   // Save current state to global variables
   void SaveToGlobal()
   {
      GlobalVariableSet(m_global_prefix + "CumulativeProfit", m_cumulative_profit);
      GlobalVariableSet(m_global_prefix + "TotalTrades", m_total_trades);
      GlobalVariableSet(m_global_prefix + "LastDealTicket", (double)m_last_deal_ticket);
      GlobalVariableSet(m_global_prefix + "WinningTrades", m_winning_trades);
      GlobalVariableSet(m_global_prefix + "LosingTrades", m_losing_trades);
      GlobalVariableSet(m_global_prefix + "TotalProfits", m_total_profits);
      GlobalVariableSet(m_global_prefix + "TotalLosses", m_total_losses);
      
      // Save initial balance for percentage calculations
      GlobalVariableSet(m_global_prefix + "InitialBalance", m_initial_balance);
   }
   
   // Load state from global variables
   void LoadFromGlobal()
   {
      if(GlobalVariableCheck(m_global_prefix + "CumulativeProfit"))
         m_cumulative_profit = GlobalVariableGet(m_global_prefix + "CumulativeProfit");
         
      if(GlobalVariableCheck(m_global_prefix + "TotalTrades"))
         m_total_trades = (int)GlobalVariableGet(m_global_prefix + "TotalTrades");
         
      if(GlobalVariableCheck(m_global_prefix + "LastDealTicket"))
         m_last_deal_ticket = (ulong)GlobalVariableGet(m_global_prefix + "LastDealTicket");
         
      if(GlobalVariableCheck(m_global_prefix + "WinningTrades"))
         m_winning_trades = (int)GlobalVariableGet(m_global_prefix + "WinningTrades");
         
      if(GlobalVariableCheck(m_global_prefix + "LosingTrades"))
         m_losing_trades = (int)GlobalVariableGet(m_global_prefix + "LosingTrades");
         
      if(GlobalVariableCheck(m_global_prefix + "TotalProfits"))
         m_total_profits = GlobalVariableGet(m_global_prefix + "TotalProfits");
         
      if(GlobalVariableCheck(m_global_prefix + "TotalLosses"))
         m_total_losses = GlobalVariableGet(m_global_prefix + "TotalLosses");
         
      // Load initial balance if exists, otherwise use current balance
      if(GlobalVariableCheck(m_global_prefix + "InitialBalance"))
         m_initial_balance = GlobalVariableGet(m_global_prefix + "InitialBalance");
      else
         m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
public:
   // Constructor
   CProfitTracker(int magicNumber, string symbol = NULL)
   {
      m_magic_number = magicNumber;
      m_symbol = symbol == NULL ? Symbol() : symbol;
      m_initialized = false;
      
      // Initialize performance metrics
      m_cumulative_profit = 0;
      m_total_trades = 0;
      m_last_deal_ticket = 0;
      
      // Initialize statistics
      m_winning_trades = 0;
      m_losing_trades = 0;
      m_total_profits = 0;
      m_total_losses = 0;
      
      // Store initial balance for percentage calculations
      m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      // Set global variable prefix
      m_global_prefix = "EMATrend_" + m_symbol + "_" + IntegerToString(m_magic_number) + "_";
      
      // Load previous state if exists
      LoadFromGlobal();
   }
   
   // Initialize by loading trade history
   bool Initialize(datetime startTime = 0)
   {
      if(m_initialized)
         return true;
         
      // Use beginning of history if no start time specified
      if(startTime == 0)
      {
         // MQL5 doesn't have ACCOUNT_OPEN_TIME, use beginning of history instead
         datetime server_time = TimeCurrent();
         startTime = server_time - 30*24*60*60; // Look back 30 days by default
         Print("Using lookback period of 30 days for profit tracking");
      }
         
      // Select history from the specified start time
      if(!HistorySelect(startTime, TimeCurrent()))
      {
         Print("Failed to select history for initializing profit tracker");
         return false;
      }
      
      // Process all deals to find our trades
      int totalDeals = HistoryDealsTotal();
      
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         
         // Skip deals that don't belong to our symbol and magic number
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != m_symbol)
            continue;
            
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic_number)
            continue;
            
         // We only process outgoing deals (position closing)
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            
            // Update our statistics
            m_cumulative_profit += profit;
            m_total_trades++;
            
            // Track win/loss statistics
            if(profit >= 0)
            {
               m_winning_trades++;
               m_total_profits += profit;
            }
            else
            {
               m_losing_trades++;
               m_total_losses += MathAbs(profit);
            }
            
            // Update last deal ticket
            if(dealTicket > m_last_deal_ticket)
               m_last_deal_ticket = dealTicket;
         }
      }
      
      m_initialized = true;
      
      // Save loaded data to globals
      SaveToGlobal();
      
      Print("Profit Tracker initialized: Total trades: ", m_total_trades, 
            ", Profit: ", DoubleToString(m_cumulative_profit, 2),
            ", Win rate: ", DoubleToString(GetWinRate(), 2), "%");
            
      return true;
   }
   
   // Update statistics with new closed trades
   void Update()
   {
      // Early exit if we can't select history
      if(!HistorySelect(0, TimeCurrent()))
      {
         Print("Failed to select history for updating profit tracker");
         return;
      }
      
      // Process deals since last update
      ulong newLastDealTicket = m_last_deal_ticket;
      double newProfit = 0;
      int newTrades = 0;
      int newWins = 0;
      double newProfits = 0;
      double newLosses = 0;
      
      int totalDeals = HistoryDealsTotal();
      
      // First pass: calculate changes
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         
         // Skip already processed deals
         if(dealTicket <= m_last_deal_ticket)
            continue;
            
         // Check if this deal belongs to our symbol and magic number
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != m_symbol)
            continue;
            
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic_number)
            continue;
            
         // Only count completed trades (position closing)
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            newProfit += profit;
            newTrades++;
            
            // Track wins and losses for winrate calculation
            if(profit >= 0)
            {
               newWins++;
               newProfits += profit;
            }
            else
            {
               newLosses += MathAbs(profit);
            }
            
            // Track highest ticket for next update
            if(dealTicket > newLastDealTicket)
               newLastDealTicket = dealTicket;
         }
      }
      
      // Second pass: apply changes if we found any new deals
      if(newTrades > 0)
      {
         m_cumulative_profit += newProfit;
         m_total_trades += newTrades;
         m_winning_trades += newWins;
         m_losing_trades += (newTrades - newWins);
         m_total_profits += newProfits;
         m_total_losses += newLosses;
         m_last_deal_ticket = newLastDealTicket;
         
         // Log the update
         Print("Updated profit statistics: Added ", newTrades, " new trades, profit: ",
               DoubleToString(newProfit, 2), ", total: ", DoubleToString(m_cumulative_profit, 2));
               
         // Save data to globals
         SaveToGlobal();
      }
   }
   
   // Get statistics for open positions
   void GetOpenPositionStats(double &profit, int &count)
   {
      profit = 0;
      count = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol && 
               PositionGetInteger(POSITION_MAGIC) == m_magic_number)
            {
               profit += PositionGetDouble(POSITION_PROFIT);
               count++;
            }
         }
      }
   }
   
   // Get win rate percentage
   double GetWinRate()
   {
      if(m_total_trades == 0)
         return 0;
         
      return (double)m_winning_trades / m_total_trades * 100.0;
   }
   
   // Get profit factor
   double GetProfitFactor()
   {
      if(m_total_losses == 0)
         return (m_total_profits > 0) ? 999.99 : 0;
         
      return m_total_profits / m_total_losses;
   }
   
   // Get total closed trades count
   int GetTotalTrades()
   {
      return m_total_trades;
   }
   
   // Get cumulative profit from all closed trades
   double GetCumulativeProfit()
   {
      return m_cumulative_profit;
   }
   
   // Get winning trades count
   int GetWinningTrades()
   {
      return m_winning_trades;
   }
   
   // Get losing trades count
   int GetLosingTrades()
   {
      return m_losing_trades;
   }
   
   // Calculate profit as percentage of initial balance
   double GetProfitPercentage()
   {
      if(m_initial_balance <= 0)
         return 0;
         
      return (m_cumulative_profit / m_initial_balance) * 100.0;
   }
   
   // Calculate average profit per winning trade (percentage)
   double GetAverageProfitPercentage()
   {
      if(m_initial_balance <= 0 || m_winning_trades == 0)
         return 0;
      
      return (m_total_profits / m_winning_trades / m_initial_balance) * 100.0;
   }
   
   // Calculate average loss per losing trade (percentage)
   double GetAverageLossPercentage()
   {
      if(m_initial_balance <= 0 || m_losing_trades == 0)
         return 0;
      
      return (m_total_losses / m_losing_trades / m_initial_balance) * 100.0;
   }
   
   // Process transaction update
   void OnTradeTransaction(const MqlTradeTransaction &trans)
   {
      // Look for deal add transactions that would indicate a position was closed
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_type != DEAL_TYPE_BALANCE)
      {
         // A new deal has occurred, update our statistics
         Update();
      }
   }
   
   // Format profit information for display
   string GetProfitInfoString()
   {
      string info = "\n\n=== Profit Information ===";
      
      // Show statistics for all completed trades
      info += "\nTotal Trades: " + IntegerToString(m_total_trades);
      info += "\nWin Rate: " + DoubleToString(GetWinRate(), 2) + "%";
      info += "\nProfit Factor: " + DoubleToString(GetProfitFactor(), 2);
      
      // Add profit information with percentages
      info += "\nCumulative Profit: " + DoubleToString(m_cumulative_profit, 2) + 
              " (" + DoubleToString(GetProfitPercentage(), 2) + "%)";
      
      // Add average profit and loss per trade with percentages
      // if(m_winning_trades > 0)
      // {
      //    double avgProfit = m_total_profits / m_winning_trades;
      //    info += "\nAvg. Win: " + DoubleToString(avgProfit, 2) + 
      //            " (" + DoubleToString(GetAverageProfitPercentage(), 2) + "%)";
      // }
      
      // if(m_losing_trades > 0)
      // {
      //    double avgLoss = m_total_losses / m_losing_trades;
      //    info += "\nAvg. Loss: " + DoubleToString(avgLoss, 2) + 
      //            " (" + DoubleToString(GetAverageLossPercentage(), 2) + "%)";
      // }
      
      // Get open position statistics
      double openProfit = 0;
      int openCount = 0;
      GetOpenPositionStats(openProfit, openCount);
      
      // Show open position information if any positions are open
      if(openCount > 0)
      {
         info += "\n\n--- Open Positions ---";
         info += "\nOpen Positions: " + IntegerToString(openCount);
         info += "\nOpen P/L: " + DoubleToString(openProfit, 2) + 
                 " (" + DoubleToString((openProfit / m_initial_balance) * 100, 2) + "%)";
                 
         // Total P/L represents the combined result of closed trades plus current open positions
         // double totalPL = m_cumulative_profit + openProfit;
         // info += "\nTotal P/L: " + DoubleToString(totalPL, 2) + 
         //         " (" + DoubleToString((totalPL / m_initial_balance) * 100, 2) + "%)";
      }
      
      return info;
   }
};
