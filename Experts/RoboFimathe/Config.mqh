//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                             Copyright 2025, Your Name |
//|                                             https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link "https://www.your-website.com"
#property version "1.00"

#include "Time.mqh"

//--- Parâmetros de entrada do robô
input ulong InpMagicNumber = 36371231;  // Número Mágico da Ordem
input string InpTradeSymbol = "XAUUSD"; // Símbolo para operar
input double InpLotSize = 0.01;         // Volume da operação
input double InpMaxLotSize = 0.06;      // Volume máximo da operação
input double InpLotStep = 0.01;         // Passo do volume da operação

//--- Parâmetros da estratégia
input int InpChannelMultiplier = 2; // Multiplicador para o range do canal
