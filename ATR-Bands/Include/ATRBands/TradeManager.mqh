//+------------------------------------------------------------------+
//|                                               TradeManager.mqh   |
//|                                          Copyright 2025, Jivita  |
//|                                           by Malinda Rasingolla  |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Class to manage trading operations                               |
//+------------------------------------------------------------------+
class TradeManager
{
private:
    CTrade m_trade;
    EASettings* m_settings;
    
    // Trading performance tracking
    double m_cumulativeProfit;
    int m_totalTrades;
    ulong m_lastDealTicket;
    
    // New tracking variables for winrate and profit factor
    int m_winningTrades;
    int m_losingTrades;
    double m_totalProfits;
    double m_totalLosses;
    
    // Check if there are any open positions for the symbol
    bool HasOpenPositions() {
        for (int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && 
                PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_MAGIC) == m_settings.magicNumber) {
                return true;
            }
        }
        return false;
    }
    
    // Calculate position size based on risk
    double CalculatePositionSize(double stopLossDistance) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (m_settings.riskPercentage / 100.0);
        
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        
        if (stopLossDistance == 0 || tickSize == 0 || tickValue == 0 || lotStep == 0)
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
    
    // Close positions by type
    void ClosePositions(ENUM_POSITION_TYPE posType) {
        for (int i = PositionsTotal()-1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
                continue;
                
            if (PositionGetString(POSITION_SYMBOL) != _Symbol)
                continue;
                
            if (PositionGetInteger(POSITION_MAGIC) != m_settings.magicNumber)
                continue;
            
            if (PositionGetInteger(POSITION_TYPE) == posType) {
                if (!m_trade.PositionClose(ticket)) {
                    Print("Failed to close position: ", GetLastError());
                } else {
                    Print("Closed position #", ticket);
                }
            }
        }
    }
    
