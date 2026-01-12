//+------------------------------------------------------------------+
//|                                        FimatheDailyChannels.mq5 |
//|                                             Copyright 2025, Fimathe |
//|                                            https://www.fimathe.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Fimathe"
#property link "https://www.fimathe.com"
#property version "2.00"
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_NONE
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
struct CanalStdDev {
    double central;
    double superior;
    double inferior;
    double desvio_padrao;
};

//--- Estrutura para retorno do range da sessão
struct SessionRangeFimathe
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
int handle_slow = INVALID_HANDLE;
int handle_fast = INVALID_HANDLE;

//--- Constants for state persistence
#define LAST_TYPE_NONE   0
#define LAST_TYPE_FIBO   1
#define LAST_TYPE_STDDEV 2

//--- Helper functions prototypes (Forward declarations abolished in favor of Struct)
bool ProcessFibonacci(datetime clicked_day);
bool ProcessStdDevChannel(datetime clicked_day);

//--- Globals for delayed restoration
int g_restore_type = LAST_TYPE_NONE;
datetime g_restore_date = 0;
int g_restore_attempts = 0;

//--- Struct to handle Session State
struct SessionState
{
    static void Save(int type, datetime date)
    {
        string key = GetKey();
        // Pack data: Integer part = Date, Decimal part = Type/10
        double packed = (double)date + ((double)type / 10.0);
        
        // Use GlobalVariableTemp to avoid disk I/O (memory only persistence)
        if(!GlobalVariableCheck(key)) GlobalVariableTemp(key); 
        GlobalVariableSet(key, packed);
    }
    
    static void Load(int &type, datetime &date)
    {
        string key = GetKey();
        if(!GlobalVariableCheck(key)) 
        {
            type = LAST_TYPE_NONE;
            date = 0;
            return;
        }
        
        double packed = GlobalVariableGet(key);
        date = (datetime)MathFloor(packed);
        // Extract type from decimal: (value - floor) * 10
        type = (int)MathRound((packed - MathFloor(packed)) * 10.0);
    }
    
    static void Clear()
    {
        string key = GetKey();
        if(GlobalVariableCheck(key)) GlobalVariableDel(key);
    }
    
    static string GetKey()
    {
        return "Fimathe_State_" + IntegerToString(ChartID());
    }
};

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
    handle_slow = iCustom(_Symbol, PERIOD_M5, "Examples\\ZigZag",8, 4, 4);
    if (handle_slow == INVALID_HANDLE)
    {
        Print("Erro ao criar handle do ZigZag");
        return INIT_FAILED;
    }
     // Inicializa o ZigZag com os parâmetros 12, 5, 3
    handle_fast = iCustom(_Symbol, PERIOD_M5, "Examples\\ZigZag",3, 2, 2);
    if (handle_slow == INVALID_HANDLE)
    {
        Print("Erro ao criar handle do ZigZag");
        return INIT_FAILED;
    }
   
    //--- Check for saved state (Timeframe change recalculation)
    // Defer processing to OnCalculate to ensure data is ready 
    SessionState::Load(g_restore_type, g_restore_date);
    g_restore_attempts = 0;
    
    if(g_restore_type != LAST_TYPE_NONE && g_restore_date > 0)
    {
        Print("OnInit: State found - Type: ", g_restore_type, " Date: ", TimeToString(g_restore_date), ". Queuing for restore.");
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
    
    // Only clear state if NOT changing chart (timeframe/symbol)
    if(reason != REASON_CHARTCHANGE)
    {
        SessionState::Clear();
    }

    //--- Limpa o comentário do gráfico
    Comment("");
    //--- Remove todos os objetos criados pelo indicador
    ObjectsDeleteAll(0, g_object_prefix);
    g_drawn_days.Clear();
    
    if(handle_slow != INVALID_HANDLE)
    {
        IndicatorRelease(handle_slow);
    }
}

//+------------------------------------------------------------------+
//| Retorna o início e fim da sessão de negociação de forma otimizada|
//+------------------------------------------------------------------+
bool GetSessionTimesForDay(const string symbol, const datetime for_day, datetime &session_start, datetime &session_end)
{
    // 1. Obter o início do dia (00:00:00) via aritmética (muito mais rápido que TimeToStruct)
    const datetime day_start = for_day - (for_day % 86400);
    
    // 2. Determinar o dia da semana
    MqlDateTime dt;
    TimeToStruct(for_day, dt);

    datetime from, to;
    // 3. Buscar a primeira sessão de trade (index 0)
    if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, from, to))
        return false;

    // 4. Calcular horários absolutos
    session_start = day_start + from;
    session_end   = day_start + to;

    // 5. Tratar sessões que cruzam a meia-noite
    if(session_end <= session_start)
        session_end += 86400;

    // 6. Normalização de fim de dia (23:59)
    if(to >= 86340) // Se termina no minuto 23:59
        session_end = day_start + 86399;

    return (session_start > 0);
}

