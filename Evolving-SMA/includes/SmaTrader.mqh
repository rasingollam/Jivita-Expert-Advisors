//+------------------------------------------------------------------+
//|                                                   SmaTrader.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"

#include <Trade\Trade.mqh> // Include standard trading class

//--- Signal enum
enum ENUM_TRADE_SIGNAL
  {
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL,
   SIGNAL_CLOSE_BUY, // Signal to close existing buy
   SIGNAL_CLOSE_SELL // Signal to close existing sell
  };
//+------------------------------------------------------------------+
//| Handles SMA calculation and trading execution                    |
//+------------------------------------------------------------------+
class CSmaTrader
  {
private:
   //--- Strategy Parameters
   int               m_short_period;
   int               m_long_period;
   ulong             m_magic_number;
   double            m_lot_size;
   int               m_stop_loss_pips; // Stop Loss in pips (0 = disabled)
   int               m_take_profit_pips; // Take Profit in pips (0 = disabled)

   //--- Market Info
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   double            m_point;
   double            m_spread_max_points; // Max allowable spread in points

   //--- Indicator Handles
   int               m_handle_sma_short;
   int               m_handle_sma_long;

   //--- Trading Object
   CTrade            m_trade;

public:
                     CSmaTrader();
                    ~CSmaTrader();

   //--- Initialization
   bool              Init(int short_p, int long_p, double lots, ulong magic,
                          string symbol=NULL, ENUM_TIMEFRAMES tf=PERIOD_CURRENT,
                          int sl_pips=0, int tp_pips=0, double max_spread=5.0);

   //--- Parameter Update (called after GA optimization)
   bool              UpdateParameters(int new_short_p, int new_long_p);

   //--- Core Logic (called on tick or timer)
   ENUM_TRADE_SIGNAL CheckSignal(void);
   void              ExecuteSignal(ENUM_TRADE_SIGNAL signal);

private:
   //--- Indicator Handling
   bool              CreateIndicators(void);
   void              ReleaseIndicators(void);
   bool              GetSmaValues(int shift, double &sma_short, double &sma_long);

   //--- Trading Execution
   void              OpenBuy(void);
   void              OpenSell(void);
   void              CloseBuyPositions(void);
   void              CloseSellPositions(void);
   bool              HasOpenBuyPosition(void);
   bool              HasOpenSellPosition(void);
   double            CalculateStopLoss(ENUM_ORDER_TYPE order_type, double entry_price);
   double            CalculateTakeProfit(ENUM_ORDER_TYPE order_type, double entry_price);
   bool              IsSpreadOk(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSmaTrader::CSmaTrader() :
   m_short_period(0),
   m_long_period(0),
   m_magic_number(0),
   m_lot_size(0.01),
   m_stop_loss_pips(0),
   m_take_profit_pips(0),
   m_symbol(""),
   m_timeframe(PERIOD_CURRENT),
   m_point(0.0),
   m_spread_max_points(5.0),
   m_handle_sma_short(INVALID_HANDLE),
   m_handle_sma_long(INVALID_HANDLE)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSmaTrader::~CSmaTrader()
  {
   ReleaseIndicators();
  }
//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSmaTrader::Init(int short_p, int long_p, double lots, ulong magic,
                      string symbol=NULL, ENUM_TIMEFRAMES tf=PERIOD_CURRENT,
                      int sl_pips=0, int tp_pips=0, double max_spread=5.0)
  {
   m_short_period = short_p;
   m_long_period = long_p;
   m_lot_size = lots;
   m_magic_number = magic;
   m_stop_loss_pips = sl_pips;
   m_take_profit_pips = tp_pips;
   m_spread_max_points = max_spread;

   if(symbol == NULL || symbol == "")
      m_symbol = _Symbol;
   else
      m_symbol = symbol;

   if(tf == PERIOD_CURRENT)
      m_timeframe = _Period;
   else
      m_timeframe = tf;

   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   if(m_point == 0) { Print("Error: Invalid symbol or zero point value for ", m_symbol); return false; }

   // Validate periods
   if(m_short_period <= 0 || m_long_period <= 0 || m_long_period <= m_short_period)
     {
      Print("Error: Invalid SMA periods provided (Short=", m_short_period, ", Long=", m_long_period, ")");
      return false;
     }

   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetMarginMode(); // Use account's default margin mode
   // m_trade.SetTypeFillingBySymbol(m_symbol); // Use symbol's default execution type

   if(!CreateIndicators())
      return false;

   PrintFormat("SmaTrader Initialized: Symbol=%s, TF=%s, Short=%d, Long=%d, Lots=%.2f, Magic=%d, SL=%d, TP=%d, MaxSpread=%.1f",
               m_symbol, EnumToString(m_timeframe), m_short_period, m_long_period, m_lot_size, m_magic_number, m_stop_loss_pips, m_take_profit_pips, m_spread_max_points);
   return true;
  }
//+------------------------------------------------------------------+
//| Create Indicator Handles                                         |
//+------------------------------------------------------------------+
bool CSmaTrader::CreateIndicators(void)
  {
   ReleaseIndicators(); // Release existing handles first

   m_handle_sma_short = iMA(m_symbol, m_timeframe, m_short_period, 0, MODE_SMA, PRICE_CLOSE);
   if(m_handle_sma_short == INVALID_HANDLE)
     {
      Print("Error creating Short SMA indicator: ", GetLastError());
      return false;
     }

   m_handle_sma_long = iMA(m_symbol, m_timeframe, m_long_period, 0, MODE_SMA, PRICE_CLOSE);
   if(m_handle_sma_long == INVALID_HANDLE)
     {
      Print("Error creating Long SMA indicator: ", GetLastError());
      ReleaseIndicators(); // Clean up the short handle if long failed
      return false;
     }
   Print("SMA Indicators created successfully.");
   return true;
  }
//+------------------------------------------------------------------+
//| Release Indicator Handles                                        |
//+------------------------------------------------------------------+
void CSmaTrader::ReleaseIndicators(void)
  {
   if(m_handle_sma_short != INVALID_HANDLE)
      IndicatorRelease(m_handle_sma_short);
   m_handle_sma_short = INVALID_HANDLE;

   if(m_handle_sma_long != INVALID_HANDLE)
      IndicatorRelease(m_handle_sma_long);
   m_handle_sma_long = INVALID_HANDLE;
  }
//+------------------------------------------------------------------+
//| Update Strategy Parameters                                       |
//+------------------------------------------------------------------+
bool CSmaTrader::UpdateParameters(int new_short_p, int new_long_p)
  {
   // Validate new periods
   if(new_short_p <= 0 || new_long_p <= 0 || new_long_p <= new_short_p)
     {
      Print("Error: Invalid new SMA periods provided during update (Short=", new_short_p, ", Long=", new_long_p, ")");
      return false;
     }

   // Check if parameters actually changed
   if(new_short_p == m_short_period && new_long_p == m_long_period)
     {
      // Print("SMA parameters are already up-to-date.");
      return true; // No update needed
     }

   PrintFormat("Updating SMA parameters: Old Short=%d, Old Long=%d --> New Short=%d, New Long=%d",
               m_short_period, m_long_period, new_short_p, new_long_p);

   m_short_period = new_short_p;
   m_long_period = new_long_p;

   // Recreate indicators with new periods
   if(!CreateIndicators())
     {
      Print("Error: Failed to recreate indicators after parameter update.");
      // Consider reverting to old parameters or stopping trades? Handle this based on strategy.
      return false;
     }

   Print("SMA parameters updated and indicators recreated.");
   return true;
  }
//+------------------------------------------------------------------+
//| Get SMA Values for a specific shift                              |
//+------------------------------------------------------------------+
bool CSmaTrader::GetSmaValues(int shift, double &sma_short, double &sma_long)
  {
   sma_short = 0.0;
   sma_long = 0.0;

   if(m_handle_sma_short == INVALID_HANDLE || m_handle_sma_long == INVALID_HANDLE)
     {
      Print("Error: SMA handles are invalid in GetSmaValues.");
      return false;
     }

   double sma_s_buffer[1];
   double sma_l_buffer[1];

   if(CopyBuffer(m_handle_sma_short, 0, shift, 1, sma_s_buffer) != 1)
     {
      // Print("Error copying short SMA buffer: ", GetLastError()); // Can be noisy
      return false;
     }
   if(CopyBuffer(m_handle_sma_long, 0, shift, 1, sma_l_buffer) != 1)
     {
      // Print("Error copying long SMA buffer: ", GetLastError()); // Can be noisy
      return false;
     }

    // Check for empty values which mean the indicator hasn't calculated yet for this bar
   if(sma_s_buffer[0] == EMPTY_VALUE || sma_l_buffer[0] == EMPTY_VALUE)
   {
        // Print("Warning: SMA value is EMPTY_VALUE for shift ", shift);
        return false;
   }

   sma_short = sma_s_buffer[0];
   sma_long = sma_l_buffer[0];
   return true;
  }
//+------------------------------------------------------------------+
//| Check for Trading Signals                                        |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL CSmaTrader::CheckSignal(void)
  {
   double sma_s_curr, sma_l_curr; // Shift 1: Last completed bar
   double sma_s_prev, sma_l_prev; // Shift 2: Bar before last completed

   // Get SMA values for the last two completed bars
   if(!GetSmaValues(1, sma_s_curr, sma_l_curr)) return SIGNAL_NONE;
   if(!GetSmaValues(2, sma_s_prev, sma_l_prev)) return SIGNAL_NONE;

   // --- Crossover Logic ---
   bool cross_above = sma_s_prev < sma_l_prev && sma_s_curr > sma_l_curr;
   bool cross_below = sma_s_prev > sma_l_prev && sma_s_curr < sma_l_curr;

   // --- Determine Signal ---
   bool has_buy = HasOpenBuyPosition();
   bool has_sell = HasOpenSellPosition();

   if(cross_above) // Golden Cross
     {
      if(has_sell) return SIGNAL_CLOSE_SELL; // Close existing short first
      if(!has_buy) return SIGNAL_BUY;        // Open long if none exists
     }
   else if(cross_below) // Death Cross
     {
      if(has_buy) return SIGNAL_CLOSE_BUY;   // Close existing long first
      if(!has_sell) return SIGNAL_SELL;       // Open short if none exists
     }

   return SIGNAL_NONE; // No crossover or already in position
  }
//+------------------------------------------------------------------+
//| Execute Trade based on Signal                                    |
//+------------------------------------------------------------------+
void CSmaTrader::ExecuteSignal(ENUM_TRADE_SIGNAL signal)
  {
    // Check spread before opening new trades
    if((signal == SIGNAL_BUY || signal == SIGNAL_SELL) && !IsSpreadOk()) {
       PrintFormat("Spread (%.1f points) exceeds maximum allowed (%.1f points). No new trade.",
                   SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * 1.0, m_spread_max_points);
       return;
    }


   switch(signal)
     {
      case SIGNAL_BUY:
         // Double check no buy position exists before opening
         if (!HasOpenBuyPosition()) OpenBuy();
         break;
      case SIGNAL_SELL:
          // Double check no sell position exists before opening
         if (!HasOpenSellPosition()) OpenSell();
         break;
      case SIGNAL_CLOSE_BUY:
         CloseBuyPositions();
         break;
      case SIGNAL_CLOSE_SELL:
         CloseSellPositions();
         break;
      case SIGNAL_NONE:
      default:
         // Do nothing
         break;
     }
  }
//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
void CSmaTrader::OpenBuy(void)
  {
   double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double sl = CalculateStopLoss(ORDER_TYPE_BUY, price);
   double tp = CalculateTakeProfit(ORDER_TYPE_BUY, price);

   PrintFormat("Attempting to BUY %.2f lots of %s at ~%.5f, SL=%.5f, TP=%.5f",
               m_lot_size, m_symbol, price, sl, tp);

   bool result = m_trade.Buy(m_lot_size, m_symbol, price, sl, tp, "SMA Crossover Buy");
   if(result)
     {
      PrintFormat("BUY order executed successfully. Order Ticket: %d", m_trade.ResultOrder());
     }
   else
     {
      PrintFormat("BUY order failed. Error code: %d, Retcode: %d, Message: %s",
                  GetLastError(), m_trade.ResultRetcode(), m_trade.ResultComment());
     }
  }
//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
void CSmaTrader::OpenSell(void)
  {
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double sl = CalculateStopLoss(ORDER_TYPE_SELL, price);
   double tp = CalculateTakeProfit(ORDER_TYPE_SELL, price);

   PrintFormat("Attempting to SELL %.2f lots of %s at ~%.5f, SL=%.5f, TP=%.5f",
               m_lot_size, m_symbol, price, sl, tp);

   bool result = m_trade.Sell(m_lot_size, m_symbol, price, sl, tp, "SMA Crossover Sell");
   if(result)
     {
      PrintFormat("SELL order executed successfully. Order Ticket: %d", m_trade.ResultOrder());
     }
   else
     {
      PrintFormat("SELL order failed. Error code: %d, Retcode: %d, Message: %s",
                  GetLastError(), m_trade.ResultRetcode(), m_trade.ResultComment());
     }
  }
//+------------------------------------------------------------------+
//| Close all open Buy positions for this EA/symbol                  |
//+------------------------------------------------------------------+
void CSmaTrader::CloseBuyPositions(void)
  {
   int total_positions = PositionsTotal();
   bool closed_any = false;
   // Iterate backwards because closing positions changes the index order
   for(int i = total_positions - 1; i >= 0; i--)
     {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket > 0) // Ensure valid ticket
        {
         // Select position to access properties
         if(PositionSelectByTicket(position_ticket))
           {
            // Check if it belongs to this EA, symbol, and is a BUY position
            if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
               PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               PrintFormat("Attempting to close BUY position #%d", position_ticket);
               if(m_trade.PositionClose(position_ticket)) // Use CTrade for closing
                 {
                  PrintFormat("BUY Position #%d closed successfully.", position_ticket);
                  closed_any = true;
                 }
               else
                 {
                  PrintFormat("Failed to close BUY position #%d. Retcode: %d, Message: %s",
                              position_ticket, m_trade.ResultRetcode(), m_trade.ResultComment());
                 }
              }
           }
         else
           {
             // Error selecting position, might have been closed by something else
             // PrintFormat("Could not select position index %d to check for closing.", i);
           }
        }
     }
    // if (closed_any) Print("Finished closing relevant BUY positions.");
    // else Print("No relevant BUY positions found to close.");
  }
