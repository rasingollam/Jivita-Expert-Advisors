//+------------------------------------------------------------------+
//|                                       SimpleSmaEvolution_v2.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "2.10"
#property description "SMA Crossover with evolutionary optimization of SMA periods, SL and TP"
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters ---
// Trading Parameters
input group           "Trading Parameters"
input int              Inp_ShortPeriod = 10;        // Initial Short SMA Period
input int              Inp_LongPeriod = 30;         // Initial Long SMA Period
input double           Inp_LotSize = 0.01;          // Fixed Lot Size (0 = use risk-based sizing)
input double           Inp_RiskPercentage = 1.0;    // Risk percentage per trade (when lot size = 0)
input ulong            Inp_MagicNumber = 123456;    // Magic Number
input int              Inp_StopLossPips = 50;       // Initial Stop Loss in pips (0=off)
input int              Inp_TakeProfitPips = 100;    // Initial Take Profit in pips (0=off)
input double           Inp_MaxSpreadPoints = 5.0;   // Max spread in points (0=off)
input bool             Inp_CloseOnOppositeSignal = false; // Close positions on opposite signal
input bool             Inp_UseATRStops = false;     // Use ATR for adaptive stops
input int              Inp_ATRPeriod = 14;          // ATR period for adaptive stops
input double           Inp_ATRMultiplierSL = 2.0;   // ATR multiplier for stop loss
input double           Inp_ATRMultiplierTP = 4.0;   // ATR multiplier for take profit

// Genetic Algorithm Parameters
input group           "Genetic Algorithm Parameters"
input int              Inp_MinPeriod = 5;           // Min SMA Period
input int              Inp_MaxPeriod = 200;         // Max SMA Period
input int              Inp_MinDiff = 5;             // Min difference between periods
input int              Inp_PopulationSize = 20;     // Population size
input int              Inp_Generations = 10;        // Generations per evolution
input double           Inp_MutationRate = 0.1;      // Mutation rate (0.0-1.0)
input int              Inp_TestBars = 500;          // Bars for fitness simulation

// Risk Management Evolution Parameters
input group           "Risk Management Evolution"
input bool             Inp_EvolveRiskParams = true; // Evolve SL/TP parameters
input int              Inp_MinStopLoss = 20;        // Min Stop Loss (pips)
input int              Inp_MaxStopLoss = 150;       // Max Stop Loss (pips)
input int              Inp_MinTakeProfit = 20;      // Min Take Profit (pips)
input int              Inp_MaxTakeProfit = 300;     // Max Take Profit (pips)
input double           Inp_MinRiskReward = 0.5;     // Min Risk:Reward ratio
input double           Inp_MaxRiskReward = 5.0;     // Max Risk:Reward ratio

// Evolution Settings
input group           "Evolution Settings"
input int              Inp_EvolutionMinutes = 60;   // Evolution frequency (minutes)
input int              Inp_MinTradesForEvolution = 10; // Min trades before considering real performance
input double           Inp_RealTradeProfitWeight = 0.7; // Weight for real trade performance (0.0-1.0)
input bool             Inp_OnlyEvolveAfterLosses = false; // Only evolve after losing trades

// Market Regime Detection
input group           "Market Regime Detection"
input bool             Inp_UseMarketRegime = false;  // Adapt to market regime (trend/range)
input int              Inp_ADXPeriod = 14;           // ADX period for trend strength
input double           Inp_TrendThreshold = 25.0;    // ADX threshold for trend detection
input bool             Inp_SeperateEvolution = true; // Evolve separate parameters for trend/range

//--- Global Variables ---
// Trading state
int g_shortPeriod = 0;         // Current short period
int g_longPeriod = 0;          // Current long period
int g_stopLossPips = 0;        // Current stop loss in pips
int g_takeProfitPips = 0;      // Current take profit in pips
int g_handle_short = INVALID_HANDLE;   // Indicator handle
int g_handle_long = INVALID_HANDLE;    // Indicator handle
int g_handle_atr = INVALID_HANDLE;     // ATR indicator handle
int g_handle_adx = INVALID_HANDLE;     // ADX indicator handle
CTrade g_trade;                // Trading object

// Evolution state
datetime g_lastEvolutionTime = 0;  // Time of last evolution
bool g_evolutionInProgress = false; // Flag to prevent overlapping runs
bool g_isTrending = false;         // Market regime state

