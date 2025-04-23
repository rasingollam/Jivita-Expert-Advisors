//+------------------------------------------------------------------+
//|                                        EvolvingSmaCrossover.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"
#property description "SMA Crossover EA with self-evolving parameters using Genetic Algorithm (OOP)"

//--- Include custom classes (Adjust path if needed)
#include "includes/SmaTrader.mqh"         // Corrected path
#include "includes/GeneticAlgorithm.mqh"  // Corrected path (includes Chromosome.mqh and ENUM_OPTIMIZATION_CRITERION)

//--- Input Parameters ---
// Trading Parameters
input group           "Trading Parameters"
input int             InpInitialShortSmaPeriod = 10;      // Initial Short SMA Period
input int             InpInitialLongSmaPeriod  = 30;      // Initial Long SMA Period
input double          InpLotSize               = 0.01;    // Fixed Lot Size
input ulong           InpMagicNumber           = 123456;  // EA Magic Number
input int             InpStopLossPips          = 50;      // Stop Loss in Pips (0 to disable)
input int             InpTakeProfitPips        = 100;     // Take Profit in Pips (0 to disable)
input double          InpMaxSpreadPoints       = 5.0;     // Maximum allowed spread in Points (0 to disable)

// Genetic Algorithm Parameters
input group           "Genetic Algorithm Parameters"
input int             InpGaPopulationSize      = 50;      // GA Population Size
input int             InpGaGenerations         = 20;      // GA Generations per evolution cycle
input double          InpGaMutationRate        = 0.10;    // GA Mutation Rate (0.0 to 1.0)
input double          InpGaCrossoverRate       = 0.70;    // GA Crossover Rate (0.0 to 1.0)
input int             InpGaMinSmaPeriod        = 5;       // GA Minimum SMA Period Constraint
input int             InpGaMaxSmaPeriod        = 200;     // GA Maximum SMA Period Constraint
input int             InpGaMinPeriodDifference = 5;       // GA Minimum Difference between Long and Short Periods
input int             InpGaFitnessHistoryBars  = 500;     // Bars for Fitness Backtest Simulation
input ENUM_OPTIMIZATION_CRITERION InpGaOptimizationCriterion = CRITERION_BALANCE; // GA Fitness Goal

// Evolution Trigger Parameters
input group           "Evolution Trigger"
input int             InpEvolutionFrequencyMinutes = 60;   // How often to run GA (in minutes)

//--- Global Objects ---
CSmaTrader         *g_trader = NULL; // Pointer to the trader object
CGeneticAlgorithm  *g_ga = NULL;     // Pointer to the GA object
CChromosome        *g_best_params = NULL; // Pointer to the current best parameters found by GA

//--- Timer Constants ---
#define EVOLUTION_TIMER_EVENT 1 // Custom timer event ID
#define TRADE_CHECK_TIMER_EVENT 2 // Optional: Timer for trade checks instead of OnTick

