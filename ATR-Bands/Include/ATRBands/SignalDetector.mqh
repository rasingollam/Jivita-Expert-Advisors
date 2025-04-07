//+------------------------------------------------------------------+
//|                                              SignalDetector.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "Settings.mqh"
#include "ATRIndicator.mqh"

//+------------------------------------------------------------------+
//| Class to detect trading signals                                  |
//+------------------------------------------------------------------+
class SignalDetector
{
private:
    EASettings* m_settings;
    ATRIndicator* m_atrIndicator;
    
    // Signal processing tracking
    datetime m_lastSignalTime;
    SignalInfo m_currentSignal;
    bool m_lastSignalProcessed;
    
    // Improved signal arrow creation for better visibility
    void CreateSignalArrow(int i, string signalType, bool isBuy, double price, color arrowColor) {
        if (m_settings.isOptimization) return;
        
        string signal_name = "ATRSignal_" + signalType + (isBuy ? "Buy_" : "Sell_") + IntegerToString(i);
        ENUM_OBJECT arrowCode = isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
        
        // Adjust signal position for better visibility
        double arrowPrice = price;
        double vertOffset = 15 * _Point;  // Increased offset for better visibility
        
        // Place arrow with more spacing from price
        if(isBuy) {
            arrowPrice = price - vertOffset; // Buy below the price
        } else {
            arrowPrice = price + vertOffset; // Sell above the price
        }
        
        if (ObjectCreate(0, signal_name, arrowCode, 0, m_atrIndicator.GetTime(i), arrowPrice)) {
            ObjectSetInteger(0, signal_name, OBJPROP_COLOR, arrowColor);
            ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, 3); // Larger size for better visibility
            ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
            
            // Add a text label for extra clarity
            string label_name = "ATRSignal_Label_" + IntegerToString(i);
            if (ObjectCreate(0, label_name, OBJ_TEXT, 0, m_atrIndicator.GetTime(i), arrowPrice + (isBuy ? -vertOffset : vertOffset))) {
                ObjectSetString(0, label_name, OBJPROP_TEXT, isBuy ? "TOUCH BUY" : "TOUCH SELL");
                ObjectSetInteger(0, label_name, OBJPROP_COLOR, arrowColor);
                ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
            }
        }
    }
    
    // Delete existing signal objects
    void DeleteSignalObjects() {
        if (!m_settings.isOptimization) {
            ObjectsDeleteAll(0, "ATRSignal_");
        }
    }
    
public:
    // Constructor with renamed parameters to avoid shadowing
    SignalDetector(EASettings* p_settings, ATRIndicator* p_atrIndicator) {
        m_settings = p_settings;
        m_atrIndicator = p_atrIndicator;
        m_lastSignalTime = 0;
        m_lastSignalProcessed = false;
        m_currentSignal = SignalInfo();
    }
    
    // Clear the signal state
    void ResetSignal() {
        m_currentSignal = SignalInfo();
    }
    
    // Get the current signal information
    SignalInfo GetCurrentSignal() const {
        return m_currentSignal;
    }
    
    // Detect trading signals based on ATR bands - touch signals only
    SignalInfo DetectSignals(int barsToProcess = 5) {
        // Reset the current signal
        ResetSignal();
        
        // Add diagnostic info
        static datetime lastDetectionLog = 0;
        bool shouldLog = TimeCurrent() - lastDetectionLog > 300; // Log every 5 minutes
        
        if(shouldLog) {
            Print("Signal detection running at ", TimeToString(TimeCurrent()));
            lastDetectionLog = TimeCurrent();
        }
        
        // Limit bars to process in backtesting to avoid issues
        barsToProcess = MathMin(barsToProcess, 50);
        
        // Delete previous signal objects
        DeleteSignalObjects();
        
        // Check if it's time to reset signal processing status
        datetime current_time = iTime(_Symbol, _Period, 0);
        if (current_time != m_lastSignalTime) {
            m_lastSignalProcessed = false;
            m_lastSignalTime = current_time;
        }
        
        // If the last signal was already processed, don't generate a new one
        if (m_lastSignalProcessed) {
            return m_currentSignal;
        }
        
        // Check if ATR multiplier is zero - in this case, no signals can be generated
        if(m_settings.atrMultiplier == 0) {
            if(m_settings.testMode) {
                Print("ATR Multiplier is zero - no signals will be generated");
            }
            return m_currentSignal;
        }
        
        // Process bars to detect signals - TOUCH SIGNALS ONLY
        // We need at least 2 bars to properly calculate signals
        if(barsToProcess < 2) {
            Print("Warning: Not enough bars to process for signals");
            return m_currentSignal;
        }
        
        for (int i = 1; i < barsToProcess-1 && !IsStopped(); i++) {
            // Get values for the PREVIOUS bar (i+1) - this is the correct approach
            double prev_atr = m_atrIndicator.GetATR(i+1);  // ATR of previous bar
            double prev_close = m_atrIndicator.GetClose(i+1);  // Close of previous bar
            
            // Current candle data (i)
            double candle_close = m_atrIndicator.GetClose(i);
            double candle_high = m_atrIndicator.GetHigh(i);
            double candle_low = m_atrIndicator.GetLow(i);
            
            // Calculate band values using PREVIOUS bar's data
            double upper_band = prev_close + (prev_atr * m_settings.atrMultiplier);
            double lower_band = prev_close - (prev_atr * m_settings.atrMultiplier);
            
            // Debug output to verify calculation
            if(i == 1) {
                Print("SIGNAL DETECTION - Bar ", i);
                Print("Previous bar [", i+1, "] - ATR: ", prev_atr, ", Close: ", prev_close);
                Print("Current bar [", i, "] - High: ", candle_high, ", Low: ", candle_low, ", Close: ", candle_close);
                Print("Calculated bands - Upper: ", upper_band, ", Lower: ", lower_band);
            }
            
            // Check for sell touch signals - high touches upper band but close below it
            if (candle_high >= upper_band && candle_close < upper_band) {
                // Create visual signal - sell on touch of upper band
                if(!m_settings.isOptimization) {
                    CreateSignalArrow(i, "Touch", false, candle_high, m_settings.sellTouchColor);
                }
                
                // Set trading signal if this is the most recent completed bar
                if (i == 1 && !m_lastSignalProcessed) {
                    m_currentSignal = SignalInfo(true, false, "Touch Sell");
                    m_lastSignalProcessed = true;
                    
                    Print("Touch Sell signal detected at bar ", i, 
                          " - High: ", candle_high, 
                          " touched upper band: ", upper_band);
                }
            }
            
            // Check for buy touch signals - low touches lower band but close above it
            if (candle_low <= lower_band && candle_close > lower_band) {
                // Create visual signal - buy on touch of lower band
                if(!m_settings.isOptimization) {
                    CreateSignalArrow(i, "Touch", true, candle_low, m_settings.buyTouchColor);
                }
                
                // Set trading signal if this is the most recent completed bar
                if (i == 1 && !m_lastSignalProcessed) {
                    m_currentSignal = SignalInfo(true, true, "Touch Buy");
                    m_lastSignalProcessed = true;
                    
                    Print("Touch Buy signal detected at bar ", i, 
                          " - Low: ", candle_low, 
                          " touched lower band: ", lower_band);
                }
            }
        }
        
        // Add signal detection logging
        if(m_currentSignal.hasSignal) {
            Print("Signal detected: ", m_currentSignal.signalType, 
                  ", Direction: ", (m_currentSignal.isBuySignal ? "BUY" : "SELL"));
        } else if(shouldLog) {
            Print("No trading signal detected");
        }
        
        return m_currentSignal;
    }
};