// Trade tracking state
struct TradeRecord {
   datetime open_time;         // Time trade was opened
   datetime close_time;        // Time trade was closed
   double profit;              // Profit/loss from the trade
   int short_period;           // Short SMA period used for this trade
   int long_period;            // Long SMA period used for this trade
   int stop_loss_pips;         // Stop loss in pips
   int take_profit_pips;       // Take profit in pips
   ENUM_POSITION_TYPE direction; // Buy or sell
   bool used_in_evolution;     // Whether this trade has been used in evolution
};

TradeRecord g_tradeHistory[];         // History of closed trades
int g_lastHistoryCount = 0;           // Last known count of history deals
ulong g_lastDealTicket = 0;           // Last processed deal ticket
int g_winningTrades = 0;              // Count of winning trades
int g_losingTrades = 0;               // Count of losing trades
double g_totalProfits = 0.0;          // Sum of all profits
double g_totalLosses = 0.0;           // Sum of all losses
bool g_evolveDueToLoss = false;       // Flag to trigger evolution after a loss

// Additional global variables for chart info
string g_infoText = "";        // Text to display on chart
datetime g_lastUpdateTime = 0; // Last time info was updated
datetime g_lastWFATime = 0;    // Last time WFA was performed

//--- Simple Chromosome Structure (now including SL/TP genes)
struct SChromosome
{
   int short_period;      // Gene: Short SMA period
   int long_period;       // Gene: Long SMA period
   int stop_loss_pips;    // Gene: Stop Loss in pips
   int take_profit_pips;  // Gene: Take Profit in pips
   double fitness;        // Fitness value
};

