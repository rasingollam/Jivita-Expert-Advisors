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
    
    // Draw ATR bands on chart - simplified to draw horizontal lines for last candle's ATR
    void DrawBands(int count) {
        if (m_settings.isOptimization) return;
        
        // Delete previous bands before drawing new ones
        DeleteBandObjects();
        
        // Ensure we have enough data
        if(count < 3) {
            Print("Warning: Not enough data to draw ATR bands - need at least 3 bars");
            return;
        }
        
        // Get values from the last completed bar (index 1)
        double prev_atr = m_atrValues[1];      // ATR of the last completed candle
        double prev_close = m_closeValues[1];  // Close of the last completed candle
        
        // Store current ATR values for panel display - handle special case when multiplier is 0
        m_currentATR = prev_atr;
        
        // Check if ATR multiplier is zero - in this case, bands will be at the closing price
        if(m_settings.atrMultiplier == 0) {
            m_currentUpperBand = prev_close;
            m_currentLowerBand = prev_close;
            
            Print("ATR Multiplier is zero - bands set to closing price: ", DoubleToString(prev_close, 5));
            
            // If multiplier is zero, don't draw any bands
            return;
        } else {
            m_currentUpperBand = prev_close + (prev_atr * m_settings.atrMultiplier);
            m_currentLowerBand = prev_close - (prev_atr * m_settings.atrMultiplier);
        }
        
        // Log band calculation
        Print("BANDS: Using last completed bar values - ATR: ", DoubleToString(m_currentATR, 5), 
              ", Close: ", DoubleToString(prev_close, 5),
              ", Upper: ", DoubleToString(m_currentUpperBand, 5),
              ", Lower: ", DoubleToString(m_currentLowerBand, 5));
        
        // Draw horizontal lines with limited length, from bar 2 to next 2 bars
        
        // Get time values for line start and end - limited to just 4 bars total
        datetime startTime = m_timeValues[2];  // 2 bars back
        
        // Calculate end time - exactly 2 bars forward from current bar
        int barPeriod = PeriodSeconds(_Period);
        datetime endTime = m_timeValues[0] + (barPeriod * 2);  // 2 bars ahead of current bar
        
        // Create upper band horizontal line
        string upper_name = "ATRBand_Upper_H";
        if(!ObjectCreate(0, upper_name, OBJ_TREND, 0, startTime, m_currentUpperBand, endTime, m_currentUpperBand)) {
            Print("Failed to create upper band line: ", GetLastError());
        } else {
            // Set upper band line properties - dotted style
            ObjectSetInteger(0, upper_name, OBJPROP_COLOR, m_settings.upperBandColor);
            ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_DOT);  // Changed to dotted
            ObjectSetInteger(0, upper_name, OBJPROP_WIDTH, m_settings.lineWidth);
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_RIGHT, false); // Not extended to right
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_LEFT, false);
        }
        
        // Create lower band horizontal line
        string lower_name = "ATRBand_Lower_H";
        if(!ObjectCreate(0, lower_name, OBJ_TREND, 0, startTime, m_currentLowerBand, endTime, m_currentLowerBand)) {
            Print("Failed to create lower band line: ", GetLastError());
        } else {
            // Set lower band line properties - dotted style
            ObjectSetInteger(0, lower_name, OBJPROP_COLOR, m_settings.lowerBandColor);
            ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_DOT);  // Changed to dotted
            ObjectSetInteger(0, lower_name, OBJPROP_WIDTH, m_settings.lineWidth);
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_RIGHT, false); // Not extended to right
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_LEFT, false);
        }
        
        // Display ATR value as a label
        string atr_label = "ATRBand_Value";
        string atr_text = "ATR(" + IntegerToString(m_settings.atrPeriod) + "): " + 
                         DoubleToString(m_atrValues[1], _Digits) + 
                         "  |  Upper: " + DoubleToString(m_currentUpperBand, _Digits) +
                         "  |  Lower: " + DoubleToString(m_currentLowerBand, _Digits);
        
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