//--- Global variables ---
datetime g_last_evolution_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Initializing Evolving SMA Crossover EA...");

   //--- Validate Inputs ---
   if(InpInitialLongSmaPeriod <= InpInitialShortSmaPeriod) {
       Print("Error: Initial Long SMA Period must be greater than Initial Short SMA Period.");
       return(INIT_FAILED);
   }
    if(InpGaMaxSmaPeriod <= InpGaMinSmaPeriod) {
       Print("Error: GA Max SMA Period must be greater than GA Min SMA Period.");
       return(INIT_FAILED);
   }
   if(InpGaMinPeriodDifference <= 0){
       Print("Error: GA Min Period Difference must be positive.");
       return(INIT_FAILED);
   }
    if(InpGaMaxSmaPeriod <= InpGaMinSmaPeriod + InpGaMinPeriodDifference){
       Print("Error: GA Max/Min/Difference constraints are impossible.");
       return(INIT_FAILED);
   }
   if(InpGaPopulationSize < 4) { // Need at least a few for meaningful evolution
       Print("Warning: GA Population size is very small (", InpGaPopulationSize, "). Consider increasing.");
   }
   if(InpGaGenerations < 1) {
       Print("Warning: GA Generations is less than 1. Evolution might not be effective.");
   }


   //--- Create Objects ---
   g_trader = new CSmaTrader();
   if(CheckPointer(g_trader) == POINTER_INVALID) {
      Print("Error: Failed to create CSmaTrader object!");
      return(INIT_FAILED);
   }

   g_ga = new CGeneticAlgorithm(InpGaPopulationSize, InpGaMutationRate, InpGaCrossoverRate, InpGaGenerations,
                                InpGaMinSmaPeriod, InpGaMaxSmaPeriod, InpGaMinPeriodDifference, InpGaFitnessHistoryBars,
                                _Symbol, _Period, InpGaOptimizationCriterion);
   if(CheckPointer(g_ga) == POINTER_INVALID) {
      Print("Error: Failed to create CGeneticAlgorithm object!");
      delete g_trader; // Clean up trader object
      g_trader = NULL;
      return(INIT_FAILED);
   }

   // Create an initial best parameters object
   g_best_params = new CChromosome(InpGaMinSmaPeriod, InpGaMaxSmaPeriod, InpGaMinPeriodDifference);
    if(CheckPointer(g_best_params) == POINTER_INVALID) {
      Print("Error: Failed to create CChromosome object for best params!");
      delete g_trader;
      delete g_ga;
      g_trader = NULL;
      g_ga = NULL;
      return(INIT_FAILED);
    }
   // Set initial parameters from inputs
   g_best_params->SetShortPeriod(InpInitialShortSmaPeriod); // Use ->
   g_best_params->SetLongPeriod(InpInitialLongSmaPeriod);  // Use ->
   g_best_params->SetFitness(-DBL_MAX); // Use -> // Start with worst fitness

   //--- Initialize Trader ---
   if(!g_trader->Init(InpInitialShortSmaPeriod, InpInitialLongSmaPeriod, InpLotSize, InpMagicNumber, // Use ->
                     _Symbol, _Period, InpStopLossPips, InpTakeProfitPips, InpMaxSpreadPoints))
     {
      Print("Error: Failed to initialize CSmaTrader object!");
      delete g_trader;
      delete g_ga;
      delete g_best_params;
      g_trader = NULL;
      g_ga = NULL;
      g_best_params = NULL;
      return(INIT_FAILED);
     }

   //--- Set Timer for Evolution ---
   // Convert frequency from minutes to seconds
   int timer_interval_seconds = InpEvolutionFrequencyMinutes * 60;
   if(timer_interval_seconds <= 0)
   {
        Print("Warning: Evolution frequency is zero or negative. Disabling automatic evolution.");
   } else {
        // Trigger the first evolution sooner (e.g., after 1 minute) instead of waiting full interval
        EventSetTimer(1 * 60); // First run after 1 minute
        PrintFormat("Evolution timer set. First run in ~1 minute, then every %d minutes.", InpEvolutionFrequencyMinutes);
   }

   // Optional: Set a faster timer for trade checks if not using OnTick
   // EventSetTimer(TRADE_CHECK_TIMER_EVENT, 1); // Check every second

   Print("Evolving SMA Crossover EA Initialized Successfully.");
   g_last_evolution_time = TimeCurrent(); // Record init time as last evolution time initially
   //---
   return(INIT_SUCCEEDED); // Ensure this is INIT_SUCCEEDED
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Deinitializing Evolving SMA Crossover EA... Reason: ", reason);

   //--- Kill Timers ---
   EventKillTimer();

   //--- Clean up Objects ---
   if(CheckPointer(g_trader) == POINTER_DYNAMIC)
     {
      delete g_trader;
      g_trader = NULL;
     }
   if(CheckPointer(g_ga) == POINTER_DYNAMIC)
     {
      delete g_ga;
      g_ga = NULL;
     }
    if(CheckPointer(g_best_params) == POINTER_DYNAMIC)
     {
      delete g_best_params;
      g_best_params = NULL;
     }

   Print("Evolving SMA Crossover EA Deinitialized.");
   //---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Check for valid objects ---
   if(CheckPointer(g_trader) == POINTER_INVALID) return;

   //--- Check for new bar (optional, can reduce redundant checks) ---
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(current_bar_time == last_bar_time)
     {
      return; // No new bar, no need to check signals yet
     }
   last_bar_time = current_bar_time;


   //--- Check Trading Signal ---
   ENUM_TRADE_SIGNAL signal = g_trader->CheckSignal(); // Use ->

   //--- Execute Signal ---
   if(signal != SIGNAL_NONE)
     {
       g_trader->ExecuteSignal(signal); // Use ->
     }
   //---
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   //--- Check for valid objects ---
   if(CheckPointer(g_ga) == POINTER_INVALID ||
      CheckPointer(g_trader) == POINTER_INVALID ||
      CheckPointer(g_best_params) == POINTER_INVALID ) return;


    // Determine if it's time for evolution
    datetime current_time = TimeCurrent();
    int frequency_seconds = InpEvolutionFrequencyMinutes * 60;

    // Check if frequency is enabled and enough time has passed
    if(frequency_seconds > 0 && (current_time - g_last_evolution_time >= frequency_seconds))
    {
       PrintFormat("Evolution Triggered: Current Time = %s, Last Evolution = %s",
                   TimeToString(current_time), TimeToString(g_last_evolution_time));

       // --- Run GA Evolution ---
       Print("Starting GA evolution cycle...");
       CChromosome *result = g_ga->RunEvolution(); // Use -> // This can take time!

        if(CheckPointer(result) != POINTER_INVALID)
        {
           // --- Compare with current best and update trader if improved ---
           bool update_needed = false;
           double new_fitness = result->GetFitness(); // Use ->
           double old_fitness = g_best_params->GetFitness(); // Use ->

           if(InpGaOptimizationCriterion == CRITERION_MAX_DRAWDOWN) { // Minimization
               // Update if new fitness is significantly lower (e.g., by 1%) to avoid chasing noise
               if (new_fitness < old_fitness * 0.99 && MathIsValidNumber(old_fitness) && old_fitness != DBL_MAX) update_needed = true; // Added checks
               else if (!MathIsValidNumber(old_fitness) || old_fitness == DBL_MAX) update_needed = true; // Update if old fitness was invalid/initial
           } else { // Maximization
               // Update if new fitness is significantly higher (e.g., by 1%)
               if (new_fitness > old_fitness * 1.01 && MathIsValidNumber(old_fitness) && old_fitness != -DBL_MAX) update_needed = true; // Added checks
               else if (!MathIsValidNumber(old_fitness) || old_fitness == -DBL_MAX) update_needed = true; // Update if old fitness was invalid/initial
           }

           // Also update if the initial parameters haven't been evaluated yet (redundant with checks above, but safe)
           // if (old_fitness <= -DBL_MAX || old_fitness >= DBL_MAX) update_needed = true;


           if(update_needed && MathIsValidNumber(new_fitness)) // Ensure new fitness is valid before updating
           {
                PrintFormat("GA found improved parameters! Old Fitness: %.4f, New Fitness: %.4f", old_fitness, new_fitness);
                PrintFormat("Updating trader with Short=%d, Long=%d", result->GetShortPeriod(), result->GetLongPeriod()); // Use -> for result

                // Update the global best parameters tracker
                g_best_params->Copy(result); // Use ->

                // Update the trader's active parameters
                if(!g_trader->UpdateParameters(result->GetShortPeriod(), result->GetLongPeriod())) // Use -> for g_trader and result
                {
                   Print("Error: Failed to update trader parameters after optimization!");
                   // Consider how to handle this - revert? stop?
                }
           } else {
               PrintFormat("GA finished, but no significant improvement found over current best (Current: %.4f, New: %.4f). Keeping existing parameters.", old_fitness, new_fitness);
           }

        } else {
            Print("GA Error: Evolution returned invalid result pointer.");
        }


       g_last_evolution_time = TimeCurrent(); // Reset the timer regardless of update
       Print("GA evolution cycle complete.");

        // Re-set the timer for the next interval
        if(frequency_seconds > 0) // Only reset if frequency is valid
        {
            EventSetTimer(frequency_seconds);
            PrintFormat("Next evolution scheduled in %d minutes.", InpEvolutionFrequencyMinutes);
        }

    } // End if time for evolution


   /*
   // --- Optional: Handle trade checks via timer instead of OnTick ---
   int timer_id = EventGetInteger(L"id"); // Get which timer triggered
   if(timer_id == TRADE_CHECK_TIMER_EVENT)
   {
       // Check Trading Signal
       ENUM_TRADE_SIGNAL signal = g_trader->CheckSignal();

       // Execute Signal
       if(signal != SIGNAL_NONE)
       {
           g_trader->ExecuteSignal(signal);
       }
   }
   */

  }
//+------------------------------------------------------------------+