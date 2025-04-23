//+------------------------------------------------------------------+
//|                                                  Chromosome.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Represents a single solution (set of SMA parameters)             |
//+------------------------------------------------------------------+
class CChromosome
  {
private:
   int               m_short_period;
   int               m_long_period;
   double            m_fitness;
   int               m_min_period;
   int               m_max_period;
   int               m_period_diff_min; // Minimum difference between long and short

public:
                     CChromosome(int min_p=5, int max_p=200, int min_diff=5);
                    ~CChromosome();

   //--- Initialization
   void              InitRandom(void);

   //--- Getters
   int               GetShortPeriod(void) const { return m_short_period; }
   int               GetLongPeriod(void) const  { return m_long_period; }
   double            GetFitness(void) const     { return m_fitness; }

   //--- Setters
   void              SetShortPeriod(int period);
   void              SetLongPeriod(int period);
   void              SetFitness(double fitness) { m_fitness = fitness; }

   //--- Mutation
   void              Mutate(double mutation_rate);

   //--- Copy
   void              Copy(CChromosome *source);

private:
   int               GenerateRandomPeriod(void);
   void              ValidatePeriods(void); // Ensure long > short + min_diff
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChromosome::CChromosome(int min_p=5, int max_p=200, int min_diff=5) :
   m_short_period(0),
   m_long_period(0),
   m_fitness(0.0),
   m_min_period(min_p),
   m_max_period(max_p),
   m_period_diff_min(min_diff > 0 ? min_diff : 1) // Ensure min_diff is at least 1
  {
   MathSrand((int)GetTickCount()); // Seed random number generator
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
   while(m_long_period <= m_short_period + m_period_diff_min); // Ensure long is sufficiently larger
  }
//+------------------------------------------------------------------+
//| Generate a random period within bounds                           |
//+------------------------------------------------------------------+
int CChromosome::GenerateRandomPeriod(void)
  {
   return(m_min_period + (int)(MathRand() / (32767.0 + 1.0) * (m_max_period - m_min_period + 1)));
  }
//+------------------------------------------------------------------+
//| Set Short Period                                                 |
//+------------------------------------------------------------------+
void CChromosome::SetShortPeriod(int period)
  {
   m_short_period = MathMax(m_min_period, MathMin(m_max_period, period));
   ValidatePeriods();
  }
//+------------------------------------------------------------------+
//| Set Long Period                                                  |
//+------------------------------------------------------------------+
void CChromosome::SetLongPeriod(int period)
  {
   m_long_period = MathMax(m_min_period, MathMin(m_max_period, period));
   ValidatePeriods();
  }
//+------------------------------------------------------------------+
//| Ensure Long Period is sufficiently larger than Short Period       |
//+------------------------------------------------------------------+
void CChromosome::ValidatePeriods(void)
  {
   if(m_long_period <= m_short_period + m_period_diff_min)
     {
      // If invalid, try increasing long period first
      m_long_period = m_short_period + m_period_diff_min;
      if (m_long_period > m_max_period)
        {
         // If long period hits max, decrease short period
         m_long_period = m_max_period;
         m_short_period = m_max_period - m_period_diff_min;
         // Ensure short period doesn't go below min
         if (m_short_period < m_min_period) m_short_period = m_min_period;
         // Final check if min/max/diff constraints are impossible
         if (m_long_period <= m_short_period + m_period_diff_min)
         {
            // Handle impossible constraints, maybe default to min/min+diff
             m_short_period = m_min_period;
             m_long_period = m_min_period + m_period_diff_min;
             if(m_long_period > m_max_period) { /* Constraint issue */ }
             PrintFormat("Warning: Period constraints difficult to meet. Adjusted to Short=%d, Long=%d", m_short_period, m_long_period);
         }

        }
     }
     // Also ensure short isn't pushed above long (can happen if setter is called directly)
      if(m_short_period >= m_long_period) {
          m_short_period = m_long_period - m_period_diff_min;
           if (m_short_period < m_min_period) {
               m_short_period = m_min_period;
               m_long_period = m_short_period + m_period_diff_min; // Reset long based on new short
               if(m_long_period > m_max_period) m_long_period = m_max_period; // Cap long
           }
      }

      // Final clamp
      m_short_period = MathMax(m_min_period, MathMin(m_max_period, m_short_period));
      m_long_period = MathMax(m_min_period, MathMin(m_max_period, m_long_period));

  }
//+------------------------------------------------------------------+
//| Mutate the chromosome's genes                                    |
//+------------------------------------------------------------------+
void CChromosome::Mutate(double mutation_rate)
  {
   if(MathRand() / 32767.0 < mutation_rate)
     {
      // Mutate short period (e.g., +/- a small percentage or fixed amount)
      int change = (int)(MathMax(1.0, m_short_period * 0.1) * (MathRand() / 32767.0 * 2.0 - 1.0)); // +/- 10% (at least 1)
      SetShortPeriod(m_short_period + change);
      // Ensure validity after mutation
      ValidatePeriods();
     }

   if(MathRand() / 32767.0 < mutation_rate)
     {
      // Mutate long period
      int change = (int)(MathMax(1.0, m_long_period * 0.1) * (MathRand() / 32767.0 * 2.0 - 1.0)); // +/- 10% (at least 1)
      SetLongPeriod(m_long_period + change);
      // Ensure validity after mutation
      ValidatePeriods();
     }
  }
//+------------------------------------------------------------------+
//| Copy data from another chromosome                                |
//+------------------------------------------------------------------+
void CChromosome::Copy(CChromosome *source)
  {
   if(CheckPointer(source) == POINTER_INVALID)
      return;

   m_short_period = source.GetShortPeriod();
   m_long_period = source.GetLongPeriod();
   m_fitness = source.GetFitness();
   m_min_period = source.m_min_period; // Copy constraints too
   m_max_period = source.m_max_period;
   m_period_diff_min = source.m_period_diff_min;
  }
//+------------------------------------------------------------------+