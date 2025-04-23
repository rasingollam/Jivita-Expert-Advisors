//+------------------------------------------------------------------+
//|                                            GeneticAlgorithm.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"

#include "Chromosome.mqh"

//--- Optimization criteria enum (matches Strategy Tester options for potential consistency)
//--- Moved outside the class definition ---
enum ENUM_OPTIMIZATION_CRITERION
  {
   CRITERION_BALANCE,       // Max balance
   CRITERION_PROFIT_FACTOR, // Max profit factor
   CRITERION_EXPECTED_PAYOFF,// Max expected payoff
   CRITERION_MAX_DRAWDOWN,  // Min drawdown %
   CRITERION_SHARPE_RATIO,  // Max Sharpe Ratio
   // Add others if needed
  };

//+------------------------------------------------------------------+
//| Manages the population and evolution process                     |
//+------------------------------------------------------------------+
class CGeneticAlgorithm
  {
private:
   CChromosome      *m_population[];       // Array of pointers to chromosomes
   int               m_population_size;
   double            m_mutation_rate;
   double            m_crossover_rate;
   int               m_generations;
   int               m_min_period;
   int               m_max_period;
   int               m_period_diff_min;
   int               m_fitness_history_bars; // How many bars back to check for fitness
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_OPTIMIZATION_CRITERION m_criterion; // Uses the enum defined above
   CChromosome      *m_best_chromosome;    // Stores the best overall found

   //--- Internal GA structures
   CChromosome      *m_new_population[];
   double            m_total_fitness;

public:
                     CGeneticAlgorithm(int pop_size = 50, double mut_rate = 0.1, double cross_rate = 0.7, int gens = 100,
                                       int min_p = 5, int max_p = 200, int min_diff = 5, int fitness_bars=500,
                                       string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                                       ENUM_OPTIMIZATION_CRITERION criterion = CRITERION_BALANCE);
                    ~CGeneticAlgorithm();

   //--- GA Operations
   void              InitializePopulation(void);
   void              EvaluatePopulation(void);
   void              EvolveGeneration(void);
   CChromosome      *RunEvolution(void); // Runs all generations
   CChromosome      *GetBestChromosome(void) { return m_best_chromosome; }

private:
   //--- Core GA steps
   void              Selection(CChromosome*& parent1, CChromosome*& parent2); // Selects 2 parents
   void              Crossover(CChromosome *parent1, CChromosome *parent2, CChromosome *child1, CChromosome *child2);
   void              Mutation(void); // Mutates the new population

   //--- Fitness calculation (THE MOST CRITICAL AND POTENTIALLY SLOW PART)
   double            CalculateFitness(CChromosome *chromosome);
   double            SimulateStrategy(int short_period, int long_period); // Simplified backtest

   //--- Helper methods
   void              FindBestChromosome(void); // Finds best in current population
   int               CompareChromosomes(const void* left, const void* right); // For sorting
   void              SortPopulation(void); // Optional: Sort by fitness
   void              ResizePopulations(int new_size);
   void              CleanPopulation(CChromosome*& pop_array[]);

   //--- Selection Methods (Example: Tournament)
   CChromosome      *TournamentSelection(int tournament_size = 5);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGeneticAlgorithm::CGeneticAlgorithm(int pop_size = 50, double mut_rate = 0.1, double cross_rate = 0.7, int gens = 100,
                                   int min_p = 5, int max_p = 200, int min_diff = 5, int fitness_bars=500,
                                   string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                                   ENUM_OPTIMIZATION_CRITERION criterion = CRITERION_BALANCE) :
   m_population_size(pop_size),
   m_mutation_rate(mut_rate),
   m_crossover_rate(cross_rate),
   m_generations(gens),
   m_min_period(min_p),
   m_max_period(max_p),
   m_period_diff_min(min_diff),
   m_fitness_history_bars(fitness_bars),
   m_symbol(symbol),
   m_timeframe(tf),
   m_criterion(criterion),
   m_total_fitness(0.0),
   m_best_chromosome(NULL)
  {
   if(m_symbol == NULL || m_symbol == "")
      m_symbol = _Symbol;
   if(m_timeframe == PERIOD_CURRENT)
      m_timeframe = _Period;

   // Validate population size
   if(m_population_size <= 0) m_population_size = 2; // Need at least 2 for crossover
   if(m_population_size % 2 != 0) m_population_size++; // Make it even for easier crossover pairing

   ResizePopulations(m_population_size);
   m_best_chromosome = new CChromosome(m_min_period, m_max_period, m_period_diff_min); // Initialize best
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGeneticAlgorithm::~CGeneticAlgorithm()
  {
   CleanPopulation(m_population);
   CleanPopulation(m_new_population);
   if(CheckPointer(m_best_chromosome) == POINTER_DYNAMIC)
      delete m_best_chromosome;
  }
//+------------------------------------------------------------------+
//| Resize internal population arrays                                |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::ResizePopulations(int new_size)
  {
   CleanPopulation(m_population);       // Clean old before resizing
   CleanPopulation(m_new_population);

   ArrayResize(m_population, new_size);
   ArrayResize(m_new_population, new_size);

   // Allocate memory for chromosomes (pointers are NULL initially)
   for(int i = 0; i < new_size; i++)
     {
      m_population[i] = NULL; // Initialize to NULL
      m_new_population[i] = NULL;
     }
   m_population_size = new_size;
  }
//+------------------------------------------------------------------+
//| Delete chromosome objects in a population array                  |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::CleanPopulation(CChromosome*& pop_array[])
  {
   int size = ArraySize(pop_array);
   for(int i = 0; i < size; i++)
     {
      if(CheckPointer(pop_array[i]) == POINTER_DYNAMIC)
        {
         delete pop_array[i];
         pop_array[i] = NULL; // Prevent double deletion
        }
     }
  }
//+------------------------------------------------------------------+
//| Initialize population with random chromosomes                    |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::InitializePopulation(void)
  {
   Print("GA: Initializing population...");
   for(int i = 0; i < m_population_size; i++)
     {
      // Delete old object if it exists
      if(CheckPointer(m_population[i]) == POINTER_DYNAMIC) delete m_population[i];

      m_population[i] = new CChromosome(m_min_period, m_max_period, m_period_diff_min);
      if(CheckPointer(m_population[i]) == POINTER_INVALID)
        {
         Print("GA Error: Failed to allocate memory for chromosome ", i);
         continue; // Skip if allocation failed
        }
      m_population[i]->InitRandom(); // Ensure -> is used
      // Optional: Print initial individuals
      // PrintFormat("Initial %d: Short=%d, Long=%d", i, m_population[i]->GetShortPeriod(), m_population[i]->GetLongPeriod()); // Ensure -> is used
     }
   // Initialize best chromosome with the first one initially
   if(m_population_size > 0 && CheckPointer(m_population[0]) == POINTER_DYNAMIC)
     m_best_chromosome->Copy(m_population[0]); // Ensure -> is used
   m_best_chromosome->SetFitness(-DBL_MAX); // Ensure -> is used
   Print("GA: Population Initialized.");
  }
//+------------------------------------------------------------------+
//| Evaluate fitness of the entire population                        |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::EvaluatePopulation(void)
  {
   Print("GA: Evaluating population fitness...");
   m_total_fitness = 0;
   double best_fitness_in_pop = -DBL_MAX; // Use -DBL_MAX for maximization, DBL_MAX for minimization
   if (m_criterion == CRITERION_MAX_DRAWDOWN) best_fitness_in_pop = DBL_MAX;

   int best_index_in_pop = -1;

   for(int i = 0; i < m_population_size; i++)
     {
      if(CheckPointer(m_population[i]) == POINTER_INVALID) continue;

      double fitness = CalculateFitness(m_population[i]);
      m_population[i]->SetFitness(fitness); // Ensure -> is used
      m_total_fitness += fitness; // Note: This sum isn't directly useful for tournament selection

      // Track best in current population
      bool is_better = false;
      if(m_criterion == CRITERION_MAX_DRAWDOWN) { // Minimization
          if(fitness < best_fitness_in_pop) is_better = true;
      } else { // Maximization (default)
          if(fitness > best_fitness_in_pop) is_better = true;
      }

      if(is_better) {
          best_fitness_in_pop = fitness;
          best_index_in_pop = i;
      }

      // Check against overall best found so far
      bool is_overall_better = false;
       if(m_criterion == CRITERION_MAX_DRAWDOWN) { // Minimization
           if(fitness < m_best_chromosome->GetFitness()) is_overall_better = true; // Ensure -> is used
       } else { // Maximization (default)
           if(fitness > m_best_chromosome->GetFitness()) is_overall_better = true; // Ensure -> is used
       }

       if(is_overall_better) {
           m_best_chromosome->Copy(m_population[i]); // Ensure -> is used
           // PrintFormat("GA: New overall best found! Fitness=%.2f, Short=%d, Long=%d", fitness, m_population[i]->GetShortPeriod(), m_population[i]->GetLongPeriod()); // Ensure -> is used
       }
     }
    // Optional: Print best of this generation
    // if(best_index_in_pop != -1) PrintFormat("GA: Gen Best: Fitness=%.2f, Short=%d, Long=%d", best_fitness_in_pop, m_population[best_index_in_pop]->GetShortPeriod(), m_population[best_index_in_pop]->GetLongPeriod()); // Ensure -> is used
   Print("GA: Fitness Evaluation Complete.");
  }
//+------------------------------------------------------------------+
//| Calculate fitness for a single chromosome (SIMPLIFIED)           |
//+------------------------------------------------------------------+
double CGeneticAlgorithm::CalculateFitness(CChromosome *chromosome)
  {
   if(CheckPointer(chromosome) == POINTER_INVALID) return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); // Worst possible fitness

   int short_p = chromosome->GetShortPeriod();
   int long_p = chromosome->GetLongPeriod();

   // --- SIMULATED BACKTEST ---
   // This is a placeholder for performance reasons. A real implementation
   // needs careful handling of historical data and trade simulation.
   double result = SimulateStrategy(short_p, long_p);
   // --- END SIMULATED BACKTEST ---

   // Handle cases where simulation might fail or produce invalid numbers
   if(!MathIsValidNumber(result)) {
        result = (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX);
   }
   // PrintFormat("Fitness for Short=%d, Long=%d -> %.4f", short_p, long_p, result); // Debug
   return result;
  }
//+------------------------------------------------------------------+
//| Simulate SMA Crossover Strategy (VERY SIMPLIFIED EXAMPLE)        |
//+------------------------------------------------------------------+
double CGeneticAlgorithm::SimulateStrategy(int short_period, int long_period)
  {
   // --- Get Historical Data ---
   MqlRates rates[];
   int bars_to_copy = m_fitness_history_bars + MathMax(short_period, long_period) + 2; // Need enough data for initial MA calculation + history
   if(CopyRates(m_symbol, m_timeframe, 0, bars_to_copy, rates) < bars_to_copy)
     {
      Print("GA Error: Could not copy enough rates for fitness evaluation.");
      return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); // Return worst fitness on error
     }

   // --- Calculate SMAs ---
   double sma_short_buffer[];
   double sma_long_buffer[];
   int calculated;

   // Define and calculate Short SMA
   int handle_short = iMA(m_symbol, m_timeframe, short_period, 0, MODE_SMA, PRICE_CLOSE);
   if(handle_short == INVALID_HANDLE) { Print("GA Error: Invalid short SMA handle"); return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); }
   calculated = CopyBuffer(handle_short, 0, 0, bars_to_copy, sma_short_buffer);
   if(calculated <= m_fitness_history_bars) { IndicatorRelease(handle_short); Print("GA Error: Not enough short SMA data calculated"); return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); }

   // Define and calculate Long SMA
   int handle_long = iMA(m_symbol, m_timeframe, long_period, 0, MODE_SMA, PRICE_CLOSE);
   if(handle_long == INVALID_HANDLE) { IndicatorRelease(handle_short); Print("GA Error: Invalid long SMA handle"); return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); }
   calculated = CopyBuffer(handle_long, 0, 0, bars_to_copy, sma_long_buffer);
   if(calculated <= m_fitness_history_bars) { IndicatorRelease(handle_short); IndicatorRelease(handle_long); Print("GA Error: Not enough long SMA data calculated"); return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); }


   // --- Simulate Trading Logic ---
   double balance = 10000.0; // Starting virtual balance
   double equity = balance;
   double peak_equity = balance;
   double max_drawdown_pct = 0.0;
   double gross_profit = 0.0;
   double gross_loss = 0.0;
   int trades_count = 0;
   double points_profit = 0; // Use points for simplicity, avoid spread/slippage complexity here

   int current_position = 0; // 0 = none, 1 = long, -1 = short
   double entry_price = 0.0;

   // Simulate from oldest required bar to second most recent
   // Index 0 is the current forming bar, 1 is the last completed bar.
   // We need sma[i] and sma[i+1] to check crossover at bar i.
   // Data is newest first (index 0), so we iterate backwards.
   // Start index calculation: Array size is bars_to_copy. Last usable index is bars_to_copy-1.
   // We need index i and i+1 for SMA. We iterate up to index 1 (second to last bar).
   // The loop should go from index = bars_to_copy - 2 down to 1.
   int start_idx = ArraySize(sma_short_buffer) - 2; // Index for previous bar relative to current
   int end_idx = 1; // Simulate up to the close of the second to last bar

   if (start_idx < m_fitness_history_bars) start_idx = m_fitness_history_bars; // Ensure we simulate enough bars
   if (start_idx < end_idx) { // Not enough data
       IndicatorRelease(handle_short); IndicatorRelease(handle_long);
       Print("GA Warning: Not enough calculated indicator data for simulation window.");
       return (m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX);
   }


   for(int i = start_idx; i >= end_idx; i--)
     {
       // Check for valid SMA values
       if (sma_short_buffer[i] == EMPTY_VALUE || sma_long_buffer[i] == EMPTY_VALUE ||
           sma_short_buffer[i+1] == EMPTY_VALUE || sma_long_buffer[i+1] == EMPTY_VALUE)
       {
            continue; // Skip bar if MA data is missing
       }

       // Current bar's MAs
       double sma_s_curr = sma_short_buffer[i];
       double sma_l_curr = sma_long_buffer[i];
       // Previous bar's MAs
       double sma_s_prev = sma_short_buffer[i+1];
       double sma_l_prev = sma_long_buffer[i+1];

       // --- Crossover Logic ---
       bool buy_signal = sma_s_prev < sma_l_prev && sma_s_curr > sma_l_curr;
       bool sell_signal = sma_s_prev > sma_l_prev && sma_s_curr < sma_l_curr;

       // --- Trade Execution Simulation ---
       // Close existing position if signal reverses
       if(current_position == 1 && sell_signal) // Long open, sell signal
         {
            double exit_price = rates[i].close; // Exit at close of signal bar
            double profit = (exit_price - entry_price);
            points_profit += profit;
            if (profit > 0) gross_profit += profit; else gross_loss -= profit; // gross loss is positive value
            balance += profit; // Simplified balance update (ignoring lots, leverage etc)
            equity = balance; // Update equity
             if (equity < peak_equity) { // Update drawdown if needed
                max_drawdown_pct = MathMax(max_drawdown_pct, (peak_equity - equity) / peak_equity * 100.0);
             }
            current_position = 0;
            trades_count++;
         }
       else if(current_position == -1 && buy_signal) // Short open, buy signal
         {
            double exit_price = rates[i].close;
            double profit = (entry_price - exit_price); // Profit for short
            points_profit += profit;
            if (profit > 0) gross_profit += profit; else gross_loss -= profit;
            balance += profit;
            equity = balance;
             if (equity < peak_equity) {
                 max_drawdown_pct = MathMax(max_drawdown_pct, (peak_equity - equity) / peak_equity * 100.0);
             }
            current_position = 0;
            trades_count++;
         }

        // Update peak equity *after* closing trades but *before* potentially opening new ones
        peak_equity = MathMax(peak_equity, equity);


       // Open new position if signal matches and no position open
       if(current_position == 0)
         {
          if(buy_signal)
            {
             current_position = 1;
             entry_price = rates[i].close; // Enter at close of signal bar
            }
          else if(sell_signal)
            {
             current_position = -1;
             entry_price = rates[i].close;
            }
         }
     }

   // --- Cleanup Indicator Handles ---
   IndicatorRelease(handle_short);
   IndicatorRelease(handle_long);

   // --- Calculate Final Fitness Metric ---
   double fitness_value = 0;
   switch(m_criterion)
     {
      case CRITERION_PROFIT_FACTOR:
         fitness_value = (gross_loss > 0) ? gross_profit / gross_loss : (gross_profit > 0 ? 99999.0 : 0.0); // Avoid division by zero
         break;
      case CRITERION_EXPECTED_PAYOFF:
         fitness_value = (trades_count > 0) ? points_profit / trades_count : 0.0;
         break;
      case CRITERION_MAX_DRAWDOWN:
         fitness_value = max_drawdown_pct; // Lower is better for drawdown
         break;
     case CRITERION_SHARPE_RATIO:
         // Calculating Sharpe requires risk-free rate and std dev of returns - more complex simulation needed
         // Placeholder: Use simple profit/drawdown ratio (higher is better)
         fitness_value = (max_drawdown_pct > 0) ? (points_profit / (max_drawdown_pct / 100.0)) : (points_profit > 0 ? 99999.0 : 0.0);
         break;
      case CRITERION_BALANCE: // Default to net profit (points)
      default:
         fitness_value = points_profit; // Using points profit as a proxy for balance change
         break;
     }

   return fitness_value;
  }

