//+------------------------------------------------------------------+
//|                                                    RoboFimathe.mq5 |
//|                                             Copyright 2025, Your Name |
//|                                             https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link "https://www.your-website.com"
#property version "1.00"
#property description "Robo Fimathe - Estratégia de Canal"

//--- Incluir arquivos de configuração e módulos
#include "Config.mqh"
#include "Session.mqh"
#include "Strategy.mqh"
#include "Trader.mqh"
#include <Trade/Trade.mqh> // Inclui a classe CTrade e constantes de negociação

//--- Variáveis globais
SessionManager g_session;
FimatheStrategy g_strategy;
TradeManager g_trader;

//--- Flags para controlar o estado das operações no dia
bool g_initial_trade_executed_today = false;
bool g_reversal_trade_executed_today = false;
ulong g_initial_position_id = 0;  // Armazena o ID da POSIÇÃO inicial
double g_initial_entry_price = 0; // Armazena o preço de entrada da posição inicial
long g_initial_deal_type = -1;    // Armazena o tipo (BUY/SELL) da operação inicial

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //---
    Print("RoboFimathe: Inicializando...");

    //--- Inicializar módulos
    g_session.Init();
    g_strategy.Init(InpTradeSymbol, InpChannelMultiplier);
    g_trader.Init(InpMagicNumber);

    Print("RoboFimathe: Inicialização concluída.");
    //---
    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //---
    Print("RoboFimathe: Desinicializando. Razão: ", reason);
    //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Verificar se está dentro do horário de negociação
    if (!g_session.IsTradingHours())
    {
        return;
    }

    // Se for um novo dia, reseta as flags
    if (g_session.IsNewDay())
    {
        g_initial_trade_executed_today = false;
        g_reversal_trade_executed_today = false;
        g_initial_position_id = 0;
        g_initial_entry_price = 0;
        g_initial_deal_type = -1; // Reseta o tipo da operação inicial
        g_strategy.Reset();
        Print("Resetado para novo dia");
    }

    // Se já há operações abertas, ou se a reversão já ocorreu, não faz mais nada no OnTick
    if (g_trader.OpenTradesCount() > 0 || g_reversal_trade_executed_today)
    {
        return;
    }

    // Se a operação inicial já foi executada, não faz nada
    if (g_initial_trade_executed_today)
    {
        return;
    }

    ENUM_TIMEFRAMES timeframe = g_session.GetTimeframe();

    // Calcula os níveis se ainda não foram calculados
    if (!g_strategy.LevelsAreCalculated())
    {
        g_strategy.CalculateLevels(timeframe);
    }

    // Verifica nova vela para tomar decisões
    if (g_session.IsNewCandle(_Symbol, timeframe))
    {
        MqlRates rates[];
        if (CopyRates(_Symbol, timeframe, 1, 1, rates) < 1)
        {
            return;
        }

        double last_close_price = rates[0].close; // Usa a vela mais recente (corrigido)

        if (g_strategy.CheckBuySignal(last_close_price))
        {
            double current_ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(current_ask_price > g_strategy.getMaximumValueEntrytoBuy())
            {
                ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY_LIMIT; //Quando o preço cair até esse valor, compre
                g_trader.PlacePendingOrder(orderType, InpTradeSymbol, InpLotSize, g_strategy.getMaximumValueEntrytoBuy(), g_strategy.GetBuyStopLoss(), g_strategy.GetBuyTakeProfit());
                g_initial_trade_executed_today = true;
                Print("Ordem de Compra colocada no valor limite");
            }
            else {
                if (g_trader.OpenBuy(InpTradeSymbol, InpLotSize, g_strategy.GetBuyStopLoss(), g_strategy.GetBuyTakeProfit()))
                {
                    g_initial_trade_executed_today = true;
                    Print("Ordem de Compra Inicial Aberta.");
                }
            }
            
        }
        else if (g_strategy.CheckSellSignal(last_close_price))
        {
            double current_bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(current_bid_price < g_strategy.getMaximumValueEntrytoSell())
            {
                ENUM_ORDER_TYPE orderType = ORDER_TYPE_SELL_LIMIT; //Quando o preço subir até esse valor, venda
                g_trader.PlacePendingOrder(orderType, InpTradeSymbol, InpLotSize, g_strategy.getMaximumValueEntrytoSell(), g_strategy.GetSellStopLoss(), g_strategy.GetSellTakeProfit());
                g_initial_trade_executed_today = true;
                Print("Ordem de Venda colocada no valor limite");
            }
            
            if (g_trader.OpenSell(InpTradeSymbol, InpLotSize, g_strategy.GetSellStopLoss(), g_strategy.GetSellTakeProfit()))
            {
                g_initial_trade_executed_today = true;
                Print("Ordem de Venda Inicial Aberta.");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manipulador de Eventos de Transações de Negociação               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // --- LOG DE DEBUG: Mostrar o tipo de transação recebida ---
    Print("Nova transação recebida. Tipo: ", EnumToString(trans.type));

    //--- Apenas nos interessa transações onde um DEAL é ADICIONADO ao histórico
    if (trans.type != TRADE_TRANSACTION_DEAL_ADD)
    {
        Print("Transação ignorada. Motivo: Não é um 'DEAL_ADD'.");
        return;
    }

    Print("Transação 'DEAL_ADD' recebida. Processando...");

    // Tenta carregar o deal no histórico para análise
    if (!HistorySelect(trans.deal, TimeCurrent()))
        return;

    ulong deal_ticket = trans.deal;
    long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

    // Ignora deals que não pertencem a este robô
    if (deal_magic != InpMagicNumber)
        return;

    long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    // --- 1. Rastrear a operação inicial ---
    // Se for um deal de entrada e a primeira operação do dia foi sinalizada, guardamos seus dados.
    if (deal_entry == DEAL_ENTRY_IN && g_initial_trade_executed_today && g_initial_position_id == 0)
    {
        g_initial_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
        g_initial_entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
        g_initial_deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE); // GUARDA O TIPO DA OPERAÇÃO
        Print(StringFormat("Operação inicial rastreada. Posição ID: %d, Preço Entrada: %.5f, Tipo: %s", g_initial_position_id, g_initial_entry_price, EnumToString((ENUM_DEAL_TYPE)g_initial_deal_type)));
        return;
    }

    // --- 2. Verificar se a operação inicial foi fechada por Stop Loss ---
    // Se for um deal de saída, pertence à posição inicial, o motivo for SL e a reversão ainda não ocorreu.
    if (deal_entry == DEAL_ENTRY_OUT &&
        HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == g_initial_position_id &&
        HistoryDealGetInteger(deal_ticket, DEAL_REASON) == DEAL_REASON_SL &&
        !g_reversal_trade_executed_today)
    {
        Print("Stop Loss da operação inicial atingido. Acionando reversão...");
        
        double reversal_entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE); // O preço do stop é a entrada da reversão
        double new_lot_size = InpLotSize * 2;
        double new_sl = 0;
        double new_tp = 0;

        // Se a operação stopada foi uma COMPRA, a reversão é uma VENDA
        if (g_initial_deal_type == DEAL_TYPE_BUY)
        {
            Print("Revertendo Compra -> Abrindo Venda");
            new_sl = g_strategy.GetBuyReversalStopLoss(g_initial_entry_price);
            new_tp = g_strategy.GetBuyReversalTakeProfit(reversal_entry_price);

            if (g_trader.OpenSell(InpTradeSymbol, new_lot_size, new_sl, new_tp))
            {
                g_reversal_trade_executed_today = true;
                Print(StringFormat("Ordem de Reversão (VENDA) aberta. Lote: %.2f, SL: %.5f, TP: %.5f", new_lot_size, new_sl, new_tp));
            }
        }
        // Se a operação stopada foi uma VENDA, a reversão é uma COMPRA
        else if (g_initial_deal_type == DEAL_TYPE_SELL)
        {
            Print("Revertendo Venda -> Abrindo Compra");
            new_sl = g_strategy.GetSellReversalStopLoss(g_initial_entry_price);
            new_tp = g_strategy.GetSellReversalTakeProfit(reversal_entry_price);

            if (g_trader.OpenBuy(InpTradeSymbol, new_lot_size, new_sl, new_tp))
            {
                g_reversal_trade_executed_today = true;
                Print(StringFormat("Ordem de Reversão (COMPRA) aberta. Lote: %.2f, SL: %.5f, TP: %.5f", new_lot_size, new_sl, new_tp));
            }
        }
    }
}
//+------------------------------------------------------------------+
