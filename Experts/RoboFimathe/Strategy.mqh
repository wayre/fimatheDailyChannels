//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                             Copyright 2025, Your Name |
//|                                             https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link "https://www.your-website.com"
#property version "1.00"

#include "Time.mqh"

//--- Classe para a lógica da estratégia
class FimatheStrategy
{
private:
   string m_symbol;
   int m_channel_multiplier;
   double m_tp_multiplier;
   double m_sl_multiplier;
   double m_reversal_tp_multiplier;
   double m_range_canal;
   double m_canal_superior;
   double m_canal_inferior;
   bool m_levels_calculated_today;
   double maximumBullPriceValue;
   double maximumBearPriceValue;

public:
   /**
    * Inicializa a classe com os parâmetros da estratégia, como o símbolo a ser negociado e o multiplicador do canal.*/
   void Init(string symbol, int channel_multiplier, double tp_multiplier, double sl_multiplier, double reversal_tp_multiplier)
   {
      m_symbol = symbol;
      m_channel_multiplier = channel_multiplier;
      m_tp_multiplier = tp_multiplier;
      m_sl_multiplier = sl_multiplier;
      m_reversal_tp_multiplier = reversal_tp_multiplier;
      Reset();
   }

   /**
    * Inicializa a classe com os parâmetros da estratégia, como o símbolo a ser negociado e o multiplicador do canal. │ Nada (void).*/
   void Reset()
   {
      m_range_canal = 0.0;
      m_canal_superior = 0.0;
      m_canal_inferior = 0.0;
      m_levels_calculated_today = false;
   }

   /**
    * Inicializa a classe com os parâmetros da estratégia, como o símbolo a ser negociado e o multiplicador do canal. │ true se os níveis já foram calculados; `fal...*/
   bool LevelsAreCalculated() const
   {
      return m_levels_calculated_today;
   }

   /**
    * Esta é a função mais importante. Ela executa a lógica principal para definir o canal do dia:<br>1. Espera o pregão iniciar (após a 01:00 do servidor).<br>2. Pega as 4 primeiras velas que se formam a partir desse horário.<br>3. Encontra a máxima mais alta e a mínima mais baixa entre essas 4 velas.<br>4. Define m_canal_superior (topo do canal) como a máxima e m_canal_inferior (fundo do canal) como a mínima.<br>5. C... │ Nada (void). */
   void CalculateLevels(ENUM_TIMEFRAMES timeframe)
   {
      // Se os níveis já foram calculados hoje, não faz nada.
      if (m_levels_calculated_today)
      {
         return;
      }

      // --- Obtém dinamicamente o horário de início da sessão para saber quando o mercado abre ---
      datetime session_open_time = GetSessionStartTime(m_symbol);
      if (session_open_time == 0 || TimeCurrent() < session_open_time)
      {
         return; // Retorna se não houver sessão hoje ou se o mercado ainda não abriu
      }

      // --- Define o horário base da estratégia (01:00) conforme a regra documentada ---
      MqlDateTime dt_base;
      TimeToStruct(TimeCurrent(), dt_base);
      dt_base.hour = 1;
      dt_base.min = 0;
      dt_base.sec = 0;
      datetime strategy_base_time = StructToTime(dt_base);

      // --- Verifica se as 4 velas a partir da base (01:00) já se formaram ---
      // A 4ª vela (iniciada às 01:15 em M5) fecha às 01:20.
      long period_seconds = PeriodSeconds(timeframe);
      datetime fourth_bar_close_time = strategy_base_time + (datetime)(4 * period_seconds);

      // Se o tempo atual for menor que o tempo de fechamento da quarta barra, ela ainda não se formou.
      if (TimeCurrent() < fourth_bar_close_time)
      {
         return; // Aguardando as 4 barras fecharem.
      }
      Print("As 4 barras (base 01:00) devem existir. Calculando níveis...");

      // --- Agora que as 4 barras devem existir, copiamos os dados desse intervalo ---
      MqlRates rates[];
      // Usamos a base da estratégia (01:00) como início para garantir a captura das velas corretas
      int copied = CopyRates(m_symbol, timeframe, strategy_base_time, fourth_bar_close_time, rates);

      // Esta verificação agora é uma segurança extra.
      if (copied < 4)
      {
         Print("Erro: Não foi possível copiar as 4 velas da sessão mesmo após o tempo esperado. Velas copiadas: ", copied);
         return;
      }
      Print("Copiadas: ", copied);

      // --- Calcula o canal com base nessas 4 velas ---
      double max_high = 0;
      double min_low = 999999999; // Usando valor alto para garantir a primeira atribuição

      // O array 'rates' contém as 4 primeiras velas da sessão
      // rates[0] é a vela mais antiga
      for (int i = 0; i < 4; i++)
      {
         Print("Vela ", i, ": High=", rates[i].high, ", Low=", rates[i].low);
         if (rates[i].high > max_high)
            max_high = rates[i].high;
         if (rates[i].low < min_low)
            min_low = rates[i].low;
      }

      // Calcula o range inicial do canal
      double range_canal = max_high - min_low;
      Print("Range inicial do canal: ", range_canal);

      // Verifica a regra do "Canal Grande" (> 1000 pontos) usando o método robusto do Indicador
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      bool isBigChannel = (point > 0 && (range_canal / point) >= 1000);

      if (isBigChannel)
      {
         range_canal /= 2;
         max_high = min_low + range_canal; // Ajusta o topo do canal
         // Print("Canal grande (>1000pts), range ajustado para a metade: ", NormalizeDouble(range_canal, _Digits));
      }

      // Define as propriedades da classe com os valores calculados
      m_range_canal = NormalizeDouble(range_canal, _Digits);
      m_canal_inferior = min_low;
      m_canal_superior = max_high; // max_high já foi ajustado se o canal era grande
      m_levels_calculated_today = true; // Marca como calculado para o dia de hoje.

      // --- Calcula os limites de entrada junto com os níveis do canal ---
      maximumBullPriceValue = m_canal_superior + m_range_canal + (m_range_canal * 0.2);
      maximumBearPriceValue = m_canal_inferior - m_range_canal - (m_range_canal * 0.2);

      Print("Níveis do Canal Calculados (4 primeiras velas):");
      Print("Superior=", m_canal_superior, ", Inferior=", m_canal_inferior, ", Range=", m_range_canal);
      Print("MaximumBullValue:", maximumBullPriceValue);
      Print("MaximumBearValue:", maximumBearPriceValue);
   }

