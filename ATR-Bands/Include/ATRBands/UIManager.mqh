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
#define PANEL_Y 30      
#define PANEL_WIDTH 300
#define PANEL_HEIGHT_INITIAL 200
#define PANEL_PADDING 10
#define SECTION_SPACING 8
#define LINE_SPACING 4
#define HEADER_COLOR clrDodgerBlue
#define TITLE_COLOR clrWhite
#define TEXT_COLOR clrLightGray
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
    
    // Minimized state tracking
    bool m_isPanelMinimized;
    int m_titleBarHeight;
    
    // Panel position variables
    int m_panelX;
    int m_panelY;
    
    // Performance tracking variables
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
    
    // Create the panel structure
    void CreatePanelStructure() {
        // Disable chart redraws during bulk creation
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Remove any existing panel
        RemoveAllPanelObjects();
        
        // Initialize minimized state
        m_isPanelMinimized = false;
        m_titleBarHeight = PANEL_PADDING * 2 + 25; // Height of title bar
        m_needsFullRedraw = true;
        
        // Create main panel background
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
        AddPanelObject(objName);
        
        // Add panel title
        CreatePanelLabel(PANEL_NAME + "_Title", PANEL_TITLE, m_panelX + PANEL_PADDING, m_panelY + PANEL_PADDING, 14, TITLE_COLOR, true);
        
        // Add minimize button
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
        
        // Create profit information section only
        CreateSectionHeaderStatic("Profit Information", y);
        
        // Create labels for profit information
        CreateInfoLabelPair("Current Positions Profit", "0.00", y);
        CreateInfoLabelPair("Cumulative Closed Profit", "0.00", y);
        CreateInfoLabelPair("Total Profit", "0.00", y);
        CreateInfoLabelPair("Win Rate", "0%", y);
        CreateInfoLabelPair("Profit Factor", "0.00", y);
        CreateInfoLabelPair("Total Completed Trades", "0", y);
        
        // Re-enable chart object creation events
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        ChartRedraw();
    }
    
    // Toggle panel minimized state
    void ToggleMinimizedState() {
        m_isPanelMinimized = !m_isPanelMinimized;
        
        // Change button text based on state
        string btnName = PANEL_NAME + "_MinimizeBtn";
        if(ObjectFind(0, btnName) >= 0) {
            ObjectSetString(0, btnName, OBJPROP_TEXT, m_isPanelMinimized ? "+" : "-");
        }
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Update panel based on minimized state
        string objName = PANEL_NAME + "_BG";
        if(m_isPanelMinimized) {
            // Set panel to just show title bar
            ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_titleBarHeight);
            
            // Hide all objects except title bar
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
            
            // Show all objects
            for(int i = 0; i < m_panelObjectCount; i++) {
                string name = m_panelObjects[i];
                if(ObjectFind(0, name) >= 0) {
                    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                }
            }
        }
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        ChartRedraw();
    }
    
    // Update panel content with current information
    void UpdatePanelContent() {
        if (!m_panelInitialized) return;
        
        // Throttle updates
        if(TimeCurrent() - m_lastUpdateTime < 0.25 && !m_needsFullRedraw) return;
        
        m_lastUpdateTime = TimeCurrent();
        m_needsFullRedraw = false;
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Get current profits
        double currentProfit = m_tradeManager.CalculateTotalProfit();
        double cumulativeProfit = m_tradeManager.GetCumulativeProfit();
        double totalProfit = currentProfit + cumulativeProfit;
        
        // Update Profit Information section
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double currentProfitPercentage = 0;
        double totalProfitPercentage = 0;
        
        // Get win rate and profit factor
        double winRate = m_tradeManager.GetWinRate();
        double profitFactor = m_tradeManager.GetProfitFactor();
        int winningTrades = m_tradeManager.GetWinningTrades();
        int losingTrades = m_tradeManager.GetLosingTrades();
        
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
        
        // Win Rate with W/L counts
        string winRateText = DoubleToString(winRate, 1) + "% (" + 
                            IntegerToString(winningTrades) + "W/" + 
                            IntegerToString(losingTrades) + "L)";
        UpdateInfoValue("Win Rate", winRateText, winRate >= 50 ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR);
        
        // Profit Factor
        string pfText = DoubleToString(profitFactor, 2);
        UpdateInfoValue("Profit Factor", pfText, profitFactor >= 1.0 ? PROFIT_POSITIVE_COLOR : PROFIT_NEGATIVE_COLOR);
                      
        UpdateInfoValue("Total Completed Trades", 
                       IntegerToString(m_tradeManager.GetTotalTrades()));
        
        // Calculate panel height
        int contentEndY = m_panelY + PANEL_PADDING + 30;  // Start after title bar
        contentEndY += SECTION_SPACING + 18 + 5;  // Header space
        contentEndY += 6 * (16 + LINE_SPACING);   // 6 items
        contentEndY += PANEL_PADDING;  // Bottom padding
        
        // Update panel height
        int minHeight = PANEL_HEIGHT_INITIAL;
        int newHeight = MathMax(contentEndY - m_panelY, minHeight);
        
        if(newHeight != m_currentPanelHeight) {
            m_currentPanelHeight = newHeight;
            
            string objName = PANEL_NAME + "_BG";
            if(ObjectFind(0, objName) >= 0 && !m_isPanelMinimized) {
                ObjectSetInteger(0, objName, OBJPROP_YSIZE, m_currentPanelHeight);
            }
        }
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        ChartRedraw();
    }
    
    // Update panel position when moved
    void UpdatePanelPosition(int newX, int newY) {
        int deltaX = newX - m_panelX;
        int deltaY = newY - m_panelY;
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
        
        // Update all panel objects
        for(int i = 0; i < m_panelObjectCount; i++) {
            string objName = m_panelObjects[i];
            if(ObjectFind(0, objName) >= 0) {
                int xDistance = (int)ObjectGetInteger(0, objName, OBJPROP_XDISTANCE);
                int yDistance = (int)ObjectGetInteger(0, objName, OBJPROP_YDISTANCE);
                
                ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance + deltaX);
                ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance + deltaY);
            }
        }
        
        m_panelX = newX;
        m_panelY = newY;
        
        ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
        ChartRedraw();
    }
    
