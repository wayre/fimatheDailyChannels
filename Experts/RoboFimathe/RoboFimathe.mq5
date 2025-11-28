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

//--- Variáveis globais
SessionManager g_session;
FimatheStrategy g_strategy;
TradeManager g_trader;

//--- Flag para controlar se uma operação já foi realizada no dia
bool trade_executed_today = false;

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

    // Se for um novo dia, reseta a flag de trade
    if (g_session.IsNewDay())
    {
        trade_executed_today = false;
        g_strategy.Reset();
        Print("Resetado para novo dia");
    }

    // Se já há operações abertas, não faz nada
    if (g_trader.OpenTradesCount() > 0)
    {
        return;
    }

    // Se já operou hoje, não faz nada
    if (trade_executed_today)
    {
        return;
    }

    ENUM_TIMEFRAMES timeframe = g_session.GetTimeframe();

    // Calcula os níveis se ainda não foram calculados
    bool LevelsNotWentCalculated = !g_strategy.LevelsAreCalculated();
    if (LevelsNotWentCalculated)
    {
        g_strategy.CalculateLevels(timeframe);
    }

    // Verifica nova vela para tomar decisões
    if (g_session.IsNewCandle(_Symbol, timeframe))
    {
        MqlRates rates[];
        if (CopyRates(_Symbol, timeframe, 0, 1, rates) < 1)
        {
            return;
        }

        double current_close_price = rates[0].close;

        if (g_strategy.CheckBuySignal(current_close_price))
        {
            if (g_trader.OpenBuy(InpTradeSymbol, InpLotSize, g_strategy.GetBuyStopLoss(), g_strategy.GetBuyTakeProfit()))
            {
                trade_executed_today = true;
                Print("Ordem de Compra Aberta.");
            }
        }
        else if (g_strategy.CheckSellSignal(current_close_price))
        {
            if (g_trader.OpenSell(InpTradeSymbol, InpLotSize, g_strategy.GetSellStopLoss(), g_strategy.GetSellTakeProfit()))
            {
                trade_executed_today = true;
                Print("Ordem de Venda Aberta.");
            }
        }
    }
}
//+------------------------------------------------------------------+
