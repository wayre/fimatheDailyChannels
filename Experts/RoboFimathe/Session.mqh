//+------------------------------------------------------------------+
//|                                                      Session.mqh |
//|                                             Copyright 2025, Your Name |
//|                                             https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link "https://www.wayre.dev"
#property version "1.00"

#include "Time.mqh"
/**
 *   O arquivo Session.mqh define a classe SessionManager. A finalidade principal desta classe é centralizar e gerenciar
  todo o controle de tempo e sessão do robô. Em vez de espalhar lógicas de tempo pelo código principal, tudo fica
  organizado aqui.

  Ela responde a três perguntas fundamentais para o robô:
   1. É hora de operar? (Está dentro do dia e horário de negociação?)
   2. O dia mudou? (Para reiniciar as variáveis e estratégias diárias)
   3. Abriu uma nova vela/candle? (Para tomar decisões apenas uma vez por vela)
*/

// Estrutura para rastrear o tempo da última barra para cada timeframe
struct TimeframeBarInfo
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime last_bar_time;
};

//--- Classe para gerenciar a sessão e o tempo
class SessionManager
{
private:
   TimeframeBarInfo m_bar_info[];
   int m_last_day; // Armazena o último dia registrado

   // Função auxiliar para encontrar ou criar informações da barra para um timeframe
   int GetBarInfoIndex(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      for (int i = 0; i < ArraySize(m_bar_info); i++)
      {
         if (m_bar_info[i].symbol == symbol && m_bar_info[i].timeframe == timeframe)
            return i;
      }

      // Se não encontrado, adiciona um novo
      int new_index = ArraySize(m_bar_info);
      ArrayResize(m_bar_info, new_index + 1);
      m_bar_info[new_index].symbol = symbol;
      m_bar_info[new_index].timeframe = timeframe;
      m_bar_info[new_index].last_bar_time = 0;
      return new_index;
   }

public:
   void Init()
   {
      ArrayFree(m_bar_info);
      m_last_day = -1; // Inicializa com -1 para garantir que a primeira verificação seja 'true'
   }

   bool IsNewCandle(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      int info_index = GetBarInfoIndex(symbol, timeframe);
      datetime current_bar_time = iTime(symbol, timeframe, 0);

      if (m_bar_info[info_index].last_bar_time < current_bar_time)
      {
         m_bar_info[info_index].last_bar_time = current_bar_time;
         return true;
      }
      return false;
   }

   bool IsTradingHours()
   {
      return ::IsTradingHours();
   }

   ENUM_TIMEFRAMES GetTimeframe()
   {
      MqlDateTime hoje;
      TimeToStruct(TimeCurrent(), hoje);

      if (hoje.day_of_week == MONDAY)
      {
         return PERIOD_M15;
      }
      else
      {
         return PERIOD_M5;
      }
   }

   int GetSessionStartBarIndex()
   {
      // Implementar lógica para encontrar o índice da primeira barra da sessão diária
      return 0;
   }

   bool IsNewDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt); // Pega a data/hora atual do servidor

      // Compara o dia do ano atual com o último dia armazenado
      if (m_last_day != dt.day_of_year)
      {
         m_last_day = dt.day_of_year; // Atualiza o dia armazenado
         return true;
      }
      return false; // Continua no mesmo dia
   }
};
