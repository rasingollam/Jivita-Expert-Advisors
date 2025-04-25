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

//--- Global Variables ---
// Trading state
int g_shortPeriod = 0;         // Current short period
int g_longPeriod = 0;          // Current long period
int g_stopLossPips = 0;        // Current stop loss in pips
int g_takeProfitPips = 0;      // Current take profit in pips
int g_handle_short = INVALID_HANDLE;   // Indicator handle
int g_handle_long = INVALID_HANDLE;    // Indicator handle
CTrade g_trade;                // Trading object

// Evolution state
datetime g_lastEvolutionTime = 0;  // Time of last evolution
bool g_evolutionInProgress = false; // Flag to prevent overlapping runs

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

//--- Simple Chromosome Structure (now including SL/TP genes)
struct SChromosome
{
   int short_period;      // Gene: Short SMA period
   int long_period;       // Gene: Long SMA period
   int stop_loss_pips;    // Gene: Stop Loss in pips
   int take_profit_pips;  // Gene: Take Profit in pips
   double fitness;        // Fitness value
};

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
//| Create/recreate indicator handles                                |
//+------------------------------------------------------------------+
bool CreateIndicators()
{
   // Release existing handles
   if(g_handle_short != INVALID_HANDLE) IndicatorRelease(g_handle_short);
   if(g_handle_long != INVALID_HANDLE) IndicatorRelease(g_handle_long);
   
   // Create new handles with hidden visualization
   g_handle_short = iMA(_Symbol, _Period, g_shortPeriod, 0, MODE_SMA, PRICE_CLOSE);
   g_handle_long = iMA(_Symbol, _Period, g_longPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   if(g_handle_short == INVALID_HANDLE || g_handle_long == INVALID_HANDLE) {
      Print("Error: Failed to create indicator handles. Error code: ", GetLastError());
      return false;
   }
   
   // Set visualization to hidden (disable plotting on chart)
   // This makes the EA less processing intensive
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(g_shortPeriod) + ")");
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(g_longPeriod) + ")");
   
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
   
   // SMA crossover logic
   bool cross_up = short_current[1] <= long_current[1] && short_current[0] > long_current[0]; // Golden cross
   bool cross_down = short_current[1] >= long_current[1] && short_current[0] < long_current[0]; // Death cross
   
   // Check current open positions
   bool has_buy = HasOpenPosition(POSITION_TYPE_BUY);
   bool has_sell = HasOpenPosition(POSITION_TYPE_SELL);
   
   // Determine signal
   if(cross_up) {
      if(has_sell) return -1; // Close sell signal
      if(!has_buy) return 1;  // Open buy signal
   } else if(cross_down) {
      if(has_buy) return -2;  // Close buy signal
      if(!has_sell) return 2; // Open sell signal
   }
   
   return 0; // No signal
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                  |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDistance)
{
   // If fixed lot size is set or stop loss is disabled, return fixed size
   if(Inp_LotSize > 0 || Inp_StopLossPips <= 0 || stopLossDistance <= 0)
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
   
   if(stopLossDistance <= 0 || tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
      return minLot;
   
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
//| Execute trading signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(int signal)
{
   double price, sl, tp;
   double lotSize;
   double stopLossDistance;
   
   switch(signal) {
      case 1: // Open Buy
         {
            if(!IsSpreadOK()) {
               Print("Spread too high for BUY entry");
               return;
            }
            price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // Calculate stop loss price
            sl = g_stopLossPips > 0 ? price - g_stopLossPips * Point() : 0;
            tp = g_takeProfitPips > 0 ? price + g_takeProfitPips * Point() : 0;
            
            // Calculate position size based on risk percentage
            stopLossDistance = price - sl;
            lotSize = CalculatePositionSize(stopLossDistance);
            
            g_trade.Buy(lotSize, _Symbol, price, sl, tp, "SMA Buy");
            break;
         }
         
      case 2: // Open Sell
         {
            if(!IsSpreadOK()) {
               Print("Spread too high for SELL entry");
               return;
            }
            price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Calculate stop loss price
            sl = g_stopLossPips > 0 ? price + g_stopLossPips * Point() : 0;
            tp = g_takeProfitPips > 0 ? price - g_takeProfitPips * Point() : 0;
            
            // Calculate position size based on risk percentage
            stopLossDistance = sl - price;
            lotSize = CalculatePositionSize(stopLossDistance);
            
            g_trade.Sell(lotSize, _Symbol, price, sl, tp, "SMA Sell");
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
//| Calculate performance metrics for specific SMA & SL/TP settings  |
//+------------------------------------------------------------------+
bool GetParameterPerformance(int short_period, int long_period, int sl_pips, int tp_pips,
                            double &winRate, double &profitFactor)
{
   int win_count = 0;
   int loss_count = 0;
   double profit_sum = 0;
   double loss_sum = 0;
   
   // Count trades with these exact parameters
   for(int i = 0; i < ArraySize(g_tradeHistory); i++) {
      if(g_tradeHistory[i].short_period == short_period && 
         g_tradeHistory[i].long_period == long_period &&
         // Consider SL/TP match if the feature is enabled
         (!Inp_EvolveRiskParams || 
          (g_tradeHistory[i].stop_loss_pips == sl_pips && 
           g_tradeHistory[i].take_profit_pips == tp_pips))) {
           
         if(g_tradeHistory[i].profit >= 0) {
            win_count++;
            profit_sum += g_tradeHistory[i].profit;
         } else {
            loss_count++;
            loss_sum += MathAbs(g_tradeHistory[i].profit);
         }
      }
   }
   
   int total_trades = win_count + loss_count;
   if(total_trades == 0) return false; // No trades with these parameters
   
   winRate = (double)win_count / total_trades;
   profitFactor = (loss_sum > 0) ? profit_sum / loss_sum : (profit_sum > 0 ? 10.0 : 0.0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Evaluate real performance impact on chromosome fitness           |
//+------------------------------------------------------------------+
double EvaluateRealPerformance(int short_period, int long_period, int sl_pips, int tp_pips)
{
   // 1. Check exact parameter matches
   double win_rate = 0, profit_factor = 0;
   if(GetParameterPerformance(short_period, long_period, sl_pips, tp_pips, win_rate, profit_factor)) {
      // We have real data for these exact parameters
      return (profit_factor * 5) + (win_rate * 5); // Weight both metrics
   }
   
   // 2. No exact matches, try similar parameters within a range
   int sma_range = 3;    // Look for periods within +/- 3
   int sl_range = 10;    // SL within +/- 10 pips
   int tp_range = 20;    // TP within +/- 20 pips
   int match_count = 0;
   double sum_win_rate = 0;
   double sum_profit_factor = 0;
   
   for(int s = short_period - sma_range; s <= short_period + sma_range; s++) {
      for(int l = long_period - sma_range; l <= long_period + sma_range; l++) {
         // Only check SL/TP ranges if the feature is enabled
         int sl_min = Inp_EvolveRiskParams ? sl_pips - sl_range : sl_pips;
         int sl_max = Inp_EvolveRiskParams ? sl_pips + sl_range : sl_pips;
         int tp_min = Inp_EvolveRiskParams ? tp_pips - tp_range : tp_pips;
         int tp_max = Inp_EvolveRiskParams ? tp_pips + tp_range : tp_pips;
         
         for(int sl = sl_min; sl <= sl_max; sl += 5) {
            for(int tp = tp_min; tp <= tp_max; tp += 10) {
               if(GetParameterPerformance(s, l, sl, tp, win_rate, profit_factor)) {
                  // Calculate distance based on all parameters
                  double sma_distance = MathSqrt(MathPow(s - short_period, 2) + MathPow(l - long_period, 2));
                  double risk_distance = Inp_EvolveRiskParams ? 
                     MathSqrt(MathPow((sl - sl_pips) / 10.0, 2) + MathPow((tp - tp_pips) / 20.0, 2)) : 0;
                  
                  double total_distance = sma_distance + risk_distance;
                  double weight = 1.0 / (1.0 + total_distance);  // Higher weight for closer parameters
                  
                  sum_win_rate += win_rate * weight;
                  sum_profit_factor += profit_factor * weight;
                  match_count++;
               }
            }
         }
      }
   }
   
   if(match_count > 0) {
      // Return weighted average of similar parameters
      double avg_win_rate = sum_win_rate / match_count;
      double avg_profit_factor = sum_profit_factor / match_count;
      return (avg_profit_factor * 5) + (avg_win_rate * 5);
   }
   
   // 3. No real data at all - return neutral value
   return 0.0; 
}

//+------------------------------------------------------------------+
//| Run genetic algorithm to find optimal parameters                  |
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
   
   // Initialize population
   SChromosome population[];
   ArrayResize(population, Inp_PopulationSize);
   
   // Create initial random population
   for(int i = 0; i < Inp_PopulationSize; i++) {
      // Generate SMA periods
      population[i].short_period = RandomPeriod(Inp_MinPeriod, Inp_MaxPeriod - Inp_MinDiff);
      population[i].long_period = population[i].short_period + Inp_MinDiff + 
                               RandomPeriod(0, Inp_MaxPeriod - population[i].short_period - Inp_MinDiff);
                               
      // Generate SL/TP parameters if enabled
      if(Inp_EvolveRiskParams) {
         population[i].stop_loss_pips = RandomPeriod(Inp_MinStopLoss, Inp_MaxStopLoss);
         
         // Generate TP based on SL and RR ratio
         double min_tp = population[i].stop_loss_pips * Inp_MinRiskReward;
         double max_tp = population[i].stop_loss_pips * Inp_MaxRiskReward;
         
         // Ensure TP is within the overall constraints
         min_tp = MathMax(min_tp, Inp_MinTakeProfit);
         max_tp = MathMin(max_tp, Inp_MaxTakeProfit);
         
         population[i].take_profit_pips = RandomPeriod((int)min_tp, (int)max_tp);
      } else {
         // Use current SL/TP 
         population[i].stop_loss_pips = g_stopLossPips;
         population[i].take_profit_pips = g_takeProfitPips;
      }
      
      population[i].fitness = -1000000; // Initial worst fitness
   }
   
   // Add current parameters as one individual
   int current_idx = Inp_PopulationSize - 1; // Replace last one
   population[current_idx].short_period = g_shortPeriod;
   population[current_idx].long_period = g_longPeriod;
   population[current_idx].stop_loss_pips = g_stopLossPips;
   population[current_idx].take_profit_pips = g_takeProfitPips;
   
   // Track best solution
   SChromosome best;
   best.short_period = g_shortPeriod;
   best.long_period = g_longPeriod;
   best.stop_loss_pips = g_stopLossPips;
   best.take_profit_pips = g_takeProfitPips;
   best.fitness = -1000000;
   
   // Evaluate initial population
   EvaluatePopulation(population, useRealTradeData);
   
   // Find initial best
   FindBest(population, best);
   
   if(Inp_EvolveRiskParams) {
      PrintFormat("Initial best: Short=%d, Long=%d, SL=%d, TP=%d, Fitness=%.4f", 
                 best.short_period, best.long_period, 
                 best.stop_loss_pips, best.take_profit_pips, best.fitness);
   } else {
      PrintFormat("Initial best: Short=%d, Long=%d, Fitness=%.4f", 
                 best.short_period, best.long_period, best.fitness);
   }
   
   // Run generations
   for(int gen = 0; gen < Inp_Generations; gen++) {
      // Create next generation through crossover and mutation
      SChromosome offspring[];
      ArrayResize(offspring, Inp_PopulationSize);
      
      // Elitism - keep the best solution
      offspring[0] = best;
      
      // Create rest of population through selection, crossover, mutation
      for(int i = 1; i < Inp_PopulationSize; i++) {
         // Select parents (tournament selection)
         int p1_idx = TournamentSelect(population);
         int p2_idx = TournamentSelect(population);
         
         // Crossover
         if(MathRand() / 32767.0 < 0.7) { // 70% crossover rate
            // Simple crossover - swap parameters
            offspring[i].short_period = population[p1_idx].short_period;
            offspring[i].long_period = population[p2_idx].long_period;
            
            if(Inp_EvolveRiskParams) {
               // Also crossover SL/TP parameters
               offspring[i].stop_loss_pips = population[p1_idx].stop_loss_pips;
               offspring[i].take_profit_pips = population[p2_idx].take_profit_pips;
            } else {
               // Keep current SL/TP
               offspring[i].stop_loss_pips = g_stopLossPips;
               offspring[i].take_profit_pips = g_takeProfitPips;
            }
            
            // Ensure long > short + min_diff
            if(offspring[i].long_period <= offspring[i].short_period + Inp_MinDiff) {
               offspring[i].long_period = offspring[i].short_period + Inp_MinDiff;
            }
         } else {
            // No crossover, just copy one parent
            offspring[i] = population[p1_idx];
         }
         
         // Mutation
         MutateChromosome(offspring[i]);
      }
      
      // Evaluate new generation
      EvaluatePopulation(offspring, useRealTradeData);
      
      // Find best in new generation
      SChromosome gen_best;
      gen_best.fitness = -1000000;
      FindBest(offspring, gen_best);
      
      // Update best if generation's best is better
      if(gen_best.fitness > best.fitness) {
         best = gen_best;
         
         if(Inp_EvolveRiskParams) {
            PrintFormat("Gen %d: New best! Short=%d, Long=%d, SL=%d, TP=%d, Fitness=%.4f", 
                      gen+1, best.short_period, best.long_period, 
                      best.stop_loss_pips, best.take_profit_pips, best.fitness);
         } else {
            PrintFormat("Gen %d: New best! Short=%d, Long=%d, Fitness=%.4f", 
                      gen+1, best.short_period, best.long_period, best.fitness);
         }
      }
      
      // Replace population with offspring
      ArrayCopy(population, offspring);
   }
   
   // Check if we found better parameters than current
   bool improvement = false;
   
   // Always check SMA periods
   if(best.short_period != g_shortPeriod || best.long_period != g_longPeriod)
      improvement = true;
      
   // Check SL/TP only if we're evolving risk params
   if(Inp_EvolveRiskParams && 
      (best.stop_loss_pips != g_stopLossPips || best.take_profit_pips != g_takeProfitPips))
      improvement = true;
      
   if(best.fitness > -1000000 && improvement) {
      best_result = best;
      return true;
   }
   
   return false; // No improvement found
}

//+------------------------------------------------------------------+
//| Evaluate fitness of all chromosomes in a population              |
//+------------------------------------------------------------------+
void EvaluatePopulation(SChromosome &population[], bool useRealTradeData)
{
   int size = ArraySize(population);
   
   for(int i = 0; i < size; i++) {
      // Simulate on historical data first (always do this)
      double simFitness = SimulateSMA(
         population[i].short_period, 
         population[i].long_period,
         population[i].stop_loss_pips, 
         population[i].take_profit_pips
      );
      
      // Blend with real trade performance if enabled and data available
      if(useRealTradeData && Inp_RealTradeProfitWeight > 0) {
         double realFitness = EvaluateRealPerformance(
            population[i].short_period, 
            population[i].long_period,
            population[i].stop_loss_pips, 
            population[i].take_profit_pips
         );
         
         // Blend the two fitness values using the weight parameter
         population[i].fitness = (simFitness * (1.0 - Inp_RealTradeProfitWeight)) + 
                               (realFitness * Inp_RealTradeProfitWeight);
      } else {
         population[i].fitness = simFitness;
      }
   }
}

//+------------------------------------------------------------------+
//| Find best chromosome in a population                             |
//+------------------------------------------------------------------+
void FindBest(SChromosome &population[], SChromosome &best)
{
   int size = ArraySize(population);
   
   for(int i = 0; i < size; i++) {
      if(population[i].fitness > best.fitness) {
         best = population[i];
      }
   }
}

//+------------------------------------------------------------------+
//| Tournament selection - select best from random candidates         |
//+------------------------------------------------------------------+
int TournamentSelect(SChromosome &population[])
{
   int pop_size = ArraySize(population);
   int tournament_size = 3; // Select from 3 random candidates
   int best_idx = MathRand() % pop_size;
   double best_fitness = population[best_idx].fitness;
   
   for(int i = 1; i < tournament_size; i++) {
      int idx = MathRand() % pop_size;
      if(population[idx].fitness > best_fitness) {
         best_idx = idx;
         best_fitness = population[idx].fitness;
      }
   }
   
   return best_idx;
}

//+------------------------------------------------------------------+
//| Mutate a chromosome based on mutation rate                        |
//+------------------------------------------------------------------+
void MutateChromosome(SChromosome &chromosome)
{
   // Mutate short period
   if(MathRand() / 32767.0 < Inp_MutationRate) {
      int change = (MathRand() % 11) - 5; // -5 to +5
      chromosome.short_period += change;
      
      // Apply constraints
      chromosome.short_period = MathMax(Inp_MinPeriod, chromosome.short_period);
      chromosome.short_period = MathMin(Inp_MaxPeriod - Inp_MinDiff, chromosome.short_period);
      
      // Ensure long period is valid
      if(chromosome.long_period <= chromosome.short_period + Inp_MinDiff)
         chromosome.long_period = chromosome.short_period + Inp_MinDiff;
   }
   
   // Mutate long period
   if(MathRand() / 32767.0 < Inp_MutationRate) {
      int change = (MathRand() % 11) - 5; // -5 to +5
      chromosome.long_period += change;
      
      // Apply constraints
      chromosome.long_period = MathMax(chromosome.short_period + Inp_MinDiff, chromosome.long_period);
      chromosome.long_period = MathMin(Inp_MaxPeriod, chromosome.long_period);
   }
   
   // Only mutate risk parameters if enabled
   if(Inp_EvolveRiskParams) {
      // Mutate stop loss
      if(MathRand() / 32767.0 < Inp_MutationRate) {
         int change = (int)((MathRand() % 21) - 10); // -10 to +10 pips
         chromosome.stop_loss_pips += change;
         
         // Apply constraints
         chromosome.stop_loss_pips = MathMax(Inp_MinStopLoss, chromosome.stop_loss_pips);
         chromosome.stop_loss_pips = MathMin(Inp_MaxStopLoss, chromosome.stop_loss_pips);
         
         // Adjust TP to maintain valid RR if needed
         double current_rr = (double)chromosome.take_profit_pips / chromosome.stop_loss_pips;
         if(current_rr < Inp_MinRiskReward || current_rr > Inp_MaxRiskReward) {
            // Recalculate TP based on average of min/max RR
            double target_rr = (Inp_MinRiskReward + Inp_MaxRiskReward) / 2.0;
            chromosome.take_profit_pips = (int)(chromosome.stop_loss_pips * target_rr);
            chromosome.take_profit_pips = MathMax(Inp_MinTakeProfit, chromosome.take_profit_pips);
            chromosome.take_profit_pips = MathMin(Inp_MaxTakeProfit, chromosome.take_profit_pips);
         }
      }
      
      // Mutate take profit
      if(MathRand() / 32767.0 < Inp_MutationRate) {
         int change = (int)((MathRand() % 41) - 20); // -20 to +20 pips
         chromosome.take_profit_pips += change;
         
         // Calculate min/max TP based on SL and RR constraints
         int min_tp = (int)(chromosome.stop_loss_pips * Inp_MinRiskReward);
         int max_tp = (int)(chromosome.stop_loss_pips * Inp_MaxRiskReward);
         
         // Also consider global TP constraints
         min_tp = MathMax(min_tp, Inp_MinTakeProfit);
         max_tp = MathMin(max_tp, Inp_MaxTakeProfit);
         
         // Apply constraints
         chromosome.take_profit_pips = MathMax(min_tp, chromosome.take_profit_pips);
         chromosome.take_profit_pips = MathMin(max_tp, chromosome.take_profit_pips);
      }
   }
}

//+------------------------------------------------------------------+
//| Generate a random period within specified range                   |
//+------------------------------------------------------------------+
int RandomPeriod(int min_val, int max_val)
{
   if(max_val <= min_val) return min_val;
   return min_val + MathRand() % (max_val - min_val + 1);
}

//+------------------------------------------------------------------+
//| Simulate SMA strategy with given parameters to calculate fitness  |
//+------------------------------------------------------------------+
double SimulateSMA(int short_period, int long_period, int sl_pips, int tp_pips)
{
   // Verify parameters
   if(short_period <= 0 || long_period <= short_period) return -1000000;
   
   // Create temporary indicator handles WITHOUT PLOTTING (more efficient)
   int temp_short = iMA(_Symbol, _Period, short_period, 0, MODE_SMA, PRICE_CLOSE);
   int temp_long = iMA(_Symbol, _Period, long_period, 0, MODE_SMA, PRICE_CLOSE);
   
   if(temp_short == INVALID_HANDLE || temp_long == INVALID_HANDLE) {
      if(temp_short != INVALID_HANDLE) IndicatorRelease(temp_short);
      if(temp_long != INVALID_HANDLE) IndicatorRelease(temp_long);
      return -1000000;
   }
   
   // Remove charts to reduce processing load
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(short_period) + ")");
   ChartIndicatorDelete(0, 0, "Moving Average(" + string(long_period) + ")");
   
   // Get historical data
   MqlRates rates[];
   int bars_needed = Inp_TestBars + long_period + 2;
   if(CopyRates(_Symbol, _Period, 0, bars_needed, rates) < bars_needed) {
      IndicatorRelease(temp_short);
      IndicatorRelease(temp_long);
      return -1000000;
   }
   
   // Get indicator values
   double short_buffer[];
   double long_buffer[];
   if(CopyBuffer(temp_short, 0, 0, bars_needed, short_buffer) < bars_needed ||
      CopyBuffer(temp_long, 0, 0, bars_needed, long_buffer) < bars_needed) {
      IndicatorRelease(temp_short);
      IndicatorRelease(temp_long);
      return -1000000;
   }
   
   // Release temporary indicators
   IndicatorRelease(temp_short);
   IndicatorRelease(temp_long);
   
   // Calculate pip value for SL/TP
   double pip_value = Point();
   
   // Simulation variables
   double balance = 10000.0;
   double profit = 0.0;
   int trades = 0;
   int wins = 0;
   double max_drawdown = 0;
   double peak_balance = balance;
   int position = 0; // 0=flat, 1=long, -1=short
   double entry_price = 0.0;
   double sl_price = 0.0;
   double tp_price = 0.0;
   
   // Simulate trading
   for(int i = long_period + 1; i < Inp_TestBars; i++) {
      // Check for crossover
      bool cross_up = short_buffer[i+1] <= long_buffer[i+1] && short_buffer[i] > long_buffer[i];
      bool cross_down = short_buffer[i+1] >= long_buffer[i+1] && short_buffer[i] < long_buffer[i];
      
      // Handle SL/TP hits
      if(position != 0) {
         if(position == 1) { // Long position
            // Check for stop loss hit
            if(sl_price > 0 && rates[i].low <= sl_price) {
               double p = sl_price - entry_price;
               profit += p;
               trades++;
               position = 0;
               balance += p;
            }
            // Check for take profit hit
            else if(tp_price > 0 && rates[i].high >= tp_price) {
               double p = tp_price - entry_price;
               profit += p;
               wins++;
               trades++;
               position = 0;
               balance += p;
            }
            // Handle signal-based exit if enabled
            else if(Inp_CloseOnOppositeSignal && cross_down) {
               double p = rates[i].close - entry_price;
               profit += p;
               if(p > 0) wins++;
               trades++;
               position = 0;
               balance += p;
            }
         }
         else if(position == -1) { // Short position
            // Check for stop loss hit
            if(sl_price > 0 && rates[i].high >= sl_price) {
               double p = entry_price - sl_price;
               profit += p;
               trades++;
               position = 0;
               balance += p;
            }
            // Check for take profit hit
            else if(tp_price > 0 && rates[i].low <= tp_price) {
               double p = entry_price - tp_price;
               profit += p;
               wins++;
               trades++;
               position = 0;
               balance += p;
            }
            // Handle signal-based exit if enabled
            else if(Inp_CloseOnOppositeSignal && cross_up) {
               double p = entry_price - rates[i].close;
               profit += p;
               if(p > 0) wins++;
               trades++;
               position = 0;
               balance += p;
            }
         }
      }
      
      // Handle position entry
      if(position == 0) {
         if(cross_up) {
            position = 1;
            entry_price = rates[i].close;
            // Set SL/TP if enabled
            if(sl_pips > 0) sl_price = entry_price - sl_pips * pip_value;
            else sl_price = 0;
            if(tp_pips > 0) tp_price = entry_price + tp_pips * pip_value;
            else tp_price = 0;
         }
         else if(cross_down) {
            position = -1;
            entry_price = rates[i].close;
            // Set SL/TP if enabled
            if(sl_pips > 0) sl_price = entry_price + sl_pips * pip_value;
            else sl_price = 0;
            if(tp_pips > 0) tp_price = entry_price - tp_pips * pip_value;
            else tp_price = 0;
         }
      }
   }
   
   // Calculate comprehensive fitness value
   double fitness = 0;
   
   // No trades or all losses is bad
   if(trades == 0) return -500;
   
   double win_rate = (double)wins / trades;
   double avg_profit = profit / trades;
   
   // Combine different metrics
   fitness = profit * 0.4;                   // 40% weight on raw profit
   fitness += win_rate * 1000 * 0.25;        // 25% weight on win rate
   fitness += (100.0 - max_drawdown) * 0.25; // 25% weight on avoiding drawdown
   fitness += trades * 0.1;                  // 10% weight on number of trades
   
   // Add penalty for parameters that are too far from current
   // This helps prevent massive jumps in parameters
   double sma_penalty = 0.05 * (MathAbs(short_period - g_shortPeriod) + 
                              MathAbs(long_period - g_longPeriod));
                              
   double risk_penalty = 0.0;
   if(Inp_EvolveRiskParams) {
      risk_penalty = 0.03 * (MathAbs(sl_pips - g_stopLossPips) / 10.0 + 
                           MathAbs(tp_pips - g_takeProfitPips) / 20.0);
   }
   
   fitness -= (sma_penalty + risk_penalty);
   
   return fitness;
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
   g_infoText += "Risk Parameters: SL=" + IntegerToString(g_stopLossPips) + 
                 ", TP=" + IntegerToString(g_takeProfitPips) + " pips\n";
   
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
   
   Comment(g_infoText);
}
//+------------------------------------------------------------------+