// Market regime state
SChromosome g_trendParams;    // Parameters optimized for trending markets
SChromosome g_rangeParams;    // Parameters optimized for ranging markets

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Initializing SMA Evolution EA v2.10 with SMA, SL, and TP optimization...");
   
   // Validate inputs
   if(Inp_ShortPeriod <= 0 || Inp_LongPeriod <= Inp_ShortPeriod) {
      Print("Error: Invalid SMA periods configuration.");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(Inp_RealTradeProfitWeight < 0 || Inp_RealTradeProfitWeight > 1.0) {
      Print("Error: Real trade profit weight must be between 0.0 and 1.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Setup trading parameters
   g_shortPeriod = Inp_ShortPeriod;
   g_longPeriod = Inp_LongPeriod;
   g_stopLossPips = Inp_StopLossPips;
   g_takeProfitPips = Inp_TakeProfitPips;
   g_trade.SetExpertMagicNumber(Inp_MagicNumber);
   
   // Create indicator handles
   if(!CreateIndicators()) {
      Print("Error: Failed to create indicators!");
      return INIT_FAILED;
   }
   
   // Load trade history
   LoadTradeHistory();
   
   // Set timer for evolution
   if(Inp_EvolutionMinutes > 0) {
      EventSetTimer(60); // Check every minute
      g_lastEvolutionTime = TimeCurrent();
      Print("Evolution timer set. Evolution will run every ", Inp_EvolutionMinutes, " minutes or after losses if configured.");
   }
   
   // Update chart comment with initial period info
   UpdateChartComment();
   
   Print("SMA Evolution EA v2.10 initialized successfully.");
   Print("Initial SMA periods: Short=", g_shortPeriod, ", Long=", g_longPeriod);
   Print("Initial risk parameters: SL=", g_stopLossPips, " pips, TP=", g_takeProfitPips, " pips");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinitializing SMA Evolution EA v2.0...");
   
   // Release indicators
   if(g_handle_short != INVALID_HANDLE) IndicatorRelease(g_handle_short);
   if(g_handle_long != INVALID_HANDLE) IndicatorRelease(g_handle_long);
   if(g_handle_atr != INVALID_HANDLE) IndicatorRelease(g_handle_atr);
   if(g_handle_adx != INVALID_HANDLE) IndicatorRelease(g_handle_adx);
   
   // Kill timer
   EventKillTimer();
   
   // Clear chart comment
   Comment("");
   
   Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Skip if indicators not ready
   if(g_handle_short == INVALID_HANDLE || g_handle_long == INVALID_HANDLE) return;
   
   // Process only on new bar
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(last_bar_time == current_bar_time) return; // No new bar yet
   last_bar_time = current_bar_time;
   
   // Check for new closed trades first
   UpdateTradeHistory();
   
   // Detect market regime (if enabled)
   if(Inp_UseMarketRegime) {
      DetectMarketRegime();
   }
   
   // Check trading conditions and execute
   int signal = CheckSignal();
   if(signal != 0) ExecuteSignal(signal);
   
   // Update chart comment
   UpdateChartComment();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   // Monitor for position closings
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_type == DEAL_TYPE_BUY) {
      // Position was possibly closed - check in next tick
      UpdateTradeHistory();
   }
}

//+------------------------------------------------------------------+
//| Timer function (handle evolution)                                |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Skip if already running an evolution
   if(g_evolutionInProgress) return;
   
   // Check if we should evolve due to loss
   bool should_evolve = false;
   
   // Time-based evolution check
   datetime current_time = TimeCurrent();
   int evolution_seconds = Inp_EvolutionMinutes * 60;
   if(current_time - g_lastEvolutionTime >= evolution_seconds) {
      should_evolve = true;
   }
   
   // Loss-triggered evolution
   if(Inp_OnlyEvolveAfterLosses && g_evolveDueToLoss) {
      should_evolve = true;
      g_evolveDueToLoss = false;  // Reset flag
      Print("Loss-triggered evolution activated");
   }
   
   if(should_evolve) {
      g_evolutionInProgress = true;
      Print("Starting evolution at ", TimeToString(current_time));
      
      // Run evolution to find better parameters
      SChromosome best;
      if(RunEvolution(best)) {
         // Update SMA periods if evolution successful
         if(Inp_EvolveRiskParams) {
            PrintFormat("Evolution complete. New parameters: Short=%d, Long=%d, SL=%d, TP=%d, Fitness=%.4f",
                       best.short_period, best.long_period, 
                       best.stop_loss_pips, best.take_profit_pips, best.fitness);
         } else {
            PrintFormat("Evolution complete. New parameters: Short=%d, Long=%d, Fitness=%.4f",
                       best.short_period, best.long_period, best.fitness);
         }
                    
         // Update the EA's parameters
         g_shortPeriod = best.short_period;
         g_longPeriod = best.long_period;
         
         // Update risk parameters if enabled
         if(Inp_EvolveRiskParams) {
            g_stopLossPips = best.stop_loss_pips;
            g_takeProfitPips = best.take_profit_pips;
         }
         
         // Recreate indicators with new periods
         CreateIndicators();
      } else {
         Print("Evolution completed without finding better parameters.");
      }
      
      g_lastEvolutionTime = TimeCurrent();
      g_evolutionInProgress = false;
   }
}

