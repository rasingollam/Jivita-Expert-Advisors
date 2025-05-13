//+------------------------------------------------------------------+
//|                                                TradeManager.mqh  |
//|                           Copyright 2025, Jivita Expert Advisors |
//|                                            by Malinda Rasingolla |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita Expert Advisors"
#property version   "1.00"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Class to manage trading operations for MultiTF-EmaTrend          |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade            m_trade;
   int               m_magic_number;
   string            m_trade_comment;
   bool              m_trading_enabled;
   double            m_lot_size;
   
   // Stop loss and take profit settings
   bool              m_use_sl;
   double            m_sl_atr_multiplier;
   double            m_risk_reward_ratio;
   int               m_atr_period;
   int               m_atr_handle;
   
   // Position and signal tracking
   bool              m_has_position;
   bool              m_is_long;
   int               m_last_processed_signal; // -1 = none, 0 = buy, 1 = sell
   
   // Trailing stop settings
   bool              m_enable_trailing_stop;  // Whether to use trailing stop functionality
   bool              m_show_trailing_stop;    // Whether to show trailing stop visualization
   
   // Trailing stop visualization
   string            m_trendline_name;
   datetime          m_line_start_time;
   datetime          m_line_end_time;
   double            m_current_stop_level;  // Track the current stop level
   datetime          m_last_bar_time;       // Track when we last updated the stop
   
   // Risk-based position sizing
   double            m_risk_percent;      // Risk percentage per trade
   
   // Time-based trading filter settings
   bool              m_enable_time_filter;
   int               m_trading_start_hour;
   int               m_trading_start_minute;
   int               m_trading_end_hour;
   int               m_trading_end_minute;
   bool              m_use_server_time;
   
   // Get current position info for this EA
   bool              GetPositionInfo();
   
   // Calculate ATR-based stop loss and take profit
   double            CalculateStopLoss(bool isBuy, double price);
   double            CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss);
   
   // Calculate lot size based on risk percentage and stop loss
   double            CalculateLotSize(double entryPrice, double stopLoss);
   
   // Trailing stop visualization methods
   void              UpdateTrailingStopLine();
   void              RemoveTrailingStopLine();
   
   // Check if price has crossed the trailing stop line
   bool              CheckStopLevelCrossed();
   
public:
                     CTradeManager();
                     ~CTradeManager();
                     
   // Initialize with parameters                  
   void              Init(int magic, bool enabled, double lots);
   
   // Configure stop loss and take profit settings
   void              ConfigureRiskManagement(bool useSl, double slAtrMulti, double riskReward, int atrPeriod);
   
   // Configure trailing stop settings
   void              ConfigureTrailingStop(bool enableTrailing, bool showVisual);
   
   // Configure risk-based position sizing
   void              ConfigureRiskBasedSize(double riskPercent);
   
   // Configure time-based trading filter
   void              ConfigureTimeFilter(bool enableFilter, int startHour, int startMinute, 
                                       int endHour, int endMinute, bool useServerTime);
   
   // Previous method now renamed for clarity
   void              ConfigureTrailingStopVisual(bool showLine) { m_show_trailing_stop = showLine; }
   
   // Process trading signals
   void              ProcessSignal(int signalType, bool allowNewTrades = true);
   
   // Open a new position
   bool              OpenPosition(bool isBuy);
   
   // Close any existing positions
   bool              CloseAllPositions();
   
   // Update trailing stop on each tick
   void              OnTick();
   
   // Method to notify trade manager of a new bar
   void              OnNewBar();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_magic_number = 123456;
   m_trade_comment = "MultiTF-EmaTrend";
   m_trading_enabled = true;
   m_lot_size = 0.01;
   
   m_use_sl = true;
   m_sl_atr_multiplier = 1.0;
   m_risk_reward_ratio = 2.0;
   m_atr_period = 14;
   m_atr_handle = INVALID_HANDLE;
   
   m_has_position = false;
   m_is_long = false;
   m_last_processed_signal = -1;
   
   // Initialize trailing stop settings
   m_enable_trailing_stop = true;
   m_show_trailing_stop = true;
   
   // Initialize trailing stop visualization
   m_trendline_name = "TrailingStopLine";
   m_line_start_time = 0;
   m_line_end_time = 0;
   m_current_stop_level = 0;
   m_last_bar_time = 0;
   
   // Initialize risk-based sizing
   m_risk_percent = 1.0; // Default 1% risk
   
   // Initialize time filter settings
   m_enable_time_filter = false;
   m_trading_start_hour = 8;
   m_trading_start_minute = 30;
   m_trading_end_hour = 16;
   m_trading_end_minute = 30;
   m_use_server_time = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
   
   // Remove trailing stop line
   RemoveTrailingStopLine();
}