//+------------------------------------------------------------------+
//| Calcula os dados do Fibonacci para um dia específico                |
//+------------------------------------------------------------------+
FiboData CalculateFiboDataForDay(const datetime for_day)
{
    FiboData result = {0};
    result.is_valid = false;

    string symbol = Symbol();

    SessionRangeFimathe range_4candles_day = getInfoSessionFimathe(for_day);
    if (!range_4candles_day.valid) return result;   

    // Pega o maior high e o menor low dos 4 primeiros candles
    double max_high = range_4candles_day.max;
    double min_low = range_4candles_day.min;

    // Pega o range dos 4 primeiros candles
    result.range = range_4candles_day.range * SymbolInfoDouble(symbol, SYMBOL_POINT);
    Print("Range: ", result.range);
    
    
    // Ajusta o range para ser múltiplo de 1000 pontos
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(point > 0 && result.range / point >= 1000)
    {
        result.range /= 2;
        max_high = min_low + result.range;
        Print("CalculateFiboDataForDay: Range > 1000 pontos, ajustado para ", result.range);
    }
    
    g_comment_robot = "Size Channel: " + DoubleToString(result.range/point,0);
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

    // Lógica de divisão do range se for maior que 1000 pontos
    if(points_range > 2000)
    {
        range = range / 4;
    } else if(points_range > 1000)
    {
        // int n = 2;
        // while(true)
        // {
        //     double sub_range = points_range / n;
        //     if(sub_range <= 900 && sub_range >= 500)
        //     {
        //         range = range / n;
        //         Print("CalculateFiboDataFromChannel: Range original ", points_range, " dividido por ", n, " -> ", range/point);
        //         break;
        //     }
        //     n = n*2;
        //     if(n > 100) break; // Proteção
        // }
        range = range / 2;
    }

    result.min_low = MathMin(lineUp, lineDown);
    result.range = range;
    result.max_high = result.min_low + range;

    g_comment_robot = "Size Canal: " + DoubleToString(result.range/point,0);
    Comment(g_comment_robot);
    
    // Preenche horários da sessão
    datetime session_start = 0;
    datetime session_end = 0;
    GetSessionTimesForDay(_Symbol, selected_day, session_start, session_end);
    
    SessionRangeFimathe range_4candles_day = getInfoSessionFimathe(selected_day);
    result.time1 = range_4candles_day.last_candle;
    result.time2 = session_end;
    
    result.is_valid = true;
    return result;
}

