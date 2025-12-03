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
input int InpLevels = 20; // Número de níveis do Fibonacci

//--- Estrutura para armazenar as coordenadas dos objetos
struct ObjectCoords
{
    datetime time1, time2;
    double   price1, price2;
    string   obj_name;
};

//--- Estrutura para armazenar os dados do canal
struct FiboData
{
    double max_high;
    double min_low;
    double range;
    bool is_valid;
    datetime time1;
    datetime time2;
};

//--- Estrutura para retorno dos valores do canal de desvio padrão
struct StdDevChannelValues
{
    double lineUp;
    double lineDown;
};

//--- Estrutura para retorno do range da sessão
struct SessionRange
{
    double max;
    double min;
    double range;
    bool   valid;
    datetime first_candle;
    datetime last_candle;
};

//--- Variáveis globais
ObjectCoords fibo_coords; // Variável global para salvar coords
string g_object_prefix;            // Prefixo para os nomes dos objetos no gráfico
string g_comment_robot = "";
CArrayLong g_drawn_days;     // Armazena os dias para os quais os canais já foram desenhados

//--- Flags globais para o estado das teclas (compatível com Wine/Linux)
bool g_shift_down = false;
bool g_ctrl_down = false;
int g_zigzag_handle = INVALID_HANDLE;



//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("OnInit: FimatheDailyChannels v2.00 inicializando...");
    //--- Cria um prefixo único para os objetos deste indicador
    g_object_prefix = "FimatheDailyChannel_" + IntegerToString(ChartID()) + "_";
    g_drawn_days.Clear();

    // Inicializa o ZigZag com os parâmetros 12, 5, 3
    g_zigzag_handle = iCustom(_Symbol, PERIOD_M15, "Examples\\ZigZag", 1, 4, 1);
    if (g_zigzag_handle == INVALID_HANDLE)
    {
        Print("Erro ao criar handle do ZigZag");
        return INIT_FAILED;
    }

    // Habilita eventos do mouse e de criação/deleção de objetos
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

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
    
    if(g_zigzag_handle != INVALID_HANDLE)
    {
        IndicatorRelease(g_zigzag_handle);
    }
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
        /**
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
        */
        MqlDateTime dt;
        TimeToStruct(for_day, dt);
        dt.hour = 1; dt.min = 0; dt.sec = 0;
        session_start = StructToTime(dt);
        dt.hour = 23; dt.min = 55; dt.sec = 0;
        session_end = StructToTime(dt);
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Calcula os dados do Fibonacci para um dia específico                |
//+------------------------------------------------------------------+
FiboData CalculateFiboDataForDay(const datetime for_day)
{
    FiboData result = {0};
    result.is_valid = false;

    string symbol = Symbol();

    SessionRange range_4candles_day = getInfoSession(for_day);
    if (!range_4candles_day.valid) return result;   

    // Pega o maior high e o menor low dos 4 primeiros candles
    double max_high = range_4candles_day.max;
    double min_low = range_4candles_day.min;

    // Pega o range dos 4 primeiros candles
    result.range = range_4candles_day.range;
    
    
    // Ajusta o range para ser múltiplo de 1000 pontos
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(point > 0 && result.range / point >= 1000)
    {
        result.range /= 2;
        max_high = min_low + result.range;
        Print("CalculateFiboDataForDay: Range > 1000 pontos, ajustado para ", result.range);
    }
    
    g_comment_robot = "TAMANHO DO CANAL: " + DoubleToString(result.range/point,0);
    Comment(g_comment_robot);

    result.max_high = max_high;
    result.min_low = min_low;
    result.time1 = range_4candles_day.first_candle;
    result.time2 = range_4candles_day.last_candle;
    result.is_valid = true;

    Print("CalculateFiboDataForDay: Cálculo para ", TimeToString(for_day, TIME_DATE), " concluído com sucesso.");
    return result;
}