//+------------------------------------------------------------------+
//| Initialize the trade manager                                     |
//+------------------------------------------------------------------+
void CTradeManager::Init(int magic, bool enabled, double lots)
{
   m_magic_number = magic;
   m_trading_enabled = enabled;
   m_lot_size = lots;
   
   // Set up the trade object
   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   
   // Check if we already have a position (in case of EA restart)
   GetPositionInfo();
   
   // Reset signal tracking
   m_last_processed_signal = -1;
}

//+------------------------------------------------------------------+
//| Configure risk management settings                               |
//+------------------------------------------------------------------+
void CTradeManager::ConfigureRiskManagement(bool useSl, double slAtrMulti, double riskReward, int atrPeriod)
{
   m_use_sl = useSl;
   m_sl_atr_multiplier = slAtrMulti;
   m_risk_reward_ratio = riskReward;
   m_atr_period = atrPeriod;
   
   // Create ATR indicator handle if we're using SL/TP
   if(m_use_sl)
   {
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
         
      m_atr_handle = iATR(Symbol(), PERIOD_CURRENT, m_atr_period);
      
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("Failed to create ATR indicator handle for TradeManager");
         m_use_sl = false; // Disable SL if we can't create the indicator
      }
   }
}

//+------------------------------------------------------------------+
//| Configure trailing stop settings                                 |
//+------------------------------------------------------------------+
void CTradeManager::ConfigureTrailingStop(bool enableTrailing, bool showVisual)
{
   m_enable_trailing_stop = enableTrailing;
   m_show_trailing_stop = showVisual;
   
   // If visualization is turned off, remove existing line
   if(!m_show_trailing_stop)
   {
      RemoveTrailingStopLine();
   }
}

//+------------------------------------------------------------------+
//| Configure risk-based position sizing                             |
//+------------------------------------------------------------------+
void CTradeManager::ConfigureRiskBasedSize(double riskPercent)
{
   m_risk_percent = riskPercent;
}

//+------------------------------------------------------------------+
//| Configure time-based trading filter                              |
//+------------------------------------------------------------------+
void CTradeManager::ConfigureTimeFilter(bool enableFilter, int startHour, int startMinute, 
                                      int endHour, int endMinute, bool useServerTime)
{
   m_enable_time_filter = enableFilter;
   m_trading_start_hour = startHour;
   m_trading_start_minute = startMinute;
   m_trading_end_hour = endHour;
   m_trading_end_minute = endMinute;
   m_use_server_time = useServerTime;
   
   Print("Time filter configured: ", 
        (m_enable_time_filter ? "Enabled" : "Disabled"), 
        ", Trading hours: ", 
        (m_trading_start_hour < 10 ? "0" : ""), m_trading_start_hour, ":", 
        (m_trading_start_minute < 10 ? "0" : ""), m_trading_start_minute, " - ", 
        (m_trading_end_hour < 10 ? "0" : ""), m_trading_end_hour, ":", 
        (m_trading_end_minute < 10 ? "0" : ""), m_trading_end_minute);
}

