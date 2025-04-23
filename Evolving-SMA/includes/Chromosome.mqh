#ifndef JIVITA_CHROMOSOME_MQH
#define JIVITA_CHROMOSOME_MQH

//+------------------------------------------------------------------+
//|                                                  Chromosome.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"
#property strict // Ensure strict compilation mode

//+------------------------------------------------------------------+
//| Represents a single solution (set of SMA parameters)             |
//+------------------------------------------------------------------+
class CChromosome
  {
private: // Restore private members
   int               m_short_period;
   int               m_long_period;
   double            m_fitness;
   int               m_min_period;
   int               m_max_period;
   int               m_period_diff_min;

public:
                     CChromosome(int min_p=5, int max_p=200, int min_diff=5);
                    ~CChromosome();

   //--- Initialization
   void              InitRandom(void);

   //--- Getters
   int               GetShortPeriod(void) const { return m_short_period; }
   int               GetLongPeriod(void) const  { return m_long_period; }
   double            GetFitness(void) const     { return m_fitness; }

   //--- Setters (Restore validation)
   void              SetShortPeriod(int period);
   void              SetLongPeriod(int period);
   void              SetFitness(double fitness) { m_fitness = fitness; } // Fitness doesn't need validation here

   //--- Mutation
   void              Mutate(double mutation_rate);

   //--- Copy (Renamed)
   void              CopyFrom(CChromosome *source); // Renamed from Copy

private:
   int               GenerateRandomPeriod(void);
   void              ValidatePeriods(void); // Restore validation method
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChromosome::CChromosome(int min_p=5, int max_p=200, int min_diff=5) :
   m_short_period(0),
   m_long_period(0),
   m_fitness(-DBL_MAX), // Initialize fitness to worst possible value for maximization
   m_min_period(min_p),
   m_max_period(max_p),
   m_period_diff_min(min_diff > 0 ? min_diff : 1)
  {
   // Ensure min/max are logical
   if(m_min_period < 1) m_min_period = 1;
   if(m_max_period <= m_min_period) m_max_period = m_min_period + m_period_diff_min; // Ensure max > min + diff
   if(m_max_period <= m_min_period) m_max_period = m_min_period + 1; // Absolute fallback

   MathSrand((int)GetTickCount());
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChromosome::~CChromosome()
  {
  }
//+------------------------------------------------------------------+
//| Initialize with random valid periods                             |
//+------------------------------------------------------------------+
void CChromosome::InitRandom(void)
  {
   do
     {
      m_short_period = GenerateRandomPeriod();
      m_long_period = GenerateRandomPeriod();
     }
   // Keep trying until validation passes
   while(m_long_period <= m_short_period + m_period_diff_min || m_short_period < m_min_period || m_long_period > m_max_period);

   ValidatePeriods(); // Final check
  }
//+------------------------------------------------------------------+
//| Generate a random period within bounds                           |
//+------------------------------------------------------------------+
int CChromosome::GenerateRandomPeriod(void)
  {
   // Use the validated min/max from constructor
   return(m_min_period + (int)(MathRand() / (32767.0 + 1.0) * (m_max_period - m_min_period + 1)));
  }
//+------------------------------------------------------------------+
//| Set Short Period (with validation)                               |
//+------------------------------------------------------------------+
void CChromosome::SetShortPeriod(int period)
  {
   m_short_period = MathMax(m_min_period, MathMin(m_max_period - m_period_diff_min, period)); // Ensure short can't force long out of bounds
   ValidatePeriods();
  }
//+------------------------------------------------------------------+
//| Set Long Period (with validation)                                |
//+------------------------------------------------------------------+
void CChromosome::SetLongPeriod(int period)
  {
   m_long_period = MathMax(m_min_period + m_period_diff_min, MathMin(m_max_period, period)); // Ensure long respects min bound
   ValidatePeriods();
  }
//+------------------------------------------------------------------+
//| Ensure Long Period is sufficiently larger than Short Period       |
//+------------------------------------------------------------------+
void CChromosome::ValidatePeriods(void)
  {
    // Clamp short period first
    m_short_period = MathMax(m_min_period, MathMin(m_max_period - m_period_diff_min, m_short_period));

    // Clamp long period based on potentially adjusted short period
    m_long_period = MathMax(m_short_period + m_period_diff_min, MathMin(m_max_period, m_long_period));

    // Final check: If long period clamping forced it too low, readjust short period down
    if (m_long_period <= m_short_period + m_period_diff_min) {
        m_short_period = m_long_period - m_period_diff_min;
        // Re-clamp short period to its absolute minimum if necessary
        m_short_period = MathMax(m_min_period, m_short_period);
    }
  }
//+------------------------------------------------------------------+
//| Mutate the chromosome's genes                                    |
//+------------------------------------------------------------------+
void CChromosome::Mutate(double mutation_rate)
  {
   bool mutated = false;
   // Use a slightly larger mutation range, e.g., 10% of the total range
   int range = m_max_period - m_min_period;
   int change_amount = MathMax(1, (int)round(range * 0.1)); // Mutate by up to 10% or at least 1

   if(MathRand() / 32767.0 < mutation_rate)
     {
      int change = (MathRand() % (2 * change_amount + 1)) - change_amount; // e.g., -change_amount to +change_amount
      m_short_period += change;
      mutated = true;
     }

   if(MathRand() / 32767.0 < mutation_rate)
     {
      int change = (MathRand() % (2 * change_amount + 1)) - change_amount;
      m_long_period += change;
      mutated = true;
     }

   // Always validate after potential mutation
   if (mutated) {
       ValidatePeriods();
   }
  }
//+------------------------------------------------------------------+
//| Copy data from another chromosome (Renamed)                      |
//+------------------------------------------------------------------+
void CChromosome::CopyFrom(CChromosome *source) // Renamed from Copy
  {
   if(CheckPointer(source) == POINTER_INVALID)
      return;

   // Can access private members of another object of the same class
   m_short_period = source->m_short_period;
   m_long_period = source->m_long_period;
   m_fitness = source->m_fitness;
   m_min_period = source->m_min_period; // Copy constraints too
   m_max_period = source->m_max_period;
   m_period_diff_min = source->m_period_diff_min;
  }
//+------------------------------------------------------------------+

#endif // JIVITA_CHROMOSOME_MQH