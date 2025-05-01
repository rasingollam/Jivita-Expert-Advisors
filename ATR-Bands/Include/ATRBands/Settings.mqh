//+------------------------------------------------------------------+
//|                                                    Settings.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Class to store EA settings                                       |
//+------------------------------------------------------------------+
class EASettings
{
public:
    // ATR indicator settings
    int atrPeriod;
    double atrMultiplier;
    ENUM_APPLIED_PRICE price;
    color upperBandColor;
    color lowerBandColor;
    int lineWidth;
    
    // Signal settings
    ENUM_SIGNAL_TYPE signalType;
    int signalSize;
    color crossColor;
    color reversalColor;
    color buyTouchColor;
    color sellTouchColor;
    
    // Trading settings
    bool tradingEnabled;
    double riskRewardRatio;
    double riskPercentage;
    int stopLossPips;
    bool useAtrStopLoss;        // Whether to use ATR-based stop loss
    double atrStopLossMultiplier; // ATR multiplier for stop loss
    bool useEmaTrailingStop;       // Whether to use EMA-based trailing stop
    int emaTrailingPeriod;         // EMA period for trailing stop
    bool useTakeProfit;
    int magicNumber;
    
    // Trading schedule settings
    bool allowMonday;
    bool allowTuesday;
    bool allowWednesday;
    bool allowThursday;
    bool allowFriday;
    bool allowSaturday;
    bool allowSunday;
    
    // Target profit and stop loss settings
    double targetProfitPercent;
    double stopLossPercent;
    bool targetReached;
    bool stopLossReached;
    
    // Optimization and testing flags
    bool isOptimization;
    bool testMode;
    
    // Start time for history tracking
    datetime startTime;
    
    // Constructor
    EASettings() {
        // Set default values
        atrPeriod = 14;
        atrMultiplier = 1.0;
        price = PRICE_CLOSE;
        upperBandColor = clrRed;
        lowerBandColor = clrBlue;
        lineWidth = 1;
        
        signalType = SIGNAL_TYPE_TOUCH;
        signalSize = 3;
        crossColor = clrYellow;
        reversalColor = clrMagenta;
        buyTouchColor = clrLime;
        sellTouchColor = clrRed;
        
        tradingEnabled = true;
        riskRewardRatio = 1.5;
        riskPercentage = 1.0;
        stopLossPips = 10;
        useAtrStopLoss = false;         // Default to fixed pips stop loss
        atrStopLossMultiplier = 1.0;    // Default multiplier of 1.0
        useEmaTrailingStop = false;     // Default to not using EMA trailing stop
        emaTrailingPeriod = 14;         // Default EMA period
        useTakeProfit = true;
        magicNumber = 12345;
        
        allowMonday = true;
        allowTuesday = true;
        allowWednesday = true;
        allowThursday = true;
        allowFriday = true;
        allowSaturday = true;
        allowSunday = true;
        
        targetProfitPercent = 0.0;
        stopLossPercent = 0.0;
        targetReached = false;
        stopLossReached = false;
        
        isOptimization = false;
        testMode = false;
        
        startTime = TimeCurrent();
    }
    
