//+------------------------------------------------------------------+
//|                                                       Enums.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+

// Define enum for signal types
enum ENUM_SIGNAL_TYPE {
   SIGNAL_TYPE_BREAKOUT = 0,    // Trade only breakout signals
   SIGNAL_TYPE_TOUCH = 1,       // Trade only touch signals
   SIGNAL_TYPE_BOTH = 2         // Trade both signal types
};

// Add a function to verify enum values are valid
bool IsValidSignalType(ENUM_SIGNAL_TYPE type) {
   return type >= SIGNAL_TYPE_BREAKOUT && type <= SIGNAL_TYPE_BOTH;
}

// Add string representation for signal type
string SignalTypeToString(ENUM_SIGNAL_TYPE type) {
   switch(type) {
      case SIGNAL_TYPE_BREAKOUT: return "Breakout";
      case SIGNAL_TYPE_TOUCH: return "Touch";
      case SIGNAL_TYPE_BOTH: return "Both";
      default: return "Unknown";
   }
}

// Structure to hold signal information
struct SignalInfo {
   bool hasSignal;              // Whether a signal exists
   bool isBuySignal;            // True for buy, false for sell
   string signalType;           // Description of the signal type
   
   // Constructor
   SignalInfo(bool has = false, bool buy = false, string type = "") {
      hasSignal = has;
      isBuySignal = buy;
      signalType = type;
   }
};