//+------------------------------------------------------------------+
//| Calcula os dados do Fibonacci a partir de um canal de desvio     |
//+------------------------------------------------------------------+
FiboData CalculateFiboDataFromChannel(datetime selected_day, double lineUp, double lineDown)
{
    FiboData result = {0};
    result.is_valid = false;

    double range = MathAbs(lineUp - lineDown);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(point == 0) return result;

    double points_range = range / point;
    Print(">>>>>>>>>>>>>>>>>>>>>> points_range: ", points_range);

    // Lógica de divisão do range se for maior que 1000 pontos
    if(points_range > 1000)
    {
        int n = 2;
        while(true)
        {
            double sub_range = points_range / n;
            if(sub_range <= 900 && sub_range >= 500)
            {
                range = range / n;
                Print("CalculateFiboDataFromChannel: Range original ", points_range, " dividido por ", n, " -> ", range/point);
                break;
            }
            n++;
            if(n > 100) break; // Proteção
        }
    }

    result.min_low = MathMin(lineUp, lineDown);
    result.range = range;
    result.max_high = result.min_low + range;

    g_comment_robot = "TAMANHO DO CANAL: " + DoubleToString(result.range/point,0);
    Comment(g_comment_robot);
    
    // Preenche horários da sessão
    datetime session_start = 0;
    datetime session_end = 0;
    GetSessionTimesForDay(_Symbol, selected_day, session_start, session_end);
    
    SessionRange range_4candles_day = getInfoSession(selected_day);
    result.time1 = range_4candles_day.last_candle;
    result.time2 = session_end;
    
    result.is_valid = true;
    return result;
}

//+------------------------------------------------------------------+
//| Desenha o objeto Fibonacci para um dia                           |
//+------------------------------------------------------------------+
void DrawDayFibonacci(const FiboData &data, const datetime for_day)
{
    if(!data.is_valid) return;

    string day_str = TimeToString(for_day, TIME_DATE);
    string obj_name = g_object_prefix + "Fibo";

    // Define o tempo de início e fim para o objeto Fibonacci
    MqlDateTime dt;
    TimeToStruct(for_day, dt);
    dt.hour = 1; dt.min = 0; dt.sec = 0;
    datetime time1 = StructToTime(dt);
    dt.hour = 8; dt.min = 59; dt.sec = 59;
    datetime time2 = StructToTime(dt);

    // Cria ou move o objeto Fibonacci
    if(ObjectFind(0, obj_name) < 0)
    {
        if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, data.time1, data.min_low, time2, data.max_high))
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
    const int first = -InpLevels;
    const int last  = InpLevels;
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

    // Pega as coordenadas do objeto e seta na variavel global
    GetObjectCoords(obj_name, fibo_coords);
    fibo_coords.obj_name = obj_name;
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
                    last_logged_time = bar_time; // Atualiza o último candle registrado
                }
                return;
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Processa e desenha o Fibonacci para o dia clicado                |
//+------------------------------------------------------------------+
void ProcessFibonacci(datetime clicked_day)
{
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

//+------------------------------------------------------------------+
//| Processa e desenha o Canal de Desvio Padrão                      |
//+------------------------------------------------------------------+
void ProcessStdDevChannel(datetime clicked_day)
{
    // --- Lógica do Canal de Desvio Padrão ---
    // 1. Identificar o ultimo candle pivô com a funcao GetZigZagPivot.
    //    Regra: "pivo da ultima perna do dia anterior até o fechamento do 4 candle do timeframe atual do clicked_day"
    
    // Limpa objetos antigos e desenha o novo
    ObjectsDeleteAll(0, g_object_prefix);
    g_drawn_days.Clear();

    datetime pivot = 0;
    
    pivot = GetZigZagPivot(clicked_day);
    
    if (pivot > 0)
    {
        datetime pivot_datetime;
        pivot_datetime = pivot;
        SessionRange range_4candles_day = getInfoSession(clicked_day);
        datetime selected_date = range_4candles_day.last_candle;
        
        StdDevChannelValues stdDevChanel = DrawAndGetStdDevChannelValues(pivot_datetime, selected_date, 1.62);

        FiboData fibo_data = CalculateFiboDataFromChannel(clicked_day, stdDevChanel.lineUp, stdDevChanel.lineDown);
        
        if( fibo_data.is_valid)
        {
            DrawDayFibonacci(fibo_data, clicked_day);
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
        Print("Nenhum pivô encontrado para o cálculo do StdDev Channel.");
    }
}

//+------------------------------------------------------------------+
//| Lida com o evento de clique no gráfico                           |
//+------------------------------------------------------------------+
void HandleClickWayreChannel(long lparam, double dparam)
{
    datetime time_from_click;
    double price_from_click;
    int subwindow = 0;

    // Converte as coordenadas do clique (lparam=x, dparam=y) para uma data/hora válida
    if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subwindow, time_from_click, price_from_click) && subwindow == 0)
    {
        // Normaliza para o início do dia
        MqlDateTime dt;
        TimeToStruct(time_from_click, dt);
        dt.hour = 0; dt.min = 0; dt.sec = 0;
        datetime clicked_day = StructToTime(dt);

        // ProcessFibonacci(clicked_day);
        ProcessStdDevChannel(clicked_day);
    }
    else
    {
        Print("Clique fora da janela principal do gráfico.");
    }
}

