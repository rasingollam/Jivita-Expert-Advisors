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
    
    // Draw ATR bands on chart
    void DrawBands(int count) {
        if (m_settings.isOptimization) return;
        
        // Iterate through points to draw band segments
        for (int i = 0; i < count-2 && !IsStopped(); i++) {
            // Calculate bands for each point
            double prev_atr1 = m_atrValues[i+1];
            double prev_close1 = m_closeValues[i+1];
            double prev_atr2 = m_atrValues[i+2];
            double prev_close2 = m_closeValues[i+2];
            
            double upper_band1 = prev_close1 + (prev_atr1 * m_settings.atrMultiplier);
            double lower_band1 = prev_close1 - (prev_atr1 * m_settings.atrMultiplier);
            double upper_band2 = prev_close2 + (prev_atr2 * m_settings.atrMultiplier);
            double lower_band2 = prev_close2 - (prev_atr2 * m_settings.atrMultiplier);
            
            // Create upper band segment
            string upper_name = "ATRBand_Upper_" + IntegerToString(i);
            if (ObjectCreate(0, upper_name, OBJ_TREND, 0, m_timeValues[i], upper_band1, m_timeValues[i+1], upper_band2)) {
                ObjectSetInteger(0, upper_name, OBJPROP_COLOR, m_settings.upperBandColor);
                ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, upper_name, OBJPROP_WIDTH, m_settings.lineWidth);
                ObjectSetInteger(0, upper_name, OBJPROP_RAY_RIGHT, false);
                ObjectSetInteger(0, upper_name, OBJPROP_RAY_LEFT, false);
            }
            
            // Create lower band segment
            string lower_name = "ATRBand_Lower_" + IntegerToString(i);
            if (ObjectCreate(0, lower_name, OBJ_TREND, 0, m_timeValues[i], lower_band1, m_timeValues[i+1], lower_band2)) {
                ObjectSetInteger(0, lower_name, OBJPROP_COLOR, m_settings.lowerBandColor);
                ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, lower_name, OBJPROP_WIDTH, m_settings.lineWidth);
                ObjectSetInteger(0, lower_name, OBJPROP_RAY_RIGHT, false);
                ObjectSetInteger(0, lower_name, OBJPROP_RAY_LEFT, false);
            }
        }
        
        // Display ATR value as a label
        if (!m_settings.isOptimization) {
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
        }
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
    
    // Calculate ATR bands and update values
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
        
        // Remove previous lines
        DeleteBandObjects();
        
        // Use more conservative data count for testing
        int dataCount = MathMin(barsCount + 1, 100); // Limit to 100 bars to avoid issues
        
        // Resize arrays more efficiently
        if (ArraySize(m_atrValues) < dataCount) ArrayResize(m_atrValues, dataCount);
        if (ArraySize(m_closeValues) < dataCount) ArrayResize(m_closeValues, dataCount);
        if (ArraySize(m_highValues) < dataCount) ArrayResize(m_highValues, dataCount);
        if (ArraySize(m_lowValues) < dataCount) ArrayResize(m_lowValues, dataCount);
        if (ArraySize(m_timeValues) < dataCount) ArrayResize(m_timeValues, dataCount);
        
        // Copy indicator data with error checking
        int copied = CopyBuffer(m_atrHandle, 0, 0, dataCount, m_atrValues);
        if (copied <= 0) {
            Print("Failed to copy ATR values: ", GetLastError());
            return false;
        }
        
        // Combine all copy operations with single error check for efficiency
        bool copySuccess = 
            CopyClose(_Symbol, _Period, 0, dataCount, m_closeValues) > 0 &&
            CopyHigh(_Symbol, _Period, 0, dataCount, m_highValues) > 0 &&
            CopyLow(_Symbol, _Period, 0, dataCount, m_lowValues) > 0 &&
            CopyTime(_Symbol, _Period, 0, dataCount, m_timeValues) > 0;
            
        if (!copySuccess) {
            Print("Failed to copy price data: ", GetLastError());
            return false;
        }
        
        // Add safety checks for array access
        if(ArraySize(m_atrValues) <= 1 || ArraySize(m_closeValues) <= 1) {
            Print("Warning: Insufficient data available - ATR array size: ", 
                 ArraySize(m_atrValues), ", Close array size: ", ArraySize(m_closeValues));
            return false;
        }
        
        // More robust error handling for zero or negative ATR values
        if (m_atrValues[1] <= 0) {
            Print("Warning: Invalid ATR value detected: ", m_atrValues[1], " at bar time: ", 
                  TimeToString(m_timeValues[1]), " - Using minimum value");
            m_atrValues[1] = 0.0001; // Use a minimal non-zero value
        }
        
        // Store current values for the most recent bar (index 1 because index 0 is the current forming bar)
        m_currentATR = m_atrValues[1];
        m_currentUpperBand = m_closeValues[1] + (m_currentATR * m_settings.atrMultiplier);
        m_currentLowerBand = m_closeValues[1] - (m_currentATR * m_settings.atrMultiplier);
        
        // Draw bands on the chart
        if (!m_settings.isOptimization) {
            DrawBands(barsCount);
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