public:
    // Constructor
    UIManager(EASettings* p_settings, ATRIndicator* p_atrIndicator, SignalDetector* p_signalDetector, TradeManager* p_tradeManager) {
        m_settings = p_settings;
        m_atrIndicator = p_atrIndicator;
        m_signalDetector = p_signalDetector;
        m_tradeManager = p_tradeManager;
        
        m_panelObjectCount = 0;
        m_currentPanelHeight = PANEL_HEIGHT_INITIAL;
        m_panelInitialized = false;
        m_isPanelMinimized = false;
        m_titleBarHeight = PANEL_PADDING * 2 + 25;
        
        m_panelX = PANEL_X;
        m_panelY = PANEL_Y;
        
        m_lastUpdateTime = 0;
        m_needsFullRedraw = true;
    }
    
    // Destructor
    ~UIManager() {
        Cleanup();
    }
    
    // Initialize the UI
    bool Initialize() {
        if (m_settings == NULL || m_atrIndicator == NULL || 
            m_signalDetector == NULL || m_tradeManager == NULL) {
            Print("Cannot initialize UI - missing components");
            return false;
        }
        
        if (m_settings.isOptimization) return true;
        
        ArrayResize(m_panelObjects, 50);
        
        CreatePanelStructure();
        m_panelInitialized = true;
        
        return true;
    }
    
    // Clean up UI elements
    void Cleanup() {
        if (m_panelInitialized) {
            ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, false);
            
            RemoveAllPanelObjects();
            m_panelInitialized = false;
            
            ObjectsDeleteAll(0, "ATRBand_");
            ObjectsDeleteAll(0, "ATRSignal_");
            
            ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
            
            Comment("");
            ChartRedraw();
        }
    }
    
    // Handle chart events
    bool ProcessChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
        if(id == CHARTEVENT_OBJECT_CLICK) {
            if(sparam == PANEL_NAME + "_MinimizeBtn") {
                ToggleMinimized();
                return true;
            }
        }
        
        return false;
    }
    
    // Toggle minimized state
    void ToggleMinimized() {
        ToggleMinimizedState();
    }
    
    // Update the UI
    void Update() {
        if(MQLInfoInteger(MQL_TESTER) || m_settings.isOptimization) {
            return;
        }
        
        if(!m_panelInitialized) {
            CreatePanelStructure();
            m_panelInitialized = true;
            m_needsFullRedraw = true;
        }
        
        if(!m_isPanelMinimized) {
            UpdatePanelContent();
        }
    }
};