void HandleClickFimathe(long lparam, double dparam)
{
    datetime time_from_click;
    double price_from_click;
    int subwindow = 0;

    // Converte as coordenadas do clique (lparam=x, dparam=y) para uma data/hora válida
    if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subwindow, time_from_click, price_from_click) && subwindow == 0)
    {
        // Normaliza para o início do dia
        MqlDateTime dt;
        TimeToStruct(time_from_click, dt);
        dt.hour = 0; dt.min = 0; dt.sec = 0;
        datetime clicked_day = StructToTime(dt);

        ProcessFibonacci(clicked_day);
        // ProcessStdDevChannel(clicked_day);
    }
    else
    {
        Print("Clique fora da janela principal do gráfico.");
    }
}


//+------------------------------------------------------------------+
//| Função de evento do gráfico                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Debug global para verificar quais eventos estão chegando
    // Print("Event: ", id, " lparam: ", lparam, " dparam: ", dparam, " sparam: ", sparam);
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
        if((int)lparam == 17) g_ctrl_down = true;
    }
    else if(id == CHARTEVENT_KEYUP)
    {
        if((int)lparam == 16) g_shift_down = false;
        if((int)lparam == 17) g_ctrl_down = false;
    }

    // --- Lida com o evento de clique (Shift + Click) ---
    if(id == CHARTEVENT_CLICK && g_shift_down)
    {
        HandleClickWayreChannel(lparam, dparam);
    }
    // --- Lida com o evento de clique (Ctrl + Click) ---
    if(id == CHARTEVENT_CLICK && g_ctrl_down)
    {
        HandleClickFimathe(lparam, dparam);
    }

    if(id == CHARTEVENT_OBJECT_CHANGE || id == CHARTEVENT_OBJECT_DRAG)
    {
        if(fibo_coords.obj_name == "") return;
        
        // Verifica se o objeto alterado é o nosso Fibonacci
        if(sparam == fibo_coords.obj_name)
        {
            if(ObjectChanged(fibo_coords.obj_name, fibo_coords))
            {
                g_comment_robot = "TAMANHO DO CANAL: " + DoubleToString((fibo_coords.price2 - fibo_coords.price1) / _Point, 0);
                Comment(g_comment_robot);
            }
        }
    }
}

/**
 * Pega as coordenadas de um objeto
 */
void GetObjectCoords(string obj_name, ObjectCoords &coords)
{
    coords.time1  = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME,  0);
    coords.time2  = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME,  1);
    coords.price1 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 0);
    coords.price2 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 1);
}

/**
 * Verifica se um objeto foi Alterado
 */
