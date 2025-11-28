//+------------------------------------------------------------------+
//|                                              FimatheLevels.mq5 |
//|                                        Copyright 2025, Fimathe |
//|                                        https://www.fimathe.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Fimathe"
#property link "https://www.fimathe.com"
#property version "1.00"
#property description "Indicador que desenha os níveis de projeção da estratégia Fimathe."
#property indicator_chart_window

//--- Inclui o arquivo Time.mqh para usar a função GetSessionStartTime
#include "../../Experts/RoboFimathe/Time.mqh"

//--- Constantes do Indicador
#define NUM_LEVELS 5                // Número de níveis para desenhar acima e abaixo
#define LINE_PREFIX "FimatheLevel_" // Prefixo para os nomes dos objetos

//--- Variáveis Globais
int g_last_day_drawn = 0;               // Controla o dia em que as linhas foram desenhadas
bool g_levels_calculated_today = false; // Controla se os níveis do dia já foram calculados
datetime g_session_start_time = 0;      // Armazena o início da sessão do dia

//--- Funções Auxiliares de Desenho
void CalculateAndDrawLevels();
void DeleteAllLines();
void DrawHorizontalLine(const string name, const double price, const datetime time1, const datetime time2, const color line_color, const ENUM_LINE_STYLE style, const int width);

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                           |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Inicializa as variáveis
   g_last_day_drawn = 0;
   g_levels_calculated_today = false;
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Apaga todas as linhas ao remover o indicador
   DeleteAllLines();
}

//+------------------------------------------------------------------+
//| Função principal do indicador, chamada a cada tick               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const long &spread[])
{
   //--- Pega o dia do ano da barra atual
   MqlDateTime dt;
   TimeToStruct(time[rates_total - 1], dt);
   int current_day = dt.day_of_year;

   //--- Se mudou o dia, limpa tudo e reseta as flags
   if (current_day != g_last_day_drawn)
   {
      DeleteAllLines();
      g_levels_calculated_today = false;
      g_last_day_drawn = current_day;
   }

   //--- Se os níveis do dia já foram calculados, não faz mais nada
   if (g_levels_calculated_today)
   {
      return (rates_total);
   }

   //--- Tenta calcular e desenhar os níveis
   CalculateAndDrawLevels();

   return (rates_total);
}

//+------------------------------------------------------------------+
//| Calcula os níveis da estratégia e chama a função de desenho      |
//+------------------------------------------------------------------+
void CalculateAndDrawLevels()
{
   //--- 1. Obter o horário de início da sessão
   g_session_start_time = GetSessionStartTime(_Symbol);
   if (g_session_start_time == 0 || TimeCurrent() < g_session_start_time)
   {
      return; // Sessão ainda não iniciou ou não foi encontrada
   }

   //--- 2. Tenta copiar as 4 primeiras velas da sessão
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, g_session_start_time, 4, rates);

   //--- 3. Se não houver 4 velas, não faz nada ainda
   if (copied < 4)
   {
      return;
   }

   //--- 4. Calcula o canal com base nas 4 velas
   double max_high = 0;
   double min_low = 999999;
   for (int i = 0; i < 4; i++)
   {
      if (rates[i].high > max_high)
         max_high = rates[i].high;
      if (rates[i].low < min_low)
         min_low = rates[i].low;
   }

   double range_canal = max_high - min_low;

   // Se o range for inválido, não desenha
   if (range_canal <= 0)
      return;

   //--- 5. Define o horário de término das linhas (12:00 do dia atual)
   MqlDateTime dt;
   TimeToStruct(g_session_start_time, dt);
   dt.hour = 12;
   dt.min = 0;
   dt.sec = 0;
   datetime end_line_time = StructToTime(dt);

   //--- 6. Desenha as linhas
   // Linhas principais do canal
   DrawHorizontalLine(LINE_PREFIX + "Superior", max_high, g_session_start_time, end_line_time, clrBlue, STYLE_SOLID, 2);
   DrawHorizontalLine(LINE_PREFIX + "Inferior", min_low, g_session_start_time, end_line_time, clrBlue, STYLE_SOLID, 2);

   // Projeções para cima e para baixo
   for (int i = 1; i <= NUM_LEVELS; i++)
   {
      // Níveis acima
      double up_level = max_high + (i * range_canal);
      DrawHorizontalLine(LINE_PREFIX + "Up_" + (string)i, up_level, g_session_start_time, end_line_time, clrGreen, STYLE_DOT, 1);

      // Níveis abaixo
      double down_level = min_low - (i * range_canal);
      DrawHorizontalLine(LINE_PREFIX + "Down_" + (string)i, down_level, g_session_start_time, end_line_time, clrRed, STYLE_DOT, 1);
   }

   //--- 7. Marca como calculado para hoje
   g_levels_calculated_today = true;
}

//+------------------------------------------------------------------+
//| Desenha uma linha horizontal no gráfico                          |
//+------------------------------------------------------------------+
void DrawHorizontalLine(const string name, const double price, const datetime time1, const datetime time2, const color line_color, const ENUM_LINE_STYLE style, const int width)
{
   // Tenta criar o objeto de linha de tendência
   if (!ObjectCreate(0, name, OBJ_TREND, 0, 0, 0))
   {
      // Se falhar, talvez o objeto já exista, então apenas movemos
      ObjectMove(0, name, 0, time1, price);
      ObjectMove(0, name, 1, time2, price);
   }
   else
   {
      // Se criou com sucesso, define as coordenadas
      ObjectMove(0, name, 0, time1, price);
      ObjectMove(0, name, 1, time2, price);
   }

   // Define as propriedades da linha
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJ_TREND, OBJPROP_RAY_RIGHT, false); // Garante que a linha não seja infinita
}

//+------------------------------------------------------------------+
//| Apaga todas as linhas criadas pelo indicador                     |
//+------------------------------------------------------------------+
void DeleteAllLines()
{
   ObjectsDeleteAll(0, LINE_PREFIX);
   ChartRedraw();
}
//+------------------------------------------------------------------+
