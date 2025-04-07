//+------------------------------------------------------------------+
//|                                                   ATR Bands.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jivita by Malinda Rasingolla"
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
input int              StopLossPips = 10;              // Stop Loss in pips
input bool             UseTakeProfit = true;           // Use Take Profit
input int              MagicNumber = 12345;            // Magic Number to identify this EA's trades
input double           TargetProfitPercent = 0.0;      // Target profit percentage (0 = disabled)
input double           StopLossPercent = 0.0;          // Stop trading when drawdown exceeds this percentage (0 = disabled)

// Class instances for the EA components
ATRIndicator* atrIndicator = NULL;
SignalDetector* signalDetector = NULL;
TradeManager* tradeManager = NULL;
UIManager* uiManager = NULL;
EASettings* settings = NULL;

// Track last bar time for detecting new bars
datetime lastBarTime = 0;
datetime lastLogTime = 0;  // For limiting debug output

// Default values for removed parameters
const int DEFAULT_SIGNAL_SIZE = 3;  // Default signal size
const bool DEFAULT_TEST_MODE = false;  // Default test mode setting

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Add detailed initialization logging
   Print("===== ATR BANDS EA INITIALIZATION START =====");
   Print("Symbol: ", _Symbol, ", Period: ", EnumToString(_Period));
   Print("Inputs - ATR Period: ", ATR_Period, ", Multiplier: ", ATR_Multiplier);
   
   // Protect against reinitialization without proper cleanup
   if(settings != NULL || atrIndicator != NULL || signalDetector != NULL || 
      tradeManager != NULL || uiManager != NULL) {
      Print("Warning: EA is being reinitialized. Cleaning up previous resources...");
      OnDeinit(REASON_PROGRAM);
   }
   
   // Check if we're running in optimization mode
   bool isOptimization = MQLInfoInteger(MQL_OPTIMIZATION);
   Print("ATR Bands EA initializing, optimization mode: ", (isOptimization ? "Yes" : "No"));
   
   // Initialize settings
   Print("Attempting to create settings object...");
   settings = new EASettings();
   if(settings == NULL) {
      Print("Critical error: Failed to allocate memory for settings");
      return INIT_FAILED;
   }
   
   Print("Attempting to initialize settings with parameters...");
   Print("ATR_Period:", ATR_Period, " ATR_Multiplier:", ATR_Multiplier);
   
   // Fixed signal type to TOUCH, use DEFAULT_SIGNAL_SIZE instead of input parameter
   if(!settings.Initialize(ATR_Period, ATR_Multiplier, Price, 
                           UpperBandColor, LowerBandColor, LineWidth, 
                           SIGNAL_TYPE_TOUCH, DEFAULT_SIGNAL_SIZE, clrNONE, clrNONE, 
                           BuyTouchColor, SellTouchColor, EnableTrading, 
                           RiskRewardRatio, RiskPercentage, StopLossPips, 
                           UseTakeProfit, MagicNumber, TargetProfitPercent, 
                           StopLossPercent, isOptimization, DEFAULT_TEST_MODE)) {
      Print("Failed to initialize settings - check above for detailed error");
      return INIT_FAILED;
   }
   
   // Initialize components with error checking for each component
   // ATR indicator
   atrIndicator = new ATRIndicator();
   if(atrIndicator == NULL) {
      Print("Critical error: Failed to allocate memory for ATR indicator");
      return INIT_FAILED;
   }
   
   // Enhanced error reporting for component initialization
   if(!atrIndicator.Initialize(settings)) {
      Print("ERROR: ATR indicator initialization failed - Period: ", settings.atrPeriod);
      return INIT_FAILED;
   }
   
   // Signal detector
   signalDetector = new SignalDetector(settings, atrIndicator);
   if(signalDetector == NULL) {
      Print("Critical error: Failed to allocate memory for signal detector");
      return INIT_FAILED;
   }
   
   // Trade manager
   tradeManager = new TradeManager(settings);
   if(tradeManager == NULL) {
      Print("Critical error: Failed to allocate memory for trade manager");
      return INIT_FAILED;
   }
   
   // UI manager (if not in optimization mode)
   if(!isOptimization) {
      uiManager = new UIManager(settings, atrIndicator, signalDetector, tradeManager);
      if(uiManager == NULL) {
         Print("Critical error: Failed to allocate memory for UI manager");
         return INIT_FAILED;
      }
      
      if(!uiManager.Initialize()) {
         Print("Failed to initialize UI manager");
         return INIT_FAILED;
      }
   }
   
   // Enable chart events for UI interaction
   // Fixed function parameters - ChartSetInteger requires chart_id, property_id, property_value
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   
   Print("===== ATR BANDS EA INITIALIZATION COMPLETE =====");
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
   // Add diagnostics to track execution
   if(TimeCurrent() - lastLogTime > 60) { // Log only once per minute to avoid flooding
      Print("ATR Bands EA running tick: ", TimeCurrent());
      lastLogTime = TimeCurrent();
   }
   
   // Validate components are initialized with detailed error message
   if(atrIndicator == NULL || signalDetector == NULL || tradeManager == NULL) {
      static bool errorReported = false;
      if(!errorReported) {
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
   
   // Check if trade manager needs to update profit limits
   tradeManager.CheckProfitLimits();
   
   // Only update on new bars - exactly like reference implementation
   bool newBar = IsNewBar();
   
   // Process on new bar only - just like reference implementation
   if(newBar) {
      Print("Processing new bar at: ", TimeToString(lastBarTime));
      
      // Calculate ATR bands
      if(!atrIndicator.Calculate()) {
         Print("ERROR: ATR calculation failed at bar time: ", TimeToString(lastBarTime));
         return;
      }
      
      // Log current ATR values for verification
      Print("ATR value: ", DoubleToString(atrIndicator.GetCurrentATR(), _Digits),
            ", Upper band: ", DoubleToString(atrIndicator.GetUpperBand(), _Digits),
            ", Lower band: ", DoubleToString(atrIndicator.GetLowerBand(), _Digits));
      
      // Look for touch signals only
      SignalInfo signal = signalDetector.DetectSignals();
      
      // Log detected signal
      if(signal.hasSignal) {
         Print("Detected signal: ", signal.signalType, 
               ", Direction: ", (signal.isBuySignal ? "BUY" : "SELL"));
      }
      
      // Execute trades based on signals with clear logging
      if(signal.hasSignal) {
         if(tradeManager.CanTrade()) {
            Print("Executing trade for detected signal: ", signal.signalType);
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
         } else {
            Print("Signal detected but trading not allowed - Trading state: ", 
                  (settings.targetReached ? "Target Reached" : 
                   settings.stopLossReached ? "Stop Loss Reached" : 
                   !settings.tradingEnabled ? "Trading Disabled" : "Unknown"));
         }
      }
   }
   
   // Update UI if not in optimization mode and UI exists
   if(uiManager != NULL && !settings.isOptimization) {
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