//+------------------------------------------------------------------+
//| Get current position information                                 |
//+------------------------------------------------------------------+
bool CTradeManager::GetPositionInfo()
{
   m_has_position = false;
   m_is_long = false;
   
   // Loop through positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      // Get position by index
      if(PositionGetSymbol(i) != Symbol()) continue;
      
      // Check if this position belongs to our EA
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;
      
      // We found a position belonging to our EA
      m_has_position = true;
      m_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate ATR-based stop loss level                              |
//+------------------------------------------------------------------+
double CTradeManager::CalculateStopLoss(bool isBuy, double price)
{
   // If SL is disabled or invalid ATR handle, return 0 (no stop loss)
   if(!m_use_sl || m_atr_handle == INVALID_HANDLE) 
      return 0.0;
   
   // Get ATR value
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atrBuffer) <= 0)
   {
      Print("Failed to copy ATR buffer");
      return 0.0;
   }
   
   double atr = atrBuffer[0];
   double slDistance = atr * m_sl_atr_multiplier;
   
   // Calculate stop loss price
   double stopLoss = 0.0;
   
   if(isBuy)
   {
      stopLoss = price - slDistance;
   }
   else
   {
      stopLoss = price + slDistance;
   }
   
   Print("ATR: ", DoubleToString(atr, 6), ", SL Distance: ", DoubleToString(slDistance, 6));
   
   return stopLoss;
}

