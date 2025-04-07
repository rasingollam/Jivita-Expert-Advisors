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
    
    // Create visual signal on chart - matched to reference implementation
    void CreateSignalArrow(int i, string signalType, bool isBuy, double price, color arrowColor) {
        if (m_settings.isOptimization) return;
        
        string signal_name = "ATRSignal_" + signalType + (isBuy ? "Buy_" : "Sell_") + IntegerToString(i);
        ENUM_OBJECT arrowCode = isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
        
        // Create arrow object at exact time and price - like reference
        if (!ObjectCreate(0, signal_name, arrowCode, 0, m_atrIndicator.GetTime(i), price)) {
            Print("Failed to create signal arrow: ", GetLastError());
            return;
        }
        
        // Set arrow properties - exactly like reference
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, m_settings.signalSize);
        ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, isBuy ? ANCHOR_BOTTOM : ANCHOR_TOP);
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
        
        if(shouldLog || m_settings.testMode) {
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
            if(m_settings.testMode) Print("New bar detected, resetting signal processing state");
        }
        
        // If the last signal was already processed, don't generate a new one
        if (m_lastSignalProcessed) {
            if(m_settings.testMode) Print("Signal already processed for this bar - skipping");
            return m_currentSignal;
        }
        
        // Process bars to detect signals - only touch signals now
        for (int i = 1; i < barsToProcess-1 && !IsStopped(); i++) {
            // Get values for the bar
            double prev_atr = m_atrIndicator.GetATR(i);
            double prev_close = m_atrIndicator.GetClose(i);
            
            // Current candle data
            double candle_close = m_atrIndicator.GetClose(i);
            double candle_high = m_atrIndicator.GetHigh(i);
            double candle_low = m_atrIndicator.GetLow(i);
            
            // Calculate band values for this bar
            double upper_band = prev_close + (prev_atr * m_settings.atrMultiplier);
            double lower_band = prev_close - (prev_atr * m_settings.atrMultiplier);
            
            if(m_settings.testMode && i == 1) {
                Print("Bar ", i, " - ATR: ", prev_atr, 
                     ", Close: ", prev_close,
                     ", Upper: ", upper_band,
                     ", Lower: ", lower_band);
            }
            
            // TOUCH SIGNALS ONLY - Removed previous checks for SIGNAL_TYPE_BREAKOUT or SIGNAL_TYPE_BOTH
            
            // Check for sell touch signals - high touches upper band but close below it
            if (candle_high >= upper_band && candle_close < upper_band) {
                // Create visual signal - sell on touch of upper band
                if(!m_settings.isOptimization) {
                    CreateSignalArrow(i, "Touch", false, candle_high, m_settings.sellTouchColor);
                }
                
                // Set trading signal if this is the most recent completed bar - always set for TOUCH now
                if (i == 1 && !m_lastSignalProcessed) {
                    m_currentSignal = SignalInfo(true, false, "Touch Sell");
                    m_lastSignalProcessed = true;
                    
                    if(m_settings.testMode) Print("Touch Sell signal detected at bar ", i);
                }
            }
            
            // Check for buy touch signals - low touches lower band but close above it
            if (candle_low <= lower_band && candle_close > lower_band) {
                // Create visual signal - buy on touch of lower band
                if(!m_settings.isOptimization) {
                    CreateSignalArrow(i, "Touch", true, candle_low, m_settings.buyTouchColor);
                }
                
                // Set trading signal if this is the most recent completed bar - always set for TOUCH now
                if (i == 1 && !m_lastSignalProcessed) {
                    m_currentSignal = SignalInfo(true, true, "Touch Buy");
                    m_lastSignalProcessed = true;
                    
                    if(m_settings.testMode) Print("Touch Buy signal detected at bar ", i);
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