//+------------------------------------------------------------------+
//| Perform Tournament Selection to choose a parent                  |
//+------------------------------------------------------------------+
CChromosome *CGeneticAlgorithm::TournamentSelection(int tournament_size = 5)
{
    if (m_population_size <= 0) return NULL;
    if (tournament_size > m_population_size) tournament_size = m_population_size;
    if (tournament_size <= 0) tournament_size = 2;

    CChromosome *best_in_tournament = NULL;

    for (int i = 0; i < tournament_size; ++i)
    {
        int random_index = (int)(MathRand() / (32767.0 + 1.0) * m_population_size);
        if (random_index >= m_population_size) random_index = m_population_size - 1; // Ensure index is valid

        CChromosome *candidate = m_population[random_index];
         if (CheckPointer(candidate) == POINTER_INVALID) continue; // Skip if pointer invalid

        if (best_in_tournament == NULL)
        {
            best_in_tournament = candidate;
        }
        else
        {
             bool candidate_is_better = false;
              if(m_criterion == CRITERION_MAX_DRAWDOWN) { // Minimization
                  if(candidate->GetFitness() < best_in_tournament->GetFitness()) candidate_is_better = true; // Ensure -> is used
              } else { // Maximization (default)
                  if(candidate->GetFitness() > best_in_tournament->GetFitness()) candidate_is_better = true; // Ensure -> is used
              }

              if (candidate_is_better) {
                 best_in_tournament = candidate;
              }
        }
    }
    // Fallback if somehow no valid candidate was found (shouldn't happen with valid population)
    if(best_in_tournament == NULL && m_population_size > 0) {
       int random_index = (int)(MathRand() / (32767.0 + 1.0) * m_population_size);
       if (random_index >= m_population_size) random_index = m_population_size - 1;
        best_in_tournament = m_population[random_index];
    }

    return best_in_tournament;
}

