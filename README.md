Me interessei pela forma de qualificar os canais candidatos utilizando o coeficiente de Correlação de Pearson (R). Talvez seja util tentar ir por este lado.

A identificaçao Algoritica da estrutura de mercado com pivôs e zigzap foi a alternativa escolhida para pegar as informacoes do mercado.

O objetivo é escolher o melhor canal do passado recente de uma data especifica do "Symbol do Forex" que é utilizada para a montagem de outro objeto no metatrader.

Mas nao há risco a repintagem do zigzag porque apenas utilizarei o ZigZag para pegar os dados do mercado do dia anterior ao que estou analisando.

Preciso que seja analizado o melhor canal em dois zigzap distintos e determinar o canal que esteja melhor para os os dois canais do zigzap ao mesmo tempo.

A pontuacao de um canal é dada pela soma de proximidade de pontos de pivôs e pelo coeficiente de correlação dePearson.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# Fimathe Daily Channels

**Fimathe Daily Channels** is a MetaTrader 5 indicator designed to analyze daily market ranges and trends using Fimathe logic. It automates the drawing of Fibonacci levels and Standard Deviation Channels, providing traders with key support and resistance levels.

## Features

### 1. Daily Fibonacci Levels

- Automatically calculates the daily range based on the first 4 candles of the trading session.
- Draws Fibonacci levels to identify potential reversal and continuation zones.
- **Smart Range Calculation**: If the daily range exceeds 1000 points, the indicator automatically splits it into smaller, tradable sub-ranges (between 500 and 900 points) to maintain relevance.

### 2. Standard Deviation Channel

- Identifies market trends using a Standard Deviation Channel.
- Uses ZigZag pivots to determine the start of the channel and projects it to the current session.
- Helps visualize the "fair price" area and potential overbought/oversold conditions.

### 3. Interactive Controls

The indicator is designed for interactive analysis:

- **Shift + Click**: Calculates and draws **both** the Standard Deviation Channel and Fibonacci levels for the clicked day.
- **Ctrl + Click**: Calculates and draws **only** the Fibonacci levels for the clicked day.

### 4. Customization

- Fully customizable colors and styles for lines and levels.
- Adjustable number of Fibonacci levels.

## Installation

1. Copy the `FimatheDailyChannels.ex5` (or `.mq5`) file to your MetaTrader 5 `MQL5/Indicators/` folder.
2. Restart MetaTrader 5 or refresh the indicators list.
3. Drag and drop the indicator onto your chart.

## Usage

1. **Load the Indicator**: Add it to your chart (e.g., M5 or M15 timeframe).
2. **Analyze a Day**:
   - Hold **Shift** and click on any candle of a specific day to see the full analysis (Channel + Fibo).
   - Hold **Ctrl** and click to see just the Fibo levels.
3. **Clean Chart**: The indicator automatically removes old objects when you click a new day, keeping your chart clean and focused.

## Requirements

- MetaTrader 5 Platform.
- Active internet connection for data.

---

_Copyright 2025, Fimathe_