//+------------------------------------------------------------------+
//| Close all open Sell positions for this EA/symbol                 |
//+------------------------------------------------------------------+
void CSmaTrader::CloseSellPositions(void)
  {
   int total_positions = PositionsTotal();
   bool closed_any = false;
   for(int i = total_positions - 1; i >= 0; i--)
     {
      ulong position_ticket = PositionGetTicket(i);
       if(position_ticket > 0)
         {
          if(PositionSelectByTicket(position_ticket))
            {
             if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
                PositionGetString(POSITION_SYMBOL) == m_symbol &&
                PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                PrintFormat("Attempting to close SELL position #%d", position_ticket);
                if(m_trade.PositionClose(position_ticket))
                  {
                   PrintFormat("SELL Position #%d closed successfully.", position_ticket);
                   closed_any = true;
                  }
                else
                  {
                   PrintFormat("Failed to close SELL position #%d. Retcode: %d, Message: %s",
                               position_ticket, m_trade.ResultRetcode(), m_trade.ResultComment());
                  }
               }
            }
            // else { PrintFormat("Could not select position index %d to check for closing.", i); }
         }
     }
    // if (closed_any) Print("Finished closing relevant SELL positions.");
    // else Print("No relevant SELL positions found to close.");
  }
//+------------------------------------------------------------------+
//| Check if an open Buy position exists                             |
//+------------------------------------------------------------------+
bool CSmaTrader::HasOpenBuyPosition(void)
  {
   int total_positions = PositionsTotal();
   for(int i = 0; i < total_positions; i++)
     {
       ulong position_ticket = PositionGetTicket(i);
       if(position_ticket > 0 && PositionSelectByTicket(position_ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
               PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               return true; // Found an open buy position for this EA/symbol
              }
         }
     }
   return false;
  }
