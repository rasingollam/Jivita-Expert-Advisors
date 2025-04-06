//+------------------------------------------------------------------+
//|                                                   ATR Bands.mq5  |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Jivita by Malinda Rasingolla"
#property version   "1.00"
#property description "Expert Advisor that trades on signals base on ATR Bands"

#include <Trade/Trade.mqh>

// Create trade object for executing trades
CTrade Trade;

// Define enum for signal types
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_TYPE_BREAKOUT = 0,    // Trade only breakout signals
   SIGNAL_TYPE_TOUCH = 1,       // Trade only touch signals
   SIGNAL_TYPE_BOTH = 2         // Trade both signal types
};

//--- input parameters
input int      ATR_Period = 14;        // ATR Period
input double   ATR_Multiplier = 1.0;   // ATR Multiplier
input ENUM_APPLIED_PRICE Price = PRICE_CLOSE; // Price type
input color    UpperBandColor = clrYellow;  // Upper band color
input color    LowerBandColor = clrBlue; // Lower band color
input int      LineWidth = 1;           // Width of the lines
input color    BuySignalColor = clrLime; // Buy signal color (breakout)
input color    SellSignalColor = clrRed; // Sell signal color (breakout)
input color    BuyTouchColor = clrGreen; // Buy signal color (touch)
input color    SellTouchColor = clrMaroon; // Sell signal color (touch)
input int      SignalSize = 3;          // Size of signal arrows

// Trade parameters
input bool     EnableTrading = true;    // Enable automatic trading
input ENUM_SIGNAL_TYPE SignalType = SIGNAL_TYPE_BOTH; // Signal type to trade
input double   RiskRewardRatio = 1.5;   // Risk to Reward Ratio (1.0 = 1:1)
input double   RiskPercentage = 1.0;    // Risk percentage of account
input int      StopLossPips = 10;       // Stop Loss in pips
input bool     UseTakeProfit = true;    // Use Take Profit
input int      MagicNumber = 12345;     // Magic Number to identify this EA's trades
input double   TargetProfitPercent = 0.0; // Target profit percentage (0 = disabled)
input double   StopLossPercent = 0.0;   // Stop trading when drawdown exceeds this percentage (0 = disabled)

//--- handle for ATR indicator
int            atrHandle;

// Variables to track trading activity
bool           lastSignalProcessed = false;
datetime       lastSignalTime = 0;

// Add global variables to track cumulative profits and performance
double g_cumulativeProfit = 0.0;
int g_totalTrades = 0;
ulong g_lastDealTicket = 0;
datetime g_startTime;

// Define constants for panel dimensions and styling
#define PANEL_NAME "ATRPanel"
#define PANEL_TITLE "ATR Bands Expert Advisor"
#define PANEL_X 20
#define PANEL_Y 20
#define PANEL_WIDTH 300
#define PANEL_HEIGHT_INITIAL 460  // Initial panel height, will auto-adjust
#define PANEL_PADDING 10
#define SECTION_SPACING 8
#define LINE_SPACING 4
#define HEADER_COLOR clrDodgerBlue
#define TITLE_COLOR clrWhite
#define TEXT_COLOR clrLightGray
#define SIGNAL_BUY_COLOR clrLime
#define SIGNAL_SELL_COLOR clrRed
#define PROFIT_POSITIVE_COLOR clrLime
#define PROFIT_NEGATIVE_COLOR clrRed
#define PANEL_BACKGROUND_COLOR C'25,25,25'
#define PANEL_BORDER_COLOR clrDimGray

// Variables to track panel objects
string g_panelObjects[];
int g_panelObjectCount = 0;

// Add a flag to track if the panel structure has been initialized
bool g_panelInitialized = false;

// Add variable to track panel height
int g_currentPanelHeight = PANEL_HEIGHT_INITIAL;

// Add flag to detect optimization mode
bool g_isOptimization = false;

// Add variables to track the last bar time
datetime g_lastBarTime = 0;

// Variables to store current values for panel updates
double g_currentATR = 0;
double g_currentUpperBand = 0;
double g_currentLowerBand = 0;
bool g_currentBuySignal = false;
bool g_currentSellSignal = false;
string g_currentSignalType = "";

// Add a global variable to track trading status
bool g_tradingEnabled = true;
bool g_targetReached = false;

