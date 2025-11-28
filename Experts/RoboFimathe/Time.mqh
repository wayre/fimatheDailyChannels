//+------------------------------------------------------------------+
//|                                                         Time.mqh |
//|                                      Copyright 2025, Fimathe |
//|                                             https://www.fimathe.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Fimathe"
#property link "https://www.fimathe.com"
#property version "3.00"

// Variável para armazenar o nome do símbolo, para facilitar a leitura.
// Em um EA real, você usaria Symbol() ou _Symbol.
#define CURRENT_SYMBOL Symbol()

//+------------------------------------------------------------------+
//| Verifica se o dia atual é um dia de negociação fixo.             |
//| Operação definida pelo usuário: MONDAY (1) até FRIDAY (5).       |
//| (Exclui Domingo à noite e Sábado integralmente)                  |
//+------------------------------------------------------------------+
bool IsTradingDay()
{
    MqlDateTime dt;
    // Pega o tempo atual do servidor (TimeCurrent())
    TimeToStruct(TimeCurrent(), dt);

    // MQL define MONDAY = 1 e FRIDAY = 5
    if (dt.day_of_week >= MONDAY && dt.day_of_week <= FRIDAY)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Verifica se a hora atual está dentro do horário de negociação.   |
//| Horário é obtido dinamicamente da corretora (SymbolInfoSessionTrade).
//| Usa o Horário do Servidor (UTC+2 ou o que estiver configurado).  |
//+------------------------------------------------------------------+
bool IsTradingHours()
{
    MqlDateTime dt;
    // Pega o tempo atual do servidor
    TimeToStruct(TimeCurrent(), dt);

    // 1. Verifica primeiro a restrição de dia (Segunda a Sexta)
    if (!IsTradingDay())
    {
        return false;
    }

    // Variáveis para armazenar o tempo de início e fim da sessão de negociação
    datetime trade_start = 0;
    datetime trade_end = 0;

    // 2. Busca o horário da primeira sessão de negociação do dia atual para o símbolo.
    // O índice 0 geralmente representa a principal sessão diária.
    bool success = SymbolInfoSessionTrade(
        CURRENT_SYMBOL,
        (ENUM_DAY_OF_WEEK)dt.day_of_week, // Dia da semana (convertido para o tipo correto)
        0,                                // Índice da sessão (primeira sessão)
        trade_start,                      // Tempo de início (formato datetime)
        trade_end                         // Tempo de fim (formato datetime)
    );

    // 3. Se não houver sessão de negociação definida para este dia, o mercado está fechado.
    if (!success || trade_start == 0 || trade_end == 0)
    {
        // Se a função falhar ou retornar zero, significa que não há negociação.
        return false;
    }

    // 4. Conversão e comparação

    // Converte o tempo de início e fim para MqlDateTime para extrair hora e minuto
    MqlDateTime dt_start, dt_end;
    TimeToStruct(trade_start, dt_start);
    TimeToStruct(trade_end, dt_end);

    // Converte todos os horários para minutos a partir da meia-noite (00:00)
    // para uma comparação precisa e simples.

    // Minutos atuais (Hora do Servidor)
    int current_minutes = dt.hour * 60 + dt.min;

    // Minutos de início da sessão (Ex: 01:00 = 60 minutos)
    int start_minutes = dt_start.hour * 60 + dt_start.min;

    // Minutos de fim da sessão (Ex: 21:40 = 1300 minutos)
    int end_minutes = dt_end.hour * 60 + dt_end.min;

    // 5. Verifica se o horário atual está dentro do intervalo da sessão.
    // A comparação usa >= start e < end (o ponto final não está incluso na negociação)
    if (end_minutes > start_minutes) // Sessão normal no mesmo dia
    {
        if (current_minutes >= start_minutes && current_minutes < end_minutes)
        {
            return true;
        }
    }
    else // Sessão que atravessa a meia-noite (ex: começa 23:00, termina 04:00)
    {
        if (current_minutes >= start_minutes || current_minutes < end_minutes)
        {
            return true;
        }
    }

    return false;
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

            return StructToTime(dt); // Retorna o datetime completo para hoje
        }
    }

    return 0; // Retorna 0 se não encontrar sessão
}
//+------------------------------------------------------------------+
// Exemplo de uso em uma função OnTick() de um EA:
/*
void OnTick()
{
    if (IsTradingHours())
    {
        // Coloque sua lógica de negociação aqui
        // Ex: Abrir ordem, gerenciar trailing stop, etc.
        // Print("Estamos operando dentro do horário e dia permitido.");
    }
    else
    {
        // O mercado está fora do seu horário ou dia de operação.
        // Ex: Print("Mercado fechado ou fora do horário M-F.");
    }
}
*/