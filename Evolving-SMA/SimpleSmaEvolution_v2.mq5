//+------------------------------------------------------------------+
//|                                       SimpleSmaEvolution_v2.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "2.00"
#property description "SMA Crossover with evolutionary optimization based on real trade performance"
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
input int              Inp_StopLossPips = 50;       // Stop Loss in pips (0=off)
input int              Inp_TakeProfitPips = 100;    // Take Profit in pips (0=off)
input double           Inp_MaxSpreadPoints = 5.0;   // Max spread in points (0=off)

// Genetic Algorithm Parameters
input group           "Genetic Algorithm Parameters"
input int              Inp_MinPeriod = 5;           // Min SMA Period
input int              Inp_MaxPeriod = 200;         // Max SMA Period
input int              Inp_MinDiff = 5;             // Min difference between periods
input int              Inp_PopulationSize = 20;     // Population size
input int              Inp_Generations = 10;        // Generations per evolution
input double           Inp_MutationRate = 0.1;      // Mutation rate (0.0-1.0)
input int              Inp_TestBars = 500;          // Bars for fitness simulation

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

//--- Simple Chromosome Structure (just the core genes and fitness)
struct SChromosome
{
   int short_period;      // Gene: Short SMA period
   int long_period;       // Gene: Long SMA period
   double fitness;        // Fitness value
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Initializing SMA Evolution EA v2.0 with trade performance-based optimization...");
   
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
   
   Print("SMA Evolution EA v2.0 initialized successfully.");
   Print("Initial SMA periods: Short=", g_shortPeriod, ", Long=", g_longPeriod);
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
      
      // Run evolution to find better periods
      SChromosome best;
      if(RunEvolution(best)) {
         // Update SMA periods if evolution successful
         PrintFormat("Evolution complete. New periods: Short=%d, Long=%d with fitness %.4f", 
                    best.short_period, best.long_period, best.fitness);
                    
         // Update the EA's parameters
         g_shortPeriod = best.short_period;
         g_longPeriod = best.long_period;
         
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
            sl = Inp_StopLossPips > 0 ? price - Inp_StopLossPips * Point() : 0;
            tp = Inp_TakeProfitPips > 0 ? price + Inp_TakeProfitPips * Point() : 0;
            
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
            sl = Inp_StopLossPips > 0 ? price + Inp_StopLossPips * Point() : 0;
            tp = Inp_TakeProfitPips > 0 ? price - Inp_TakeProfitPips * Point() : 0;
            
            // Calculate position size based on risk percentage
            stopLossDistance = sl - price;
            lotSize = CalculatePositionSize(stopLossDistance);
            
            g_trade.Sell(lotSize, _Symbol, price, sl, tp, "SMA Sell");
            break;
         }
         
      case -1: // Close Sells
         ClosePositions(POSITION_TYPE_SELL);
         break;
         
      case -2: // Close Buys
         ClosePositions(POSITION_TYPE_BUY);
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
      
