//+------------------------------------------------------------------+
//|                                        FimatheDailyChannels.mq5 |
//|                                             Copyright 2025, Fimathe |
//|                                            https://www.fimathe.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Fimathe"
#property link "https://www.fimathe.com"
#property version "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0
// #property indicator_chart_events true // Esta linha é desnecessária em MQL5 e causa erro. A função OnChartEvent() é suficiente.

//--- Inclusões
#include <Arrays/ArrayLong.mqh>

//--- Inputs
input int InpChannelLevels = 10;
input color InpBaseChannelColor = C'63, 46, 139'; // Cor do Canal Base
input color InpUpperLevelsColor = C'76, 76, 158';  // Cor dos Níveis Superiores
input color InpLowerLevelsColor = C'76, 76, 158';    // Cor dos Níveis Inferiores
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID;   // Estilo da Linha

//--- Estrutura para armazenar os dados do canal
struct ChannelData
{
    double max_high;
    double min_low;
    double range;
    bool is_valid;
    datetime session_start;
    datetime session_end;
};

//--- Variáveis globais
string g_object_prefix;            // Prefixo para os nomes dos objetos no gráfico
string g_comment_robot = "";
CArrayLong g_drawn_days;     // Armazena os dias para os quais os canais já foram desenhados

//--- Flags globais para o estado das teclas (compatível com Wine/Linux)
bool g_shift_down = false;


//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("OnInit: FimatheDailyChannels v2.00 inicializando...");
    //--- Cria um prefixo único para os objetos deste indicador
    g_object_prefix = "FimatheDailyChannel_" + IntegerToString(ChartID()) + "_";
    g_drawn_days.Clear();

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("OnDeinit: FimatheDailyChannels desinicializando. Razão: ", reason);
    //--- Limpa o comentário do gráfico
    Comment("");
    //--- Remove todos os objetos criados pelo indicador
    ObjectsDeleteAll(0, g_object_prefix);
    g_drawn_days.Clear();
}

//+------------------------------------------------------------------+
//| Retorna o início e fim da sessão de negociação para um dia específico.|
//+------------------------------------------------------------------+
bool GetSessionTimesForDay(const string symbol, const datetime for_day, datetime &session_start, datetime &session_end)
{
    MqlDateTime dt;
    TimeToStruct(for_day, dt);

    datetime trade_start_time = 0;
    datetime trade_end_time = 0;

    if(SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, trade_start_time, trade_end_time))
    {
        if(trade_start_time > 0)
        {
            MqlDateTime dt_start, dt_end;
            TimeToStruct(trade_start_time, dt_start);
            TimeToStruct(trade_end_time, dt_end);

            dt.hour = dt_start.hour;
            dt.min = dt_start.min;
            dt.sec = 0;
            session_start = StructToTime(dt);

            if (trade_end_time < trade_start_time)
            {
                MqlDateTime dt_temp_end;
                TimeToStruct(for_day + 86400, dt_temp_end); // Adiciona um dia
                dt_temp_end.hour = dt_end.hour;
                dt_temp_end.min = dt_end.min;
                dt_temp_end.sec = 0;
                session_end = StructToTime(dt_temp_end);
            }
            else
            {
                dt.hour = dt_end.hour;
                dt.min = dt_end.min;
                dt.sec = 0;
                session_end = StructToTime(dt);
            }
            
            if (dt_end.hour == 23 && dt_end.min == 59)
            {
                session_end = session_start + 86400 - 1;
            }

            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Desenha um nível de canal como um retângulo no gráfico          |
//+------------------------------------------------------------------+
void DrawChannelLevel(const string name, const double price, const string text, const color line_color, const ENUM_LINE_STYLE line_style, const datetime start_time, const datetime end_time, const int width = 1)
{
    if(ObjectFind(0, name) < 0) // Correção: < 0 significa que não encontrou
    {
        if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, start_time, price, end_time, price))
            return;
    }
    else
    {
        ObjectMove(0, name, 0, start_time, price);
        ObjectMove(0, name, 1, end_time, price);
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_FILL, false);
}


