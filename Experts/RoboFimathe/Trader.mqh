//+------------------------------------------------------------------+
//|                                                        Trader.mqh |
//|                                             Copyright 2025, Your Name |
//|                                             https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.your-website.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Classe para gerenciar a execução de ordens
class TradeManager
{
private:
   CTrade m_trade;
   ulong  m_magic_number;

public:
   void Init(ulong magic_number)
   {
      m_magic_number = magic_number;
      m_trade.SetExpertMagicNumber(m_magic_number);
      m_trade.SetMarginMode(); // Usa o modo de margem padrão da conta
   }

   bool OpenBuy(string symbol, double volume, double sl, double tp)
   {
      return m_trade.Buy(volume, symbol, 0, sl, tp);
   }

   bool OpenSell(string symbol, double volume, double sl, double tp)
   {
      return m_trade.Sell(volume, symbol, 0, sl, tp);
   }

   int OpenTradesCount()
    {
        int count = 0;
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if (PositionGetInteger(POSITION_MAGIC) == m_magic_number)
            {
                count++;
            }
        }
        return count;
    }
};