   // retorna o valor limite permitido para a operacao de venda
   double getMaximumValueEntrytoSell() 
   {
      return maximumBearPriceValue;
   }
   
   // retorna o valor limite permitido para a operacao de compra
   double getMaximumValueEntrytoBuy() 
   {
      return maximumBullPriceValue;
   }
   
   /**
    * Verifica se existe um sinal de compra. A regra é: o preço de fechamento do candle anterior
    * é maior que o topo do canal (m_canal_superior) somado a uma vez a altura do canal (m_range_canal).
    */
   bool CheckBuySignal(double last_close_price) const
   {
      if (!m_levels_calculated_today)
         return false;
      Print("Identificado um sinal de compra.");
      return last_close_price > m_canal_superior + m_range_canal;
   }

   /**
    * Verifica se existe um sinal de venda. A regra é: o preço de fechamento do candle anterior
    * é menor que o fundo do canal (m_canal_inferior) subtraindo uma vez a altura do canal (m_range_canal).
    */
   bool CheckSellSignal(double last_close_price) const
   {
      if (!m_levels_calculated_today)
         return false;

      return last_close_price < m_canal_inferior - m_range_canal;
   }

   /**
    * Verifica se ainda é possível operar hoje, ou se um sinal de entrada/saída já ocorreu.
    * Varre os candles do dia desde o início da sessão para identificar se um sinal já foi gerado.
    * @param timeframe O timeframe a ser verificado.
    * @return true se ainda não houve sinal, false se um sinal já ocorreu hoje.
    */
   bool CheckIsPossibleTradeToday(ENUM_TIMEFRAMES timeframe) const
   {
      // 1. Obter o horário de início da sessão para o símbolo atual
      datetime session_start_time = GetSessionStartTime(m_symbol);

      // Se não houver horário de sessão definido ou se os níveis não foram calculados,
      // presume-se que não é possível operar ou que o setup não está pronto.
      if (session_start_time == 0 || !m_levels_calculated_today)
      {
         return false;
      }

      // 2. Copiar os candles desde o início da sessão até o momento atual
      MqlRates rates[];
      int copied_count = CopyRates(m_symbol, timeframe, session_start_time, TimeCurrent(), rates);

      // Se não conseguiu copiar nenhum candle (ex: market closed / no data), presume-se que não é possível operar.
      if (copied_count <= 0)
      {
         return false;
      }

      // 3. Percorrer os candles copiados (do mais antigo para o mais novo)
      //    O CopyRates com start_time preenche o array do mais antigo (índice 0) para o mais novo.
      //    Queremos verificar sinais em candles *fechados* do histórico.
      //    O último candle copiado (rates[copied_count - 1]) pode estar em formação.
      //    Ajustamos o limite para excluir o candle em formação, se houver.
      int limit_idx = copied_count;
      if (limit_idx > 0 && rates[limit_idx - 1].time >= TimeCurrent() - PeriodSeconds(timeframe))
      {
         // Se o tempo do último candle copiado é igual ou maior ao tempo de início da barra atual,
         // significa que esse último candle está em formação, então o excluímos da checagem.
         limit_idx--;
      }

      // 4. Verificar sinais em todos os candles fechados do dia
      for (int i = 0; i < limit_idx; i++)
      {
         // Usamos o close price de cada candle histórico como se fosse o 'current_close_price' no OnTick
         double history_close_price = rates[i].close;

         if (CheckBuySignal(history_close_price) || CheckSellSignal(history_close_price))
         {
            // Um sinal já ocorreu em algum momento do dia nos candles históricos fechados.
            return false;
         }
      }

      // Se chegou até aqui, significa que nenhum sinal ocorreu nos candles históricos fechados do dia.
      // Logo, ainda é possível que um sinal ocorra no futuro.
      return true;
   }