//+------------------------------------------------------------------+
//| Desenha o objeto Fibonacci para um dia                           |
//+------------------------------------------------------------------+
void DrawDayFibonacci(const FiboData &fibo_data, const datetime for_day)
{
    if(!fibo_data.is_valid) return;

    string day_str = TimeToString(for_day, TIME_DATE);
    string obj_name = g_object_prefix + "Fibo";

    // Define o tempo de início e fim para o objeto Fibonacci
    MqlDateTime dt;
    TimeToStruct(for_day, dt);
    datetime time2 =0;

    dt.hour = 1; dt.min = 0; dt.sec = 0;
    datetime time1 = StructToTime(dt);
    

    datetime current_time = TimeTradeServer();
    TimeToStruct(current_time, dt);
    dt.hour = 1; dt.min = 0; dt.sec = 0;
    current_time = StructToTime(dt);
    
    TimeToStruct(for_day, dt);
    
    // checar se for_day é a data de hoje
    if(for_day >= current_time)
    {
        dt.hour = 9; dt.min = 0; dt.sec = 0;
        time2 = StructToTime(dt);
        
        //pega o ultimo datetime do candle
        datetime last_candle = TimeCurrent();
        time2 = time2 > last_candle ? time2 : last_candle;
    }else {
        //get last candle
        // dt.hour = 23; dt.min = 55; dt.sec = 0;
        dt.hour = 9; dt.min = 0; dt.sec = 0;
        time2 = StructToTime(dt);
    }
    

    // Cria ou move o objeto Fibonacci
    if(ObjectFind(0, obj_name) < 0)
    {
        if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, fibo_data.time1, fibo_data.min_low, time2, fibo_data.max_high))
        {
            Print("Erro ao criar objeto Fibonacci: ", GetLastError());
            return;
        }
    }
    else
    {
        ObjectMove(0, obj_name, 0, time1, fibo_data.min_low);
        ObjectMove(0, obj_name, 1, time2, fibo_data.max_high);
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
bool ProcessFibonacci(datetime clicked_day)
{
    // Save state for persistence
    SessionState::Save(LAST_TYPE_FIBO, clicked_day);

    // Limpa objetos antigos e desenha o novo
    ObjectsDeleteAll(0, g_object_prefix);
    g_drawn_days.Clear();

    FiboData data = CalculateFiboDataForDay(clicked_day);
    if(data.is_valid)
    {
        DrawDayFibonacci(data, clicked_day);
        g_drawn_days.Add(clicked_day);
        ChartRedraw();
        return true;
    }
    else
    {
        Print("ProcessFibonacci: Falha ao calcular dados. (Talvez dados ainda não carregados?)");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Processa e desenha o Canal de Desvio Padrão                      |
//+------------------------------------------------------------------+
bool ProcessStdDevChannel(datetime clicked_day)
{
    // --- Lógica do Canal de Desvio Padrão ---
    // 1. Identificar o ultimo candle pivô com a funcao GetZigZagPivot.
    //    Regra: "pivo da ultima perna do dia anterior até o fechamento do 4 candle do timeframe atual do clicked_day"
    
    // Save state for persistence
    SessionState::Save(LAST_TYPE_STDDEV, clicked_day);
    
    // Limpa objetos antigos e desenha o novo
    ObjectsDeleteAll(0, g_object_prefix);
    g_drawn_days.Clear();

    datetime pivot_datetime = GetDualZigZagChampion(clicked_day);

    if (pivot_datetime > 0)
    {
        SessionRangeFimathe range_4candles_day = getInfoSessionFimathe(clicked_day);
        
        if(!range_4candles_day.valid) return false;

        datetime time2 = range_4candles_day.last_candle;
        datetime selected_date = range_4candles_day.last_candle;
        
        // Desenha Canal de Desvio Padrão
        string stdDevChannelName = g_object_prefix + "StdDev_Channel";
        addObjStdDevChannel(stdDevChannelName, pivot_datetime, time2);
        
        // --- 3. Calcula o canal de desvio padrão para selected_date ---
        CanalStdDev canal = CalcularCanalStdDev(pivot_datetime, time2, selected_date);
        FiboData fibo_data = CalculateFiboDataFromChannel(clicked_day, canal.superior, canal.inferior);
        
        if( fibo_data.is_valid)
        {
            DrawDayFibonacci(fibo_data, clicked_day);
            g_drawn_days.Add(clicked_day);
            ChartRedraw();
            return true;
        }
        else
        {
            Print("ProcessStdDevChannel: Falha ao calcular dados. (Fibo data invalid)");
            return false;
        }
    }   
    else
    {
        Print("ProcessStdDevChannel: Nenhum pivô encontrado para o cálculo do StdDev Channel.");
        return false;
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
        g_shift_down = false;
    }
    // --- Lida com o evento de clique (Ctrl + Click) ---
    if(id == CHARTEVENT_CLICK && g_ctrl_down)
    {
        HandleClickFimathe(lparam, dparam);
        g_ctrl_down = false;
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
    // A lógica de desenho é tratada pelo OnChartEvent (clique).
    
    // Check for restoration queue
    if(g_restore_type != LAST_TYPE_NONE && g_restore_date > 0)
    {
        g_restore_attempts++;
        bool success = false;
        
        // Attempt to restore
        if(g_restore_type == LAST_TYPE_FIBO)
        {
             success = ProcessFibonacci(g_restore_date);
        }
        else if(g_restore_type == LAST_TYPE_STDDEV)
        {
             success = ProcessStdDevChannel(g_restore_date);
        }
        
        if(success)
        {
            Print("OnCalculate: Restoration successful after ", g_restore_attempts, " attempts.");
            g_restore_type = LAST_TYPE_NONE; // Clear queue
            g_restore_date = 0;
        }
        else
        {
             // If failed, we keep trying in next ticks up to a limit
             if(g_restore_attempts > 50) // Give it some time (approx 50 ticks)
             {
                 Print("OnCalculate: Failed to restore state after ", g_restore_attempts, " attempts. Giving up.");
                 g_restore_type = LAST_TYPE_NONE;
                 g_restore_date = 0;
             }
        }
    }

    return (rates_total);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Calcula o range (max/min) dos 4 primeiros candles da sessão      |
//+------------------------------------------------------------------+
SessionRangeFimathe getInfoSessionFimathe(datetime selected_day)
{
    SessionRangeFimathe result;
    result.max   = -DBL_MAX;
    result.min   =  DBL_MAX;
    result.range =  0.0;
    result.valid =  false;

    string symbol = _Symbol;
    datetime session_start, session_end;

    // 1. Obter horários da sessão
    if(!GetSessionTimesForDay(symbol, selected_day, session_start, session_end))
    {
        Print("CalculateSessionRangeFimathe: Falha ao obter horário da sessão.");
        return result;
    }

    // 2. Timeframe baseado no dia da semana
    ENUM_TIMEFRAMES timeframe = GetTimeframeByDay(selected_day);
    string weekdays[] = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"};
    MqlDateTime dt;
    TimeToStruct(selected_day, dt);
    Print("Timeframe: ", timeframe, " - ", dt.day_of_week, " - ", weekdays[dt.day_of_week]);

    // 3. Copiar os candles da sessão usando intervalo de tempo
    // Isso garante que pegamos os primeiros candles disponíveis a partir de session_start
    MqlRates rates[];
    ArraySetAsSeries(rates, false); // Garante ordem cronológica (índice 0 é o mais antigo)

    int copied = CopyRates(symbol, timeframe, session_start, session_end, rates);

    if(copied < 4)
    {
        Print("CalculateSessionRangeFimathe: Falha ao copiar candles suficientes (copiados: ", copied, "). Mínimo necessário: 4.");
        return result;
    }

    int qtde_candles = dt.day_of_week == 1 ? 12 : 4;
    // 4. Calcular range dos 4 primeiros candles
    // Iteramos apenas os 4 primeiros candles (índices 0, 1, 2, 3)
    for(int i = 0; i < qtde_candles; i++)
    {
        if(rates[i].high > result.max) result.max = rates[i].high;
        if(rates[i].low  < result.min) result.min = rates[i].low;
    }
    
    result.first_candle = rates[0].time;
    result.last_candle   = rates[qtde_candles-1].time; 
    
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

// --- Calcula Regressão Linear Simples (y = a + bx) ---
// Retorna 'intercept' (nível inicial) e 'slope' (inclinação por barra)
void CalculateLinearRegression(const double &y_values[], int count, double &intercept, double &slope)
{
   if(count < 2) { intercept=0; slope=0; return; }

   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_xx = 0;
   
   // x é sempre sequencial (0, 1, 2...) neste contexto de tempo
   for(int i=0; i<count; i++) {
      double x = (double)i;
      double y = y_values[i];
      
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_xx += x * x;
   }
   
   double denominator = (count * sum_xx) - (sum_x * sum_x);
   
   if(denominator == 0.0) { intercept=0; slope=0; return; }
   
   slope = ((count * sum_xy) - (sum_x * sum_y)) / denominator;
   intercept = (sum_y - (slope * sum_x)) / count;
}

// Calcula o Coeficiente de Correlação de Pearson (-1 a 1)
double CalculatePearsonCorrelation(const double &x[], const double &y[], int count)
{
   if(count < 2) return 0.0;

   double sum_x = 0, sum_y = 0;
   // Calcula Médias
   for(int i=0; i<count; i++) {
      sum_x += x[i];
      sum_y += y[i];
   }
   double mean_x = sum_x / count;
   double mean_y = sum_y / count;

   double num = 0.0;
   double den_x = 0.0;
   double den_y = 0.0;

   // Calcula Numerador e Denominador
   for(int i=0; i<count; i++) {
      double dx = x[i] - mean_x;
      double dy = y[i] - mean_y;
      num += dx * dy;
      den_x += dx * dx;
      den_y += dy * dy;
   }

   if(den_x == 0 || den_y == 0) return 0.0;

   return num / MathSqrt(den_x * den_y);
}

//+------------------------------------------------------------------+
//| Função: GetDualZigZagChampion (Otimizada com CopyRates)          |
//+------------------------------------------------------------------+
datetime GetDualZigZagChampion(datetime selected_datetime, int lookback=200)
{
   // Estrutura interna para "limpar" os ZigZags (Sparse -> Dense)
    struct ZigPoint {
    double val;          // Valor do Preço
    datetime time;       // Tempo
    int rates_index;     // Índice no array MqlRates (para cálculo rápido)
    };

   // --- 1. AQUISIÇÃO DE DADOS (COPYRATES) ---
   if(handle_slow == INVALID_HANDLE || handle_fast == INVALID_HANDLE) return 0;

   MqlRates rates[];
   double slow_buffer[], fast_buffer[];
   
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(slow_buffer, true);
   ArraySetAsSeries(fast_buffer, true);

   // Copia tudo de uma vez para performance
   if(CopyRates(_Symbol, _Period, selected_datetime, lookback, rates) <= 0 ||
      CopyBuffer(handle_slow, 0, selected_datetime, lookback, slow_buffer) <= 0 ||
      CopyBuffer(handle_fast, 0, selected_datetime, lookback, fast_buffer) <= 0)
   {
      return 0; // Falha na cópia
   }

   // --- 2. EXTRAÇÃO LIMPA (SPARSE -> DENSE) ---
   // Cria listas apenas com os pivôs reais, descartando zeros
   ZigPoint slow_points[];
   ZigPoint fast_points[];
   
   int s_count = 0;
   ArrayResize(slow_points, lookback);
   for(int i = 0; i < lookback; i++) {
      if(slow_buffer[i] != 0 && slow_buffer[i] != EMPTY_VALUE) {
         slow_points[s_count].val = slow_buffer[i];
         slow_points[s_count].time = rates[i].time;
         slow_points[s_count].rates_index = i; // Guarda índice para cálculo linear
         s_count++;
      }
   }
   ArrayResize(slow_points, s_count);

   int f_count = 0;
   ArrayResize(fast_points, lookback);
   for(int i = 0; i < lookback; i++) {
      if(fast_buffer[i] != 0 && fast_buffer[i] != EMPTY_VALUE) {
         fast_points[f_count].val = fast_buffer[i];
         fast_points[f_count].time = rates[i].time;
         fast_points[f_count].rates_index = i;
         f_count++;
      }
   }
   ArrayResize(fast_points, f_count);

   // --- 3. DEFINIÇÃO DE CONSTANTES DA SESSÃO ---
   SessionRangeFimathe session_info = getInfoSessionFimathe(selected_datetime);
   datetime time2 = session_info.last_candle;
   
   // Encontrar o índice de time2 no array rates (aproximado)
   int idx_time2 = 0;
   for(int k=0; k<lookback; k++) {
      if(rates[k].time <= time2) { idx_time2 = k; break; }
   }

   // Variáveis de Controle do Campeão
   datetime best_datetime = 0;
   double best_score = -999999.0;

   // Arrays auxiliares para cálculo de regressão (reutilizáveis)
   double x_reg[]; ArrayResize(x_reg, lookback);
   double y_reg[]; ArrayResize(y_reg, lookback);

   // --- 4. ITERAÇÃO MESTRA (CANDIDATOS ZIGZAG LENTO) ---
   // Itera sobre cada pivô lento como possível início do canal (time1)
   for(int i = 0; i < s_count; i++)
   {
      datetime time1 = slow_points[i].time;
      if(time1 >= time2) continue; // Validação temporal básica

      int idx_time1 = slow_points[i].rates_index;
      
      // A. OBTER DADOS DO CANAL DE REFERÊNCIA
      // Chamamos a função externa para obter a largura e os pontos base
      CanalStdDev canal = CalcularCanalStdDev(time1, time2, time1, 1.0);
      
      // Nota: CalcularCanalStdDev nos dá os valores no ponto time1 (target).
      // Para pontuar outros pontos, precisamos da inclinação (slope) da reta.
      // Vamos calcular a Regressão Linear deste segmento para poder projetar os valores.
      
      int data_count = idx_time1 - idx_time2 + 1;
      if(data_count < 2) continue;

      // Preenche arrays para regressão (Preços de Fechamento entre Time1 e Time2)
      for(int k=0; k < data_count; k++) {
         y_reg[k] = rates[idx_time1 - k].close; // Do passado para o futuro
         x_reg[k] = (double)k;
      }

      double slope, intercept;
      CalculateLinearRegression(y_reg, data_count, intercept, slope);
      
      // Largura do Canal (Baseada no calculo externo ou desvio padrão interno)
      double largura_total = MathAbs(canal.superior - canal.inferior);
      double semi_largura = largura_total / 2.0;
      double tolerancia = largura_total * 0.15; // 15% de margem para considerar "próximo"

      // B. LOOP DE PONTUAÇÃO (SCORING)
      double current_score = 0;

      // --- Validação Cruzada: Pivôs RÁPIDOS ---
      for(int f = 0; f < f_count; f++)
      {
         // Ignora pivôs fora da janela temporal do canal analisado
         if(fast_points[f].time < time1 || fast_points[f].time > time2) continue;

         // Projeção Matemática: Qual seria o valor do Centro/Sup/Inf neste exato momento?
         // Distância em barras do início (time1)
         double delta_bars = (double)(idx_time1 - fast_points[f].rates_index);
         
         double proj_central = intercept + (slope * delta_bars);
         double proj_sup = proj_central + semi_largura;
         double proj_inf = proj_central - semi_largura;
         double val = fast_points[f].val;

         // Regras de Pontuação (Rápido)
         bool is_inside = (val <= proj_sup && val >= proj_inf);
         
         if(is_inside)
         {
            // Bônus por proximidade das bordas (Superior ou Inferior)
            if(MathAbs(val - proj_sup) < tolerancia || MathAbs(val - proj_inf) < tolerancia)
               current_score += 1.5; // Peso Médio
            
            // Bônus por proximidade do centro (Regressão à média)
            else if(MathAbs(val - proj_central) < tolerancia)
               current_score += 0.5; // Peso Baixo
         }
         else
         {
            // PENALIDADE: Rompimento do canal
            current_score -= 5.0; 
         }
      }

      // --- Validação Mestra: Pivôs LENTOS ---
      for(int s = 0; s < s_count; s++)
      {
         // Ignora pivôs fora da janela
         if(slow_points[s].time < time1 || slow_points[s].time > time2) continue;

         // Projeção Matemática
         double delta_bars = (double)(idx_time1 - slow_points[s].rates_index);
         
         double proj_central = intercept + (slope * delta_bars);
         double proj_sup = proj_central + semi_largura;
         double proj_inf = proj_central - semi_largura;
         double val = slow_points[s].val;

         bool is_inside = (val <= proj_sup && val >= proj_inf);

         if(is_inside)
         {
            // Bônus ALTO por proximidade das bordas (Pivô Lento na Borda = Estrutura Forte)
            if(MathAbs(val - proj_sup) < tolerancia || MathAbs(val - proj_inf) < tolerancia)
               current_score += 3.0; // Peso Alto (Prioridade)
            
            else if(MathAbs(val - proj_central) < tolerancia)
               current_score += 1.0;
         }
         else
         {
            // PENALIDADE: Pivô Lento fora do canal invalida fortemente a estrutura
            current_score -= 5.0;
         }
      }

      // Adicional: Pearson Correlation como fator multiplicador de qualidade
      // Canais muito erráticos (Pearson baixo) perdem valor no score final
      double pearson = CalculatePearsonCorrelation(x_reg, y_reg, data_count);
      current_score += (MathAbs(pearson) * 10.0); // Bônus de até 10 pontos pela linearidade

      // C. RANKING
      if(current_score > best_score)
      {
         best_score = current_score;
         best_datetime = time1;
      }
   }

   return best_datetime; // Retorna o início do melhor canal encontrado
}

//+------------------------------------------------------------------+
//| Identifica um padrão de pivô "A-B-C-D" válido no ZigZag.         |
//|                                                                  |
//| Critérios de validação:                                          |
//| 1. Estrutura de Alta (D < B e B > C) ou Baixa (D > B e B < C).   |
//| 2. Retração (C) deve estar entre 20% e 80% do movimento A-D.     |
//| 3. A perna C-D deve ser maior que a largura do Canal de Desvio   |
//|    Padrão calculado (Expansão).                                  |
//|                                                                  |
//| Return: Datetime do ponto 'D' (início do movimento) se válido.   |
//+------------------------------------------------------------------+
datetime GetDatetimeChecked(const datetime selected_datetime, int lookback = 200)
{
    if(handle_slow == INVALID_HANDLE) return 0;

    double zigzag_buffer[];
    datetime time_buffer[];
    
    ENUM_TIMEFRAMES period = PERIOD_M5;

    ArraySetAsSeries(zigzag_buffer, true);
    ArraySetAsSeries(time_buffer, true);

    // Cópia em massa para performance
    if(CopyBuffer(handle_slow, 0, selected_datetime, lookback, zigzag_buffer) <= 0 ||
       CopyTime(_Symbol, period, selected_datetime, lookback, time_buffer) <= 0)
    {
        // Print("GetDatetimeChecked: Erro ao copiar buffer ZigZag. Error: ", GetLastError());
        return 0;
    }

    struct ZigPoint {
        double val;          // Valor do Preço
        datetime time;       // Tempo
        int original_index;  // Índice para acesso rápido ao Close
    };
    ZigPoint points[];
    
    // Reserva memória antecipadamente para evitar realocações no loop
    ArrayResize(points, lookback); 
    int count = 0;

    // 1. Extração de pontos válidos (filtrando zeros/vazios)
    for(int i = 0; i < lookback; i++)
    {
        if(zigzag_buffer[i] != 0 && zigzag_buffer[i] != EMPTY_VALUE)
        {
            points[count].val = zigzag_buffer[i];
            points[count].time = time_buffer[i];
            count++;
        }
    }

    ArrayResize(points, count);

    int total_points = ArraySize(points);
    if(total_points < 4) return 0; // Necessário ao menos a, b, c, d para a verificação

    // 2. Busca pela regra a < b < c ou a > b > c
    // Começamos em 0 (mais recente) e olhamos para trás
    for(int i = 0; i <= total_points - 4; i++)
    {
        Print(points[i].time);
        double a = points[i].val;
        double b = points[i+1].val;
        double c = points[i+2].val;
        double d = points[i+3].val;

        // User Logic Implementation
        // Range total entre a e d
        double range_ad = MathAbs(a - d);
        bool condition_met = false;
        
        if (range_ad > 0)
        {
            // O range fibonacci é entre variavel "a" e variavel "d"
            // Verifica se 'c' esta entre 0.382 e 0.618 desse range (a-d)
            // Para isso calculamos a distancia de c ate o inicio d (ou ate a), em comparacao ao total
            double dist_c_d = MathAbs(c - d);
            double c_pos_ratio = dist_c_d / range_ad;
            
            bool is_fib_ok = (c_pos_ratio >= 0.2 && c_pos_ratio <= 0.8);

            // Se é primeira perna de baixa onde "b" < "a" 
            // espero um "c" como pullback sendo "c" > "b" ... seguido de um "d" < "b".
            if (b < a)
            {
                if (c > b && d < b && is_fib_ok)
                {
                    condition_met = true;
                }
            }
            // Se é primeira perna de alta onde "b" > "a" 
            // entao espero um "c" como pullback sendo "c" < "b" ... seguindo de um "d" > "b". 
            // (Nota: Corrigido "d > b" conforme logica de tendencia oposta simetrica, invertendo sinais)
            else if (b > a)
            {
                if (c < b && d > b && is_fib_ok)
                {
                    condition_met = true;
                }
            }

            // a distancia entre a perna "c" até d" deve ser 2 vezes maior que o canal de desvio padrão
            if (condition_met)
            {
                SessionRangeFimathe range_4candles_day = getInfoSessionFimathe(selected_datetime);
                datetime time2 = range_4candles_day.last_candle;
                
                // Calcula o canal de desvio padrão para selected_date ---
                CanalStdDev canal = CalcularCanalStdDev(points[i+3].time, time2, points[i+3].time);
                Print("Candle A: ", points[i].time, " time1: ", points[i+3].time, " time2: ", time2);
                double dist_cd = MathAbs(c - d);
                double distCanal = MathAbs(canal.superior - canal.inferior);

                // Deve ser maior que o DOBRO da distCanal
                bool is_expansion_valid = (dist_cd > distCanal);
                
                Print("dist_cd: ", dist_cd, " distCanal: ", distCanal);
                
                if (!is_expansion_valid)
                {
                    condition_met = false;
                }
            }
        }

        if(condition_met)
        {
            return points[i+3].time; // Retorna o datetime de 'c'
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Busca o último pivô do ZigZag que respeita a condição "Inside".  |
//|                                                                  |
//| Lógica:                                                          |
//| 1. Analisa pivôs passados a partir de 'datetime_base'.           |
//| 2. Valida se o pivô está dentro do Range dos 4 candles iniciais. |
//| 3. Aprofunda no histórico (lookback) até encontrar um pivô que   |
//|    esteja FORA do range.                                         |
//| 4. Retorna o pivô imediatamente anterior ao que saiu do range    |
//|    (ou seja, o pivô mais antigo que ainda é considerado Inside). |
//|                                                                  |
//| Return: Datetime do pivô encontrado ou 0.                        |
//+------------------------------------------------------------------+
datetime GetZigZagPivot(datetime datetime_base, int lookback=50)
{
    if (handle_slow == INVALID_HANDLE) return 0;

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

    if (CopyBuffer(handle_slow, 0, session_start, lookback, zigzag_buffer) < lookback)
    {
        int available = Bars(_Symbol, _Period);
        if (available < lookback) lookback = available; // Ajusta lookback se não houver dados suficientes
        if (CopyBuffer(handle_slow, 0, session_start, lookback, zigzag_buffer) <= 0)
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
    SessionRangeFimathe range_4candles_day = getInfoSessionFimathe(session_start);
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

    int total_pivots = ArraySize(found_pivots);
    if(total_pivots <= 0)
    {
        return 0; // Nenhum pivô encontrado na janela
    }
    
    return return_datetime ? return_datetime : found_pivots[total_pivots-1].time; // Retorna o datetime do último pivot encontrado
}


//+------------------------------------------------------------------+
//| Determina o timeframe de análise com base no dia da semana       |
//| da data fornecida.                                               |
//| Também atualiza os comentários de debug no gráfico.              |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframeByDay(datetime date_selected)
{
    MqlDateTime dt;
    TimeToStruct(date_selected, dt);

    string weekdays[] = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"};
    
    ENUM_TIMEFRAMES timeframe;
    timeframe = dt.day_of_week == MONDAY ? PERIOD_M5 : PERIOD_M5;
    
    g_comment_robot += "\n" + weekdays[dt.day_of_week] + " " + EnumToString(timeframe);
    Print(g_comment_robot);
    Comment(g_comment_robot);
    
    return timeframe;
}

/**
 * Calcula o canal de Desvio Padrão
 */
CanalStdDev CalcularCanalStdDev(datetime time1, datetime time2, datetime target_time, double mult = 1)
{
    CanalStdDev res = {0,0,0,0};
    string symbol = _Symbol;
    ENUM_TIMEFRAMES timeframe = PERIOD_M5;

    int idx1 = iBarShift(symbol, timeframe, time1);
    int idx2 = iBarShift(symbol, timeframe, time2);
    int idxTarget = iBarShift(symbol, timeframe, target_time);
    
    int n = MathAbs(idx1 - idx2) + 1;
    if(n < 2) return res;

    double prices[];
    ArraySetAsSeries(prices, true);
    if(CopyClose(symbol, timeframe, MathMin(idx1, idx2), n, prices) < n) return res;

    // 1. Regressão Linear (para a linha central)
    double sumX = 0, sumY = 0, sumX2 = 0, sumXY = 0;
    for(int i = 0; i < n; i++)
    {
        double x = i;
        double y = prices[n - 1 - i]; 
        sumX  += x;
        sumY  += y;
        sumX2 += x * x;
        sumXY += x * y;
    }

    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    double intercept = (sumY - slope * sumX) / n;

    // 2. Desvio Padrão "Modo MT5" (Desvio dos Preços, não dos resíduos)
    double meanY = sumY / n;
    double sumVar = 0;
    for(int i = 0; i < n; i++)
    {
        double diff = prices[i] - meanY;
        sumVar += diff * diff;
    }
    res.desvio_padrao = MathSqrt(sumVar / n);

    // 3. Cálculo Final
    int x_target = MathAbs(idx1 - idxTarget);
    res.central  = intercept + (slope * x_target);
    res.superior = res.central + (mult * res.desvio_padrao);
    res.inferior = res.central - (mult * res.desvio_padrao);

    return res;
}

/**
 * Desenha um Canal de Desvio Padrão
*/
void addObjStdDevChannel(string obj_name, datetime time1, datetime time2, double deviation=1)
{
    // --- 1. Cria ou atualiza o objeto gráfico ---
    if(ObjectFind(0, obj_name) >= 0)
    {
        ObjectDelete(0, obj_name);
    }

    // ObjectCreate(0, obj_name, OBJ_REGRESSION, 0, time1, 0, time2, 0);
    ObjectCreate(0, obj_name, OBJ_STDDEVCHANNEL, 0, time1, 0, time2, 0);
    ObjectSetDouble(0, obj_name, OBJPROP_DEVIATION, deviation);
    // ObjectSetDouble(0, obj_name, OBJPROP_DEVIATION, deviation);
    // rgba(104, 115, 139, 1)
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, C'104, 115, 139'); // Cor padrão, pode ser parametrizada
    ObjectSetInteger(0, obj_name, OBJPROP_RAY, true);      // Estende o canal

    // Propriedades para tornar o objeto selecionável e editável
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_FILL, false); 
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, obj_name, OBJPROP_STATE, true);
    ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);  
    ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, false); // Garante a extensão à direita
}
