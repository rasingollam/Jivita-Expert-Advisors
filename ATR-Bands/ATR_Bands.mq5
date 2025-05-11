//+------------------------------------------------------------------+
//|                                                   ATR Bands.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita by Malinda Rasingolla"
#property version   "1.00"
#property description "Expert Advisor that trades on ATR Bands Touch signals"

// Include standard library and custom classes
#include <Trade/Trade.mqh>
#include "Include/ATRBands/Enums.mqh"
#include "Include/ATRBands/Settings.mqh"
#include "Include/ATRBands/ATRIndicator.mqh"
#include "Include/ATRBands/SignalDetector.mqh"
#include "Include/ATRBands/TradeManager.mqh"
#include "Include/ATRBands/UIManager.mqh"
#include "Include/ATRBands/OptimizationHelper.mqh"

// EA Input Parameters
input group "ATR Band Settings"
input int              ATR_Period = 14;                // ATR Period
input double           ATR_Multiplier = 1.0;           // ATR Multiplier
input ENUM_APPLIED_PRICE Price = PRICE_CLOSE;          // Price type
input color            UpperBandColor = clrYellow;     // Upper band color
input color            LowerBandColor = clrBlue;       // Lower band color
input int              LineWidth = 1;                  // Width of the lines

input group "Signal Settings"
// Signal type is now fixed to TOUCH only (removed input)
input color            BuyTouchColor = clrGreen;       // Buy signal color (touch)
input color            SellTouchColor = clrMaroon;     // Sell signal color (touch)

input group "Trade Settings"
input bool             EnableTrading = true;           // Enable automatic trading
input double           RiskRewardRatio = 1.5;          // Risk to Reward Ratio (1.0 = 1:1)
input double           RiskPercentage = 1.0;           // Risk percentage of account
input bool             UseAtrStopLoss = true;          // Use ATR-based stop loss
input double           AtrStopLossMultiplier = 1.0;    // ATR multiplier for stop loss
input bool             UseEmaTrailingStop = false;     // Use EMA-based trailing stop
input int              EmaTrailingPeriod = 20;         // EMA period for trailing stop
input int              StopLossPips = 10;              // Fixed Stop Loss in pips (when not using ATR)
input bool             UseTakeProfit = true;           // Use Take Profit
input int              MagicNumber = 12345;            // Magic Number to identify this EA's trades

input group "Trading Schedule"
input bool             Monday = true;                  // Allow trading on Monday
input bool             Tuesday = true;                 // Allow trading on Tuesday
input bool             Wednesday = true;               // Allow trading on Wednesday
input bool             Thursday = true;                // Allow trading on Thursday
input bool             Friday = true;                  // Allow trading on Friday
input bool             Saturday = false;               // Allow trading on Saturday
input bool             Sunday = false;                 // Allow trading on Sunday

input group "Trading Hours"
input bool             UseTimeFilter = false;          // Enable time filter for entries
input string           TradeStartTime = "09:00";       // Trading start time (24h format)
input string           TradeEndTime = "17:00";         // Trading end time (24h format)

input group "Risk Management"
input double           TargetProfitPercent = 0.0;      // Target profit percentage (0 = disabled)
input double           StopLossPercent = 0.0;          // Stop trading when drawdown exceeds this percentage (0 = disabled)

// Class instances for the EA components
ATRIndicator* atrIndicator = NULL;
SignalDetector* signalDetector = NULL;
TradeManager* tradeManager = NULL;
UIManager* uiManager = NULL;
EASettings* settings = NULL;
OptimizationHelper* optHelper = NULL;

// Track last bar time for detecting new bars
datetime lastBarTime = 0;
datetime lastLogTime = 0;  // For limiting debug output

// Default values for removed parameters
const int DEFAULT_SIGNAL_SIZE = 3;  // Default signal size
const bool DEFAULT_TEST_MODE = false;  // Default test mode setting