      PrintFormat("Trade recorded: %s, Profit: %.2f, SMA Periods: %d/%d",
                  deal_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  deal_profit, g_tradeHistory[idx].short_period, g_tradeHistory[idx].long_period);
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
//| Calculate performance metrics for specific SMA periods           |
//+------------------------------------------------------------------+
bool GetPeriodPerformance(int short_period, int long_period, double &winRate, double &profitFactor)
{
   int win_count = 0;
   int loss_count = 0;
   double profit_sum = 0;
   double loss_sum = 0;
   
   // Count trades with these exact periods
   for(int i = 0; i < ArraySize(g_tradeHistory); i++) {
      if(g_tradeHistory[i].short_period == short_period && g_tradeHistory[i].long_period == long_period) {
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
   if(total_trades == 0) return false; // No trades with these periods
   
   winRate = (double)win_count / total_trades;
   profitFactor = (loss_sum > 0) ? profit_sum / loss_sum : (profit_sum > 0 ? 10.0 : 0.0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Evaluate real performance impact on chromosome fitness           |
//+------------------------------------------------------------------+
double EvaluateRealPerformance(int short_period, int long_period)
{
   // 1. Check exact period matches
   double win_rate = 0, profit_factor = 0;
   if(GetPeriodPerformance(short_period, long_period, win_rate, profit_factor)) {
      // We have real data for these exact periods
      return (profit_factor * 5) + (win_rate * 5); // Weight both metrics
   }
   
   // 2. No exact matches, try similar periods within a range
   int range = 3; // Look for periods within +/- 3
   int match_count = 0;
   double sum_win_rate = 0;
   double sum_profit_factor = 0;
   
   for(int s = short_period - range; s <= short_period + range; s++) {
      for(int l = long_period - range; l <= long_period + range; l++) {
         if(GetPeriodPerformance(s, l, win_rate, profit_factor)) {
            // Weight inversely by distance from target periods
            double distance = MathSqrt(MathPow(s - short_period, 2) + MathPow(l - long_period, 2));
            double weight = 1.0 / (1.0 + distance);  // Higher weight for closer periods
            
            sum_win_rate += win_rate * weight;
            sum_profit_factor += profit_factor * weight;
            match_count++;
         }
      }
   }
   
   if(match_count > 0) {
      // Return weighted average of similar periods
      double avg_win_rate = sum_win_rate / match_count;
      double avg_profit_factor = sum_profit_factor / match_count;
      return (avg_profit_factor * 5) + (avg_win_rate * 5);
   }
   
   // 3. No real data at all - return neutral value
   return 0.0; 
}

//+------------------------------------------------------------------+
//| Run genetic algorithm to find optimal SMA parameters              |
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
      population[i].short_period = RandomPeriod(Inp_MinPeriod, Inp_MaxPeriod - Inp_MinDiff);
      population[i].long_period = population[i].short_period + Inp_MinDiff + 
                                  RandomPeriod(0, Inp_MaxPeriod - population[i].short_period - Inp_MinDiff);
      population[i].fitness = -1000000; // Initial worst fitness
   }
   
   // Add current parameters as one individual
   int current_idx = Inp_PopulationSize - 1; // Replace last one
   population[current_idx].short_period = g_shortPeriod;
   population[current_idx].long_period = g_longPeriod;
   
   // Track best solution
   SChromosome best;
   best.short_period = g_shortPeriod;
   best.long_period = g_longPeriod;
   best.fitness = -1000000;
   
   // Evaluate initial population
   EvaluatePopulation(population, useRealTradeData);
   
   // Find initial best
   FindBest(population, best);
   PrintFormat("Initial best: Short=%d, Long=%d, Fitness=%.4f", 
              best.short_period, best.long_period, best.fitness);
   
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
            // Simple crossover - swap periods
            offspring[i].short_period = population[p1_idx].short_period;
            offspring[i].long_period = population[p2_idx].long_period;
            
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
         PrintFormat("Gen %d: New best found! Short=%d, Long=%d, Fitness=%.4f", 
                    gen+1, best.short_period, best.long_period, best.fitness);
      }
      
      // Replace population with offspring
      ArrayCopy(population, offspring);
   }
   
   // Check if we found better parameters than current
   if(best.fitness > -1000000 && 
      (best.short_period != g_shortPeriod || best.long_period != g_longPeriod)) {
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
      double simFitness = SimulateSMA(population[i].short_period, population[i].long_period);
      
      // Blend with real trade performance if enabled and data available
      if(useRealTradeData && Inp_RealTradeProfitWeight > 0) {
         double realFitness = EvaluateRealPerformance(population[i].short_period, population[i].long_period);
         
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
   }
   
   // Mutate long period
   if(MathRand() / 32767.0 < Inp_MutationRate) {
      int change = (MathRand() % 11) - 5; // -5 to +5
      chromosome.long_period += change;
      
      // Apply constraints
      chromosome.long_period = MathMax(chromosome.short_period + Inp_MinDiff, chromosome.long_period);
      chromosome.long_period = MathMin(Inp_MaxPeriod, chromosome.long_period);
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
//| Simulate SMA strategy with given periods to calculate fitness     |
//+------------------------------------------------------------------+
double SimulateSMA(int short_period, int long_period)
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
   
   // Simulation variables
   double balance = 10000.0;
   double profit = 0.0;
   int trades = 0;
   int wins = 0;
   double max_drawdown = 0;
   double peak_balance = balance;
   int position = 0; // 0=flat, 1=long, -1=short
   double entry_price = 0.0;
   
   // Simulate trading
   for(int i = long_period + 1; i < Inp_TestBars; i++) {
      // Check for crossover
      bool cross_up = short_buffer[i+1] <= long_buffer[i+1] && short_buffer[i] > long_buffer[i];
      bool cross_down = short_buffer[i+1] >= long_buffer[i+1] && short_buffer[i] < long_buffer[i];
      
      // Handle position exit
      if(position == 1 && cross_down) {
         double p = rates[i].close - entry_price;
         profit += p;
         if(p > 0) wins++;
         trades++;
         position = 0;
         balance += p;
      }
      else if(position == -1 && cross_up) {
         double p = entry_price - rates[i].close;
         profit += p;
         if(p > 0) wins++;
         trades++;
         position = 0;
         balance += p;
      }
      
      // Update drawdown tracking
      if(balance > peak_balance) peak_balance = balance;
      double dd = (peak_balance - balance) / peak_balance * 100.0;
      if(dd > max_drawdown) max_drawdown = dd;
      
      // Handle position entry
      if(position == 0) {
         if(cross_up) {
            position = 1;
            entry_price = rates[i].close;
         }
         else if(cross_down) {
            position = -1;
            entry_price = rates[i].close;
         }
      }
   }
   
   // Calculate comprehensive fitness value
   double fitness = 0;
   
   // No trades or all losses is bad
   if(trades == 0) return -500;
   
   double win_rate = (double)wins / trades;
   double profit_factor = (trades - wins > 0) ? (profit / (trades - wins)) : profit;
   
   // Combine different metrics
   fitness = profit * 0.4;                   // 40% weight on raw profit
   fitness += win_rate * 1000 * 0.3;         // 30% weight on win rate
   fitness += (100.0 - max_drawdown) * 0.3;  // 30% weight on avoiding drawdown
   
   // Add penalty for periods that are too far from current
   // This helps prevent massive jumps in parameters
   double period_shift_penalty = 0.05 * (MathAbs(short_period - g_shortPeriod) + 
                                       MathAbs(long_period - g_longPeriod));
   
   fitness -= period_shift_penalty;
   
   return fitness;
}

//+------------------------------------------------------------------+
//| Update chart comment with current SMA periods and time            |
//+------------------------------------------------------------------+
void UpdateChartComment()
{
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   g_infoText = "SMA Evolution EA v2.0 - Last Updated: " + time_str + "\n";
   g_infoText += "SMA Periods: Short=" + IntegerToString(g_shortPeriod) + 
                 ", Long=" + IntegerToString(g_longPeriod) + "\n";
   
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