// Add global variables to track loss limits
bool g_stopLossReached = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check if we're running in optimization mode
   g_isOptimization = MQLInfoInteger(MQL_OPTIMIZATION);
   
   // Initialize the start time for the EA
   g_startTime = TimeCurrent();
   
   // Set the Magic Number for the Trade object
   Trade.SetExpertMagicNumber(MagicNumber);
   
   // Try to restore previous values from global variables - include Magic Number in variable names
   if(!g_isOptimization && GlobalVariableCheck("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_CumulativeProfit"))
      g_cumulativeProfit = GlobalVariableGet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_CumulativeProfit");
   
   if(!g_isOptimization && GlobalVariableCheck("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_TotalTrades"))
      g_totalTrades = (int)GlobalVariableGet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_TotalTrades");
   
   if(!g_isOptimization && GlobalVariableCheck("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_LastDealTicket"))
      g_lastDealTicket = (ulong)GlobalVariableGet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_LastDealTicket");

   //--- get ATR indicator handle
   atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Initialize trading enabled flag from input
   g_tradingEnabled = EnableTrading;
   
   // Only create visual elements when not in optimization mode
   if(!g_isOptimization)
   {
      //--- Remove previous lines if they exist
      ObjectsDeleteAll(0, PANEL_NAME);
      ObjectsDeleteAll(0, "ATRBand_");
      ObjectsDeleteAll(0, "ATRSignal_");
      
      // Initialize panel
      if(!g_panelInitialized)
      {
         CreatePanelStructure();
         g_panelInitialized = true;
      }
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Only save and clean up visual elements when not in optimization mode
   if(!g_isOptimization)
   {
      // Save the cumulative profit and total trades to global variables - include Magic Number
      GlobalVariableSet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_CumulativeProfit", g_cumulativeProfit);
      GlobalVariableSet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_TotalTrades", g_totalTrades);
      GlobalVariableSet("ATR_EA_" + _Symbol + "_" + IntegerToString(MagicNumber) + "_LastDealTicket", (double)g_lastDealTicket);
      
      // Clear the comment from the chart
      Comment("");
      
      //--- Remove all objects created by this EA
      ObjectsDeleteAll(0, PANEL_NAME);
      ObjectsDeleteAll(0, "ATRBand_");
      ObjectsDeleteAll(0, "ATRSignal_");
      
      // Remove any labels
      if(ObjectFind(0, "ATRBand_Value") >= 0)
         ObjectDelete(0, "ATRBand_Value");
      
      // Remove all panel objects
      RemoveAllPanelObjects();
      
      // Force chart redraw
      ChartRedraw();
   }
   
   //--- release ATR indicator handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Remove all panel objects                                         |
//+------------------------------------------------------------------+
void RemoveAllPanelObjects()
{
   ObjectsDeleteAll(0, PANEL_NAME);
   g_panelObjectCount = 0;
   ArrayResize(g_panelObjects, g_panelObjectCount);
}

//+------------------------------------------------------------------+
//| Convert pips to price points based on symbol digits              |
//+------------------------------------------------------------------+
double PipsToPoints(int pips)
{
   // Get point value
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   // For 5-digit brokers, multiply by 10
   if(_Digits == 5 || _Digits == 3)
      return pips * 10 * point;
   else
      return pips * point;
}

//+------------------------------------------------------------------+
//| Calculate Position Size based on Risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDistance)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercentage / 100.0);
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(stopLossDistance == 0 || tickSize == 0 || tickValue == 0 || lotStep == 0)
      return minLot;
      
   // Calculate lot size based on risk
   double riskPerTick = riskAmount / (stopLossDistance / tickSize * tickValue);
   double lots = NormalizeDouble(riskPerTick, 2);
   
   // Ensure lot size is valid
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   
   // Adjust to lot step
   lots = MathFloor(lots / lotStep) * lotStep;
   
   return lots;
}

