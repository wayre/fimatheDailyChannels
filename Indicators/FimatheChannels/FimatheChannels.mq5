//+------------------------------------------------------------------+
//|                                              FimatheChannels.mq5 |
//|                                      Copyright 2025, Fimathe |
//|                                             https://www.fimathe.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Fimathe"
#property link "https://www.fimathe.com"
#property version "1.01"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

//--- Input para o número de níveis de canais
input int InpChannelLevels = 10;
input color InpBaseChannelColor = C'63, 46, 139'; // Cor do Canal Base
input color InpUpperLevelsColor = C'76, 76, 158';  // Cor dos Níveis Superiores
input color InpLowerLevelsColor = C'76, 76, 158';    // Cor dos Níveis Inferiores
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID;   // Estilo da Linha

//--- Variáveis globais
datetime g_calculated_for_day = 0; // Guarda o dia para o qual os níveis foram calculados
string g_object_prefix;            // Prefixo para os nomes dos objetos no gráfico
string commentRobot = "";

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Cria um prefixo único para os objetos deste indicador
    g_object_prefix = "FimatheChannel_";// + IntegerToString(ChartID()) + "_";

    //--- Força um recálculo na inicialização
    g_calculated_for_day = 0;

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Limpa o comentário do gráfico
    Comment("");
    //--- Remove todos os objetos criados pelo indicador
    ObjectsDeleteAll(0, g_object_prefix);
}

//+------------------------------------------------------------------+
//| Retorna o horário de início da sessão de negociação para o dia atual.|
//| Retorna 0 se não houver sessão de negociação.                     |
//+------------------------------------------------------------------+
datetime GetSessionStartTime(const string symbol)
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    datetime trade_start = 0;
    datetime trade_end = 0;

    // Busca o horário da primeira sessão de negociação (índice 0)
    if (SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, trade_start, trade_end))
    {
        // Se a função for bem-sucedida e retornar um horário de início válido,
        // constrói o datetime completo para o dia de hoje.
        if (trade_start > 0)
        {
            MqlDateTime dt_start;
            TimeToStruct(trade_start, dt_start); // Extrai a hora/minuto da sessão

            dt.hour = dt_start.hour;
            dt.min = dt_start.min;
            dt.sec = 0;

            return (StructToTime(dt)); // Retorna o datetime completo para hoje
        }
    }

    return (0); // Retorna 0 se não encontrar sessão
}

//+------------------------------------------------------------------+
//| Desenha uma linha horizontal no gráfico                           |
//+------------------------------------------------------------------+
void DrawHorizontalLine(const string name, const double price, const string text, const color line_color, const ENUM_LINE_STYLE line_style, const int width = 1)
{
    if (ObjectFind(0, name) != 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    }
    else
    {
        ObjectMove(0, name, 0, 0, price);
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Calcula e desenha os níveis do canal                              |
//+------------------------------------------------------------------+
bool CalculateAndDrawLevels()
{
    // --- Define o timeframe com base no dia da semana ---
    MqlDateTime dt_temp;
    TimeToStruct(TimeCurrent(), dt_temp);

    ENUM_TIMEFRAMES timeframe;
    if (dt_temp.day_of_week == MONDAY)
    {
        timeframe = PERIOD_M15;
    }
    else
    {
        timeframe = PERIOD_M5;
    }

    string symbol = Symbol();
    bool isBigChannel = false; // usado para identificar de o cam; maior que 1000 pontos

    // --- Obtém dinamicamente o horário de início da sessão ---
    datetime session_start_time = GetSessionStartTime(symbol);

    if (session_start_time == 0)
    {
        // Ainda não há sessão para hoje, não é um erro.
        return false;
    }

    // --- Encontra o tempo de abertura da primeira vela da sessão para alinhar o cálculo ---
    int bar_shift = iBarShift(symbol, timeframe, session_start_time);
    datetime first_bar_open_time = iTime(symbol, timeframe, bar_shift);

    long period_seconds = PeriodSeconds(timeframe);
    datetime fourth_bar_close_time = first_bar_open_time + (datetime)(4 * period_seconds);

    // --- Verifica se as 4 velas já se formaram ---
    if (TimeCurrent() < fourth_bar_close_time)
    {
        // Ainda é cedo, as 4 velas não fecharam.
        return false;
    }
    
    // --- Copia os dados das 4 primeiras velas da sessão ---
    MqlRates rates[];
    int copied = CopyRates(symbol, timeframe, first_bar_open_time, fourth_bar_close_time, rates);

    if (copied < 4)
    {
        return false;
    }

    // --- Calcula o canal com base nessas 4 velas ---
    double max_high = 0;
    double min_low = 999999999; // Valor inicial alto

    for (int i = 0; i < 4; i++)
    {
        if (rates[i].high > max_high)
            max_high = rates[i].high;
        if (rates[i].low < min_low)
            min_low = rates[i].low;
    }

    double range_canal = max_high - min_low;

    // Normaliza o range para pontos para a verificação dos 1000 pontos
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    // Se o range for maior ou igual a 1000 pontos, divide pela metade.
    isBigChannel = point > 0 && range_canal / point >= 1000;
    if (isBigChannel)
    {
        range_canal /= 2;
        max_high = min_low + range_canal;
    }
    
    commentRobot = "TAMANHO DO CANAL: " + DoubleToString(StringToDouble(DoubleToString(range_canal,2))*100,0);

    // --- Desenha as novas linhas ---
    // Canal Base
    DrawHorizontalLine(g_object_prefix + "Superior_("+commentRobot+"pts_)", max_high, "Canal Superior", InpBaseChannelColor, STYLE_DASH, 2);
    DrawHorizontalLine(g_object_prefix + "Inferior_("+commentRobot+"pts_)", min_low, "Canal Inferior", InpBaseChannelColor, STYLE_DASH, 2);
    
    // Níveis Superiores
    for (int i = 1; i <= InpChannelLevels; i++)
    {
        double level_price = max_high + (i * range_canal);
        string level_name = "Nível " + IntegerToString(i) + " Up";
        DrawHorizontalLine(g_object_prefix + "Up_" + IntegerToString(i), level_price, level_name, InpUpperLevelsColor, InpLineStyle);
    }

    // Níveis Inferiores
    for (int i = 1; i <= InpChannelLevels; i++)
    {
        double level_price = min_low - (i * range_canal);
        string level_name = "Nível " + IntegerToString(i) + " Down";
        DrawHorizontalLine(g_object_prefix + "Down_" + IntegerToString(i), level_price, level_name, InpLowerLevelsColor, InpLineStyle);
    }

    ChartRedraw();
    return true; // Sucesso
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
    //--- Obtém o início do dia atual (baseado no tempo do servidor)
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    datetime today_start = StructToTime(dt);

    //--- Se for um novo dia, limpa os canais antigos e tenta calcular os novos.
    if (g_calculated_for_day != today_start)
    {
        // É um novo dia, então removemos os objetos antigos.
        ObjectsDeleteAll(0, g_object_prefix);

        // Se o cálculo dos novos níveis for bem-sucedido, atualiza a data.
        if (CalculateAndDrawLevels())
        {
            g_calculated_for_day = today_start;
        }
    }

    return (rates_total);
}
//+------------------------------------------------------------------+
