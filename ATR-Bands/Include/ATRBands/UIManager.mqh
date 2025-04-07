//+------------------------------------------------------------------+
//|                                                  UIManager.mqh   |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include "Settings.mqh"
#include "ATRIndicator.mqh"
#include "SignalDetector.mqh"
#include "TradeManager.mqh"

// Define constants for panel dimensions and styling
#define PANEL_NAME "ATRPanel"
#define PANEL_TITLE "ATR Bands"
#define PANEL_X 20
#define PANEL_Y 20
#define PANEL_WIDTH 300
#define PANEL_HEIGHT_INITIAL 460
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

//+------------------------------------------------------------------+
//| Class to manage the EA's user interface                          |
//+------------------------------------------------------------------+
class UIManager
{
private:
    EASettings* m_settings;
    ATRIndicator* m_atrIndicator;
    SignalDetector* m_signalDetector;
    TradeManager* m_tradeManager;
    
    // Panel objects tracking
    string m_panelObjects[];
    int m_panelObjectCount;
    int m_currentPanelHeight;
    bool m_panelInitialized;
    
    // Add minimized state tracking
    bool m_isPanelMinimized;
    int m_titleBarHeight;
    
    // Panel position variables - added to fix compilation errors
    int m_panelX;
    int m_panelY;
    
    // Panel dragging related variables
    bool m_isDragging;
    int m_dragStartX;
    int m_dragStartY;
    
    // Add performance tracking variables
    datetime m_lastUpdateTime;
    bool m_needsFullRedraw;
    
    // Add object to panel tracking array
    void AddPanelObject(string objName) {
        m_panelObjectCount++;
        ArrayResize(m_panelObjects, m_panelObjectCount);
        m_panelObjects[m_panelObjectCount - 1] = objName;
    }
    
    // Remove all panel objects
    void RemoveAllPanelObjects() {
        ObjectsDeleteAll(0, PANEL_NAME);
        m_panelObjectCount = 0;
        ArrayResize(m_panelObjects, m_panelObjectCount);
    }
    
    // Create a label on the panel
    void CreatePanelLabel(string name, string text, int x, int y, int fontSize, color textColor, bool isBold=false) {
        if(MQLInfoInteger(MQL_TESTER)) return;
        
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        
        AddPanelObject(name);
    }
    
    // Create a line on the panel
    void CreatePanelLine(string name, int x1, int y1, int x2, int y2, color lineColor) {
        if(MQLInfoInteger(MQL_TESTER)) return;
        
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
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
    
    // Create a section header in the panel
    void CreateSectionHeaderStatic(string title, int &y) {
        y += SECTION_SPACING;
        
        // Create the header text
        string labelName = PANEL_NAME + "_" + title;
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, m_panelX + PANEL_PADDING);
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
                       m_panelX + PANEL_PADDING, 
                       y, 
                       m_panelX + PANEL_WIDTH - PANEL_PADDING, 
                       y, 
                       HEADER_COLOR);
        
