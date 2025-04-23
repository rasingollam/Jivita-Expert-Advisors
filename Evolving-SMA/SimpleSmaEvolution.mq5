//+------------------------------------------------------------------+
//|                                          SimpleSmaEvolution.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"
#property description "Simple SMA Crossover with evolutionary optimization (non-OOP version)"
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters ---
// Trading Parameters
input int              Inp_ShortPeriod = 10;        // Short SMA Period
input int              Inp_LongPeriod = 30;         // Long SMA Period
input double           Inp_LotSize = 0.01;          // Fixed Lot Size
input ulong            Inp_MagicNumber = 123456;    // Magic Number
input int              Inp_StopLossPips = 50;       // Stop Loss in pips (0=off)
input int              Inp_TakeProfitPips = 100;    // Take Profit in pips (0=off)
input double           Inp_MaxSpreadPoints = 5.0;   // Max spread in points (0=off)

// Optimization Parameters
input int              Inp_MinPeriod = 5;           // Min SMA Period
input int              Inp_MaxPeriod = 200;         // Max SMA Period
input int              Inp_MinDiff = 5;             // Min difference between periods
input int              Inp_PopulationSize = 20;     // Population size
input int              Inp_Generations = 10;        // Generations per evolution
input double           Inp_MutationRate = 0.1;      // Mutation rate (0.0-1.0)
input int              Inp_TestBars = 500;          // Bars for fitness test
input int              Inp_EvolutionMinutes = 60;   // Evolution frequency (minutes)

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
   Print("Initializing Simple SMA Evolution EA...");
   
   // Validate inputs
   if(Inp_ShortPeriod <= 0 || Inp_LongPeriod <= Inp_ShortPeriod) {
      Print("Error: Invalid SMA periods configuration.");
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
   
   // Set timer for evolution
   if(Inp_EvolutionMinutes > 0) {
      EventSetTimer(60); // Check every minute
      g_lastEvolutionTime = TimeCurrent();
      Print("Evolution timer set. Evolution will run every ", Inp_EvolutionMinutes, " minutes.");
   }
   
   // Update chart comment with initial period info
   UpdateChartComment();
   
   Print("Simple SMA Evolution EA initialized successfully.");
   Print("Initial SMA periods: Short=", g_shortPeriod, ", Long=", g_longPeriod);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinitializing Simple SMA Evolution EA...");
   
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
   
   // Optional: Process only on new bar
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(last_bar_time == current_bar_time) return; // No new bar yet
   last_bar_time = current_bar_time;
   
   // Check trading conditions and execute
   int signal = CheckSignal();
   if(signal != 0) ExecuteSignal(signal);
   
   // Update chart comment periodically (every 10 seconds)
   datetime current_time = TimeCurrent();
   if(current_time - g_lastUpdateTime > 10) {
      UpdateChartComment();
      g_lastUpdateTime = current_time;
   }
}

//+------------------------------------------------------------------+
//| Timer function (handle evolution)                                |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Skip if already running an evolution or not time yet
   if(g_evolutionInProgress) return;
   
   datetime current_time = TimeCurrent();
   int evolution_seconds = Inp_EvolutionMinutes * 60;
   
   if(current_time - g_lastEvolutionTime >= evolution_seconds) {
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
   
   // Update chart comment after creating indicators
   UpdateChartComment();
   
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
//| Execute trading signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(int signal)
{
   double price, sl, tp;
   
   switch(signal) {
      case 1: // Open Buy
         if(!IsSpreadOK()) {
            Print("Spread too high for BUY entry");
            return;
         }
         price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         sl = Inp_StopLossPips > 0 ? price - Inp_StopLossPips * Point() : 0;
         tp = Inp_TakeProfitPips > 0 ? price + Inp_TakeProfitPips * Point() : 0;
         g_trade.Buy(Inp_LotSize, _Symbol, price, sl, tp, "SMA Buy");
         break;
         
      case 2: // Open Sell
         if(!IsSpreadOK()) {
            Print("Spread too high for SELL entry");
            return;
         }
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl = Inp_StopLossPips > 0 ? price + Inp_StopLossPips * Point() : 0;
         tp = Inp_TakeProfitPips > 0 ? price - Inp_TakeProfitPips * Point() : 0;
         g_trade.Sell(Inp_LotSize, _Symbol, price, sl, tp, "SMA Sell");
         break;
         
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
//| Run genetic algorithm to find optimal SMA parameters              |
//+------------------------------------------------------------------+
bool RunEvolution(SChromosome &best_result)
{
   Print("Starting genetic algorithm optimization...");
   
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
   EvaluatePopulation(population);
   
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
      EvaluatePopulation(offspring);
      
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
void EvaluatePopulation(SChromosome &population[])
{
   int size = ArraySize(population);
   
   for(int i = 0; i < size; i++) {
      population[i].fitness = SimulateSMA(population[i].short_period, population[i].long_period);
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
      }
      else if(position == -1 && cross_up) {
         double p = entry_price - rates[i].close;
         profit += p;
         if(p > 0) wins++;
         trades++;
         position = 0;
      }
      
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
   
   // Calculate fitness value
   double fitness = 0;
   
   // Simple profit-based fitness
   fitness = profit;
   
   // Add penalty for periods that are too far from current
   // This helps prevent massive jumps in parameters
   double period_shift_penalty = 0.1 * (MathAbs(short_period - g_shortPeriod) + 
                                       MathAbs(long_period - g_longPeriod));
   
   fitness -= period_shift_penalty;
   
   // Additional factors could be considered:
   // - win rate
   // - profit factor
   // - maximum drawdown, etc.
   
   return fitness;
}

//+------------------------------------------------------------------+
//| Update chart comment with current SMA periods and time            |
//+------------------------------------------------------------------+
void UpdateChartComment()
{
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   g_infoText = "SimpleSmaEvolution EA - Last Updated: " + time_str + "\n";
   g_infoText += "SMA Periods: Short=" + IntegerToString(g_shortPeriod) + 
                 ", Long=" + IntegerToString(g_longPeriod) + "\n";
   
   if(Inp_EvolutionMinutes > 0) {
      datetime next_evo = g_lastEvolutionTime + Inp_EvolutionMinutes * 60;
      datetime time_left = next_evo - TimeCurrent();
      int mins = (int)(time_left / 60);
      int secs = (int)(time_left % 60);
      g_infoText += "Next Evolution: " + IntegerToString(mins) + "m " + IntegerToString(secs) + "s";
      
      if(g_evolutionInProgress) {
         g_infoText += " (Evolution in progress...)";
      }
   } else {
      g_infoText += "Evolution disabled";
   }
   
   Comment(g_infoText);
}
//+------------------------------------------------------------------+