public:
    // Constructor with renamed parameter to avoid shadowing
    TradeManager(EASettings* p_settings) {
        m_settings = p_settings;
        m_cumulativeProfit = 0;
        m_totalTrades = 0;
        m_lastDealTicket = 0;
        
        // Initialize new tracking variables
        m_winningTrades = 0;
        m_losingTrades = 0;
        m_totalProfits = 0;
        m_totalLosses = 0;
        
        // Set Magic Number for trade object
        m_trade.SetExpertMagicNumber(m_settings.magicNumber);
        
        // Restore previous values from global variables if not in optimization
        if (!m_settings.isOptimization) {
            string prefix = "ATR_EA_" + _Symbol + "_" + IntegerToString(m_settings.magicNumber) + "_";
            
            if (GlobalVariableCheck(prefix + "CumulativeProfit")) {
                m_cumulativeProfit = GlobalVariableGet(prefix + "CumulativeProfit");
            }
            
            if (GlobalVariableCheck(prefix + "TotalTrades")) {
                m_totalTrades = (int)GlobalVariableGet(prefix + "TotalTrades");
            }
            
            if (GlobalVariableCheck(prefix + "LastDealTicket")) {
                m_lastDealTicket = (ulong)GlobalVariableGet(prefix + "LastDealTicket");
            }
            
            // Load win/loss statistics
            if (GlobalVariableCheck(prefix + "WinningTrades")) {
                m_winningTrades = (int)GlobalVariableGet(prefix + "WinningTrades");
            }
            
            if (GlobalVariableCheck(prefix + "LosingTrades")) {
                m_losingTrades = (int)GlobalVariableGet(prefix + "LosingTrades");
            }
            
            if (GlobalVariableCheck(prefix + "TotalProfits")) {
                m_totalProfits = GlobalVariableGet(prefix + "TotalProfits");
            }
            
            if (GlobalVariableCheck(prefix + "TotalLosses")) {
                m_totalLosses = GlobalVariableGet(prefix + "TotalLosses");
            }
        }
    }
    
    // Save history state to global variables
    void SaveHistory() {
        if (!m_settings.isOptimization) {
            string prefix = "ATR_EA_" + _Symbol + "_" + IntegerToString(m_settings.magicNumber) + "_";
            
            GlobalVariableSet(prefix + "CumulativeProfit", m_cumulativeProfit);
            GlobalVariableSet(prefix + "TotalTrades", m_totalTrades);
            GlobalVariableSet(prefix + "LastDealTicket", (double)m_lastDealTicket);
            
            // Save win/loss statistics
            GlobalVariableSet(prefix + "WinningTrades", m_winningTrades);
            GlobalVariableSet(prefix + "LosingTrades", m_losingTrades);
            GlobalVariableSet(prefix + "TotalProfits", m_totalProfits);
            GlobalVariableSet(prefix + "TotalLosses", m_totalLosses);
        }
    }
    
    // Check if trading is allowed
    bool CanTrade() const {
        if (!m_settings.tradingEnabled) return false;
        if (m_settings.targetReached) return false;
        if (m_settings.stopLossReached) return false;
        return true;
    }
    
    // Execute a buy order
    bool ExecuteBuy(string signalType) {
        // Check if trading is enabled
        if (!CanTrade()) {
            string reason = "trading disabled";
            if (m_settings.targetReached) reason = "target profit reached";
            if (m_settings.stopLossReached) reason = "stop loss threshold reached";
            Print("Buy signal ignored: ", reason);
            return false;
        }
        
        // Check for existing positions
        if (HasOpenPositions()) return false;
        
        // Close any existing sell positions
        ClosePositions(POSITION_TYPE_SELL);
        
        // Calculate entry and SL/TP levels
        double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double stopLossDistance = m_settings.PipsToPoints(m_settings.stopLossPips);
        double takeProfitDistance = stopLossDistance * m_settings.riskRewardRatio;
        
        double stopLossPrice = entryPrice - stopLossDistance;
        double takeProfitPrice = 0;
        
        if (m_settings.useTakeProfit) {
            takeProfitPrice = entryPrice + takeProfitDistance;
        }
        
        // Calculate position size
        double lotSize = CalculatePositionSize(stopLossDistance);
        
        // Execute the order
        if (!m_trade.Buy(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "ATR Signal: " + signalType)) {
            Print("Error opening Buy order: ", GetLastError());
            return false;
        }
        
        Print("Buy order executed. Signal: ", signalType, 
              ", Lot Size: ", lotSize, 
              ", SL: ", stopLossPrice, 
              ", TP: ", (m_settings.useTakeProfit ? DoubleToString(takeProfitPrice) : "None"));
              
        return true;
    }
    
    // Execute a sell order
    bool ExecuteSell(string signalType) {
        // Check if trading is enabled
        if (!CanTrade()) {
            string reason = "trading disabled";
            if (m_settings.targetReached) reason = "target profit reached";
            if (m_settings.stopLossReached) reason = "stop loss threshold reached";
            Print("Sell signal ignored: ", reason);
            return false;
        }
        
        // Check for existing positions
        if (HasOpenPositions()) return false;
        
        // Close any existing buy positions
        ClosePositions(POSITION_TYPE_BUY);
        
        // Calculate entry and SL/TP levels
        double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double stopLossDistance = m_settings.PipsToPoints(m_settings.stopLossPips);
        double takeProfitDistance = stopLossDistance * m_settings.riskRewardRatio;
        
        double stopLossPrice = entryPrice + stopLossDistance;
        double takeProfitPrice = 0;
        
        if (m_settings.useTakeProfit) {
            takeProfitPrice = entryPrice - takeProfitDistance;
        }
        
        // Calculate position size
        double lotSize = CalculatePositionSize(stopLossDistance);
        
        // Execute the order
        if (!m_trade.Sell(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "ATR Signal: " + signalType)) {
            Print("Error opening Sell order: ", GetLastError());
            return false;
        }
        
        Print("Sell order executed. Signal: ", signalType, 
              ", Lot Size: ", lotSize, 
              ", SL: ", stopLossPrice, 
              ", TP: ", (m_settings.useTakeProfit ? DoubleToString(takeProfitPrice) : "None"));
              
        return true;
    }
    
    // Manually enable trading
    void EnableTrading() {
        m_settings.tradingEnabled = true;
        m_settings.targetReached = false;
        m_settings.stopLossReached = false;
    }
    
    // Manually disable trading
    void DisableTrading() {
        m_settings.tradingEnabled = false;
    }
    
    // Calculate total profit for open positions
    double CalculateTotalProfit() {
        double totalProfit = 0.0;
        
        for (int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && 
                PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_MAGIC) == m_settings.magicNumber) {
                totalProfit += PositionGetDouble(POSITION_PROFIT);
            }
        }
        
        return totalProfit;
    }
    
    // Check profit targets and loss limits - optimized version
    bool CheckProfitLimits() {
        // Add logging to troubleshoot
        static datetime lastCheckTime = 0;
        if(TimeCurrent() - lastCheckTime > 300) { // Log every 5 minutes
            double currentProfit = CalculateTotalProfit();
            double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            Print("Profit check - Current: ", DoubleToString(currentProfit, 2), 
                  ", Cumulative: ", DoubleToString(m_cumulativeProfit, 2),
                  ", Balance: ", DoubleToString(accountBalance, 2));
            lastCheckTime = TimeCurrent();
        }
        
        // Clear any existing error state
        ResetLastError();
        
        // Cache results to avoid multiple calculations
        double currentProfit = CalculateTotalProfit();
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double totalProfit = m_cumulativeProfit + currentProfit;
        
        // Early exit if account balance is zero (prevents division by zero)
        if(accountBalance <= 0.0) return false;
        
        double totalProfitPercentage = (totalProfit / accountBalance) * 100.0;
        bool shouldDisableTrading = false;
        
        // Process target profit condition
        if(m_settings.targetProfitPercent > 0.0) {
            if(totalProfitPercentage >= m_settings.targetProfitPercent) {
                if(m_settings.tradingEnabled) {
                    m_settings.tradingEnabled = false;
                    m_settings.targetReached = true;
                    shouldDisableTrading = true;
                    Print("Target profit of ", m_settings.targetProfitPercent, 
                          "% reached (current: ", DoubleToString(totalProfitPercentage, 2), 
                          "%). Trading automatically disabled.");
                }
            } else if(m_settings.targetReached) {
                // Reset flag but don't re-enable trading automatically
                m_settings.targetReached = false;
            }
        }
        
        // Process stop loss condition
        if(m_settings.stopLossPercent > 0.0) {
            if(totalProfitPercentage <= -m_settings.stopLossPercent) {
                if(m_settings.tradingEnabled) {
                    m_settings.tradingEnabled = false;
                    m_settings.stopLossReached = true;
                    shouldDisableTrading = true;
                    Print("Stop loss threshold of -", m_settings.stopLossPercent, 
                          "% reached (current: ", DoubleToString(totalProfitPercentage, 2), 
                          "%). Trading automatically disabled.");
                }
            } else if(m_settings.stopLossReached) {
                // Reset flag but don't re-enable trading automatically
                m_settings.stopLossReached = false;
            }
        }
        
        // Add state logging if trading gets disabled
        if(shouldDisableTrading) {
            Print("WARNING: Trading automatically disabled - Target/Stop reached");
        }
        
        return shouldDisableTrading;
    }
    
    // Add a method to reset trading state for testing
    void ResetTradingState() {
        m_settings.tradingEnabled = true;
        m_settings.targetReached = false;
        m_settings.stopLossReached = false;
        
        Print("Trade Manager: Trading state reset to enabled");
    }
    
    // Update cumulative profit from history - optimized version
    void UpdateCumulativeProfit() {
        // Early exit if we can't select history
        if(!HistorySelect(m_settings.GetStartTime(), TimeCurrent())) {
            Print("Failed to select history for updating cumulative profit");
            return;
        }
        
        // Use a more efficient approach with bulk processing
        ulong newLastDealTicket = m_lastDealTicket;
        double newProfit = 0.0;
        int newTrades = 0;
        int newWins = 0;
        double newProfits = 0.0;
        double newLosses = 0.0;
        int totalDeals = HistoryDealsTotal();
        
        // First pass: calculate changes without updating state
        for(int i = 0; i < totalDeals; i++) {
            ulong dealTicket = HistoryDealGetTicket(i);
            
            // Skip already processed deals
            if(dealTicket <= m_lastDealTicket) continue;
            
            // Check if this deal belongs to our symbol and Magic Number
            if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
            if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_settings.magicNumber) continue;
            
            // Only count completed trades (position closing)
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                newProfit += profit;
                newTrades++;
                
                // Track wins and losses for winrate calculation
                if(profit >= 0) {
                    newWins++;
                    newProfits += profit;
                } else {
                    newLosses += MathAbs(profit);
                }
                
                // Track highest ticket for next update
                if(dealTicket > newLastDealTicket)
                    newLastDealTicket = dealTicket;
            }
        }
        
        // Second pass: apply changes if we found any new deals
        if(newTrades > 0) {
            m_cumulativeProfit += newProfit;
            m_totalTrades += newTrades;
            m_winningTrades += newWins;
            m_losingTrades += (newTrades - newWins);
            m_totalProfits += newProfits;
            m_totalLosses += newLosses;
            m_lastDealTicket = newLastDealTicket;
            
            // Log the update for debugging
            if(newTrades == 1) {
                Print("Added ", DoubleToString(newProfit, 2), " to cumulative profit from 1 trade");
            } else {
                Print("Added ", DoubleToString(newProfit, 2), " to cumulative profit from ", 
                      IntegerToString(newTrades), " trades");
            }
            
            // Save immediately to prevent data loss
            SaveHistory();
        }
    }
    
    // Handle trade transaction events
    void OnTradeTransaction(const MqlTradeTransaction &trans,
                            const MqlTradeRequest &request,
                            const MqlTradeResult &result) {
        // Look for position close events
        if (trans.type == TRADE_TRANSACTION_DEAL_ADD && 
            (trans.deal_type == DEAL_TYPE_SELL || trans.deal_type == DEAL_TYPE_BUY)) {
            // Update cumulative profit
            UpdateCumulativeProfit();
        }
    }
    
    // Get cumulative profit
    double GetCumulativeProfit() const {
        return m_cumulativeProfit;
    }
    
    // Get total trades count
    int GetTotalTrades() const {
        return m_totalTrades;
    }
    
    // New methods to retrieve win rate and profit factor
    double GetWinRate() const {
        if(m_totalTrades <= 0) return 0;
        return (double)m_winningTrades / m_totalTrades * 100.0;
    }
    
    double GetProfitFactor() const {
        if(m_totalLosses <= 0) return 0;
        return m_totalProfits / m_totalLosses;
    }
    
    int GetWinningTrades() const {
        return m_winningTrades;
    }
    
    int GetLosingTrades() const {
        return m_losingTrades;
    }
};