//+------------------------------------------------------------------+
//| Select two parents using Tournament Selection                    |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::Selection(CChromosome*& parent1, CChromosome*& parent2)
  {
     // Ensure parents are different individuals if possible
     parent1 = TournamentSelection();
     do {
        parent2 = TournamentSelection();
     } while (parent1 == parent2 && m_population_size > 1); // Keep trying if same parent selected and pop size > 1

     // Handle edge case where population might be 1 or all individuals are identical copies
      if (parent1 == NULL || parent2 == NULL) {
           Print("GA Warning: Parent selection failed. Using random individuals if available.");
           if(m_population_size > 0) {
               if (parent1 == NULL) parent1 = m_population[0];
               if (parent2 == NULL) parent2 = m_population[ MathMin(1, m_population_size-1) ]; // Use second if exists, else first again
           } else {
               // Cannot proceed without a population
               Print("GA Error: Cannot perform selection with zero population size.");
           }
      }
  }
//+------------------------------------------------------------------+
//| Perform Crossover between two parents                            |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::Crossover(CChromosome *parent1, CChromosome *parent2, CChromosome *child1, CChromosome *child2)
  {
    if(CheckPointer(parent1) == POINTER_INVALID || CheckPointer(parent2) == POINTER_INVALID ||
       CheckPointer(child1) == POINTER_INVALID || CheckPointer(child2) == POINTER_INVALID)
    {
        Print("GA Error: Invalid pointers passed to Crossover.");
        // Optionally copy parents directly if crossover fails due to bad pointers
        if(CheckPointer(child1) != POINTER_INVALID && CheckPointer(parent1) != POINTER_INVALID) child1->Copy(parent1); // Ensure -> is used
        if(CheckPointer(child2) != POINTER_INVALID && CheckPointer(parent2) != POINTER_INVALID) child2->Copy(parent2); // Ensure -> is used
        return;
    }

   // Perform crossover with probability m_crossover_rate
   if(MathRand() / 32767.0 < m_crossover_rate)
     {
      // Simple single-point crossover for the two parameters
      // Swap the long periods between the two children
      // Set periods - the setter methods should handle validation internally
      child1->SetShortPeriod(parent1->GetShortPeriod()); // Ensure -> is used
      child1->SetLongPeriod(parent2->GetLongPeriod()); // Ensure -> is used // Gets long from parent 2

      child2->SetShortPeriod(parent2->GetShortPeriod()); // Ensure -> is used
      child2->SetLongPeriod(parent1->GetLongPeriod()); // Ensure -> is used // Gets long from parent 1

      // Make sure long periods are always greater than short + min_diff
      // (using public setters instead of private ValidatePeriods method)
      if(child1->GetLongPeriod() <= child1->GetShortPeriod() + m_period_diff_min)
         child1->SetLongPeriod(child1->GetShortPeriod() + m_period_diff_min);
         
      if(child2->GetLongPeriod() <= child2->GetShortPeriod() + m_period_diff_min)
         child2->SetLongPeriod(child2->GetShortPeriod() + m_period_diff_min);

     }
   else
     {
      // No crossover, children are clones of parents
      child1->Copy(parent1); // Ensure -> is used
      child2->Copy(parent2); // Ensure -> is used
     }
  }