bool ObjectChanged(string obj_name, ObjectCoords &old_coords)
{
    // Pega coordenadas atuais do objeto
    ObjectCoords current_coords;
    GetObjectCoords(obj_name, current_coords);
    
    // Compara com as antigas
    if(current_coords.time1  != old_coords.time1  || 
       current_coords.time2  != old_coords.time2  ||
       current_coords.price1 != old_coords.price1 ||
       current_coords.price2 != old_coords.price2)
    {
        g_comment_robot = "TAMANHO DO CANAL: " + IntegerToString((int)(current_coords.price2 - current_coords.price1));
        Comment(g_comment_robot);
        
        // Atualiza coords salvas
        old_coords.time1  = current_coords.time1;
        old_coords.time2  = current_coords.time2;
        old_coords.price1 = current_coords.price1;
        old_coords.price2 = current_coords.price2;
        
        return true; // Mudou!
    }
    
    return false; // Sem alteração
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


//+------------------------------------------------------------------+
//| Calcula o range (max/min) dos 4 primeiros candles da sessão      |
//+------------------------------------------------------------------+
SessionRange getInfoSession(datetime selected_day)
{
    SessionRange result;
    result.max   = -DBL_MAX;
    result.min   =  DBL_MAX;
    result.range =  0.0;
    result.valid =  false;

    string symbol = _Symbol;
    datetime session_start, session_end;

    // 1. Obter horários da sessão
    if(!GetSessionTimesForDay(symbol, selected_day, session_start, session_end))
    {
        Print("CalculateSessionRange: Falha ao obter horário da sessão.");
        return result;
    }

    // 2. Timeframe baseado no dia da semana
    ENUM_TIMEFRAMES timeframe = GetTimeframeByDay(selected_day);

    // 3. Copiar os candles da sessão usando intervalo de tempo
    // Isso garante que pegamos os primeiros candles disponíveis a partir de session_start
    MqlRates rates[];
    ArraySetAsSeries(rates, false); // Garante ordem cronológica (índice 0 é o mais antigo)

    int copied = CopyRates(symbol, timeframe, session_start, session_end, rates);

    if(copied < 4)
    {
        Print("CalculateSessionRange: Falha ao copiar candles suficientes (copiados: ", copied, "). Mínimo necessário: 4.");
        return result;
    }

    // 4. Calcular range dos 4 primeiros candles
    // Iteramos apenas os 4 primeiros candles (índices 0, 1, 2, 3)
    for(int i = 0; i < 4; i++)
    {
        if(rates[i].high > result.max) result.max = rates[i].high;
        if(rates[i].low  < result.min) result.min = rates[i].low;
    }
    
    result.first_candle = rates[0].time;
    result.last_candle   = rates[3].time; 
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(point <= 0)
    {
        Print("ERRO: SYMBOL_POINT inválido para ", symbol);
        return result;
    }
    double diff_points = MathAbs(result.max - result.min) / point;
    result.range = (int)MathRound(diff_points);
    result.valid = true;

    return result;
}


//+------------------------------------------------------------------+
//| Verifica se a maioria dos candles (70%) está dentro do range     |
//+------------------------------------------------------------------+
bool IsMajorityInside(datetime start_time, datetime end_time, double range_max, double range_min, double threshold_percent=0.7)
{
    MqlRates rates[];
    int total = CopyRates(_Symbol, _Period, start_time, end_time, rates);
    
    if(total <= 0) return false;
    
    int inside_count = 0;
    
    for(int i=0; i<total; i++)
    {
        double p_high = rates[i].high;
        double p_low = rates[i].low;
        double p_range = p_high - p_low;
        
        if(p_range == 0) 
        {
             // Se o candle não tem corpo/tamanho, verificamos se o preço está dentro
             if(p_high <= range_max && p_low >= range_min) inside_count++;
             continue;
        }
        
        double overlap_high = MathMin(p_high, range_max);
        double overlap_low = MathMax(p_low, range_min);
        
        if(overlap_high > overlap_low)
        {
            double overlap = overlap_high - overlap_low;
            if(overlap > 0.5 * p_range)
            {
                inside_count++;
            }
        }
    }
    
    return ((double)inside_count / total) >= threshold_percent;
}

//+------------------------------------------------------------------+
//| Retorna o datetime do último pivô identificado pelo ZigZag        |
//+------------------------------------------------------------------+
datetime GetZigZagPivot(datetime datetime_base, int lookback=50)
{
    if (g_zigzag_handle == INVALID_HANDLE) return 0;

    // 1. Determinar o fim da sessão para o dia do datetime_base
    datetime session_start, session_end;
    if(!GetSessionTimesForDay(_Symbol, datetime_base, session_start, session_end))
    {
        Print("GetZigZagPivot: Falha ao obter horário da sessão para ", TimeToString(datetime_base));
        return 0;
    }
    
    /**
     * 2. Copiar os dados do ZigZag para o buffer
     */
    double zigzag_buffer[];
    ArraySetAsSeries(zigzag_buffer, true); // Garante que o índice 0 é o mais recente dos copiados

    if (CopyBuffer(g_zigzag_handle, 0, session_start, lookback, zigzag_buffer) < lookback)
    {
        int available = Bars(_Symbol, _Period);
        if (available < lookback) lookback = available; // Ajusta lookback se não houver dados suficientes
        if (CopyBuffer(g_zigzag_handle, 0, session_start, lookback, zigzag_buffer) <= 0)
        {
             Print("GetZigZagPivot: Erro ao copiar buffer do ZigZag a partir de session_start");
             return 0;
        }
    }

    datetime time[];
    ArraySetAsSeries(time, true); // Garante que o índice 0 é o mais recente dos copiados
    if (CopyTime(_Symbol, _Period, session_start, lookback, time) < lookback)
    {
         if (CopyTime(_Symbol, _Period, session_start, lookback, time) <= 0)
         {
            Print("GetZigZagPivot: Erro ao copiar tempo a partir de session_start");
            return 0;
         }
    }
            
    // crie um struct contendo o datetime e o valor do pivô
    struct PivotData
    {
        datetime time;
        double value;
        bool isInside;
    };
    PivotData found_pivots[];

    // --- Calcula o range dos 4 primeiros candles do dia ---
    SessionRange range_4candles_day = getInfoSession(session_start);
    double range_max = range_4candles_day.max;
    double range_min = range_4candles_day.min;
    // range_max = range_max + (range_max * 0.05);
    // range_min = range_min - (range_min * 0.05);

    datetime return_datetime = 0;
    
    // Loop para iterar sobre o buffer do ZigZag e encontrar pivôs
    for (int i = 0; i < lookback; i++)
    {
        // Se o valor for válido e diferente de 0 e diferente de EMPTY_VALUE, é um pivô
        if (zigzag_buffer[i] != 0 && zigzag_buffer[i] != EMPTY_VALUE)
        {
            // ignora pivots do datetime_base, quero apenas pivots anteriores
            if(time[i] >= datetime_base)
            {
                continue;
            }

            // Adiciona o pivô ao array de pivôs encontrados
            int size = ArraySize(found_pivots);
            ArrayResize(found_pivots, size + 1);
            found_pivots[size].time  = time[i];
            found_pivots[size].value = zigzag_buffer[i];
            found_pivots[size].isInside = false;

            //Apenas pivots do dia anterior ao datetime_base
            // Print("[", size, "]=> ", TimeToString(found_pivots[size].time, TIME_DATE|TIME_MINUTES));
            
            // VERIFICA SE ESTÁ "INSIDE" (dentro do range dos 4 primeiros candles)
            MqlRates pivo_rate[];
            
            // Copia os dados do candle do pivô
            if(CopyRates(_Symbol, _Period, time[i], 1, pivo_rate) == 1)
            {
                double p_high = pivo_rate[0].high;
                double p_low = pivo_rate[0].low;
                double p_range = p_high - p_low;
                
                if(p_range > 0)
                {
                    // Calcula a sobreposição entre o candle do pivô e o range da sessão
                    double overlap_high = MathMin(p_high, range_max);
                    double overlap_low = MathMax(p_low, range_min);
                    
                    // Se houver sobreposição
                    if(overlap_high < overlap_low)
                    {
                        // Print("Pivô ", i, " não está Inside");
                    }

                    double overlap = overlap_high - overlap_low;
                    // Se mais de 50% do candle do pivô estiver dentro do range
                    if(overlap > 0.5 * p_range)
                    {
                        found_pivots[size].isInside = true;
                    }
                    else
                    {
                        // Se não estiver 50% dentro, verifica se a maioria (70%) dos candles 
                        // desde o início da sessão até o pivô estão dentro do range
                        if(IsMajorityInside(session_start, time[i], range_max, range_min, 0.85))
                        {
                            found_pivots[size].isInside = true;
                            // Print("Pivô ", size, " está Inside (Critério da Maioria)");
                        }
                        else
                        {
                            // Print("Pivô ", size, " não está Inside");

                            // resultado do último pivot encontrado
                            if(size > 0)
                            {
                                return_datetime = found_pivots[size-1].time;
                            }
                            break; // Interrompe a busca se não atender aos critérios
                        }
                    }
                }
            }
        }
    }
    // Print("Total de pivôs encontrados: ", ArraySize(found_pivots));
    // for(int i = 0; i < ArraySize(found_pivots); i++)
    // {
    //     Print("Pivô ", i, ": Tempo=", TimeToString(found_pivots[i].time, TIME_DATE|TIME_SECONDS), ", Valor=", found_pivots[i].value, ", Inside=", found_pivots[i].isInside);
    // }

    int total_pivots = ArraySize(found_pivots);
    if(total_pivots <= 0)
    {
        return 0; // Nenhum pivô encontrado na janela
    }
    
    // Imprime todos os pivôs encontrados
    // for(int i = 0; i < total_pivots; i++)
    // {
    //     Print("Pivô [", i, "] encontrado em: ", TimeToString(found_pivots[i].time, TIME_DATE|TIME_MINUTES), 
    //           " Inside: ", found_pivots[i].isInside);
    // }
    
    return return_datetime ? return_datetime : found_pivots[total_pivots-1].time; // Retorna o datetime do último pivot encontrado
}


/**
Pega o timeframe baseado no sdia da semana */
ENUM_TIMEFRAMES GetTimeframeByDay(datetime date_selected)
{
    MqlDateTime dt;
    TimeToStruct(date_selected, dt);

    // string weekdays[] = {"Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"};
    
    ENUM_TIMEFRAMES timeframe;
    timeframe = dt.day_of_week == MONDAY ? PERIOD_M15 : PERIOD_M5;
    
    // Print("Dia da semana: ", weekdays[dt.day_of_week], " - Timeframe: ", timeframe);
    
    return timeframe;
}

/**
 * Desenha um Canal de Desvio Padrão
*/
void addObjStdDevChannel(string obj_name, datetime time1, datetime time2, double deviation=1.618)
{
    // --- 1. Cria ou atualiza o objeto gráfico ---
    if(ObjectFind(0, obj_name) >= 0)
    {
        ObjectDelete(0, obj_name);
    }

    ObjectCreate(0, obj_name, OBJ_STDDEVCHANNEL, 0, time1, 0, time2, 0);

    ObjectSetDouble(0, obj_name, OBJPROP_DEVIATION, deviation);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, C'11,11,49'); // Cor padrão, pode ser parametrizada
    ObjectSetInteger(0, obj_name, OBJPROP_RAY, true);      // Estende o canal

    // Propriedades para tornar o objeto selecionável e editável
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_FILL, true); 
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, obj_name, OBJPROP_STATE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);  
}

