//+------------------------------------------------------------------+
//|                                          OptimizationHelper.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper class to diagnose optimization issues                     |
//+------------------------------------------------------------------+
class OptimizationHelper
{
private:
    bool m_isOptimization;
    int m_signalCount;
    int m_tradeCount;
    string m_symbol;
    
public:
    // Constructor
    OptimizationHelper(string symbol) {
        m_isOptimization = MQLInfoInteger(MQL_OPTIMIZATION);
        m_signalCount = 0;
        m_tradeCount = 0;
        m_symbol = symbol;
        
        // Create a marker file only during optimization
        if(m_isOptimization) {
            string filename = "ATR_Bands_Optimization_Check.txt";
            int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT);
            if(fileHandle != INVALID_HANDLE) {
                FileWrite(fileHandle, "Optimization started on " + TimeToString(TimeCurrent()));
                FileWrite(fileHandle, "Symbol: " + m_symbol);
                FileClose(fileHandle);
            }
        }
    }
    
    // Log a signal detection for debugging
    void LogSignalDetected(string signalType, bool isBuySignal) {
        if(!m_isOptimization) return;
        
        m_signalCount++;
        
        string filename = "ATR_Bands_Signals.txt";
        int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT);
        if(fileHandle != INVALID_HANDLE) {
            FileWrite(fileHandle, "Signal #" + IntegerToString(m_signalCount) + 
                     " detected at " + TimeToString(TimeCurrent()) +
                     ": " + signalType + " - " + (isBuySignal ? "BUY" : "SELL"));
            FileClose(fileHandle);
        }
    }
    
    // Log a trade execution for debugging
    void LogTradeExecuted(string signalType, bool isBuyOrder) {
        if(!m_isOptimization) return;
        
        m_tradeCount++;
        
        string filename = "ATR_Bands_Trades.txt";
        int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT);
        if(fileHandle != INVALID_HANDLE) {
            FileWrite(fileHandle, "Trade #" + IntegerToString(m_tradeCount) + 
                     " executed at " + TimeToString(TimeCurrent()) +
                     ": " + signalType + " - " + (isBuyOrder ? "BUY" : "SELL"));
            FileClose(fileHandle);
        }
    }
};
