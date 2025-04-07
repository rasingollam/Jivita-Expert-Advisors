//+------------------------------------------------------------------+
//|                                               ATRIndicator.mqh   |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Class to handle ATR indicator calculations                       |
//+------------------------------------------------------------------+
class ATRIndicator
{
private:
    EASettings* m_settings;
    int m_atrHandle;
    
    // Store current ATR values
    double m_currentATR;
    double m_currentUpperBand;
    double m_currentLowerBand;
    
    // Store indicator history
    double m_atrValues[];
    double m_closeValues[];
    double m_highValues[];
    double m_lowValues[];
    datetime m_timeValues[];
    
    // Delete existing band objects
    void DeleteBandObjects() {
        if (!m_settings.isOptimization) {
            ObjectsDeleteAll(0, "ATRBand_");
        }
    }
    
    // Draw ATR bands on chart - matched exactly to reference implementation
    void DrawBands(int count) {
        if (m_settings.isOptimization) return;
        
        // Delete previous bands before drawing new ones
        DeleteBandObjects();
        
        // Iterate through points to draw band segments - matching reference implementation
        for (int i = 0; i < count-2 && !IsStopped(); i++) {
            // For each position, use the ATR and close from previous candle
            double prev_atr1 = m_atrValues[i+1];
            double prev_close1 = m_closeValues[i+1];
            double prev_atr2 = m_atrValues[i+2];
            double prev_close2 = m_closeValues[i+2];
            
            // Store values for most recent bar - exactly like reference
            if (i == 0) {
                m_currentATR = prev_atr1;
                m_currentUpperBand = prev_close1 + (prev_atr1 * m_settings.atrMultiplier);
                m_currentLowerBand = prev_close1 - (prev_atr1 * m_settings.atrMultiplier);
                
                if(m_settings.testMode) {
                    Print("Current bar ATR = ", DoubleToString(m_currentATR, 5), 
                          ", Upper = ", DoubleToString(m_currentUpperBand, 5),
                          ", Lower = ", DoubleToString(m_currentLowerBand, 5));
                }
            }
            
            // Calculate band values for current and next point - exact match to reference
            double upper_band1 = prev_close1 + (prev_atr1 * m_settings.atrMultiplier);
            double lower_band1 = prev_close1 - (prev_atr1 * m_settings.atrMultiplier);
            double upper_band2 = prev_close2 + (prev_atr2 * m_settings.atrMultiplier);
            double lower_band2 = prev_close2 - (prev_atr2 * m_settings.atrMultiplier);
            
            // Create upper band segment - exactly like reference
            string upper_name = "ATRBand_Upper_" + IntegerToString(i);
            if (!ObjectCreate(0, upper_name, OBJ_TREND, 0, m_timeValues[i+1], upper_band1, m_timeValues[i+2], upper_band2)) {
                Print("Failed to create upper band line: ", GetLastError());
                continue;
            }
            
            // Set upper band line properties - exactly like reference
            ObjectSetInteger(0, upper_name, OBJPROP_COLOR, m_settings.upperBandColor);
            ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, upper_name, OBJPROP_WIDTH, m_settings.lineWidth);
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_LEFT, false);
            
            // Create lower band segment - exactly like reference
            string lower_name = "ATRBand_Lower_" + IntegerToString(i);
            if (!ObjectCreate(0, lower_name, OBJ_TREND, 0, m_timeValues[i+1], lower_band1, m_timeValues[i+2], lower_band2)) {
                Print("Failed to create lower band line: ", GetLastError());
                continue;
            }
            
            // Set lower band line properties - exactly like reference
            ObjectSetInteger(0, lower_name, OBJPROP_COLOR, m_settings.lowerBandColor);
            ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lower_name, OBJPROP_WIDTH, m_settings.lineWidth);
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_LEFT, false);
        }
        
        // Display ATR value as a label - exact match to reference
        string atr_label = "ATRBand_Value";
        string atr_text = "ATR(" + IntegerToString(m_settings.atrPeriod) + "): " + 
                         DoubleToString(m_atrValues[1], _Digits);
        
        if (ObjectFind(0, atr_label) < 0) {
            // Create new label
            ObjectCreate(0, atr_label, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, atr_label, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, atr_label, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, atr_label, OBJPROP_YDISTANCE, 10);
        }
        
        // Update label text
        ObjectSetString(0, atr_label, OBJPROP_TEXT, atr_text);
        ObjectSetInteger(0, atr_label, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, atr_label, OBJPROP_FONTSIZE, 10);
        
        // Force chart redraw
        ChartRedraw();
    }
    