/**
 * Imprime os níveis do canal de Desvio Padrão
*/
void PrintStdDevChannelLevels(string obj_name, datetime candle_time)
{
    if(ObjectFind(0, obj_name) < 0)
    {
        Print("ERRO: Objeto ", obj_name, " não encontrado!");
        return;
    }
    
    // Pega coordenadas base do canal
    datetime time1 = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME, 0);
    datetime time2 = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME, 1);
    double   price1 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 0);
    double   price2 = ObjectGetDouble(0, obj_name, OBJPROP_PRICE, 1);
    
    // Número de níveis configurados
    int levels = (int)ObjectGetInteger(0, obj_name, OBJPROP_LEVELS);
    
    Print("=== CANAL ", obj_name, " ===");
    Print("Time1: ", TimeToString(time1), " Price1: ", price1);
    Print("Time2: ", TimeToString(time2), " Price2: ", price2);
    Print("Candle: ", TimeToString(candle_time));
    
    // Calcula linha central no candle
    double delta_time = (double)(time2 - time1);
    double delta_price = price2 - price1;
    double slope = delta_price / delta_time;  // Inclinação
    
    double central_price = price1 + slope * (candle_time - time1);
    
    Print("Linha central no candle: ", NormalizeDouble(central_price, _Digits));
    
    // Para cada nível configurado
    for(int i = 0; i < levels; i++)
    {
        double level_value = ObjectGetDouble(0, obj_name, OBJPROP_LEVELVALUE, i);
        double deviation = ObjectGetDouble(0, obj_name, OBJPROP_DEVIATION);
        
        // Preço da linha = central + (desvio * nível)
        double line_price = central_price + (deviation * level_value);
        
        string level_name = (level_value > 0) ? "+" + DoubleToString(level_value, 1) + "σ" 
                                             : DoubleToString(level_value, 1) + "σ";
        
        Print("Nível ", level_name, ": ", NormalizeDouble(line_price, _Digits));
        
        // Identifica superior/inferior
        if(level_value == 2.0 || level_value == 1.0)
            Print("  ← LINHA SUPERIOR");
        else if(level_value == -1.0 || level_value == -2.0)
            Print("  ← LINHA INFERIOR");
    }
}