//+------------------------------------------------------------------+
//| Close Buy Positions                                              |
//+------------------------------------------------------------------+
void CloseBuyPositions()
{
   for(int i = PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      // Check Magic Number to only close positions opened by this EA
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      
      // Check if position is a BUY
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(!Trade.PositionClose(ticket))
            Print("Failed to close BUY position: ", GetLastError());
         else
            Print("Closed BUY position #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Close Sell Positions                                             |
//+------------------------------------------------------------------+
void CloseSellPositions()
{
   for(int i = PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      // Check Magic Number to only close positions opened by this EA
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      
      // Check if position is a SELL
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         if(!Trade.PositionClose(ticket))
            Print("Failed to close SELL position: ", GetLastError());
         else
            Print("Closed SELL position #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if there are any open positions for the symbol             |
//+------------------------------------------------------------------+
bool HasOpenPositions()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) // Check Magic Number
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute Buy Order with fixed pips SL                             |
//+------------------------------------------------------------------+
void ExecuteBuy(string signalType)
{
   // Check if we should place trades - now check global flag as well
   if(!g_tradingEnabled) 
   {
      if(g_targetReached)
         Print("Buy signal ignored: Target profit reached.");
      else if(g_stopLossReached)
         Print("Buy signal ignored: Stop loss threshold reached.");
      else
         Print("Buy signal ignored: Trading disabled.");
      return;
   }
   
   // Check if we already have positions
   if(HasOpenPositions()) return;
   
   // Close any existing SELL positions before opening a BUY
   CloseSellPositions();
   
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Set stop loss in pips
   double stopLossDistance = PipsToPoints(StopLossPips);
   double takeProfitDistance = stopLossDistance * RiskRewardRatio;
   
   // Calculate actual SL and TP prices
   double stopLossPrice = entryPrice - stopLossDistance;
   
   // Use take profit only if enabled
   double takeProfitPrice = 0;
   if(UseTakeProfit)
      takeProfitPrice = entryPrice + takeProfitDistance;
   
   // Calculate position size based on risk
   double lotSize = CalculatePositionSize(stopLossDistance);
   
   // Execute the buy order
   if(!Trade.Buy(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "ATR Signal: " + signalType))
   {
      Print("Error opening Buy order: ", GetLastError());
   }
   else
   {
      Print("Buy order executed. Signal: ", signalType, 
            ", Lot Size: ", lotSize, 
            ", SL: ", stopLossPrice, 
            ", TP: ", (UseTakeProfit ? DoubleToString(takeProfitPrice) : "None"));
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Order with fixed pips SL                            |
//+------------------------------------------------------------------+
void ExecuteSell(string signalType)
{
   // Check if we should place trades - now check global flag as well
   if(!g_tradingEnabled) 
   {
      if(g_targetReached)
         Print("Sell signal ignored: Target profit reached.");
      else if(g_stopLossReached)
         Print("Sell signal ignored: Stop loss threshold reached.");
      else
         Print("Sell signal ignored: Trading disabled.");
      return;
   }
   
   // Check if we already have positions
   if(HasOpenPositions()) return;
   
   // Close any existing BUY positions before opening a SELL
   CloseBuyPositions();
   
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Set stop loss in pips
   double stopLossDistance = PipsToPoints(StopLossPips);
   double takeProfitDistance = stopLossDistance * RiskRewardRatio;
   
   // Calculate actual SL and TP prices
   double stopLossPrice = entryPrice + stopLossDistance;
   
   // Use take profit only if enabled
   double takeProfitPrice = 0;
   if(UseTakeProfit)
      takeProfitPrice = entryPrice - takeProfitDistance;
   
   // Calculate position size based on risk
   double lotSize = CalculatePositionSize(stopLossDistance);
   
   // Execute the sell order
   if(!Trade.Sell(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "ATR Signal: " + signalType))
   {
      Print("Error opening Sell order: ", GetLastError());
   }
   else
   {
      Print("Sell order executed. Signal: ", signalType, 
            ", Lot Size: ", lotSize, 
            ", SL: ", stopLossPrice, 
            ", TP: ", (UseTakeProfit ? DoubleToString(takeProfitPrice) : "None"));
   }
}

//+------------------------------------------------------------------+
//| Update cumulative profit based on closed positions               |
//+------------------------------------------------------------------+
void UpdateCumulativeProfit()
{
   // Find the latest deal ticket
   HistorySelect(g_startTime, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      // Skip already processed deals
      if(dealTicket <= g_lastDealTicket)
         continue;
         
      // Check if this deal belongs to our symbol and Magic Number
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) // Check Magic Number
         continue;
         
      // Check if this is an out trade (position closing)
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         // Add profit to cumulative total
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         g_cumulativeProfit += profit;
         g_totalTrades++;
         
         // Update the last processed deal ticket
         if(dealTicket > g_lastDealTicket)
            g_lastDealTicket = dealTicket;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate the total profit for all open positions                |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double totalProfit = 0.0;
   int posCount = PositionsTotal();
   
   for(int i = 0; i < posCount; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) // Check Magic Number
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Create the initial panel structure with all static elements      |
//+------------------------------------------------------------------+
void CreatePanelStructure()
{
   // Remove any existing panel
   RemoveAllPanelObjects();
   
   // Create main panel background - height will be updated later
   string objName = PANEL_NAME + "_BG";
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, PANEL_X);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, PANEL_Y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, PANEL_WIDTH);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, g_currentPanelHeight);  // Initial height
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, PANEL_BACKGROUND_COLOR);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, PANEL_BORDER_COLOR);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   
   // Add to object list
   AddPanelObject(objName);
   
   // Add panel title
   CreatePanelLabel(PANEL_NAME + "_Title", PANEL_TITLE, PANEL_X + PANEL_PADDING, PANEL_Y + PANEL_PADDING, 14, TITLE_COLOR, true);
   
   // Add divider line below title
   CreatePanelLine(PANEL_NAME + "_TitleLine", 
                  PANEL_X + PANEL_PADDING, 
                  PANEL_Y + PANEL_PADDING + 25, 
                  PANEL_X + PANEL_WIDTH - PANEL_PADDING, 
                  PANEL_Y + PANEL_PADDING + 25, 
                  HEADER_COLOR);
   
   // Starting Y position for content (after title)
   int y = PANEL_Y + PANEL_PADDING + 30;
   
   // Create section headers and labels for all sections
   
   // --- ATR Information Section ---
   CreateSectionHeaderStatic("ATR Information", y);
   
   // Create labels for ATR section
   CreateInfoLabelPair("ATR Period", "", y);
   CreateInfoLabelPair("ATR Multiplier", "", y);
   CreateInfoLabelPair("Current ATR Value", "", y);
   CreateInfoLabelPair("Upper Band", "", y);
   CreateInfoLabelPair("Lower Band", "", y);
   
   // --- Signal Information Section ---
   CreateSectionHeaderStatic("Signal Information", y);
   
   // Create labels for signal section
   CreateInfoLabelPair("Signal Type Setting", "", y);
   CreateInfoLabelPair("Current Signal", "", y);
   
   // --- Trade Settings Section ---
   CreateSectionHeaderStatic("Trade Settings", y);
   
   // Create labels for trade settings
   CreateInfoLabelPair("Trading Enabled", "", y);
   CreateInfoLabelPair("Target Profit", "", y); // Add Target Profit to panel
   CreateInfoLabelPair("Stop Loss %", "", y); // Add Stop Loss Percentage to panel
   CreateInfoLabelPair("Magic Number", "", y); // Add Magic Number to panel
   CreateInfoLabelPair("Risk Percentage", "", y);
   CreateInfoLabelPair("Stop Loss", "", y);
   CreateInfoLabelPair("Risk/Reward", "", y);
   CreateInfoLabelPair("Take Profit", "", y);
   
   // --- Profit Information Section ---
   CreateSectionHeaderStatic("Profit Information", y);
   
   // Create labels for profit information
   CreateInfoLabelPair("Current Positions Profit", "", y);
   CreateInfoLabelPair("Cumulative Closed Profit", "", y);
   CreateInfoLabelPair("Total Profit", "", y);
   CreateInfoLabelPair("Total Completed Trades", "", y);
   
   // Don't create position section in advance as it's dynamic
   // We'll handle that separately in UpdatePanel
}

//+------------------------------------------------------------------+
//| Update panel height based on content                             |
//+------------------------------------------------------------------+
void UpdatePanelHeight(int contentHeight)
{
   // Make sure we're using a reasonable minimum height
   int minHeight = PANEL_HEIGHT_INITIAL;
   int newHeight = MathMax(contentHeight, minHeight);
   
   // Only update if height has changed
   if(newHeight != g_currentPanelHeight)
   {
      g_currentPanelHeight = newHeight;
      
      // Update the background rectangle
      string objName = PANEL_NAME + "_BG";
      if(ObjectFind(0, objName) >= 0)
      {
         ObjectSetInteger(0, objName, OBJPROP_YSIZE, g_currentPanelHeight);
      }
   }
}

//+------------------------------------------------------------------+
//| Create a section header with static position                     |
//+------------------------------------------------------------------+
void CreateSectionHeaderStatic(string title, int &y)
{
   y += SECTION_SPACING;
   
   // Create the header text
   string labelName = PANEL_NAME + "_" + title;
   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, PANEL_X + PANEL_PADDING);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, HEADER_COLOR);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   ObjectSetString(0, labelName, OBJPROP_TEXT, title);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   AddPanelObject(labelName);
   
   y += 18;
   
   // Create the divider line
   string lineName = PANEL_NAME + "_" + title + "_Line";
   CreatePanelLine(lineName, 
                  PANEL_X + PANEL_PADDING, 
                  y, 
                  PANEL_X + PANEL_WIDTH - PANEL_PADDING, 
                  y, 
                  HEADER_COLOR);
   
   y += 5;
}

//+------------------------------------------------------------------+
//| Create paired labels for info rows (static)                      |
//+------------------------------------------------------------------+
void CreateInfoLabelPair(string label, string initialValue, int &y)
{
   // Create label text
   string labelName = PANEL_NAME + "_Label_" + label;
   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, PANEL_X + PANEL_PADDING);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   ObjectSetString(0, labelName, OBJPROP_TEXT, label + ":");
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   AddPanelObject(labelName);
   
   // Create value text
   string valueName = PANEL_NAME + "_Value_" + label;
   ObjectCreate(0, valueName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, valueName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, PANEL_X + PANEL_PADDING + 150);
   ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, valueName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, valueName, OBJPROP_FONT, "Arial");
   ObjectSetString(0, valueName, OBJPROP_TEXT, initialValue);
   ObjectSetInteger(0, valueName, OBJPROP_HIDDEN, true);
   AddPanelObject(valueName);
   
   y += 16 + LINE_SPACING;
}