        y += 5;
    }
    
    // Create paired labels for info rows
    void CreateInfoLabelPair(string label, string initialValue, int &y) {
        // Create label text
        string labelName = PANEL_NAME + "_Label_" + label;
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, m_panelX + PANEL_PADDING);
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
        ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, m_panelX + PANEL_PADDING + 150);
        ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, valueName, OBJPROP_COLOR, TEXT_COLOR);
        ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, valueName, OBJPROP_FONT, "Arial");
        ObjectSetString(0, valueName, OBJPROP_TEXT, initialValue);
        ObjectSetInteger(0, valueName, OBJPROP_HIDDEN, true);
        AddPanelObject(valueName);
        
        y += 16 + LINE_SPACING;
    }
    
    // Update an existing info label value
    void UpdateInfoValue(string label, string value, color valueColor = TEXT_COLOR) {
        string valueName = PANEL_NAME + "_Value_" + label;
        if (ObjectFind(0, valueName) >= 0) {
            ObjectSetString(0, valueName, OBJPROP_TEXT, value);
            ObjectSetInteger(0, valueName, OBJPROP_COLOR, valueColor);
        }
    }
    
    // Update panel height based on content
    void UpdatePanelHeight(int contentHeight) {
        // Make sure we're using a reasonable minimum height
        int minHeight = PANEL_HEIGHT_INITIAL;
        int newHeight = MathMax(contentHeight, minHeight);
        
        // Only update if height has changed
        if(newHeight != m_currentPanelHeight) {
            m_currentPanelHeight = newHeight;
            
            // Update the background rectangle (only if not minimized)
            string objName = PANEL_NAME + "_BG";
            if(ObjectFind(0, objName) >= 0 && !m_isPanelMinimized) {
                ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_currentPanelHeight);
            }
        }
    }
    
    // Create the panel structure with optimized object creation
    void CreatePanelStructure() {
        // Start performance optimization - disable chart redraws during bulk creation
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Remove any existing panel
        RemoveAllPanelObjects();
        
        // Initialize minimized state
        m_isPanelMinimized = false;
        m_titleBarHeight = PANEL_PADDING * 2 + 25; // Height of title bar
        m_needsFullRedraw = true;
        
        // Create main panel background - height will be updated later
        string objName = PANEL_NAME + "_BG";
        ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, m_panelX);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, m_panelY);
        ObjectSetInteger(0, objName, OBJPROP_XSIZE, PANEL_WIDTH);
        ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_currentPanelHeight);
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
        CreatePanelLabel(PANEL_NAME + "_Title", PANEL_TITLE, m_panelX + PANEL_PADDING, m_panelY + PANEL_PADDING, 14, TITLE_COLOR, true);
        
        // Add minimize button - positioned at right side of title bar
        string btnName = PANEL_NAME + "_MinimizeBtn";
        int btnSize = 16;
        int btnX = m_panelX + PANEL_WIDTH - PANEL_PADDING - btnSize;
        int btnY = m_panelY + PANEL_PADDING;
        
        ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, btnX);
        ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, btnY);
        ObjectSetInteger(0, btnName, OBJPROP_XSIZE, btnSize);
        ObjectSetInteger(0, btnName, OBJPROP_YSIZE, btnSize);
        ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, PANEL_BACKGROUND_COLOR);
        ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, TITLE_COLOR);
        ObjectSetInteger(0, btnName, OBJPROP_COLOR, TITLE_COLOR);
        ObjectSetString(0, btnName, OBJPROP_TEXT, "-");
        ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 12);
        ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
        AddPanelObject(btnName);
        
        // Add divider line below title
        CreatePanelLine(PANEL_NAME + "_TitleLine", 
                      m_panelX + PANEL_PADDING, 
                      m_panelY + PANEL_PADDING + 25, 
                      m_panelX + PANEL_WIDTH - PANEL_PADDING, 
                      m_panelY + PANEL_PADDING + 25, 
                      HEADER_COLOR);
        
        // Starting Y position for content (after title)
        int y = m_panelY + PANEL_PADDING + 30;
        
        // Create section headers and labels for all sections
        
        // --- ATR Information Section ---
        CreateSectionHeaderStatic("ATR Information", y);
        
        // Create labels for ATR section
        CreateInfoLabelPair("ATR Period", IntegerToString(m_settings.atrPeriod), y);
        CreateInfoLabelPair("ATR Multiplier", DoubleToString(m_settings.atrMultiplier, 2), y);
        CreateInfoLabelPair("Current ATR Value", "0", y);
        CreateInfoLabelPair("Upper Band", "0", y);
        CreateInfoLabelPair("Lower Band", "0", y);
        
        // --- Signal Information Section ---
        CreateSectionHeaderStatic("Signal Information", y);
        
        // Create labels for signal section - simplified to show only Touch signals
        CreateInfoLabelPair("Signal Type", "Touch Only", y);
        CreateInfoLabelPair("Current Signal", "None", y);
        
        // --- Trade Settings Section ---
        CreateSectionHeaderStatic("Trade Settings", y);
        
        // Create labels for trade settings
        CreateInfoLabelPair("Trading Enabled", m_settings.tradingEnabled ? "ENABLED" : "DISABLED", y);
        CreateInfoLabelPair("Target Profit", (m_settings.targetProfitPercent > 0.0) ? 
                      DoubleToString(m_settings.targetProfitPercent, 2) + "%" : "Disabled", y);
        CreateInfoLabelPair("Stop Loss %", (m_settings.stopLossPercent > 0.0) ? 
                      DoubleToString(m_settings.stopLossPercent, 2) + "%" : "Disabled", y);
        CreateInfoLabelPair("Magic Number", IntegerToString(m_settings.magicNumber), y);
        CreateInfoLabelPair("Risk Percentage", DoubleToString(m_settings.riskPercentage, 2) + "%", y);
        CreateInfoLabelPair("Stop Loss", IntegerToString(m_settings.stopLossPips) + " pips", y);
        CreateInfoLabelPair("Risk/Reward", DoubleToString(m_settings.riskRewardRatio, 1), y);
        CreateInfoLabelPair("Take Profit", m_settings.useTakeProfit ? "Enabled" : "Disabled", y);
        
        // --- Profit Information Section ---
        CreateSectionHeaderStatic("Profit Information", y);
        
        // Create labels for profit information
        CreateInfoLabelPair("Current Positions Profit", "0.00", y);
        CreateInfoLabelPair("Cumulative Closed Profit", "0.00", y);
        CreateInfoLabelPair("Total Profit", "0.00", y);
        CreateInfoLabelPair("Total Completed Trades", "0", y);
        
        // Re-enable chart object creation events
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        
        // Force a single redraw at the end
        ChartRedraw();
    }
    
    // Toggle panel minimized state with optimized rendering
    void ToggleMinimizedState() {
        m_isPanelMinimized = !m_isPanelMinimized;
        
        // Change button text based on state
        string btnName = PANEL_NAME + "_MinimizeBtn";
        if(ObjectFind(0, btnName) >= 0) {
            ObjectSetString(0, btnName, OBJPROP_TEXT, m_isPanelMinimized ? "+" : "-");
        }
        
        // Temporarily disable object create events for faster handling
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Update panel height based on minimized state
        string objName = PANEL_NAME + "_BG";
        if(m_isPanelMinimized) {
            // Set panel to just show title bar
            ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_titleBarHeight);
            
            // Use a more efficient way to hide objects - hide all at once
            for(int i = 0; i < m_panelObjectCount; i++) {
                string name = m_panelObjects[i];
                
                // Skip title bar objects
                if(StringFind(name, PANEL_NAME + "_Title") >= 0 || 
                   StringFind(name, PANEL_NAME + "_MinimizeBtn") >= 0 ||
                   name == PANEL_NAME + "_BG" ||
                   name == PANEL_NAME + "_TitleLine") {
                    continue;
                }
                
                if(ObjectFind(0, name) >= 0) {
                    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                }
            }
        } else {
            // Restore full panel height
            ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_currentPanelHeight);
            
            // Show all objects at once
            for(int i = 0; i < m_panelObjectCount; i++) {
                string name = m_panelObjects[i];
                if(ObjectFind(0, name) >= 0) {
                    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                }
            }
        }
        
        // Re-enable object creation events
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        
        // Force a single redraw
        ChartRedraw();
    }
    
    // Hide or show all panel content objects (except title bar elements)
    void HidePanelContentObjects(bool hide) {
        for(int i = 0; i < m_panelObjectCount; i++) {
            string objName = m_panelObjects[i];
            
            // Skip title bar objects
            if(StringFind(objName, PANEL_NAME + "_Title") >= 0 || 
               StringFind(objName, PANEL_NAME + "_MinimizeBtn") >= 0 ||
               objName == PANEL_NAME + "_BG") {
                continue;
            }
            
            if(ObjectFind(0, objName) >= 0) {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, hide ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
            }
        }
    }
    
    // Update position section display
    void UpdatePositionSection(int &y) {
        // Clean up previous position section
        ObjectsDeleteAll(0, PANEL_NAME + "_Open Positions");
        ObjectsDeleteAll(0, PANEL_NAME + "_Pos");
        
        // Remove position-related objects from tracking
        for (int i = 0; i < m_panelObjectCount; i++) {
            if (StringFind(m_panelObjects[i], PANEL_NAME + "_Pos") >= 0 || 
                StringFind(m_panelObjects[i], PANEL_NAME + "_Open Positions") >= 0 ||
                StringFind(m_panelObjects[i], PANEL_NAME + "_Value_Pos") >= 0 ||
                StringFind(m_panelObjects[i], PANEL_NAME + "_Label_Pos") >= 0) {
                ObjectDelete(0, m_panelObjects[i]);
                m_panelObjects[i] = "";  // Mark for cleanup
            }
        }
        
        // Remove empty entries from the object list
        int newCount = 0;
        for (int i = 0; i < m_panelObjectCount; i++) {
            if (m_panelObjects[i] != "") {
                if (i != newCount) {
                    m_panelObjects[newCount] = m_panelObjects[i];
                }
                newCount++;
            }
        }
        
        // Update panel object count
        if (newCount != m_panelObjectCount) {
            m_panelObjectCount = newCount;
            ArrayResize(m_panelObjects, m_panelObjectCount);
        }
        
        // Count positions for this symbol and Magic Number
        int openPositionsCount = 0;
        for (int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && 
                PositionGetString(POSITION_SYMBOL) == _Symbol && 
                PositionGetInteger(POSITION_MAGIC) == m_settings.magicNumber) {
                openPositionsCount++;
            }
        }
        
        // Create position section only if there are positions
        if (openPositionsCount > 0) {
            // Create section header
            CreateSectionHeaderStatic("Open Positions", y);
            
            int posCount = 0;
            for (int i = 0; i < PositionsTotal(); i++) {
                ulong ticket = PositionGetTicket(i);
                if (PositionSelectByTicket(ticket) && 
                    PositionGetString(POSITION_SYMBOL) == _Symbol &&
                    PositionGetInteger(POSITION_MAGIC) == m_settings.magicNumber) {
                    
                    string posType = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
                    double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
                    double posSL = PositionGetDouble(POSITION_SL);
                    double posTP = PositionGetDouble(POSITION_TP);
                    double posProfit = PositionGetDouble(POSITION_PROFIT);
                    
                    color posColor = (posType == "BUY") ? SIGNAL_BUY_COLOR : SIGNAL_SELL_COLOR;
                    color profitColor = (posProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
                    
                    // Show position info
                    string posTypeLabel = PANEL_NAME + "_Pos" + IntegerToString(posCount) + "_Type";
                    ObjectCreate(0, posTypeLabel, OBJ_LABEL, 0, 0, 0);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_XDISTANCE, m_panelX + PANEL_PADDING);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_YDISTANCE, y);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_COLOR, posColor);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_FONTSIZE, 9);
                    ObjectSetString(0, posTypeLabel, OBJPROP_FONT, "Arial");
                    ObjectSetString(0, posTypeLabel, OBJPROP_TEXT, "#" + IntegerToString(ticket) + ": " + posType);
                    ObjectSetInteger(0, posTypeLabel, OBJPROP_HIDDEN, true);
                    AddPanelObject(posTypeLabel);
                    y += 16;
                    
                    // Create position detail labels
                    string entryLabel = "Pos" + IntegerToString(posCount) + "_Entry";
                    string slLabel = "Pos" + IntegerToString(posCount) + "_SL";
                    string tpLabel = "Pos" + IntegerToString(posCount) + "_TP";
                    string profitLabel = "Pos" + IntegerToString(posCount) + "_Profit";
                    
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
                    posCount++;
                }
            }
        }
    }
    
    // Update panel content with current information - optimized
    void UpdatePanelContent() {
        if (!m_panelInitialized) return;
        
        // Skip frequent updates - limit to once per 250ms
        if(TimeCurrent() - m_lastUpdateTime < 0.25 && !m_needsFullRedraw) return;
        
        m_lastUpdateTime = TimeCurrent();
        m_needsFullRedraw = false;
        
        // Temporarily disable object create events for faster handling
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Get current values
        double atrValue = m_atrIndicator.GetCurrentATR();
        double upperBand = m_atrIndicator.GetUpperBand();
        double lowerBand = m_atrIndicator.GetLowerBand();
        
        // Get current signal
        SignalInfo currentSignal = m_signalDetector.GetCurrentSignal();
        
        // Get current profits
        double currentProfit = m_tradeManager.CalculateTotalProfit();
        double cumulativeProfit = m_tradeManager.GetCumulativeProfit();
        double totalProfit = currentProfit + cumulativeProfit;
        
        // Update ATR Information section
        UpdateInfoValue("Current ATR Value", DoubleToString(atrValue, 5));
        UpdateInfoValue("Upper Band", DoubleToString(upperBand, 5));
        UpdateInfoValue("Lower Band", DoubleToString(lowerBand, 5));
        
        // Update Signal Information section - Always show "Touch Only"
        UpdateInfoValue("Signal Type", "Touch Only");
        
        // Update the signal display
        color signalColor = TEXT_COLOR;
        string signalText = "None";
        
        if (currentSignal.hasSignal) {
            signalText = currentSignal.isBuySignal ? 
                       "BUY (Touch)" : 
                       "SELL (Touch)";
            signalColor = currentSignal.isBuySignal ? m_settings.buyTouchColor : m_settings.sellTouchColor;
        }
        
        UpdateInfoValue("Current Signal", signalText, signalColor);
        
        // Update Trade Settings section
        string tradingStatus;
        color tradingStatusColor = TEXT_COLOR;
        
        if (m_settings.targetReached) {
            tradingStatus = "DISABLED (Target Reached)";
            tradingStatusColor = PROFIT_POSITIVE_COLOR;
        }
        else if (m_settings.stopLossReached) {
            tradingStatus = "DISABLED (Stop Loss Reached)";
            tradingStatusColor = PROFIT_NEGATIVE_COLOR;
        }
        else if (!m_settings.tradingEnabled) {
            tradingStatus = "DISABLED (Manual)";
            tradingStatusColor = TEXT_COLOR;
        }
        else {
            tradingStatus = "ENABLED";
            tradingStatusColor = PROFIT_POSITIVE_COLOR;
        }
        
        UpdateInfoValue("Trading Enabled", tradingStatus, tradingStatusColor);
        
        // Update Profit Information section
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double currentProfitPercentage = 0;
        double totalProfitPercentage = 0;
        
        if (accountBalance > 0) {
            currentProfitPercentage = (currentProfit / accountBalance) * 100.0;
            totalProfitPercentage = (totalProfit / accountBalance) * 100.0;
        }
        
        color currentProfitColor = (currentProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
        color cumulativeProfitColor = (cumulativeProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
        color totalProfitColor = (totalProfit >= 0) ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR;
        
        UpdateInfoValue("Current Positions Profit", 
                      DoubleToString(currentProfit, 2) + " (" + DoubleToString(currentProfitPercentage, 2) + "%)", 
                      currentProfitColor);
                      
        UpdateInfoValue("Cumulative Closed Profit", 
                      DoubleToString(cumulativeProfit, 2), 
                      cumulativeProfitColor);
                      
        UpdateInfoValue("Total Profit", 
                      DoubleToString(totalProfit, 2) + " (" + DoubleToString(totalProfitPercentage, 2) + "%)", 
                      totalProfitColor);
                      
        UpdateInfoValue("Total Completed Trades", 
                      IntegerToString(m_tradeManager.GetTotalTrades()));
                      
        // Calculate where static content ends
        int contentEndY = m_panelY + PANEL_PADDING + 30;  // Start after title
        
        // Skip through sections - this must match layout in CreatePanelStructure
        // ATR Information Section (header + 5 items)
        contentEndY += SECTION_SPACING + 18 + 5;  // Header space
        contentEndY += 5 * (16 + LINE_SPACING);   // 5 items
        
        // Signal Information Section (header + 2 items)
        contentEndY += SECTION_SPACING + 18 + 5;  // Header space
        contentEndY += 2 * (16 + LINE_SPACING);   // 2 items
        
        // Trade Settings Section (header + 8 items)
        contentEndY += SECTION_SPACING + 18 + 5;  // Header space
        contentEndY += 8 * (16 + LINE_SPACING);   // 8 items
        
        // Profit Information Section (header + 4 items)
        contentEndY += SECTION_SPACING + 18 + 5;  // Header space
        contentEndY += 4 * (16 + LINE_SPACING);   // 4 items
        
        // Add extra space before position section
        contentEndY += 10;
        
        // Update position section
        UpdatePositionSection(contentEndY);
        
        // Add padding at bottom
        contentEndY += PANEL_PADDING * 2;
        
        // Update panel height
        UpdatePanelHeight(contentEndY - m_panelY);
        
        // Re-enable object creation events
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        
        // Force a single redraw at the end instead of multiple redraws
        ChartRedraw();
    }
    
    // Update all panel objects' positions when panel is moved - optimized
    void UpdatePanelPosition(int newX, int newY) {
        int deltaX = newX - m_panelX;
        int deltaY = newY - m_panelY;
        
        // Disable object create events temporarily for better performance
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Update all panel objects in a batch
        for(int i = 0; i < m_panelObjectCount; i++) {
            string objName = m_panelObjects[i];
            if(ObjectFind(0, objName) >= 0) {
                int xDistance = (int)ObjectGetInteger(0, objName, OBJPROP_XDISTANCE);
                int yDistance = (int)ObjectGetInteger(0, objName, OBJPROP_YDISTANCE);
                
                ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance + deltaX);
                ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance + deltaY);
            }
        }
        
        // Update the panel position variables
        m_panelX = newX;
        m_panelY = newY;
        
        // Re-enable object creation events
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        
        // Force a single redraw
        ChartRedraw();
    }
    
    // Check if mouse is over panel title bar
    bool IsMouseOverTitleBar(int x, int y) {
        return (x >= m_panelX && x <= m_panelX + PANEL_WIDTH &&
                y >= m_panelY && y <= m_panelY + m_titleBarHeight);
    }
    
    // Create visual signal on chart - fixed arrowCode type
    void CreateSignalArrow(int i, string signalType, bool isBuy, double price, color arrowColor) {
        if (m_settings.isOptimization) return;
        
        string signal_name = "ATRSignal_" + signalType + (isBuy ? "Buy_" : "Sell_") + IntegerToString(i);
        ENUM_OBJECT arrowCode = isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL; // Fix: Use ENUM_OBJECT type
        
        if (ObjectCreate(0, signal_name, arrowCode, 0, m_atrIndicator.GetTime(i), price)) {
            ObjectSetInteger(0, signal_name, OBJPROP_COLOR, arrowColor);
            ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, m_settings.signalSize);
            ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, isBuy ? ANCHOR_BOTTOM : ANCHOR_TOP);
        }
    }
    
