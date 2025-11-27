Este é um novo projeto de robô para MetaTrader 5.  
Quero apenas que planeje a melhor forma de desenvolvermos esse robô no conceito de clean code.  
Use context7.

## Estratégia

Tenho uma estratégia chamada Robo Fimathe.

## Preparação

### Pegando valores para montagem da estratégia

Precisamos de 3 variáveis: `range_canal`, `canal_superior` e `canal_inferior`.

- `range_canal`: É a distância, em ticks, entre a máxima e a mínima das 4 primeiras barras da sessão diária no gráfico de 5 minutos.
- `canal_superior`: É a máxima desse range (dos 4 candles iniciais da sessão diária no gráfico de 5 minutos).
- `canal_inferior`: É a mínima desse range (dos 4 candles iniciais da sessão diária no gráfico de 5 minutos).
- `tempo_grafico`: Salva o tempo gráfico com 5 minutos.
- `magic_number`: Utilizado para não misturar com outros robôs.

### Processo de análise de entrada

Iniciar uma verificação de que dia da semana é hoje.  
O robô deve funcionar apenas de domingo a quinta-feira.  
O symbol operado é o XAUUSD.

- Volume mínimo: 0.01
- Volume máximo: 20
- Passo de volume: 0.01

## Horários da sessão (Trade)

| Dia       | Início | Fim   |
| --------- | ------ | ----- |
| Monday    | 01:05  | 24:00 |
| Tuesday   | 01:00  | 24:00 |
| Wednesday | 01:00  | 24:00 |
| Thursday  | 01:00  | 21:25 |
| Friday    | 01:00  | 21:40 |

A sessão abre às 20h, horário de Brasília (UTC-3) e no servidor da corretora é (informar horário do servidor).

O robô configura a variável `tempo_grafico` para 15 minutos apenas se o dia atual é domingo e, nos outros dias, configura para tempo gráfico de 5 minutos.

O sistema deve ter uma função booleana de verificação de quando o candle fechou.  
Ela será usada para executar a função de acionamento de ordens.

## Acionamento de ordens

Antes de poder abrir ordens, o robô deve aguardar o fechamento da 4ª barra para poder calcular os valores das variáveis `range_canal`, `canal_superior` e `canal_inferior`.

Só operar quando:

- Ainda não tiver feito entrada nenhuma (apenas uma única operação ao dia).
- Já tiver os valores `range_canal`, `canal_superior` e `canal_inferior` da sessão diária atual calculados, apenas após o fechamento do 4º candle do dia.

### Entrada de Compra

A entrada de compra é feita após o fechamento da primeira barra que fechar acima do preço de  
`canal_superior + (2 * range_canal)`.

### Entrada de Venda

A entrada de venda é feita após o fechamento da primeira barra que fechar abaixo do preço de  
`canal_inferior - (1 * range_canal)`.