//+------------------------------------------------------------------+
//| Update an existing info label value                              |
//+------------------------------------------------------------------+
void UpdateInfoValue(string label, string value, color valueColor = TEXT_COLOR)
{
   string valueName = PANEL_NAME + "_Value_" + label;
   if(ObjectFind(0, valueName) >= 0)
   {
      ObjectSetString(0, valueName, OBJPROP_TEXT, value);
      ObjectSetInteger(0, valueName, OBJPROP_COLOR, valueColor);
   }
}

//+------------------------------------------------------------------+
//| Handle dynamic position section updates                          |
//+------------------------------------------------------------------+
void UpdatePositionSection(int &y)
{
   int posCount = PositionsTotal();
   int openPositionsCount = 0;  // Track actual positions for this symbol and Magic Number

   // Count positions for this symbol and Magic Number
   for(int i = 0; i < posCount; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) // Check Magic Number
      {
         openPositionsCount++;
      }
   }
   
   // More aggressive cleanup of position-related objects
   // Clean up ALL objects that relate to positions, including section header
   ObjectsDeleteAll(0, PANEL_NAME + "_Open Positions");
   ObjectsDeleteAll(0, PANEL_NAME + "_Pos");
   
   // Also clean up specific position entries from our tracking array
   for(int i = 0; i < g_panelObjectCount; i++)
   {
      if(StringFind(g_panelObjects[i], PANEL_NAME + "_Pos") >= 0 || 
         StringFind(g_panelObjects[i], PANEL_NAME + "_Open Positions") >= 0 ||
         StringFind(g_panelObjects[i], PANEL_NAME + "_Value_Pos") >= 0 ||
         StringFind(g_panelObjects[i], PANEL_NAME + "_Label_Pos") >= 0)
      {
         ObjectDelete(0, g_panelObjects[i]);
         g_panelObjects[i] = "";  // Mark for cleanup
      }
   }
   
   // Remove empty entries from the object list
   for(int i = g_panelObjectCount - 1; i >= 0; i--)
   {
      if(g_panelObjects[i] == "")
      {
         for(int j = i; j < g_panelObjectCount - 1; j++)
         {
            g_panelObjects[j] = g_panelObjects[j + 1];
         }
         g_panelObjectCount--;
      }
   }
   ArrayResize(g_panelObjects, g_panelObjectCount);
   
   // Create position section only if there are positions
   if(openPositionsCount > 0)
   {
      // Create section header
      CreateSectionHeaderStatic("Open Positions", y);
      
      for(int i = 0; i < posCount; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && 
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber) // Check Magic Number
         {
            string posType = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
            double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            double posSL = PositionGetDouble(POSITION_SL);
            double posTP = PositionGetDouble(POSITION_TP);
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            
            color posColor = (posType == "BUY") ? SIGNAL_BUY_COLOR : SIGNAL_SELL_COLOR;
            color profitColor = (posProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
            
            // Show position info
            string posTypeLabel = PANEL_NAME + "_Pos" + IntegerToString(i) + "_Type";
            ObjectCreate(0, posTypeLabel, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_XDISTANCE, PANEL_X + PANEL_PADDING);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_COLOR, posColor);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, posTypeLabel, OBJPROP_FONT, "Arial");
            ObjectSetString(0, posTypeLabel, OBJPROP_TEXT, "#" + IntegerToString(ticket) + ": " + posType);
            ObjectSetInteger(0, posTypeLabel, OBJPROP_HIDDEN, true);
            AddPanelObject(posTypeLabel);
            y += 16;
            
            // Create position detail labels
            string entryLabel = "Pos" + IntegerToString(i) + "_Entry";
            string slLabel = "Pos" + IntegerToString(i) + "_SL";
            string tpLabel = "Pos" + IntegerToString(i) + "_TP";
            string profitLabel = "Pos" + IntegerToString(i) + "_Profit";
            
            CreateInfoLabelPair(entryLabel, DoubleToString(posOpen, 5), y);
            CreateInfoLabelPair(slLabel, DoubleToString(posSL, 5), y);
            CreateInfoLabelPair(tpLabel, DoubleToString(posTP, 5), y);
            CreateInfoLabelPair(profitLabel, DoubleToString(posProfit, 2), y);
            
            // Update text and colors
            UpdateInfoValue(entryLabel, DoubleToString(posOpen, 5));
            UpdateInfoValue(slLabel, DoubleToString(posSL, 5));
            UpdateInfoValue(tpLabel, DoubleToString(posTP, 5));
            UpdateInfoValue(profitLabel, DoubleToString(posProfit, 2), profitColor);
            
            y += 10; // Add extra space between positions
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update panel with current information                            |
//+------------------------------------------------------------------+
void UpdatePanel(double atr_value, double upper_band, double lower_band, bool buySignal, bool sellSignal, string signalTypeText)
{
   // Update cumulative profit
   UpdateCumulativeProfit();
   
   // Check profit targets and loss limits
   CheckProfitLimits();
   
   // Make sure panel is initialized
   if(!g_panelInitialized)
   {
      CreatePanelStructure();
      g_panelInitialized = true;
   }
   
   // Track our starting position to measure effective panel height
   int initialY = PANEL_Y;
   
   // Get the position of the static content by tracking where sections end
   int currentY = PANEL_Y + PANEL_PADDING + 30; // Start after title
   
   // Update ATR Information Section
   UpdateInfoValue("ATR Period", IntegerToString(ATR_Period));
   UpdateInfoValue("ATR Multiplier", DoubleToString(ATR_Multiplier, 2));
   UpdateInfoValue("Current ATR Value", DoubleToString(atr_value, 5));
   UpdateInfoValue("Upper Band", DoubleToString(upper_band, 5));
   UpdateInfoValue("Lower Band", DoubleToString(lower_band, 5));
   
   // Update Signal Information Section
   string signalTypeSettingText = "Both Breakout & Touch";
   if(SignalType == SIGNAL_TYPE_BREAKOUT) signalTypeSettingText = "Breakout Only";
   if(SignalType == SIGNAL_TYPE_TOUCH) signalTypeSettingText = "Touch Only";
   
   UpdateInfoValue("Signal Type Setting", signalTypeSettingText);
   
   color signalColor = TEXT_COLOR;
   string currentSignal = "None";
   
   if(buySignal)
   {
      currentSignal = "BUY (" + signalTypeText + ")";
      signalColor = SIGNAL_BUY_COLOR;
   }
   else if(sellSignal)
   {
      currentSignal = "SELL (" + signalTypeText + ")";
      signalColor = SIGNAL_SELL_COLOR;
   }
   
   UpdateInfoValue("Current Signal", currentSignal, signalColor);
   
   // Update Trade Settings Section - show special status when target or stop loss reached
   string tradingStatus;
   color tradingStatusColor = TEXT_COLOR;
   
   if(g_targetReached)
   {
      tradingStatus = "DISABLED (Target Reached)";
      tradingStatusColor = PROFIT_POSITIVE_COLOR;
   }
   else if(g_stopLossReached)
   {
      tradingStatus = "DISABLED (Stop Loss Reached)";
      tradingStatusColor = PROFIT_NEGATIVE_COLOR;
   }
   else if(!g_tradingEnabled)
   {
      tradingStatus = "DISABLED (Manual)";
      tradingStatusColor = TEXT_COLOR;
   }
   else
   {
      tradingStatus = "ENABLED";
      tradingStatusColor = PROFIT_POSITIVE_COLOR;
   }
   
   UpdateInfoValue("Trading Enabled", tradingStatus, tradingStatusColor);
   UpdateInfoValue("Target Profit", (TargetProfitPercent > 0.0) ? 
                  DoubleToString(TargetProfitPercent, 2) + "%" : "Disabled");
   UpdateInfoValue("Stop Loss %", (StopLossPercent > 0.0) ? 
                  DoubleToString(StopLossPercent, 2) + "%" : "Disabled");
   UpdateInfoValue("Magic Number", IntegerToString(MagicNumber)); 
   UpdateInfoValue("Risk Percentage", DoubleToString(RiskPercentage, 2) + "%");
   UpdateInfoValue("Stop Loss", IntegerToString(StopLossPips) + " pips");
   UpdateInfoValue("Risk/Reward", DoubleToString(RiskRewardRatio, 1));
   UpdateInfoValue("Take Profit", UseTakeProfit ? "Enabled" : "Disabled");
   
   // Update Profit Information Section
   double currentProfit = CalculateTotalProfit();
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentProfitPercentage = 0.0;
   
   // Avoid division by zero
   if(accountBalance > 0.0)
      currentProfitPercentage = (currentProfit / accountBalance) * 100.0;
   
   // Calculate all-time performance metrics
   double totalProfit = g_cumulativeProfit + currentProfit;
   double totalProfitPercentage = 0.0;
   
   // Avoid division by zero
   if(accountBalance > 0.0)
      totalProfitPercentage = (totalProfit / accountBalance) * 100.0;
   
   color currentProfitColor = (currentProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
   color totalProfitColor = (totalProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
   
   UpdateInfoValue("Current Positions Profit", DoubleToString(currentProfit, 2) + " (" + DoubleToString(currentProfitPercentage, 2) + "%)", currentProfitColor);
   UpdateInfoValue("Cumulative Closed Profit", DoubleToString(g_cumulativeProfit, 2), (g_cumulativeProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR);
   UpdateInfoValue("Total Profit", DoubleToString(totalProfit, 2) + " (" + DoubleToString(totalProfitPercentage, 2) + "%)", totalProfitColor);
   UpdateInfoValue("Total Completed Trades", IntegerToString(g_totalTrades));
   
   // Calculate where static content ends - this must match the layout from CreatePanelStructure
   // We need to manually calculate this based on the number of items in each section
   currentY = PANEL_Y + PANEL_PADDING + 30;  // Start after title
   
   // ATR Information Section (header + 5 items)
   currentY += SECTION_SPACING + 18 + 5;  // Header space
   currentY += 5 * (16 + LINE_SPACING);   // 5 items
   
   // Signal Information Section (header + 2 items)
   currentY += SECTION_SPACING + 18 + 5;  // Header space
   currentY += 2 * (16 + LINE_SPACING);   // 2 items
   
   // Trade Settings Section (header + 8 items) - Now includes Stop Loss % item
   currentY += SECTION_SPACING + 18 + 5;  // Header space
   currentY += 8 * (16 + LINE_SPACING);   // 8 items
   
   // Profit Information Section (header + 4 items)
   currentY += SECTION_SPACING + 18 + 5;  // Header space
   currentY += 4 * (16 + LINE_SPACING);   // 4 items
   
   // Add extra space before position section
   currentY += 10;
   
   // Now we have the correct position to start adding dynamic content
   int contentEndY = currentY;
   
   // Update position section - this will modify contentEndY
   UpdatePositionSection(contentEndY);
   
   // Add extra padding at the bottom 
   contentEndY += PANEL_PADDING * 2;  // Double the padding for more space
   
   // Update the panel height based on the content height
   int totalContentHeight = contentEndY - initialY;
   UpdatePanelHeight(totalContentHeight);
   
   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create the panel background                                      |
//+------------------------------------------------------------------+
void CreatePanel()
{
   // Remove any existing panel
   RemoveAllPanelObjects();
   
   // Create main panel background
   string objName = PANEL_NAME + "_BG";
   ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, PANEL_X);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, PANEL_Y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, PANEL_WIDTH);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, PANEL_HEIGHT_INITIAL);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, PANEL_BACKGROUND_COLOR);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, PANEL_BORDER_COLOR);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   
   // Add to object list
   AddPanelObject(objName);
   
   // Add panel title
   CreatePanelLabel(PANEL_NAME + "_Title", PANEL_TITLE, PANEL_X + PANEL_PADDING, PANEL_Y + PANEL_PADDING, 14, TITLE_COLOR, true);
   
   // Add divider line below title
   CreatePanelLine(PANEL_NAME + "_TitleLine", 
                  PANEL_X + PANEL_PADDING, 
                  PANEL_Y + PANEL_PADDING + 25, 
                  PANEL_X + PANEL_WIDTH - PANEL_PADDING, 
                  PANEL_Y + PANEL_PADDING + 25, 
                  HEADER_COLOR);
}