public:
    // Constructor with renamed parameters to avoid shadowing
    UIManager(EASettings* p_settings, ATRIndicator* p_atrIndicator, SignalDetector* p_signalDetector, TradeManager* p_tradeManager) {
        m_settings = p_settings;
        m_atrIndicator = p_atrIndicator;
        m_signalDetector = p_signalDetector;
        m_tradeManager = p_tradeManager;
        
        m_panelObjectCount = 0;
        m_currentPanelHeight = PANEL_HEIGHT_INITIAL;
        m_panelInitialized = false;
        m_isPanelMinimized = false;
        m_titleBarHeight = PANEL_PADDING * 2 + 25; // Height of title bar
        
        // Initialize panel position
        m_panelX = 20;  // Default X position
        m_panelY = 20;  // Default Y position
        
        // Initialize dragging variables
        m_isDragging = false;
        m_dragStartX = 0;
        m_dragStartY = 0;
        
        // Initialize performance tracking variables
        m_lastUpdateTime = 0;
        m_needsFullRedraw = true;
    }
    
    // Destructor
    ~UIManager() {
        Cleanup();
    }
    
    // Initialize the UI with optimized object creation
    bool Initialize() {
        if (m_settings == NULL || m_atrIndicator == NULL || 
            m_signalDetector == NULL || m_tradeManager == NULL) {
            Print("Cannot initialize UI - missing components");
            return false;
        }
        
        // Don't create UI in optimization mode
        if (m_settings.isOptimization) return true;
        
        // Pre-allocate object array to reduce reallocations
        ArrayResize(m_panelObjects, 100);
        
        // Create panel structure with optimized object handling
        CreatePanelStructure();
        m_panelInitialized = true;
        
        return true;
    }
    
    // Clean up all UI elements
    void Cleanup() {
        if (m_panelInitialized) {
            // Disable object create events temporarily for better performance during cleanup
            ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
            
            RemoveAllPanelObjects();
            m_panelInitialized = false;
            
            // Also ensure all drawings are removed
            ObjectsDeleteAll(0, "ATRBand_");    // Remove all ATR band lines
            ObjectsDeleteAll(0, "ATRSignal_");  // Remove all signal markers
            
            // Re-enable object creation events
            ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
            
            // Clear chart comment
            Comment("");
            
            // Force chart redraw
            ChartRedraw();
        }
    }
    
    // Handle chart events - need to add this to detect button clicks
    bool ProcessChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
        // Handle button clicks
        if(id == CHARTEVENT_OBJECT_CLICK) {
            // Check if our minimize button was clicked
            if(sparam == PANEL_NAME + "_MinimizeBtn") {
                ToggleMinimized();
                return true;
            }
        }
        
        // Handle mouse events for panel dragging
        if(id == CHARTEVENT_MOUSE_MOVE) {
            // Convert mouse coordinates
            int x = (int)lparam;
            int y = (int)dparam;
            
            // Get mouse button state - fix boolean expression issue
            bool leftButtonPressed = ((int)sparam & 1) != 0;
            
            // Handle mouse move with left button pressed (dragging)
            if(leftButtonPressed) { 
                if(m_isDragging) {
                    // Calculate the new panel position
                    int newX = m_panelX + (x - m_dragStartX);
                    int newY = m_panelY + (y - m_dragStartY);
                    
                    // Update panel position
                    UpdatePanelPosition(newX, newY);
                    return true;
                } 
                else if(IsMouseOverTitleBar(x, y)) {
                    // Start dragging
                    m_isDragging = true;
                    m_dragStartX = x;
                    m_dragStartY = y;
                    return true;
                }
            }
            else {
                // Mouse button released - end dragging
                if(m_isDragging) {
                    m_isDragging = false;
                    return true;
                }
            }
        }
        
        return false;
    }
    
    // Public method to toggle minimized state - can be called from OnChartEvent
    void ToggleMinimized() {
        ToggleMinimizedState();
    }
    
    // Update the UI with throttling to prevent excessive updates
    void Update() {
        // Skip all UI operations in strategy tester
        if(MQLInfoInteger(MQL_TESTER) || m_settings.isOptimization) {
            return;
        }
        
        // Make sure panel is initialized
        if(!m_panelInitialized) {
            CreatePanelStructure();
            m_panelInitialized = true;
            m_needsFullRedraw = true;
        }
        
        // Update content - only if panel is not minimized and needs updating
        if(!m_isPanelMinimized) {
            UpdatePanelContent();
        }
    }
};