//+------------------------------------------------------------------+
//| Mutate the new population                                        |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::Mutation(void)
  {
   for(int i = 0; i < m_population_size; i++)
     {
      if(CheckPointer(m_new_population[i]) == POINTER_INVALID) continue;
      m_new_population[i]->Mutate(m_mutation_rate); // Ensure -> is used
      // Validation is handled within CChromosome::Mutate via Setters
     }
  }
//+------------------------------------------------------------------+
//| Run one generation of the GA                                     |
//+------------------------------------------------------------------+
void CGeneticAlgorithm::EvolveGeneration(void)
  {
    if(m_population_size < 2) {
       Print("GA Warning: Population size too small for evolution (< 2).");
       return; // Cannot perform selection/crossover
    }

   // Create the next generation
   for(int i = 0; i < m_population_size / 2; i++) // Create pairs of children
     {
        // Select parents
        CChromosome *parent1 = NULL, *parent2 = NULL;
        Selection(parent1, parent2);

        // Allocate new children if needed
        int child_idx1 = i * 2;
        int child_idx2 = i * 2 + 1;

        if(CheckPointer(m_new_population[child_idx1]) == POINTER_INVALID)
           m_new_population[child_idx1] = new CChromosome(m_min_period, m_max_period, m_period_diff_min);
        if(CheckPointer(m_new_population[child_idx2]) == POINTER_INVALID)
           m_new_population[child_idx2] = new CChromosome(m_min_period, m_max_period, m_period_diff_min);


        if(CheckPointer(parent1) != POINTER_INVALID && CheckPointer(parent2) != POINTER_INVALID &&
           CheckPointer(m_new_population[child_idx1]) != POINTER_INVALID &&
           CheckPointer(m_new_population[child_idx2]) != POINTER_INVALID)
        {
           // Crossover
           Crossover(parent1, parent2, m_new_population[child_idx1], m_new_population[child_idx2]);
        } else {
            // Handle error case (e.g., copy parents if selection/allocation failed)
            if(CheckPointer(m_new_population[child_idx1]) != POINTER_INVALID && CheckPointer(parent1) != POINTER_INVALID)
                m_new_population[child_idx1]->Copy(parent1); // Ensure -> is used
            if(CheckPointer(m_new_population[child_idx2]) != POINTER_INVALID && CheckPointer(parent2) != POINTER_INVALID)
                m_new_population[child_idx2]->Copy(parent2); // Ensure -> is used
        }
     }

   // Mutate the new generation
   Mutation();

   // Replace the old population with the new population
   // Swap pointers efficiently
   CChromosome *temp_pop_ptr[];
   ArrayCopy(temp_pop_ptr, m_population);       // Backup old population pointer
   ArrayCopy(m_population, m_new_population);   // Point m_population to the new generation
   ArrayCopy(m_new_population, temp_pop_ptr);   // Point m_new_population to the old (now empty or ready for reuse)

   // Optional: Clear fitness of the now-current population as it needs re-evaluation
   for(int i=0; i<m_population_size; ++i) {
      if(CheckPointer(m_population[i]) != POINTER_INVALID)
         m_population[i]->SetFitness(m_criterion == CRITERION_MAX_DRAWDOWN ? DBL_MAX : -DBL_MAX); // Ensure -> is used
   }

  }