//+------------------------------------------------------------------+
//| Calcula os níveis do canal para um dia específico                |
//+------------------------------------------------------------------+
ChannelData CalculateChannelForDay(const datetime for_day)
{
    Print("CalculateChannelForDay: Iniciando cálculo para o dia ", TimeToString(for_day, TIME_DATE));
    ChannelData result = {0};
    result.is_valid = false;

    string symbol = Symbol();
    datetime session_start, session_end;

    if(!GetSessionTimesForDay(symbol, for_day, session_start, session_end))
    {
        Print("CalculateChannelForDay: Falha ao obter horário da sessão.");
        return result;
    }
    Print("CalculateChannelForDay: Sessão encontrada: ", TimeToString(session_start, TIME_MINUTES), " - ", TimeToString(session_end, TIME_MINUTES));

    MqlDateTime dt_temp;
    TimeToStruct(for_day, dt_temp);
    ENUM_TIMEFRAMES timeframe = (dt_temp.day_of_week == MONDAY) ? PERIOD_M15 : PERIOD_M5;
    Print("CalculateChannelForDay: Timeframe definido para ", EnumToString(timeframe));

    int bar_shift = iBarShift(symbol, timeframe, session_start, false);
    if(bar_shift < 0)
    {
        Print("CalculateChannelForDay: Não foi encontrada a barra de início da sessão.");
        return result;
    }
    
    datetime first_bar_open_time = iTime(symbol, timeframe, bar_shift);
    
    datetime end_time_for_copy = first_bar_open_time + (datetime)(4 * PeriodSeconds(timeframe));

    MqlRates rates[];
    int copied = CopyRates(symbol, timeframe, first_bar_open_time, end_time_for_copy, rates);
    if(copied < 4)
    {
        Print("CalculateChannelForDay: Falha ao copiar rates. Esperado: 4, Copiado: ", copied);
        return result;
    }
    Print("CalculateChannelForDay: ", copied, " rates copiados com sucesso.");

    double max_high = 0;
    double min_low = 999999999;
    for(int i = 0; i < 4; i++)
    {
        if(rates[i].high > max_high) max_high = rates[i].high;
        if(rates[i].low < min_low) min_low = rates[i].low;
    }

    result.range = max_high - min_low;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    if(point > 0 && result.range / point >= 1000)
    {
        result.range /= 2;
        max_high = min_low + result.range;
        Print("CalculateChannelForDay: Range > 1000 pontos, ajustado para ", result.range);
    }
    
    g_comment_robot = "TAMANHO DO CANAL: " + DoubleToString(result.range/point,0);

    result.max_high = max_high;
    result.min_low = min_low;
    result.session_start = session_start;
    result.session_end = session_end;
    result.is_valid = true;

    Print("CalculateChannelForDay: Cálculo para ", TimeToString(for_day, TIME_DATE), " concluído com sucesso.");
    return result;
}

//+------------------------------------------------------------------+
//| Desenha todos os níveis de canal para um dia                     |
//+------------------------------------------------------------------+
void DrawDayChannels(const ChannelData &data, const datetime for_day)
{
    if(!data.is_valid) return;

    string day_str = TimeToString(for_day, TIME_DATE);
    string obj_suffix = " ("+g_comment_robot+"pts)";

    // Canal Base
    DrawChannelLevel(g_object_prefix + day_str + "_Base_Up", data.max_high, "Canal Superior" + obj_suffix, InpBaseChannelColor, STYLE_DASH, data.session_start, data.session_end, 2);
    DrawChannelLevel(g_object_prefix + day_str + "_Base_Down", data.min_low, "Canal Inferior" + obj_suffix, InpBaseChannelColor, STYLE_DASH, data.session_start, data.session_end, 2);

    // Níveis Superiores
    for(int i = 1; i <= InpChannelLevels; i++)
    {
        double level_price = data.max_high + (i * data.range);
        string level_name = "Nível " + IntegerToString(i) + " Up";
        DrawChannelLevel(g_object_prefix + day_str + "_Up_" + IntegerToString(i), level_price, level_name, InpUpperLevelsColor, InpLineStyle, data.session_start, data.session_end);
    }

    // Níveis Inferiores
    for(int i = 1; i <= InpChannelLevels; i++)
    {
        double level_price = data.min_low - (i * data.range);
        string level_name = "Nível " + IntegerToString(i) + " Down";
        DrawChannelLevel(g_object_prefix + day_str + "_Down_" + IntegerToString(i), level_price, level_name, InpLowerLevelsColor, InpLineStyle, data.session_start, data.session_end);
    }
}