//+------------------------------------------------------------------+
//| Calculate take profit based on risk/reward ratio                 |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss)
{
   // If SL is disabled or stop loss is zero, return 0 (no take profit)
   if(!m_use_sl || stopLoss == 0.0)
      return 0.0;
      
   double riskDistance = MathAbs(entryPrice - stopLoss);
   double tpDistance = riskDistance * m_risk_reward_ratio;
   
   // Calculate take profit price
   double takeProfit = 0.0;
   
   if(isBuy)
   {
      takeProfit = entryPrice + tpDistance;
   }
   else
   {
      takeProfit = entryPrice - tpDistance;
   }
   
   Print("Risk: ", DoubleToString(riskDistance, 6), ", Reward: ", DoubleToString(tpDistance, 6), 
         ", R/R Ratio: ", DoubleToString(m_risk_reward_ratio, 2));
   
   return takeProfit;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CTradeManager::CalculateLotSize(double entryPrice, double stopLoss)
{
   // If risk percent is 0 or negative, use fixed lot size
   if(m_risk_percent <= 0)
      return m_lot_size;
      
   // Calculate stop distance
   double stopDistance = MathAbs(entryPrice - stopLoss);
   
   // If stop distance is 0 or invalid, use fixed lot size
   if(stopDistance <= 0)
      return m_lot_size;
      
   // Get symbol info
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
   
   // Calculate risk amount in account currency
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (m_risk_percent / 100.0);
   
   // Calculate number of ticks in stop distance
   double ticksInStopDistance = stopDistance / tickSize;
   
   // Calculate value of one lot for the stop distance
   double oneLotRisk = ticksInStopDistance * tickValue;
   
   // Calculate required lot size to match risk amount
   double lotSize = riskAmount / oneLotRisk;
   
   // Round to symbol's lot step
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Enforce min/max lot size limits
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   Print("Risk calculation - Balance: ", accountBalance, 
         ", Risk amount: ", riskAmount,
         ", Stop distance: ", stopDistance,
         ", Calculated lot size: ", lotSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Process trading signal                                           |
//+------------------------------------------------------------------+
void CTradeManager::ProcessSignal(int signalType, bool allowNewTrades)
{
   // Skip if trading is disabled
   if(!m_trading_enabled) return;
   
   // Skip if the signal is the same as the last processed signal
   if(signalType == m_last_processed_signal)
   {
      // Print("Signal type " + IntegerToString(signalType) + " already processed, skipping");
      return;
   }
   
   // Check current position status
   GetPositionInfo();
   
   // signalType: 0 = buy signal, 1 = sell signal
   bool isBuySignal = (signalType == 0);
   
   // If we have a position, check if we need to close it
   // Note: Closing positions always allowed, not restricted by time filter
   if(m_has_position)
   {
      // Close long position on sell signal
      if(m_is_long && !isBuySignal)
      {
         Print("Closing BUY position on SELL signal");
         CloseAllPositions();
      }
      // Close short position on buy signal
      else if(!m_is_long && isBuySignal)
      {
         Print("Closing SELL position on BUY signal");
         CloseAllPositions();
      }
   }
   
   // If we closed a position, remove the trailing stop line
   if(m_has_position && !GetPositionInfo())
   {
      RemoveTrailingStopLine();
   }
   
   // Open a new position if we don't have one AND we're allowed to place new trades
   if(!m_has_position && allowNewTrades)
   {
      Print("Opening new position for signal: ", (isBuySignal ? "BUY" : "SELL"));
      OpenPosition(isBuySignal);
   }
   else if(!m_has_position && !allowNewTrades && m_enable_time_filter)
   {
      Print("Signal detected but outside trading hours - not opening position");
   }
   
   // Update the last processed signal
   m_last_processed_signal = signalType;
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPosition(bool isBuy)
{
   // Skip if trading is disabled
   if(!m_trading_enabled) return false;
   
   double price = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double stopLoss = CalculateStopLoss(isBuy, price);
   double takeProfit = CalculateTakeProfit(isBuy, price, stopLoss);
   
   // Calculate position size based on risk percentage if stop loss is used
   double lotSize = m_lot_size; // Default to fixed size
   
   if(m_use_sl && stopLoss != 0 && m_risk_percent > 0)
   {
      lotSize = CalculateLotSize(price, stopLoss);
      Print("Using risk-based position sizing: ", lotSize, " lots");
   }
   else
   {
      Print("Using fixed position sizing: ", m_lot_size, " lots");
   }
   
   // Print SL/TP levels for debugging
   if(m_use_sl)
   {
      Print("Entry: ", DoubleToString(price, 6), 
            ", SL: ", DoubleToString(stopLoss, 6), 
            ", TP: ", DoubleToString(takeProfit, 6));
   }
   
   bool result = false;
   
   if(isBuy)
   {
      result = m_trade.Buy(lotSize, Symbol(), 0, stopLoss, takeProfit, m_trade_comment);
      if(result)
      {
         Print("BUY position opened successfully");
         m_has_position = true;
         m_is_long = true;
      }
      else
      {
         Print("Failed to open BUY position. Error: ", GetLastError());
      }
   }
   else
   {
      result = m_trade.Sell(lotSize, Symbol(), 0, stopLoss, takeProfit, m_trade_comment);
      if(result)
      {
         Print("SELL position opened successfully");
         m_has_position = true;
         m_is_long = false;
      }
      else
      {
         Print("Failed to open SELL position. Error: ", GetLastError());
      }
   }
   
   // If position was opened successfully, initialize the trailing stop line
   if(result && m_show_trailing_stop)
   {
      // Initialize line time bounds for a new position
      m_line_start_time = iTime(Symbol(), PERIOD_CURRENT, 10); // Start 10 bars back
      m_line_end_time = iTime(Symbol(), PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20; // Extend 20 bars into the future
      
      // Initialize m_current_stop_level with the initial stop loss
      m_current_stop_level = stopLoss;
      
      Print("Initial trailing stop level set to: ", m_current_stop_level);
      
      UpdateTrailingStopLine();
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
   bool result = true;
   int total = PositionsTotal();
   
   // Loop through positions in reverse order (to safely remove them)
   for(int i = total - 1; i >= 0; i--)
   {
      // Select position
      if(PositionGetSymbol(i) != Symbol()) continue;
      
      // Check if this position belongs to our EA
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;
      
      // Close position
      ulong ticket = PositionGetTicket(i);
      if(!m_trade.PositionClose(ticket))
      {
         Print("Failed to close position #", ticket, ". Error: ", GetLastError());
         result = false;
      }
   }
   
   // If all positions are closed, remove the trailing stop line
   if(result)
   {
      m_has_position = false;
      RemoveTrailingStopLine();
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Update trailing stop line on the chart                           |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTrailingStopLine()
{
   // Don't proceed if we shouldn't show the line or have no position
   if(!m_show_trailing_stop || !m_has_position || !m_use_sl)
      return;
   
   // Calculate current stop loss level based on ATR
   double current_price = m_is_long ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double new_stop_level = CalculateStopLoss(m_is_long, current_price);
   
   // Apply trailing stop logic - only if trailing is enabled
   if(m_enable_trailing_stop)
   {
      if(m_is_long)
      {
         // For buy (long) positions, only move stop loss up
         if(new_stop_level > m_current_stop_level)
         {
            m_current_stop_level = new_stop_level;
            Print("Trailing stop for BUY position moved UP to: ", m_current_stop_level);
         }
      }
      else
      {
         // For sell (short) positions, only move stop loss down
         if(new_stop_level < m_current_stop_level)
         {
            m_current_stop_level = new_stop_level;
            Print("Trailing stop for SELL position moved DOWN to: ", m_current_stop_level);
         }
      }
   }
   else
   {
      // If trailing is disabled, always use the current calculated level
      m_current_stop_level = new_stop_level;
   }
   
   // Update the end time to keep extending into the future
   m_line_end_time = iTime(Symbol(), PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20;
   
   // Create or update the trendline
   if(ObjectFind(0, m_trendline_name) < 0)
   {
      // Create new trendline object
      ObjectCreate(0, m_trendline_name, OBJ_TREND, 0, m_line_start_time, m_current_stop_level, m_line_end_time, m_current_stop_level);
      
      // Set line properties
      color lineColor = m_is_long ? clrRed : clrGreen;
      ObjectSetInteger(0, m_trendline_name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, m_trendline_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, m_trendline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_trendline_name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, m_trendline_name, OBJPROP_BACK, false);
      ObjectSetString(0, m_trendline_name, OBJPROP_TEXT, "ATR Trailing Stop x" + DoubleToString(m_sl_atr_multiplier, 1));
   }
   else
   {
      // Update existing trendline
      ObjectMove(0, m_trendline_name, 0, m_line_start_time, m_current_stop_level);
      ObjectMove(0, m_trendline_name, 1, m_line_end_time, m_current_stop_level);
      
      // Update color based on position type
      color lineColor = m_is_long ? clrRed : clrGreen;
      ObjectSetInteger(0, m_trendline_name, OBJPROP_COLOR, lineColor);
   }
}

//+------------------------------------------------------------------+
//| Remove trailing stop line                                        |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTrailingStopLine()
{
   // Delete the trendline if it exists
   if(ObjectFind(0, m_trendline_name) >= 0)
   {
      ObjectDelete(0, m_trendline_name);
   }
}

//+------------------------------------------------------------------+
//| Check if price has closed beyond the trailing stop               |
//+------------------------------------------------------------------+
bool CTradeManager::CheckStopLevelCrossed()
{
   if(!m_has_position || m_current_stop_level == 0)
      return false;
      
   // Get the previous bar's close price (bar 1)
   double prevClose = iClose(Symbol(), PERIOD_CURRENT, 1);
   
   // Check if the close price has crossed our trailing stop level
   if(m_is_long && prevClose < m_current_stop_level)
   {
      Print("BUY position stop triggered: Close price (", prevClose, 
            ") is below trailing stop (", m_current_stop_level, ")");
      return true;
   }
   else if(!m_is_long && prevClose > m_current_stop_level)
   {
      Print("SELL position stop triggered: Close price (", prevClose, 
            ") is above trailing stop (", m_current_stop_level, ")");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Method to notify trade manager of a new bar                      |
//+------------------------------------------------------------------+
void CTradeManager::OnNewBar()
{
   datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
   
   // Only update on new bars
   if(current_time != m_last_bar_time)
   {
      m_last_bar_time = current_time;
      
      // Update position info
      GetPositionInfo();
      
      // Check if we need to close the position due to trailing stop
      if(m_has_position && m_enable_trailing_stop && m_current_stop_level != 0 && CheckStopLevelCrossed())
      {
         Print("Trailing stop level crossed - closing position");
         CloseAllPositions();
      }
      
      // Update trailing stop if we still have a position
      if(m_has_position && (m_enable_trailing_stop || m_show_trailing_stop))
      {
         UpdateTrailingStopLine();
      }
   }
}

//+------------------------------------------------------------------+
//| On tick update for trailing stop                                 |
//+------------------------------------------------------------------+
void CTradeManager::OnTick()
{
   // Save the previous position state
   bool hadPosition = m_has_position;
   
   // Update position info 
   GetPositionInfo();
   
   // If position was closed, remove the trendline
   if(hadPosition && !m_has_position)
   {
      Print("Position closed - removing trailing stop line in OnTick");
      RemoveTrailingStopLine();
   }
   
   // We don't update the trailing stop on every tick anymore,
   // but we still check to remove the line if no position exists
}