//+------------------------------------------------------------------+
//| Run the complete evolution process                               |
//+------------------------------------------------------------------+
CChromosome* CGeneticAlgorithm::RunEvolution(void)
  {
   PrintFormat("GA: Starting evolution for %d generations.", m_generations);
   InitializePopulation(); // Start fresh
   EvaluatePopulation();   // Evaluate the initial random population

   for(int gen = 0; gen < m_generations; gen++)
     {
      // PrintFormat("GA: ---- Generation %d ----", gen + 1);
      EvolveGeneration(); // Create new generation via selection, crossover, mutation
      EvaluatePopulation(); // Evaluate the new generation's fitness

      // Optional: Print progress
      if((gen + 1) % 10 == 0) // Print every 10 generations
       PrintFormat("GA: Generation %d complete. Best Fitness so far: %.4f (Short: %d, Long: %d)",
                    gen + 1, m_best_chromosome->GetFitness(), m_best_chromosome->GetShortPeriod(), m_best_chromosome->GetLongPeriod()); // Ensure -> is used

      // Check for termination conditions (e.g., stagnation) - Not implemented here

      // Yield control briefly if running in a tight loop (important in live EA)
      Sleep(10); // Sleep 10ms to prevent blocking
       if(IsStopped()) {
           Print("GA: Evolution interrupted by EA stop.");
           break;
       }

     }

   PrintFormat("GA: Evolution finished. Best Fitness: %.4f (Short: %d, Long: %d)",
               m_best_chromosome->GetFitness(), m_best_chromosome->GetShortPeriod(), m_best_chromosome->GetLongPeriod()); // Ensure -> is used
   return m_best_chromosome;
  }
//+------------------------------------------------------------------+