   /**
    * Calcula e retorna o preço do Take Profit para uma operação de compra.
    * O TP é definido como o topo do canal mais 2.75 vezes o range do canal.
    * @return double O preço do Take Profit para compra.
    */
   double GetBuyTakeProfit() const
   {
      return m_canal_superior + (m_tp_multiplier * m_range_canal);
   }

   /**
    * Calcula e retorna o preço do Stop Loss para uma operação de compra.
    * O SL é definido como o fundo do canal menos 0.25 vezes o range do canal.
    * @return double O preço do Stop Loss para compra.
    */
   double GetBuyStopLoss() const
   {
      return m_canal_inferior - (m_sl_multiplier * m_range_canal);
   }

   /**
    * Calcula e retorna o preço do Take Profit para uma operação de venda.
    * O TP é definido como o fundo do canal menos 2.75 vezes o range do canal.
    * @return double O preço do Take Profit para venda.
    */
   double GetSellTakeProfit() const
   {
      return m_canal_inferior - (m_tp_multiplier * m_range_canal);
   }

   /**
    * Calcula e retorna o preço do Stop Loss para uma operação de venda.
    * O SL é definido como o topo do canal mais 0.25 vezes o range do canal.
    * @return double O preço do Stop Loss para venda.
    */
   double GetSellStopLoss() const
   {
      return m_canal_superior + (m_sl_multiplier * m_range_canal);
   }

   /**
    * Calcula e retorna o preço do Stop Loss para uma operação de REVERSÃO DE COMPRA (que é uma VENDA).
    * O SL da reversão é posicionado no preço de entrada da operação de compra original.
    * @param initial_buy_entry_price O preço de entrada da operação de compra original.
    * @return double O preço do Stop Loss para a venda de reversão.
    */
   double GetBuyReversalStopLoss(double initial_buy_entry_price) const
   {
      return initial_buy_entry_price;
   }

   /**
    * Calcula e retorna o preço do Take Profit para uma operação de REVERSÃO DE COMPRA (que é uma VENDA).
    * O TP é calculado a partir do preço de entrada da reversão (que é o SL da compra original).
    * @param reversal_entry_price O preço de entrada da operação de reversão (SL da compra original).
    * @return double O preço do Take Profit para a venda de reversão.
    */
   double GetBuyReversalTakeProfit(double reversal_entry_price) const
   {
      return reversal_entry_price - (m_range_canal * m_reversal_tp_multiplier);
   }

   /**
    * Calcula e retorna o preço do Stop Loss para uma operação de REVERSÃO DE VENDA (que é uma COMPRA).
    * O SL da reversão é posicionado no preço de entrada da operação de venda original.
    * @param initial_sell_entry_price O preço de entrada da operação de venda original.
    * @return double O preço do Stop Loss para a compra de reversão.
    */
   double GetSellReversalStopLoss(double initial_sell_entry_price) const
   {
      return initial_sell_entry_price;
   }

   /**
    * Calcula e retorna o preço do Take Profit para uma operação de REVERSÃO DE VENDA (que é uma COMPRA).
    * O TP é calculado a partir do preço de entrada da reversão (que é o SL da venda original).
    * @param reversal_entry_price O preço de entrada da operação de reversão (SL da venda original).
    * @return double O preço do Take Profit para a compra de reversão.
    */
   double GetSellReversalTakeProfit(double reversal_entry_price) const
   {
      return reversal_entry_price + (m_range_canal * m_reversal_tp_multiplier);
   }
};