// Helper function to get the textual description of a day of week
string TimeDayOfWeekDescription(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    
    switch(dt.day_of_week) {
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

// Helper function to check if current time is within allowed trading hours
bool IsWithinTradingHours() {
   if (!settings.useTimeFilter) return true;
   
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   
   // Create time values using just hours and minutes
   int currentTime = now.hour * 100 + now.min;
   int startTime = settings.tradeStartHour * 100 + settings.tradeStartMinute;
   int endTime = settings.tradeEndHour * 100 + settings.tradeEndMinute;
   
   // Return true if within trading hours
   if (startTime < endTime) {
      // Normal case: start time is before end time (e.g., 09:00 - 17:00)
      return (currentTime >= startTime && currentTime < endTime);
   } else {
      // Overnight case: end time is on the next day (e.g., 22:00 - 06:00)
      return (currentTime >= startTime || currentTime < endTime);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check if we're running in optimization mode
   bool isOptimizing = MQLInfoInteger(MQL_OPTIMIZATION);
   
   // Create optimization helper first thing
   optHelper = new OptimizationHelper(_Symbol);
   
   if(!isOptimizing) {
      Print("===== ATR BANDS EA INITIALIZATION START =====");
      Print("Symbol: ", _Symbol, ", Period: ", EnumToString(_Period));
      Print("Inputs - ATR Period: ", ATR_Period, ", Multiplier: ", ATR_Multiplier);
   }
   
   // Protect against reinitialization without proper cleanup
   if(settings != NULL || atrIndicator != NULL || signalDetector != NULL || 
      tradeManager != NULL || uiManager != NULL) {
      if(!isOptimizing) {
         Print("Warning: EA is being reinitialized. Cleaning up previous resources...");
      }
      OnDeinit(REASON_PROGRAM);
   }
   
   if(!isOptimizing) {
      Print("ATR Bands EA initializing, optimization mode: ", (isOptimizing ? "Yes" : "No"));
   }
   
   // Initialize settings
   settings = new EASettings();
   if(settings == NULL) {
      Print("Critical error: Failed to allocate memory for settings");
      return INIT_FAILED;
   }
   
   // Set isOptimization flag directly for clarity
   settings.isOptimization = isOptimizing;
   
   // Initialize settings with parameters
   if(!settings.Initialize(ATR_Period, ATR_Multiplier, Price, 
                           UpperBandColor, LowerBandColor, LineWidth, 
                           SIGNAL_TYPE_TOUCH, DEFAULT_SIGNAL_SIZE, clrNONE, clrNONE, 
                           BuyTouchColor, SellTouchColor, EnableTrading, 
                           RiskRewardRatio, RiskPercentage, StopLossPips, 
                           UseAtrStopLoss, AtrStopLossMultiplier,
                           UseEmaTrailingStop, EmaTrailingPeriod,
                           UseTakeProfit, MagicNumber, 
                           Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday,
                           UseTimeFilter, TradeStartTime, TradeEndTime,
                           TargetProfitPercent, 
                           StopLossPercent, isOptimizing, DEFAULT_TEST_MODE)) {
      Print("Failed to initialize settings - check above for detailed error");
      return INIT_FAILED;
   }
   
   // Initialize ATR indicator - always needed
   atrIndicator = new ATRIndicator();
   if(atrIndicator == NULL) {
      Print("Critical error: Failed to allocate memory for ATR indicator");
      return INIT_FAILED;
   }
   
   if(!atrIndicator.Initialize(settings)) {
      Print("ERROR: ATR indicator initialization failed - Period: ", settings.atrPeriod);
      return INIT_FAILED;
   }
   
   // Signal detector - always needed
   signalDetector = new SignalDetector(settings, atrIndicator);
   if(signalDetector == NULL) {
      Print("Critical error: Failed to allocate memory for signal detector");
      return INIT_FAILED;
   }
   
   // Trade manager - always needed
   tradeManager = new TradeManager(settings, atrIndicator);
   if(tradeManager == NULL) {
      Print("Critical error: Failed to allocate memory for trade manager");
      return INIT_FAILED;
   }
   
   // UI manager - only needed when not optimizing
   if(!isOptimizing) {
      uiManager = new UIManager(settings, atrIndicator, signalDetector, tradeManager);
      if(uiManager == NULL) {
         Print("Critical error: Failed to allocate memory for UI manager");
         return INIT_FAILED;
      }
      if(!uiManager.Initialize()) {
         Print("Failed to initialize UI manager");
         return INIT_FAILED;
      }
      
      // Enable chart events for UI interaction - only for object clicks, not mouse move
      ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
      ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   }
   
   if(!isOptimizing) {
      Print("===== ATR BANDS EA INITIALIZATION COMPLETE =====");
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("ATR Bands EA deinitializing, reason: ", reason);
   
   // Save trade history data to global variables
   if(tradeManager != NULL) {
      tradeManager.SaveHistory();
   }
   
   // Clean up UI with null checks
   if(uiManager != NULL) {
      uiManager.Cleanup();
      delete uiManager;
      uiManager = NULL;
   }
   
   // Clean up other components with null checks
   if(tradeManager != NULL) {
      delete tradeManager;
      tradeManager = NULL;
   }
   if(signalDetector != NULL) {
      delete signalDetector;
      signalDetector = NULL;
   }
   if(atrIndicator != NULL) {
      delete atrIndicator;
      atrIndicator = NULL;
   }
   if(settings != NULL) {
      delete settings;
      settings = NULL;
   }
   
   // Clean up optimization helper
   if(optHelper != NULL) {
      delete optHelper;
      optHelper = NULL;
   }
   
   // Remove all chart objects drawn by the EA
   ObjectsDeleteAll(0, "ATRBand_");    // Remove all ATR band lines
   ObjectsDeleteAll(0, "ATRSignal_");  // Remove all signal markers
   ObjectsDeleteAll(0, "ATRPanel");    // Remove any panel elements
   
   // Clear chart objects and comment
   Comment("");
   
   // Force chart redraw to ensure all objects are removed
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if (lastBarTime == 0 || currentBarTime > lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Critical fix: Always check optimization mode first thing
   bool isOptimizing = MQLInfoInteger(MQL_OPTIMIZATION);
   
   // Add diagnostics to track execution - but not during optimization
   if(!isOptimizing && TimeCurrent() - lastLogTime > 60) { 
      Print("ATR Bands EA running tick: ", TimeCurrent());
      lastLogTime = TimeCurrent();
   }
   
   // Validate components are initialized
   if(atrIndicator == NULL || signalDetector == NULL || tradeManager == NULL) {
      static bool errorReported = false;
      if(!errorReported && !isOptimizing) {
         string missingComponents = "";
         if(atrIndicator == NULL) missingComponents += "ATR Indicator, ";
         if(signalDetector == NULL) missingComponents += "Signal Detector, ";
         if(tradeManager == NULL) missingComponents += "Trade Manager, ";
         // Remove trailing comma and space
         if(StringLen(missingComponents) > 2)
            missingComponents = StringSubstr(missingComponents, 0, StringLen(missingComponents) - 2);
         Print("EA components not properly initialized: ", missingComponents);
         errorReported = true;
      }
      return;
   }
   
   // Check profit limits but skip during optimization
   if(!isOptimizing) {
      tradeManager.CheckProfitLimits();
   }
   
   // Check for new bar - we need this for both normal and optimization modes
   bool newBar = IsNewBar();
   
   // Process on new bar only
   if(newBar) {
      // Calculate ATR bands
      if(!atrIndicator.Calculate()) {
         if(!isOptimizing) {
            Print("ERROR: ATR calculation failed at bar time: ", TimeToString(lastBarTime));
         }
         return;
      }
      
      // Apply EMA trailing stop if enabled
      if(settings.useEmaTrailingStop) {
         tradeManager.ProcessTrailingStop();
      }
      
      // Look for touch signals
      SignalInfo signal = signalDetector.DetectSignals();
      
      // Log signal detection for optimization debugging
      if(signal.hasSignal && optHelper != NULL) {
         optHelper.LogSignalDetected(signal.signalType, signal.isBuySignal);
      }
      
      // Log detected signal - only when not optimizing
      if(signal.hasSignal && !isOptimizing) {
         Print("Detected signal: ", signal.signalType, 
               ", Direction: ", (signal.isBuySignal ? "BUY" : "SELL"));
      }
      
      // Execute trades based on signals
      if(signal.hasSignal) {
         if(isOptimizing) {
            // OPTIMIZATION MODE: Execute trades unconditionally
            bool tradeExecuted = false;
            
            if(signal.isBuySignal) {
               tradeExecuted = tradeManager.ExecuteBuy(signal.signalType);
            } else {
               tradeExecuted = tradeManager.ExecuteSell(signal.signalType);
            }
            
            // Log trade execution for debugging
            if(tradeExecuted && optHelper != NULL) {
               optHelper.LogTradeExecuted(signal.signalType, signal.isBuySignal);
            }
         } 
         else {
            // NORMAL MODE: Apply all filters
            if(tradeManager.CanTrade()) {
               // Check if within trading time window
               if(!settings.useTimeFilter || settings.IsWithinTradingHours()) {
                  Print("Executing trade for signal: ", signal.signalType);
                  
                  if(signal.isBuySignal) {
                     if(tradeManager.ExecuteBuy(signal.signalType)) {
                        Print("Buy trade executed successfully");
                     } else {
                        Print("Buy trade execution failed");
                     }
                  } else {
                     if(tradeManager.ExecuteSell(signal.signalType)) {
                        Print("Sell trade executed successfully");
                     } else {
                        Print("Sell trade execution failed");
                     }
                  }
               }
               else {
                  Print("Signal detected but outside trading hours (",
                       settings.tradeStartHour, ":",
                       (settings.tradeStartMinute < 10 ? "0" : ""), settings.tradeStartMinute,
                       " - ",
                       settings.tradeEndHour, ":",
                       (settings.tradeEndMinute < 10 ? "0" : ""), settings.tradeEndMinute, ")");
               }
            }
            else {
               Print("Signal detected but trading not allowed - Trading state: ",
                    (settings.targetReached ? "Target Reached" :
                     settings.stopLossReached ? "Stop Loss Reached" :
                     !settings.tradingEnabled ? "Trading Disabled" : "Unknown"));
            }
         }
      }
   }
   
   // Update UI only when not optimizing
   if(uiManager != NULL && !isOptimizing) {
      uiManager.Update();
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Pass transaction event to trade manager
   if (tradeManager != NULL) {
      tradeManager.OnTradeTransaction(trans, request, result);
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, 
                  const long &lparam, 
                  const double &dparam, 
                  const string &sparam) 
{
   // Pass all chart events to UI manager for handling button clicks and dragging
   if(uiManager != NULL && !MQLInfoInteger(MQL_TESTER)) {
      uiManager.ProcessChartEvent(id, lparam, dparam, sparam);
   }
}