public:
    // Constructor
    ATRIndicator() {
        m_settings = NULL;
        m_atrHandle = INVALID_HANDLE;
        m_currentATR = 0;
        m_currentUpperBand = 0;
        m_currentLowerBand = 0;
    }
    
    // Destructor
    ~ATRIndicator() {
        if (m_atrHandle != INVALID_HANDLE) {
            IndicatorRelease(m_atrHandle);
            m_atrHandle = INVALID_HANDLE;
        }
    }
    
    // Initialize the indicator with improved error handling
    bool Initialize(EASettings* p_settings) {
        if (p_settings == NULL) {
            Print("ATR indicator initialization failed: Settings pointer is NULL");
            return false;
        }
        
        m_settings = p_settings;
        
        // Create ATR indicator handle with error reporting
        Print("Creating ATR indicator with period: ", m_settings.atrPeriod);
        
        // Ensure period is valid
        if(m_settings.atrPeriod <= 0) {
            Print("ATR period must be > 0, got: ", m_settings.atrPeriod);
            return false;
        }
        
        // Create handle with error handling
        m_atrHandle = iATR(_Symbol, _Period, m_settings.atrPeriod);
        if (m_atrHandle == INVALID_HANDLE) {
            int errorCode = GetLastError();
            Print("Failed to create ATR indicator handle. Error code: ", errorCode, 
                  " (", ErrorDescription(errorCode), ")");
            return false;
        }
        
        // Initialize arrays
        ArraySetAsSeries(m_atrValues, true);
        ArraySetAsSeries(m_closeValues, true);
        ArraySetAsSeries(m_highValues, true);
        ArraySetAsSeries(m_lowValues, true);
        ArraySetAsSeries(m_timeValues, true);
        
        Print("ATR indicator initialized successfully");
        return true;
    }
    
    // Add error description helper
    string ErrorDescription(int errorCode) {
        switch(errorCode) {
            case 4301: return "Invalid parameter";
            case 4302: return "Invalid indicator handle";
            case 4303: return "Wrong indicator buffer";
            case 4304: return "Indicator buffers exceed limit";
            default: return "Unknown error";
        }
    }
    
    // Calculate ATR bands and update values - aligned with reference implementation
    bool Calculate(int barsCount = 5) {
        // Ensure handle is valid
        if (m_atrHandle == INVALID_HANDLE) {
            Print("ATR calculation failed: Invalid indicator handle");
            // Attempt to recover by reinitializing
            m_atrHandle = iATR(_Symbol, _Period, m_settings.atrPeriod);
            if (m_atrHandle == INVALID_HANDLE) {
                Print("Failed to reinitialize ATR indicator");
                return false;
            }
            Print("Successfully reinitialized ATR indicator");
        }
        
        // Use conservative data count for testing - like reference EA
        int dataCount = MathMin(barsCount + 2, 100);
        
        // Resize arrays more efficiently
        if (ArraySize(m_atrValues) < dataCount) ArrayResize(m_atrValues, dataCount);
        if (ArraySize(m_closeValues) < dataCount) ArrayResize(m_closeValues, dataCount);
        if (ArraySize(m_highValues) < dataCount) ArrayResize(m_highValues, dataCount);
        if (ArraySize(m_lowValues) < dataCount) ArrayResize(m_lowValues, dataCount);
        if (ArraySize(m_timeValues) < dataCount) ArrayResize(m_timeValues, dataCount);
        
        // Copy indicator data with error checking - exactly like reference
        int copied = CopyBuffer(m_atrHandle, 0, 0, dataCount, m_atrValues);
        if (copied <= 0) {
            Print("Failed to copy ATR values: ", GetLastError());
            return false;
        }
        
        // Combine all copy operations with single error check - like reference
        if(CopyClose(_Symbol, _Period, 0, dataCount, m_closeValues) <= 0) {
            Print("Failed to copy close prices: ", GetLastError());
            return false;
        }
        
        if(CopyHigh(_Symbol, _Period, 0, dataCount, m_highValues) <= 0) {
            Print("Failed to copy high prices: ", GetLastError());
            return false;
        }
        
        if(CopyLow(_Symbol, _Period, 0, dataCount, m_lowValues) <= 0) {
            Print("Failed to copy low prices: ", GetLastError());
            return false;
        }
        
        if(CopyTime(_Symbol, _Period, 0, dataCount, m_timeValues) <= 0) {
            Print("Failed to copy time values: ", GetLastError());
            return false;
        }
        
        // Add safety checks for array access
        if(ArraySize(m_atrValues) <= 1 || ArraySize(m_closeValues) <= 1) {
            Print("Warning: Insufficient data available - ATR array size: ", 
                 ArraySize(m_atrValues), ", Close array size: ", ArraySize(m_closeValues));
            return false;
        }
        
        // Draw bands on the chart if not in optimization mode - like reference
        if (!m_settings.isOptimization) {
            DrawBands(dataCount);
        }
        
        if(m_settings.testMode) {
            Print("ATR calculation complete - Current ATR: ", DoubleToString(m_currentATR, 5));
        }
        
        return true;
    }
    
    // Get current ATR value
    double GetCurrentATR() const {
        return m_currentATR;
    }
    
    // Get current upper band value
    double GetUpperBand() const {
        return m_currentUpperBand;
    }
    
    // Get lower band value
    double GetLowerBand() const {
        return m_currentLowerBand;
    }
    
    // Get ATR value at index
    double GetATR(int index) const {
        if (index >= 0 && index < ArraySize(m_atrValues))
            return m_atrValues[index];
        return 0;
    }
    
    // Get closing price at index
    double GetClose(int index) const {
        if (index >= 0 && index < ArraySize(m_closeValues))
            return m_closeValues[index];
        return 0;
    }
    
    // Get high price at index
    double GetHigh(int index) const {
        if (index >= 0 && index < ArraySize(m_highValues))
            return m_highValues[index];
        return 0;
    }
    
    // Get low price at index
    double GetLow(int index) const {
        if (index >= 0 && index < ArraySize(m_lowValues))
            return m_lowValues[index];
        return 0;
    }
    
    // Get time at index
    datetime GetTime(int index) const {
        if (index >= 0 && index < ArraySize(m_timeValues))
            return m_timeValues[index];
        return 0;
    }
};