//+------------------------------------------------------------------+
//| Add object to panel tracking array                               |
//+------------------------------------------------------------------+
void AddPanelObject(string objName)
{
   g_panelObjectCount++;
   ArrayResize(g_panelObjects, g_panelObjectCount);
   g_panelObjects[g_panelObjectCount - 1] = objName;
}

//+------------------------------------------------------------------+
//| Create a label on the panel                                      |
//+------------------------------------------------------------------+
void CreatePanelLabel(string name, string text, int x, int y, int fontSize, color textColor, bool isBold=false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   if(isBold)
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   
   AddPanelObject(name);
}

//+------------------------------------------------------------------+
//| Create a line on the panel                                       |
//+------------------------------------------------------------------+
void CreatePanelLine(string name, int x1, int y1, int x2, int y2, color lineColor)
{
   // For panel lines, we'll use a rectangle object instead of a trend line
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   // Set properties for the line (using a thin rectangle)
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 1); // Make it 1 pixel high
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   
   AddPanelObject(name);
}

//+------------------------------------------------------------------+
//| Create a section header in the panel                             |
//+------------------------------------------------------------------+
void CreateSectionHeader(string title, int &y)
{
   y += SECTION_SPACING;
   CreatePanelLabel(PANEL_NAME + "_" + title, title, PANEL_X + PANEL_PADDING, y, 10, HEADER_COLOR, true);
   y += 18;
   
   // Add divider line
   CreatePanelLine(PANEL_NAME + "_" + title + "_Line", 
                  PANEL_X + PANEL_PADDING, 
                  y, 
                  PANEL_X + PANEL_WIDTH - PANEL_PADDING, 
                  y, 
                  HEADER_COLOR);
   y += 5;
}

