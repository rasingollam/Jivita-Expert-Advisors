//+------------------------------------------------------------------+
//|                                                       Enums.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+

// Simplified enum - removed breakout and both options, keeping only touch signals
enum ENUM_SIGNAL_TYPE {
   SIGNAL_TYPE_TOUCH = 0       // Trade only touch signals
};

// Simple validation function - always returns true now since we only have one option
bool IsValidSignalType(ENUM_SIGNAL_TYPE type) {
   return type == SIGNAL_TYPE_TOUCH;
}

// Add string representation for signal type - simplified
string SignalTypeToString(ENUM_SIGNAL_TYPE type) {
   return "Touch";
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
