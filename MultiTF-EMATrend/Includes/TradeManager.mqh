//+------------------------------------------------------------------+
//|                                                TradeManager.mqh  |
//|                           Copyright 2025, Jivita Expert Advisors |
//|                                            by Malinda Rasingolla |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jivita Expert Advisors"
#property version   "1.00"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Class to manage trading operations for MultiTF-EmaTrend          |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade            m_trade;
   int               m_magic_number;
   string            m_trade_comment;
   bool              m_trading_enabled;
   double            m_lot_size;
   
   // Position tracking
   bool              m_has_position;
   bool              m_is_long;
   
   // Get current position info for this EA
   bool              GetPositionInfo();
   
public:
                     CTradeManager();
                     ~CTradeManager();
                     
   // Initialize with parameters                  
   void              Init(int magic, bool enabled, double lots);
   
   // Process trading signals
   void              ProcessSignal(int signalType);
   
   // Open a new position
   bool              OpenPosition(bool isBuy);
   
   // Close any existing positions
   bool              CloseAllPositions();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_magic_number = 123456;
   m_trade_comment = "MultiTF-EmaTrend";
   m_trading_enabled = true;
   m_lot_size = 0.01;
   
   m_has_position = false;
   m_is_long = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
   // Nothing to clean up
}

//+------------------------------------------------------------------+
//| Initialize the trade manager                                     |
//+------------------------------------------------------------------+
void CTradeManager::Init(int magic, bool enabled, double lots)
{
   m_magic_number = magic;
   m_trading_enabled = enabled;
   m_lot_size = lots;
   
   // Set up the trade object
   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   
   // Check if we already have a position (in case of EA restart)
   GetPositionInfo();
}

//+------------------------------------------------------------------+
//| Get current position information                                 |
//+------------------------------------------------------------------+
bool CTradeManager::GetPositionInfo()
{
   m_has_position = false;
   m_is_long = false;
   
   // Loop through positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      // Get position by index
      if(PositionGetSymbol(i) != Symbol()) continue;
      
      // Check if this position belongs to our EA
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;
      
      // We found a position belonging to our EA
      m_has_position = true;
      m_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Process trading signal                                           |
//+------------------------------------------------------------------+
void CTradeManager::ProcessSignal(int signalType)
{
   // Skip if trading is disabled
   if(!m_trading_enabled) return;
   
   // Check current position status
   GetPositionInfo();
   
   // signalType: 0 = buy signal, 1 = sell signal
   bool isBuySignal = (signalType == 0);
   
   // If we have a position, check if we need to close it
   if(m_has_position)
   {
      // Close long position on sell signal
      if(m_is_long && !isBuySignal)
      {
         Print("Closing BUY position on SELL signal");
         CloseAllPositions();
      }
      // Close short position on buy signal
      else if(!m_is_long && isBuySignal)
      {
         Print("Closing SELL position on BUY signal");
         CloseAllPositions();
      }
   }
   
   // Open a new position if we don't have one or closed the opposite one
   if(!m_has_position)
   {
      OpenPosition(isBuySignal);
   }
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPosition(bool isBuy)
{
   // Skip if trading is disabled
   if(!m_trading_enabled) return false;
   
   bool result = false;
   
   if(isBuy)
   {
      result = m_trade.Buy(m_lot_size, Symbol(), 0, 0, 0, m_trade_comment);
      if(result)
      {
         Print("BUY position opened successfully");
         m_has_position = true;
         m_is_long = true;
      }
      else
      {
         Print("Failed to open BUY position. Error: ", GetLastError());
      }
   }
   else
   {
      result = m_trade.Sell(m_lot_size, Symbol(), 0, 0, 0, m_trade_comment);
      if(result)
      {
         Print("SELL position opened successfully");
         m_has_position = true;
         m_is_long = false;
      }
      else
      {
         Print("Failed to open SELL position. Error: ", GetLastError());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
   bool result = true;
   int total = PositionsTotal();
   
   // Loop through positions in reverse order (to safely remove them)
   for(int i = total - 1; i >= 0; i--)
   {
      // Select position
      if(PositionGetSymbol(i) != Symbol()) continue;
      
      // Check if this position belongs to our EA
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;
      
      // Close position
      ulong ticket = PositionGetTicket(i);
      if(!m_trade.PositionClose(ticket))
      {
         Print("Failed to close position #", ticket, ". Error: ", GetLastError());
         result = false;
      }
   }
   
   if(result)
   {
      m_has_position = false;
   }
   
   return result;
}