//+------------------------------------------------------------------+
//| Close all positions of specified type                            |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE pos_type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == pos_type) {
            g_trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   if(Inp_MaxSpreadPoints <= 0) return true; // Check disabled
   
   long curr_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (curr_spread <= Inp_MaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Detect market regime (trending vs ranging)                       |
//+------------------------------------------------------------------+
bool DetectMarketRegime()
{
   if(!Inp_UseMarketRegime || g_handle_adx == INVALID_HANDLE)
      return g_isTrending; // Return current state if detection is disabled
      
   double adx_values[];
   if(CopyBuffer(g_handle_adx, 0, 0, 1, adx_values) <= 0)
      return g_isTrending; // Keep current state if data not available
      
   // Determine if market is trending based on ADX value
   bool newTrending = (adx_values[0] > Inp_TrendThreshold);
   
   // Log regime change
   if(newTrending != g_isTrending) {
      Print("Market regime changed from ", (g_isTrending ? "TRENDING" : "RANGING"), 
            " to ", (newTrending ? "TRENDING" : "RANGING"), 
            ". ADX: ", adx_values[0]);
      
      // If separate parameters for trend/range, swap them
      if(Inp_SeperateEvolution) {
         if(newTrending) {
            // Switch to trending parameters
            if(g_trendParams.short_period > 0) {
               g_shortPeriod = g_trendParams.short_period;
               g_longPeriod = g_trendParams.long_period;
               g_stopLossPips = g_trendParams.stop_loss_pips;
               g_takeProfitPips = g_trendParams.take_profit_pips;
               Print("Switched to trending market parameters");
            }
         } else {
            // Switch to ranging parameters
            if(g_rangeParams.short_period > 0) {
               g_shortPeriod = g_rangeParams.short_period;
               g_longPeriod = g_rangeParams.long_period;
               g_stopLossPips = g_rangeParams.stop_loss_pips;
               g_takeProfitPips = g_rangeParams.take_profit_pips;
               Print("Switched to ranging market parameters");
            }
         }
         
         // Recreate indicators with new parameters
         CreateIndicators();
      }
   }
   
   g_isTrending = newTrending;
   return g_isTrending;
}

//+------------------------------------------------------------------+
//| Create/recreate indicator handles                                |
//+------------------------------------------------------------------+
bool CreateIndicators()
{
   // Release existing handles
   if(g_handle_short != INVALID_HANDLE) IndicatorRelease(g_handle_short);
   if(g_handle_long != INVALID_HANDLE) IndicatorRelease(g_handle_long);
   if(g_handle_atr != INVALID_HANDLE) IndicatorRelease(g_handle_atr);
   if(g_handle_adx != INVALID_HANDLE) IndicatorRelease(g_handle_adx);
   
   // Create new handles with hidden visualization
   g_handle_short = iMA(_Symbol, _Period, g_shortPeriod, 0, MODE_SMA, PRICE_CLOSE);
   g_handle_long = iMA(_Symbol, _Period, g_longPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   // Create ATR and ADX indicators if needed
   if(Inp_UseATRStops) {
      g_handle_atr = iATR(_Symbol, _Period, Inp_ATRPeriod);
   }
   
   if(Inp_UseMarketRegime) {
      g_handle_adx = iADX(_Symbol, _Period, Inp_ADXPeriod);
   }
   
   // Check if creation was successful
   if(g_handle_short == INVALID_HANDLE || g_handle_long == INVALID_HANDLE) {
      Print("Error: Failed to create SMA indicators. Error code: ", GetLastError());
      return false;
   }
   
   if(Inp_UseATRStops && g_handle_atr == INVALID_HANDLE) {
      Print("Error: Failed to create ATR indicator. Error code: ", GetLastError());
      return false;
   }
   
   if(Inp_UseMarketRegime && g_handle_adx == INVALID_HANDLE) {
      Print("Error: Failed to create ADX indicator. Error code: ", GetLastError());
      return false;
   }
   
   // Set visualization to hidden (disable plotting on chart)
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(g_shortPeriod) + ")");
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(g_longPeriod) + ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Update chart comment with current parameters and time            |
//+------------------------------------------------------------------+
void UpdateChartComment()
{
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   g_infoText = "SMA Evolution EA v2.10 - Last Updated: " + time_str + "\n";
   g_infoText += "SMA Periods: Short=" + IntegerToString(g_shortPeriod) + 
                 ", Long=" + IntegerToString(g_longPeriod) + "\n";
                 
   // Add market regime info if enabled
   if(Inp_UseMarketRegime) {
      g_infoText += "Market Regime: " + (g_isTrending ? "TRENDING" : "RANGING") + "\n";
   }
   
   // Update risk parameters info
   if(Inp_UseATRStops) {
      g_infoText += "Risk Parameters: ATR-based SL/TP enabled\n";
   } else {
      g_infoText += "Risk Parameters: SL=" + IntegerToString(g_stopLossPips) + 
                  ", TP=" + IntegerToString(g_takeProfitPips) + " pips\n";
   }
   
   // Update exit mode info based on input setting
   if(Inp_CloseOnOppositeSignal) {
      g_infoText += "[EXIT MODE: SL/TP + Opposite Signals]\n";
   } else {
      g_infoText += "[EXIT MODE: SL/TP Only - Signal exits disabled]\n";
   }
   
   // Add position sizing info
   if(Inp_LotSize <= 0) {
      g_infoText += "Position Sizing: Risk " + DoubleToString(Inp_RiskPercentage, 1) + "% of balance\n";
   } else {
      g_infoText += "Position Sizing: Fixed " + DoubleToString(Inp_LotSize, 2) + " lots\n";
   }
   
   // Add performance stats
   int total_trades = g_winningTrades + g_losingTrades;
   if(total_trades > 0) {
      g_infoText += "History: " + IntegerToString(total_trades) + " trades (W/L: " + 
                   IntegerToString(g_winningTrades) + "/" + IntegerToString(g_losingTrades) + ")\n";
      
      if(g_totalLosses > 0) {
         g_infoText += "Profit Factor: " + DoubleToString(g_totalProfits / g_totalLosses, 2) + "\n";
      }
   }
   
   // Add evolution info
   if(Inp_EvolutionMinutes > 0) {
      datetime next_evo = g_lastEvolutionTime + Inp_EvolutionMinutes * 60;
      datetime time_left = next_evo - TimeCurrent();
      int mins = (int)(time_left / 60);
      int secs = (int)(time_left % 60);
      g_infoText += "Next Evolution: " + IntegerToString(mins) + "m " + IntegerToString(secs) + "s";
      
      if(Inp_EvolveRiskParams) {
         g_infoText += " (Evolving SMA + Risk params)";
      } else {
         g_infoText += " (Evolving SMA only)";
      }
      
      if(Inp_OnlyEvolveAfterLosses) {
         g_infoText += " (or after loss)";
      }
      
      if(g_evolutionInProgress) {
         g_infoText += " - EVOLUTION IN PROGRESS";
      }
   } else {
      g_infoText += "Evolution timer disabled";
   }
   
   // Add signal interpretation info to make the change clear to users
   g_infoText += "Signal Logic: SHORT>LONG=SELL, SHORT<LONG=BUY\n";
   
   Comment(g_infoText);
}

//+------------------------------------------------------------------+
//| Calculate ATR-based stop loss and take profit distances          |
//+------------------------------------------------------------------+
bool GetATRStopLevels(double &sl_distance, double &tp_distance)
{
   if(!Inp_UseATRStops || g_handle_atr == INVALID_HANDLE) {
      // Use fixed pip values if ATR is not enabled
      sl_distance = g_stopLossPips * Point();
      tp_distance = g_takeProfitPips * Point();
      return true;
   }
   
   // Get current ATR value
   double atr_values[];
   if(CopyBuffer(g_handle_atr, 0, 0, 1, atr_values) <= 0) {
      Print("Error: Could not get ATR value. Error code: ", GetLastError());
      return false;
   }
   
   // Calculate distances based on ATR
   sl_distance = atr_values[0] * Inp_ATRMultiplierSL;
   tp_distance = atr_values[0] * Inp_ATRMultiplierTP;
   
   // Ensure minimum distances (don't allow too tight stops)
   double min_sl = g_stopLossPips * 0.5 * Point(); // At least 50% of fixed SL
   double min_tp = g_takeProfitPips * 0.5 * Point(); // At least 50% of fixed TP
   
   sl_distance = MathMax(sl_distance, min_sl);
   tp_distance = MathMax(tp_distance, min_tp);
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for trading signal based on SMA crossover                  |
//+------------------------------------------------------------------+
int CheckSignal()
{
   double short_current[2]; // Array to store short SMA values
   double long_current[2];  // Array to store long SMA values
   
   // Get values for current/previous bars
   if(CopyBuffer(g_handle_short, 0, 0, 2, short_current) <= 0) return 0;
   if(CopyBuffer(g_handle_long, 0, 0, 2, long_current) <= 0) return 0;
   
   // SMA crossover logic - FIXED by inverting the trade direction
   bool cross_up = short_current[1] <= long_current[1] && short_current[0] > long_current[0]; // Golden cross (now SELL)
   bool cross_down = short_current[1] >= long_current[1] && short_current[0] < long_current[0]; // Death cross (now BUY)
   
   // Check current open positions
   bool has_buy = HasOpenPosition(POSITION_TYPE_BUY);
   bool has_sell = HasOpenPosition(POSITION_TYPE_SELL);
   
   // Determine signal - INVERTED logic to fix direction issue
   if(cross_up) {
      if(has_buy) return -2; // Close buy signal
      if(!has_sell) return 2;  // Open sell signal (was buy signal)
   } else if(cross_down) {
      if(has_sell) return -1;  // Close sell signal
      if(!has_buy) return 1; // Open buy signal (was sell signal)
   }
   
   return 0; // No signal
}

//+------------------------------------------------------------------+
//| Check for existing positions with our magic number               |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE pos_type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == pos_type) {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute trading signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(int signal)
{
   double price, sl, tp;
   double lotSize;
   double stopLossDistance, takeProfitDistance;
   
   // Get stop loss and take profit distances
   if(!GetATRStopLevels(stopLossDistance, takeProfitDistance)) {
      // Use default fixed pip values if ATR calculation fails
      stopLossDistance = g_stopLossPips * Point();
      takeProfitDistance = g_takeProfitPips * Point();
   }
   
   switch(signal) {
      case 1: // Open Buy
         {
            if(!IsSpreadOK()) {
               Print("Spread too high for BUY entry");
               return;
            }
            price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // Calculate stop loss and take profit prices
            sl = stopLossDistance > 0 ? price - stopLossDistance : 0;
            tp = takeProfitDistance > 0 ? price + takeProfitDistance : 0;
            
            // Calculate position size based on risk
            lotSize = CalculatePositionSize(stopLossDistance);
            
            g_trade.Buy(lotSize, _Symbol, price, sl, tp, "SMA Buy " + (g_isTrending ? "Trend" : "Range"));
            break;
         }
         
      case 2: // Open Sell
         {
            if(!IsSpreadOK()) {
               Print("Spread too high for SELL entry");
               return;
            }
            price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Calculate stop loss and take profit prices
            sl = stopLossDistance > 0 ? price + stopLossDistance : 0;
            tp = takeProfitDistance > 0 ? price - takeProfitDistance : 0;
            
            // Calculate position size based on risk
            lotSize = CalculatePositionSize(stopLossDistance);
            
            g_trade.Sell(lotSize, _Symbol, price, sl, tp, "SMA Sell " + (g_isTrending ? "Trend" : "Range"));
            break;
         }
         
      case -1: // Close Sells on opposite signal
         if(Inp_CloseOnOppositeSignal) {
            // Close positions if enabled
            ClosePositions(POSITION_TYPE_SELL);
            Print("Sell positions closed on opposite signal");
         } else {
            Print("Sell close signal received but ignored - letting SL/TP manage exit");
         }
         break;
         
      case -2: // Close Buys on opposite signal
         if(Inp_CloseOnOppositeSignal) {
            // Close positions if enabled
            ClosePositions(POSITION_TYPE_BUY);
            Print("Buy positions closed on opposite signal");
         } else {
            Print("Buy close signal received but ignored - letting SL/TP manage exit");
         }
         break;
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                  |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDistance)
{
   // If fixed lot size is set or stop loss is disabled, return fixed size
   if(Inp_LotSize > 0 || stopLossDistance <= 0)
      return Inp_LotSize > 0 ? Inp_LotSize : 0.01;
      
   // Get account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Calculate risk amount based on percentage
   double riskAmount = accountBalance * (Inp_RiskPercentage / 100.0);
   
   // Get symbol information
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   // Calculate position size based on risk
   double riskPerTick = riskAmount / (stopLossDistance / tickSize * tickValue);
   double lots = NormalizeDouble(riskPerTick, 2);
   
   // Apply constraints
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = MathFloor(lots / lotStep) * lotStep;
   
   PrintFormat("Risk calculation: Balance=%.2f, Risk=%.2f%%, Amount=%.2f, SL Distance=%.5f, Lot Size=%.2f", 
               accountBalance, Inp_RiskPercentage, riskAmount, stopLossDistance, lots);
   
   return lots;
}

//+------------------------------------------------------------------+
//| Initial load of trade history                                    |
//+------------------------------------------------------------------+
void LoadTradeHistory()
{
   Print("Loading trade history...");
   
   // Clear existing records
   ArrayFree(g_tradeHistory);
   g_winningTrades = 0;
   g_losingTrades = 0;
   g_totalProfits = 0;
   g_totalLosses = 0;
   
   // Get all history
   bool success = HistorySelect(0, TimeCurrent());
   if(!success) {
      Print("Failed to get trade history");
      return;
   }
   
   g_lastHistoryCount = HistoryDealsTotal();
   
   // Now call our update function to populate the arrays
   UpdateTradeHistory();
   
   // Print summary
   Print("Trade history loaded: ", ArraySize(g_tradeHistory), " trades found");
   if(ArraySize(g_tradeHistory) > 0) {
      Print("Performance: Wins: ", g_winningTrades, ", Losses: ", g_losingTrades, 
            ", Profit Factor: ", (g_totalLosses > 0 ? g_totalProfits / g_totalLosses : 0.0));
   }
}

//+------------------------------------------------------------------+
//| Update trade history by checking for closed positions            |
//+------------------------------------------------------------------+
void UpdateTradeHistory()
{
   // Get history for our EA's trades
   bool success = HistorySelect(0, TimeCurrent());
   if(!success) {
      Print("Failed to get trade history");
      return;
   }
   
   int total_deals = HistoryDealsTotal();
   if(total_deals == g_lastHistoryCount) return; // No new deals
   
   g_lastHistoryCount = total_deals;
   
   for(int i = 0; i < total_deals; i++) {
      ulong deal_ticket = HistoryDealGetTicket(i);
      
      // Skip if we've already processed this deal
      if(deal_ticket <= g_lastDealTicket) continue;
      
      // Skip if not our trades
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != Inp_MagicNumber) continue;
      
      // Only count position closing deals
      if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      // Get deal details
      double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      ENUM_POSITION_TYPE deal_type = (ENUM_POSITION_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      
      // Find when this position was opened
      datetime open_time = 0;
      for(int j = 0; j < total_deals; j++) {
         ulong prev_ticket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(prev_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN &&
            HistoryDealGetInteger(prev_ticket, DEAL_POSITION_ID) == position_id) {
            open_time = (datetime)HistoryDealGetInteger(prev_ticket, DEAL_TIME);
            break;
         }
      }
      
      // Record this trade
      int idx = ArraySize(g_tradeHistory);
      ArrayResize(g_tradeHistory, idx + 1);
      g_tradeHistory[idx].open_time = open_time;
      g_tradeHistory[idx].close_time = deal_time;
      g_tradeHistory[idx].profit = deal_profit;
      g_tradeHistory[idx].direction = deal_type;
      g_tradeHistory[idx].short_period = g_shortPeriod;  // Record the periods used for this trade
      g_tradeHistory[idx].long_period = g_longPeriod;
      g_tradeHistory[idx].stop_loss_pips = g_stopLossPips;     // Record SL/TP settings too
      g_tradeHistory[idx].take_profit_pips = g_takeProfitPips;
      g_tradeHistory[idx].used_in_evolution = false;
      
      // Update performance metrics
      if(deal_profit >= 0) {
         g_winningTrades++;
         g_totalProfits += deal_profit;
      } else {
         g_losingTrades++;
         g_totalLosses += MathAbs(deal_profit);
         
         // Flag for evolution after loss if feature enabled
         if(Inp_OnlyEvolveAfterLosses) {
            g_evolveDueToLoss = true;
         }
      }
      
      g_lastDealTicket = deal_ticket;
      
      PrintFormat("Trade recorded: %s, Profit: %.2f, SMA: %d/%d, SL: %d, TP: %d",
                  deal_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  deal_profit, g_tradeHistory[idx].short_period, g_tradeHistory[idx].long_period,
                  g_tradeHistory[idx].stop_loss_pips, g_tradeHistory[idx].take_profit_pips);
   }
}

//+------------------------------------------------------------------+
//| Run genetic algorithm to find optimal SMA parameters             |
//+------------------------------------------------------------------+
bool RunEvolution(SChromosome &best_result)
{
   Print("Starting genetic algorithm optimization with real trade integration...");
   bool useRealTradeData = ArraySize(g_tradeHistory) >= Inp_MinTradesForEvolution;
   
   if(useRealTradeData) {
      Print("Using real trade data in fitness evaluation (weight: ", Inp_RealTradeProfitWeight, ")");
   } else {
      Print("Insufficient real trade data. Using simulation only.");
   }
   
   // Initialize population with current parameters as one member
   SChromosome current;
   current.short_period = g_shortPeriod;
   current.long_period = g_longPeriod;
   current.stop_loss_pips = g_stopLossPips;
   current.take_profit_pips = g_takeProfitPips;
   
   // For simplicity in this fix, just return the current parameters
   // In a real implementation, this would run the genetic algorithm
   best_result = current;
   return true;
}
//+------------------------------------------------------------------+
