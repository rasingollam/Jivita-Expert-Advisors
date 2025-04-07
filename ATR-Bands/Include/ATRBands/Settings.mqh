//+------------------------------------------------------------------+
//|                                                    Settings.mqh  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Class to encapsulate all EA settings                             |
//+------------------------------------------------------------------+
class EASettings
{
private:
    // Start time for the EA
    datetime m_startTime;

public:
    // ATR settings
    int atrPeriod;
    double atrMultiplier;
    ENUM_APPLIED_PRICE priceType;
    
    // Visual settings
    color upperBandColor;
    color lowerBandColor;
    int lineWidth;
    color buySignalColor;
    color sellSignalColor;
    color buyTouchColor;
    color sellTouchColor;
    int signalSize;
    
    // Trading settings
    bool enableTrading;
    ENUM_SIGNAL_TYPE signalType;
    double riskRewardRatio;
    double riskPercentage;
    int stopLossPips;
    bool useTakeProfit;
    int magicNumber;
    double targetProfitPercent;
    double stopLossPercent;
    
    // Runtime settings
    bool isOptimization;
    bool tradingEnabled;
    bool targetReached;
    bool stopLossReached;
    bool testMode;         // Add test mode flag
    
    // Constructor
    EASettings() {
        m_startTime = 0;
        tradingEnabled = true;
        targetReached = false;
        stopLossReached = false;
        testMode = false;  // Default to false
    }
    
    // Improved initialization with validation and better error handling
    bool Initialize(int p_atrPeriod, double p_atrMultiplier, ENUM_APPLIED_PRICE p_price,
                    color p_upperColor, color p_lowerColor, int p_lineW,
                    ENUM_SIGNAL_TYPE p_sigType, int p_sigSize, color p_buySigColor, color p_sellSigColor,
                    color p_buyTColor, color p_sellTColor, bool p_enableTrade,
                    double p_rrRatio, double p_riskPct, int p_slPips,
                    bool p_useTP, int p_magic, double p_targetProfit, double p_stopLossPct,
                    bool p_isOptimize, bool p_testMode = false)  // Add test mode parameter
    {
        // Detailed validation with specific error messages and auto-corrections for tester mode
        bool isTester = MQLInfoInteger(MQL_TESTER);
        string errorMsg = "";
        
        // --- Handle ATR Period ---
        if(p_atrPeriod <= 0) {
            if(isTester) {
                p_atrPeriod = 14;  // Default fallback value for tester
                Print("Warning: Invalid ATR period, using default value: ", p_atrPeriod);
            } else {
                errorMsg = StringFormat("Invalid ATR period: %d, must be > 0", p_atrPeriod);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle ATR Multiplier ---
        if(p_atrMultiplier <= 0) {
            if(isTester) {
                p_atrMultiplier = 1.0;  // Default fallback value for tester
                Print("Warning: Invalid ATR multiplier, using default value: ", p_atrMultiplier);
            } else {
                errorMsg = StringFormat("Invalid ATR multiplier: %.2f, must be > 0", p_atrMultiplier);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Signal Size ---
        if(p_sigSize <= 0) {
            if(isTester) {
                p_sigSize = 3;  // Default fallback value for tester
                Print("Warning: Invalid signal size, using default value: ", p_sigSize);
            } else {
                errorMsg = StringFormat("Invalid signal size: %d, must be > 0", p_sigSize);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Risk/Reward Ratio ---
        if(p_rrRatio <= 0) {
            if(isTester) {
                p_rrRatio = 1.0;  // Default fallback value for tester
                Print("Warning: Invalid risk/reward ratio, using default value: ", p_rrRatio);
            } else {
                errorMsg = StringFormat("Invalid risk/reward ratio: %.2f, must be > 0", p_rrRatio);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Risk Percentage ---
        if(p_riskPct <= 0 || p_riskPct > 100) {
            if(isTester) {
                p_riskPct = 1.0;  // Default fallback value for tester
                Print("Warning: Invalid risk percentage, using default value: ", p_riskPct);
            } else {
                errorMsg = StringFormat("Invalid risk percentage: %.2f, must be > 0 and <= 100", p_riskPct);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Stop Loss Pips ---
        if(p_slPips <= 0) {
            if(isTester) {
                p_slPips = 20;  // Default fallback value for tester
                Print("Warning: Invalid stop loss pips, using default value: ", p_slPips);
            } else {
                errorMsg = StringFormat("Invalid stop loss pips: %d, must be > 0", p_slPips);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Target Profit ---
        if(p_targetProfit < 0) {
            if(isTester) {
                p_targetProfit = 0.0;  // Default fallback value for tester
                Print("Warning: Invalid target profit, using default value: ", p_targetProfit);
            } else {
                errorMsg = StringFormat("Invalid target profit: %.2f, must be >= 0", p_targetProfit);
                Print(errorMsg);
                return false;
            }
        }
        
        // --- Handle Stop Loss Percentage ---
        if(p_stopLossPct < 0) {
            if(isTester) {
                p_stopLossPct = 0.0;  // Default fallback value for tester
                Print("Warning: Invalid stop loss percentage, using default value: ", p_stopLossPct);
            } else {
                errorMsg = StringFormat("Invalid stop loss percentage: %.2f, must be >= 0", p_stopLossPct);
                Print(errorMsg);
                return false;
            }
        }
        
        // Store the start time
        m_startTime = TimeCurrent();
        
        // ATR settings
        this.atrPeriod = p_atrPeriod;
        this.atrMultiplier = p_atrMultiplier;
        this.priceType = p_price;
        
        // Visual settings
        this.upperBandColor = p_upperColor;
        this.lowerBandColor = p_lowerColor;
        this.lineWidth = p_lineW;
        this.signalType = p_sigType;
        this.signalSize = p_sigSize;
        this.buySignalColor = p_buySigColor;
        this.sellSignalColor = p_sellSigColor;
        this.buyTouchColor = p_buyTColor;
        this.sellTouchColor = p_sellTColor;
        
        // Trading settings
        this.enableTrading = p_enableTrade;
        this.riskRewardRatio = p_rrRatio;
        this.riskPercentage = p_riskPct;
        this.stopLossPips = p_slPips;
        this.useTakeProfit = p_useTP;
        this.magicNumber = p_magic;
        this.targetProfitPercent = p_targetProfit;
        this.stopLossPercent = p_stopLossPct;
        
        // Runtime settings
        this.isOptimization = p_isOptimize;
        this.tradingEnabled = p_enableTrade;
        this.targetReached = false;
        this.stopLossReached = false;
        this.testMode = p_testMode;  // Set test mode flag
        
        Print("EASettings initialized successfully with ATR multiplier: ", this.atrMultiplier);
        return true;
    }
    
    // Get start time
    datetime GetStartTime() const {
        return m_startTime;
    }
    
    // Convert pips to price points based on symbol digits
    double PipsToPoints(int pips) const {
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(_Digits == 5 || _Digits == 3)
            return pips * 10 * point;
        else
            return pips * point;
    }
};
