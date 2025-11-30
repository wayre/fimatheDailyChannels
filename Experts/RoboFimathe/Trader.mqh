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

   bool PlacePendingOrder(ENUM_ORDER_TYPE type, string symbol, double volume, double price, double sl, double tp)
   {
      // Para ordens pendentes, o preço de stop e take profit é definido na estrutura da requisição
      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action   = TRADE_ACTION_PENDING;
      request.magic    = m_magic_number;
      request.symbol   = symbol;
      request.volume   = volume;
      request.price    = price;
      request.sl       = sl;
      request.tp       = tp;
      request.type     = type;
      request.type_filling = ORDER_FILLING_FOK; // Ou ORDER_FILLING_IOC
      request.deviation = 10; // Slippage permitido
      
      return OrderSend(request, result);
   }

   int OpenTradesCount()
    {
        int count = 0;
        // Contar posições abertas
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            // Seleciona a posição no índice 'i' para poder ler suas propriedades
            if (PositionGetSymbol(i) != "")
            {
                if (PositionGetInteger(POSITION_MAGIC) == m_magic_number)
                {
                    count++;
                }
            }
        }

        // Contar ordens pendentes abertas
        for (int i = OrdersTotal() - 1; i >= 0; i--)
        {
            // Seleciona a ordem no índice 'i' para poder ler suas propriedades
            if (OrderSelect(OrderGetTicket(i)))
            {
                if (OrderGetInteger(ORDER_MAGIC) == m_magic_number)
                {
                    count++;
                }
            }
        }
        return count;
    }
};