//+------------------------------------------------------------------+
//| Check if an open Sell position exists                            |
//+------------------------------------------------------------------+
bool CSmaTrader::HasOpenSellPosition(void)
  {
   int total_positions = PositionsTotal();
   for(int i = 0; i < total_positions; i++)
     {
      ulong position_ticket = PositionGetTicket(i);
       if(position_ticket > 0 && PositionSelectByTicket(position_ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
               PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               return true; // Found an open sell position for this EA/symbol
              }
         }
     }
   return false;
  }
//+------------------------------------------------------------------+
//| Calculate Stop Loss Price                                        |
//+------------------------------------------------------------------+
double CSmaTrader::CalculateStopLoss(ENUM_ORDER_TYPE order_type, double entry_price)
  {
   if(m_stop_loss_pips <= 0) return 0.0; // SL disabled

   double sl_price = 0.0;
   if(order_type == ORDER_TYPE_BUY)
     {
      sl_price = entry_price - m_stop_loss_pips * m_point;
     }
   else if(order_type == ORDER_TYPE_SELL)
     {
      sl_price = entry_price + m_stop_loss_pips * m_point;
     }

    // Normalize the price according to symbol's digits
    return NormalizeDouble(sl_price, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
  }
//+------------------------------------------------------------------+
//| Calculate Take Profit Price                                      |
//+------------------------------------------------------------------+
double CSmaTrader::CalculateTakeProfit(ENUM_ORDER_TYPE order_type, double entry_price)
  {
   if(m_take_profit_pips <= 0) return 0.0; // TP disabled

   double tp_price = 0.0;
   if(order_type == ORDER_TYPE_BUY)
     {
      tp_price = entry_price + m_take_profit_pips * m_point;
     }
   else if(order_type == ORDER_TYPE_SELL)
     {
      tp_price = entry_price - m_take_profit_pips * m_point;
     }

    // Normalize the price
    return NormalizeDouble(tp_price, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
  }
//+------------------------------------------------------------------+
//| Check if current spread is acceptable                            |
//+------------------------------------------------------------------+
bool CSmaTrader::IsSpreadOk(void)
  {
    if(m_spread_max_points <= 0) return true; // Spread check disabled

    long spread_long = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    // If spread is floating, SYMBOL_SPREAD returns the current spread in points.
    // If fixed, it returns the fixed spread.
    if(spread_long < 0) { // Error getting spread
        Print("Warning: Could not retrieve spread for ", m_symbol);
        return false; // Fail safe
    }
    double spread_points = (double)spread_long;

    return (spread_points <= m_spread_max_points);
  }
//+------------------------------------------------------------------+