//+------------------------------------------------------------------+
//| Add information line to panel                                    |
//+------------------------------------------------------------------+
void AddInfoLine(string label, string value, int &y, color valueColor = TEXT_COLOR)
{
   CreatePanelLabel(PANEL_NAME + "_Label_" + label, label + ":", PANEL_X + PANEL_PADDING, y, 9, TEXT_COLOR);
   CreatePanelLabel(PANEL_NAME + "_Value_" + label, value, PANEL_X + PANEL_PADDING + 150, y, 9, valueColor);
   y += 16 + LINE_SPACING;
}

//+------------------------------------------------------------------+
//| Update cumulative profit when positions are closed               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Look for position close events
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && 
      (trans.deal_type == DEAL_TYPE_SELL || trans.deal_type == DEAL_TYPE_BUY))
   {
      // We need to look for deals that close positions
      // Rather than checking order types, just check history after each deal
      UpdateCumulativeProfit();
   }
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   // If this is the first check or time has changed
   if(g_lastBarTime == 0 || currentBarTime > g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check profit targets and loss limits                             |
//+------------------------------------------------------------------+
bool CheckProfitLimits()
{
   // Calculate current total profit percentage
   double currentProfit = CalculateTotalProfit();
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalProfit = g_cumulativeProfit + currentProfit;
   double totalProfitPercentage = 0.0;
   
   // Avoid division by zero
   if(accountBalance > 0.0)
      totalProfitPercentage = (totalProfit / accountBalance) * 100.0;
   
   // Check target profit first (if enabled)
   if(TargetProfitPercent > 0.0 && totalProfitPercentage >= TargetProfitPercent)
   {
      // Disable trading if not already disabled
      if(g_tradingEnabled)
      {
         g_tradingEnabled = false;
         g_targetReached = true;
         Print("Target profit of ", TargetProfitPercent, "% reached. Trading automatically disabled.");
      }
      return true;
   }
   else if(g_targetReached && TargetProfitPercent > 0.0)
   {
      // Reset target reached flag if profit dropped back below target
      // (trading will remain disabled but with correct status)
      g_targetReached = false;
   }
   
   // Check stop loss (if enabled)
   if(StopLossPercent > 0.0 && totalProfitPercentage <= -StopLossPercent)
   {
      // Disable trading if not already disabled
      if(g_tradingEnabled)
      {
         g_tradingEnabled = false;
         g_stopLossReached = true;
         Print("Stop loss threshold of -", StopLossPercent, "% reached. Trading automatically disabled.");
      }
      return true;
   }
   else if(g_stopLossReached && StopLossPercent > 0.0)
   {
      // Reset stop loss reached flag if profit recovered above threshold
      // (trading will remain disabled but with correct status)
      g_stopLossReached = false;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get data for a reasonable number of bars
   int bars_to_process = 5; 
   
   // Check profit targets and loss limits on every tick
   CheckProfitLimits();
   
   // Only calculate bands and signals on a new bar to improve performance
   bool newBar = IsNewBar();
   
   // Check if target profit has been reached
   CheckProfitLimits();
   
   // Perform full calculation only on new bar
   if(newBar)
   {
      // Calculate and draw ATR bands
      CalculateAndDrawATRBands(bars_to_process);
   }
   else if(!g_isOptimization)
   {
      // In visual mode, just update the panel with existing values
      // without recalculating everything
      UpdatePanel(g_currentATR, g_currentUpperBand, g_currentLowerBand, 
                 g_currentBuySignal, g_currentSellSignal, g_currentSignalType);
   }
}

//+------------------------------------------------------------------+
//| Calculate and draw ATR Bands                                     |
//+------------------------------------------------------------------+
void CalculateAndDrawATRBands(int count)
{
   //--- define variables
   double atr_values[];
   double close_values[];
   double high_values[];
   double low_values[];
   datetime time_values[];
   
   //--- allocate memory for arrays
   ArraySetAsSeries(atr_values, true);
   ArraySetAsSeries(close_values, true);
   ArraySetAsSeries(high_values, true);
   ArraySetAsSeries(low_values, true);
   ArraySetAsSeries(time_values, true);
   
   // Request enough data for our calculations
   int data_count = count + 1;  // Need +1 to get previous values
   ArrayResize(atr_values, data_count);
   ArrayResize(close_values, data_count);
   ArrayResize(high_values, data_count);
   ArrayResize(low_values, data_count);
   ArrayResize(time_values, data_count);
   
   //--- copy ATR values to array
   if(CopyBuffer(atrHandle, 0, 0, data_count, atr_values) <= 0)
   {
      Print("Failed to copy ATR values: ", GetLastError());
      return;
   }
   
   //--- copy price data
   if(CopyClose(_Symbol, _Period, 0, data_count, close_values) <= 0)
   {
      Print("Failed to copy close prices: ", GetLastError());
      return;
   }
   
   if(CopyHigh(_Symbol, _Period, 0, data_count, high_values) <= 0)
   {
      Print("Failed to copy high prices: ", GetLastError());
      return;
   }
   
   if(CopyLow(_Symbol, _Period, 0, data_count, low_values) <= 0)
   {
      Print("Failed to copy low prices: ", GetLastError());
      return;
   }
   
   //--- copy time values to array
   if(CopyTime(_Symbol, _Period, 0, data_count, time_values) <= 0)
   {
      Print("Failed to copy time values: ", GetLastError());
      return;
   }
   
   // Only update visual elements when not in optimization mode
   if(!g_isOptimization)
   {
      //--- Delete previous lines and signals
      ObjectsDeleteAll(0, "ATRBand_");
      ObjectsDeleteAll(0, "ATRSignal_");
   }
   
   // Reset signal processing flag on a new bar
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time != lastSignalTime)
   {
      lastSignalProcessed = false;
      lastSignalTime = current_time;
   }
   
   // Trading signal variables
   bool buySignal = false;
   bool sellSignal = false;
   string signalType = "";
   
   // Store current ATR and band values for display and for future use
   double currentATR = 0;
   double currentUpperBand = 0;
   double currentLowerBand = 0;
   
   //--- Process data for ATR Bands
   for(int i = 0; i < count-2 && !IsStopped(); i++)
   {
      // For each position, use the ATR and close from previous candle
      double prev_atr1 = atr_values[i+1];
      double prev_close1 = close_values[i+1];
      
      // Store ATR and band values for most recent bar
      if(i == 0)
      {
         currentATR = prev_atr1;
         currentUpperBand = prev_close1 + (prev_atr1 * ATR_Multiplier);
         currentLowerBand = prev_close1 - (prev_atr1 * ATR_Multiplier);
         
         // Save these values globally for use between ticks
         g_currentATR = currentATR;
         g_currentUpperBand = currentUpperBand;
         g_currentLowerBand = currentLowerBand;
      }
      
      double prev_atr2 = atr_values[i+2];
      double prev_close2 = close_values[i+2];
      
      // Calculate band values for current and next point
      double upper_band1 = prev_close1 + (prev_atr1 * ATR_Multiplier);
      double lower_band1 = prev_close1 - (prev_atr1 * ATR_Multiplier);
      
      double upper_band2 = prev_close2 + (prev_atr2 * ATR_Multiplier);
      double lower_band2 = prev_close2 - (prev_atr2 * ATR_Multiplier);
      
      // Only create visual objects when not in optimization mode
      if(!g_isOptimization)
      {
         // Create line for upper band segment
         string upper_name = "ATRBand_Upper_" + IntegerToString(i);
         if(!ObjectCreate(0, upper_name, OBJ_TREND, 0, time_values[i], upper_band1, time_values[i+1], upper_band2))
         {
            Print("Failed to create upper band line: ", GetLastError());
            continue;
         }
         
         // Set upper band line properties
         ObjectSetInteger(0, upper_name, OBJPROP_COLOR, UpperBandColor);
         ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, upper_name, OBJPROP_WIDTH, LineWidth);
         ObjectSetInteger(0, upper_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, upper_name, OBJPROP_RAY_LEFT, false);
         
         // Create line for lower band segment
         string lower_name = "ATRBand_Lower_" + IntegerToString(i);
         if(!ObjectCreate(0, lower_name, OBJ_TREND, 0, time_values[i], lower_band1, time_values[i+1], lower_band2))
         {
            Print("Failed to create lower band line: ", GetLastError());
            continue;
         }
         
         // Set lower band line properties
         ObjectSetInteger(0, lower_name, OBJPROP_COLOR, LowerBandColor);
         ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lower_name, OBJPROP_WIDTH, LineWidth);
         ObjectSetInteger(0, lower_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lower_name, OBJPROP_RAY_LEFT, false);
      }
      
      // Add trading signals based on price closing beyond bands
      // Skip the current forming candle (i=0) and only check completed candles
      if(i > 0)
      {
         // Get candle data
         double candle_close = close_values[i];
         double candle_high = high_values[i];
         double candle_low = low_values[i];
         
         // Method 1: Breakout signals (close beyond bands)
         // Check if close is above upper band from previous candle
         if(candle_close > upper_band1)
         {
            // Create visual signal only when not in optimization mode
            if(!g_isOptimization)
            {
               // Create buy signal (breakout)
               string signal_name = "ATRSignal_BreakoutBuy_" + IntegerToString(i);
               if(!ObjectCreate(0, signal_name, OBJ_ARROW_BUY, 0, time_values[i], candle_close))
               {
                  Print("Failed to create buy breakout signal: ", GetLastError());
               }
               else
               {
                  // Set signal properties
                  ObjectSetInteger(0, signal_name, OBJPROP_COLOR, BuySignalColor);
                  ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, SignalSize);
                  ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
               }
            }
            
            // Set trading signal if this is the most recent completed bar
            // Only consider breakout signals if configured to do so
            if(i == 1 && !lastSignalProcessed && 
               (SignalType == SIGNAL_TYPE_BREAKOUT || SignalType == SIGNAL_TYPE_BOTH))
            {
               buySignal = true;
               signalType = "Breakout Buy";
            }
         }
         
         // Check if close is below lower band from previous candle
         if(candle_close < lower_band1)
         {
            // Create visual signal only when not in optimization mode
            if(!g_isOptimization)
            {
               // Create sell signal (breakout)
               string signal_name = "ATRSignal_BreakoutSell_" + IntegerToString(i);
               if(!ObjectCreate(0, signal_name, OBJ_ARROW_SELL, 0, time_values[i], candle_close))
               {
                  Print("Failed to create sell breakout signal: ", GetLastError());
               }
               else
               {
                  // Set signal properties
                  ObjectSetInteger(0, signal_name, OBJPROP_COLOR, SellSignalColor);
                  ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, SignalSize);
                  ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_TOP);
               }
            }
            
            // Set trading signal if this is the most recent completed bar
            // Only consider breakout signals if configured to do so
            if(i == 1 && !lastSignalProcessed && 
               (SignalType == SIGNAL_TYPE_BREAKOUT || SignalType == SIGNAL_TYPE_BOTH))
            {
               sellSignal = true;
               signalType = "Breakout Sell";
            }
         }
         
         // Method 2: Touch signals (touch but close inside bands)
         // Check if candle touched upper band but closed below it
         if(candle_high >= upper_band1 && candle_close < upper_band1)
         {
            // Create visual signal only when not in optimization mode
            if(!g_isOptimization)
            {
               // Create sell signal (touch) - using SELL icon like breakout
               string signal_name = "ATRSignal_TouchSell_" + IntegerToString(i);
               // Place at close price instead of high
               if(!ObjectCreate(0, signal_name, OBJ_ARROW_SELL, 0, time_values[i], candle_close))
               {
                  Print("Failed to create sell touch signal: ", GetLastError());
               }
               else
               {
                  // Set signal properties
                  ObjectSetInteger(0, signal_name, OBJPROP_COLOR, SellTouchColor);
                  ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, SignalSize);
                  ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_TOP);
               }
            }
            
            // Set trading signal if this is the most recent completed bar
            // Only consider touch signals if configured to do so
            if(i == 1 && !lastSignalProcessed && 
               (SignalType == SIGNAL_TYPE_TOUCH || SignalType == SIGNAL_TYPE_BOTH))
            {
               sellSignal = true;
               signalType = "Touch Sell";
            }
         }
         
         // Check if candle touched lower band but closed above it
         if(candle_low <= lower_band1 && candle_close > lower_band1)
         {
            // Create visual signal only when not in optimization mode
            if(!g_isOptimization)
            {
               // Create buy signal (touch) - using BUY icon like breakout
               string signal_name = "ATRSignal_TouchBuy_" + IntegerToString(i);
               // Place at close price instead of low
               if(!ObjectCreate(0, signal_name, OBJ_ARROW_BUY, 0, time_values[i], candle_close))
               {
                  Print("Failed to create buy touch signal: ", GetLastError());
               }
               else
               {
                  // Set signal properties
                  ObjectSetInteger(0, signal_name, OBJPROP_COLOR, BuyTouchColor);
                  ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, SignalSize);
                  ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
               }
            }
            
            // Set trading signal if this is the most recent completed bar
            // Only consider touch signals if configured to do so
            if(i == 1 && !lastSignalProcessed && 
               (SignalType == SIGNAL_TYPE_TOUCH || SignalType == SIGNAL_TYPE_BOTH))
            {
               buySignal = true;
               signalType = "Touch Buy";
            }
         }
      }
   }
   
   // Execute trades based on signals - this happens regardless of optimization mode
   if(!lastSignalProcessed)
   {
      if(buySignal)
      {
         ExecuteBuy(signalType);
         lastSignalProcessed = true;
      }
      else if(sellSignal)
      {
         ExecuteSell(signalType);
         lastSignalProcessed = true;
      }
   }
   
   // At the end of processing, store the current signal flags globally
   g_currentBuySignal = buySignal;
   g_currentSellSignal = sellSignal;
   g_currentSignalType = signalType;
   
   // Only update visual elements when not in optimization mode
   if(!g_isOptimization)
   {
      // Display chart information
      UpdatePanel(currentATR, currentUpperBand, currentLowerBand, buySignal, sellSignal, signalType);
      
      // Display ATR value as a label
      string atr_label = "ATRBand_Value";
      string atr_text = "ATR(" + IntegerToString(ATR_Period) + "): " + DoubleToString(atr_values[1], _Digits);
      
      if(ObjectFind(0, atr_label) < 0) 
      {
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
      
      //--- Update the chart
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Custom function to copy price values                             |
//+------------------------------------------------------------------+
int CopyPrice(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, ENUM_APPLIED_PRICE price_type, double &array[])
{
   switch(price_type)
   {
      case PRICE_CLOSE:  return CopyClose(symbol, timeframe, start_pos, count, array);
      case PRICE_OPEN:   return CopyOpen(symbol, timeframe, start_pos, count, array);
      case PRICE_HIGH:   return CopyHigh(symbol, timeframe, start_pos, count, array);
      case PRICE_LOW:    return CopyLow(symbol, timeframe, start_pos, count, array);
      case PRICE_MEDIAN: 
         {
            double high[], low[];
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);
            ArrayResize(high, count);
            ArrayResize(low, count);
            
            if(CopyHigh(symbol, timeframe, start_pos, count, high) <= 0) return 0;
            if(CopyLow(symbol, timeframe, start_pos, count, low) <= 0) return 0;
            
            for(int i = 0; i < count; i++)
               array[i] = (high[i] + low[i]) / 2.0;
               
            return count;
         }
      case PRICE_TYPICAL:
         {
            double high[], low[], close[];
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);
            ArraySetAsSeries(close, true);
            ArrayResize(high, count);
            ArrayResize(low, count);
            ArrayResize(close, count);
            
            if(CopyHigh(symbol, timeframe, start_pos, count, high) <= 0) return 0;
            if(CopyLow(symbol, timeframe, start_pos, count, low) <= 0) return 0;
            if(CopyClose(symbol, timeframe, start_pos, count, close) <= 0) return 0;
            
            for(int i = 0; i < count; i++)
               array[i] = (high[i] + low[i] + close[i]) / 3.0;
               
            return count;
         }
      default: return CopyClose(symbol, timeframe, start_pos, count, array);
   }
}