//+------------------------------------------------------------------+
//| Lida com o evento de movimento do mouse para logar a data do candle |
//+------------------------------------------------------------------+
void HandleMouseMoveEvent(const long &lparam, const double &dparam)
{
    // Variável estática para guardar o tempo do último candle registrado
    static datetime last_logged_time = 0;

    datetime time;
    double price;
    int subwindow = 0;

    // Converte as coordenadas (x,y) do mouse do mouse para tempo e preço
    if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subwindow, time, price))
    {
        // Se estiver na janela principal do gráfico
        if(subwindow == 0)
        {
            // Encontra o índice do candle
            int bar_index = iBarShift(Symbol(), Period(), time);

            if(bar_index >= 0)
            {
                // Obtém a hora de abertura do candle
                datetime bar_time = iTime(Symbol(), Period(), bar_index);

                // Só imprime no log se o candle for diferente do último registrado
                if(bar_time != last_logged_time)
                {
                    Print("Cursor sobre o candle de: ", TimeToString(bar_time, TIME_DATE | TIME_MINUTES));
                    last_logged_time = bar_time; // Atualiza o último candle registrado
                }
                return;
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Função de evento do gráfico                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // --- Lida com o movimento do mouse para logar a data ---
    if(id == CHARTEVENT_MOUSE_MOVE)
    {
        HandleMouseMoveEvent(lparam, dparam);
        return; 
    }

    // --- Rastreia o estado das teclas para máxima compatibilidade ---
    if(id == CHARTEVENT_KEYDOWN)
    {
        if((int)lparam == 16) g_shift_down = true;
    }
    else if(id == CHARTEVENT_KEYUP)
    {
        if((int)lparam == 16) g_shift_down = false;
    }

    // --- Lida com o evento de clique (Shift + Click) ---
    if(id == CHARTEVENT_CLICK && g_shift_down)
    {
        datetime time_from_click;
        double price_from_click;
        int subwindow = 0;

        // CORREÇÃO: Converte as coordenadas do clique (lparam=x, dparam=y) para uma data/hora válida
        if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subwindow, time_from_click, price_from_click) && subwindow == 0)
        {
            // Normaliza para o início do dia
            MqlDateTime dt;
            TimeToStruct(time_from_click, dt);
            dt.hour = 0; dt.min = 0; dt.sec = 0;
            datetime clicked_day = StructToTime(dt);

            Print("Shift+Click para o dia: ", TimeToString(clicked_day, TIME_DATE));

            // Limpa objetos antigos e desenha o novo
            ObjectsDeleteAll(0, g_object_prefix);
            g_drawn_days.Clear();

            ChannelData data = CalculateChannelForDay(clicked_day);
            if(data.is_valid)
            {
                DrawDayChannels(data, clicked_day);
                g_drawn_days.Add(clicked_day);
                ChartRedraw();
            }
            else
            {
                Print("Falha ao calcular os dados do canal para o dia clicado.");
            }
        }
        else
        {
            Print("Clique fora da janela principal do gráfico.");
        }
    }
}

//+------------------------------------------------------------------+
//| Função principal do indicador                                     |
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
                const int &spread[])
{
    // A lógica de desenho agora é tratada exclusivamente pelo OnChartEvent (clique).
    // OnCalculate não precisa mais processar os dias visíveis.
    return (rates_total);
}
//+------------------------------------------------------------------+


