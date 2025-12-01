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
// rgba(156, 156, 156, 1)
//--- Inputs
input color InpFiboColor = C'156, 156, 156';      // Cor do Fibonacci
input color InpLevelColor = C'66, 65, 65'; // Cor opcional para os níveis do Fibonacci
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID;   // Estilo da Linha

//--- Estrutura para armazenar os dados do canal
struct FiboData
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
//| Calcula os dados do Fibonacci para um dia específico                |
//+------------------------------------------------------------------+
FiboData CalculateFiboDataForDay(const datetime for_day)
{
    Print("CalculateFiboDataForDay: Iniciando cálculo para o dia ", TimeToString(for_day, TIME_DATE));
    FiboData result = {0};
    result.is_valid = false;

    string symbol = Symbol();
    datetime session_start, session_end;

    if(!GetSessionTimesForDay(symbol, for_day, session_start, session_end))
    {
        Print("CalculateFiboDataForDay: Falha ao obter horário da sessão.");
        return result;
    }
    Print("CalculateFiboDataForDay: Sessão encontrada: ", TimeToString(session_start, TIME_MINUTES), " - ", TimeToString(session_end, TIME_MINUTES));

    MqlDateTime dt_temp;
    TimeToStruct(for_day, dt_temp);
    ENUM_TIMEFRAMES timeframe = (dt_temp.day_of_week == MONDAY) ? PERIOD_M15 : PERIOD_M5;
    Print("CalculateFiboDataForDay: Timeframe definido para ", EnumToString(timeframe));

    int bar_shift = iBarShift(symbol, timeframe, session_start, false);
    if(bar_shift < 0)
    {
        Print("CalculateFiboDataForDay: Não foi encontrada a barra de início da sessão.");
        return result;
    }
    
    datetime first_bar_open_time = iTime(symbol, timeframe, bar_shift);
    
    datetime end_time_for_copy = first_bar_open_time + (datetime)(4 * PeriodSeconds(timeframe));

    MqlRates rates[];
    int copied = CopyRates(symbol, timeframe, first_bar_open_time, end_time_for_copy, rates);
    if(copied < 4)
    {
        Print("CalculateFiboDataForDay: Falha ao copiar rates. Esperado: 4, Copiado: ", copied);
        return result;
    }
    Print("CalculateFiboDataForDay: ", copied, " rates copiados com sucesso.");

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
        Print("CalculateFiboDataForDay: Range > 1000 pontos, ajustado para ", result.range);
    }
    
    g_comment_robot = "TAMANHO DO CANAL: " + DoubleToString(result.range/point,0);

    result.max_high = max_high;
    result.min_low = min_low;
    result.session_start = session_start;
    result.session_end = session_end;
    result.is_valid = true;

    Print("CalculateFiboDataForDay: Cálculo para ", TimeToString(for_day, TIME_DATE), " concluído com sucesso.");
    return result;
}

//+------------------------------------------------------------------+
//| Desenha o objeto Fibonacci para um dia                           |
//+------------------------------------------------------------------+
void DrawDayFibonacci(const FiboData &data, const datetime for_day)
{
    if(!data.is_valid) return;

    string day_str = TimeToString(for_day, TIME_DATE);
    string obj_name = g_object_prefix + day_str + "_Fibo";

    // Define o tempo de início e fim para o objeto Fibonacci
    MqlDateTime dt;
    TimeToStruct(for_day, dt);
    dt.hour = 1; dt.min = 0; dt.sec = 0;
    datetime time1 = StructToTime(dt);
    dt.hour = 23; dt.min = 0; dt.sec = 0;
    datetime time2 = StructToTime(dt);

    // Cria ou move o objeto Fibonacci
    if(ObjectFind(0, obj_name) < 0)
    {
        if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, time1, data.min_low, time2, data.max_high))
        {
            Print("Erro ao criar objeto Fibonacci: ", GetLastError());
            return;
        }
    }
    else
    {
        ObjectMove(0, obj_name, 0, time1, data.min_low);
        ObjectMove(0, obj_name, 1, time2, data.max_high);
    }

    // Define as propriedades do objeto
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, C'74, 74, 74'); // Ajustado para usar InpFiboColor
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, "Fibo " + day_str);

    // Propriedades para tornar o objeto selecionável e editável
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, obj_name, OBJPROP_STATE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0);



    // Define o número total de níveis e seus valores
    const int first = -10;
    const int last  = 10;
    const int count = last - first + 1;
    ObjectSetInteger(0, obj_name, OBJPROP_LEVELS, count);

    int level_index = 0;
    for(int i = first; i <= last; i++, level_index++)
    {
        double level_value = (double)i;
        ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, level_index, level_value);
        
        // Define cor, estilo e largura para cada nível
        color level_color;
        if(i == 0 || i == 1)
        {
            level_color = C'121, 121, 121';
        }
        else
        {
            level_color = (InpLevelColor == clrNONE) ? InpFiboColor : InpLevelColor;
        }
        
        ObjectSetInteger(0, obj_name, OBJPROP_LEVELCOLOR, level_index, level_color);
        ObjectSetInteger(0, obj_name, OBJPROP_LEVELSTYLE, level_index, InpLineStyle);
        ObjectSetInteger(0, obj_name, OBJPROP_LEVELWIDTH, level_index, 1); // Largura 1 para todos os níveis
        
        // Define o texto como vazio para todos os níveis, conforme solicitado
        string level_text = ""; 
        ObjectSetString(0, obj_name, OBJPROP_LEVELTEXT, level_index, level_text);
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

            FiboData data = CalculateFiboDataForDay(clicked_day);
            if(data.is_valid)
            {
                DrawDayFibonacci(data, clicked_day);
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