    // Initialize with user settings
    bool Initialize(
        int p_atrPeriod,
        double p_atrMultiplier,
        ENUM_APPLIED_PRICE p_price,
        color p_upperBandColor,
        color p_lowerBandColor,
        int p_lineWidth,
        ENUM_SIGNAL_TYPE p_signalType,
        int p_signalSize,
        color p_crossColor,
        color p_reversalColor,
        color p_buyTouchColor,
        color p_sellTouchColor,
        bool p_tradingEnabled,
        double p_riskRewardRatio,
        double p_riskPercentage,
        int p_stopLossPips,
        bool p_useAtrStopLoss,           // New parameter
        double p_atrStopLossMultiplier,  // New parameter
        bool p_useEmaTrailingStop,       // New parameter
        int p_emaTrailingPeriod,         // New parameter
        bool p_useTakeProfit,
        int p_magicNumber,
        bool p_allowMonday,
        bool p_allowTuesday,
        bool p_allowWednesday,
        bool p_allowThursday,
        bool p_allowFriday,
        bool p_allowSaturday,
        bool p_allowSunday,
        double p_targetProfitPercent,
        double p_stopLossPercent,
        bool p_isOptimization,
        bool p_testMode
    ) {
        // Validate inputs
        if (p_atrPeriod <= 0) {
            Print("ATR period must be positive");
            return false;
        }
        
        if (p_atrMultiplier <= 0) {
            Print("ATR multiplier must be positive");
            return false;
        }
        
        if (p_lineWidth <= 0) {
            Print("Line width must be positive");
            return false;
        }
        
        if (p_signalSize <= 0) {
            Print("Signal size must be positive");
            return false;
        }
        
        if (p_riskRewardRatio <= 0) {
            Print("Risk reward ratio must be positive");
            return false;
        }
        
        if (p_riskPercentage <= 0) {
            Print("Risk percentage must be positive");
            return false;
        }
        
        if (p_stopLossPips <= 0) {
            Print("Stop loss pips must be positive");
            return false;
        }
        
        if (p_atrStopLossMultiplier <= 0) {
            Print("ATR stop loss multiplier must be positive");
            return false;
        }
        
        if (p_emaTrailingPeriod <= 0) {
            Print("EMA trailing period must be positive");
            return false;
        }
        
        if (p_magicNumber <= 0) {
            Print("Magic number must be positive");
            return false;
        }
        
        if (p_targetProfitPercent < 0) {
            Print("Target profit percent must be non-negative");
            return false;
        }
        
        if (p_stopLossPercent < 0) {
            Print("Stop loss percent must be non-negative");
            return false;
        }
        
        // Apply values
        atrPeriod = p_atrPeriod;
        atrMultiplier = p_atrMultiplier;
        price = p_price;
        upperBandColor = p_upperBandColor;
        lowerBandColor = p_lowerBandColor;
        lineWidth = p_lineWidth;
        
        signalType = p_signalType;
        signalSize = p_signalSize;
        crossColor = p_crossColor;
        reversalColor = p_reversalColor;
        buyTouchColor = p_buyTouchColor;
        sellTouchColor = p_sellTouchColor;
        
        tradingEnabled = p_tradingEnabled;
        riskRewardRatio = p_riskRewardRatio;
        riskPercentage = p_riskPercentage;
        stopLossPips = p_stopLossPips;
        useAtrStopLoss = p_useAtrStopLoss;
        atrStopLossMultiplier = p_atrStopLossMultiplier;
        useEmaTrailingStop = p_useEmaTrailingStop;
        emaTrailingPeriod = p_emaTrailingPeriod;
        useTakeProfit = p_useTakeProfit;
        magicNumber = p_magicNumber;
        
        // Apply trading schedule settings
        allowMonday = p_allowMonday;
        allowTuesday = p_allowTuesday;
        allowWednesday = p_allowWednesday;
        allowThursday = p_allowThursday;
        allowFriday = p_allowFriday;
        allowSaturday = p_allowSaturday;
        allowSunday = p_allowSunday;
        
        targetProfitPercent = p_targetProfitPercent;
        stopLossPercent = p_stopLossPercent;
        targetReached = false;
        stopLossReached = false;
        
        isOptimization = p_isOptimization;
        testMode = p_testMode;
        
        startTime = TimeCurrent();
        
        return true;
    }
    
    // Helper to convert pips to points
    double PipsToPoints(int pips) {
        return pips * 10 * _Point;
    }
    
    // Get start time for history tracking
    datetime GetStartTime() const {
        return startTime;
    }
    
    // Helper function to check if trading is allowed on the current day
    bool IsTradingAllowedToday() const {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int dayOfWeek = dt.day_of_week;
        
        // Check if trading is allowed for this day
        switch(dayOfWeek) {
            case 0: return allowSunday;
            case 1: return allowMonday;
            case 2: return allowTuesday;
            case 3: return allowWednesday;
            case 4: return allowThursday;
            case 5: return allowFriday;
            case 6: return allowSaturday;
            default: return false;
        }
    }
    
    // Get the description of the day of week
    string GetDayOfWeekDescription(int dayOfWeek) const {
        switch(dayOfWeek) {
            case 0: return "Sunday";
            case 1: return "Monday";
            case 2: return "Tuesday";
            case 3: return "Wednesday";
            case 4: return "Thursday";
            case 5: return "Friday";
            case 6: return "Saturday";
            default: return "Unknown Day";
        }
    }
};