//+------------------------------------------------------------------+
//| Desenha um Canal de Desvio Padrão e retorna os valores no target |
//+------------------------------------------------------------------+
StdDevChannelValues DrawAndGetStdDevChannelValues(datetime pivot_datetime, datetime selected_date, double deviation=1.618)
{
    StdDevChannelValues result = {0.0, 0.0};
    datetime time1 = pivot_datetime;
    string obj_name = g_object_prefix + "StdDev_Channel";

    // --- Calcula o range dos 4 primeiros candles do dia ---
    SessionRange info_session = getInfoSession(selected_date);
    datetime time2 = info_session.last_candle;

    // --- 1. Cria ou atualiza o objeto gráfico ---
    addObjStdDevChannel(obj_name, time1, time2, deviation);

    // --- 2. Imprime os níveis do canal ---
    PrintStdDevChannelLevels(obj_name, selected_date);

    // --- 2. Cálculo Matemático para garantir precisão e retorno imediato 
    // Precisamos dos dados de fechamento no intervalo [time1, time2]
    
    MqlRates rates[];
    // Seleciona o timeframe atual
    // ENUM_TIMEFRAMES timeframe = Period();

    // Pega o timeframe baseado no dia da semana
    ENUM_TIMEFRAMES timeframe = GetTimeframeByDay(selected_date);

    // Copia os dados de fechamento para o array rates
    int copied = CopyRates(_Symbol, timeframe, time1, time2, rates);
    
    if(copied > 1)
    {
        // Cálculo da Regressão Linear (Mínimos Quadrados)
        // y = mx + c
        // x é o índice (0 a N-1), y é o preço de fechamento
        
        double sum_x = 0, sum_y = 0, sum_xy = 0, sum_xx = 0;
        int n = copied;
        
        for(int i = 0; i < n; i++)
        {
            double y = rates[i].close;
            double x = (double)i; // Índice relativo ao início do array copiado
            
            sum_x += x;
            sum_y += y;
            sum_xy += (x * y);
            sum_xx += (x * x);
        }
        
        double m = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
        double c = (sum_y - m * sum_x) / n;
        
        // --- 3. Cálculo do Desvio Padrão ---
        double sum_sq_residuals = 0;
        for(int i = 0; i < n; i++)
        {
            double y = rates[i].close;
            double x = (double)i;
            double predicted = m * x + c;
            sum_sq_residuals += MathPow(y - predicted, 2);
        }
        
        double std_dev = MathSqrt(sum_sq_residuals / n);
        
        // --- 4. Projeção para o selected_date ---
        // Usamos Bars para contar quantas barras existem entre o inicio e o alvo,
        // garantindo que gaps de mercado sejam contabilizados corretamente.
        
        int bars_diff = Bars(_Symbol, timeframe, rates[0].time, selected_date);
        double target_index = (double)(bars_diff - 1);
        
        double projected_price = m * target_index + c;
        
        result.lineUp = projected_price + (deviation * std_dev);
        result.lineDown = projected_price - (deviation * std_dev);
        Print("@@@@@@@@@@@@@@ lineUp: ", result.lineUp, " - lineDown: ", result.lineDown);
    }
    
    return result;
}

