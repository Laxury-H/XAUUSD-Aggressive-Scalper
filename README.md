# XAUUSD Aggressive Scalper

MQL5 Expert Advisor for XAUUSD (Gold) on the M1 timeframe. The EA trades Stochastic (5,3,3) crossovers with a strict spread filter, one-trade-per-candle rule, fixed lot sizing, hard SL/TP, and an optional breakeven + trailing stop.

## Strategy
- Stochastic crossover: buy when %K crosses above %D from oversold (<20); sell when %K crosses below %D from overbought (>80).
- Executes on every tick but limits to one entry per bar via the last-candle timestamp.
- Filters: max allowed spread and max concurrent positions.
- Trade management: hard stop-loss/take-profit plus a breakeven trigger and trailing step once price advances.

## Files
- `AggressiveScalper.mq5` — Expert Advisor source.

## Inputs (defaults)
- `FixedLot` (0.5): Fixed position size.
- `StopLossPoints` (300): Stop loss distance in points.
- `TakeProfitPoints` (150): Take profit distance in points.
- `MaxPositions` (3): Maximum open positions (all symbols).
- `TrailingStart` (50): Profit in points to move stop to breakeven.
- `TrailingStep` (20): Minimum additional gain in points before advancing the trailing stop again.
- `MaxSpreadPoints` (40): Skip entries if current spread exceeds this.
- `MagicNumber` (123456): EA magic number for trade identification.

## How to use
1. Copy `AggressiveScalper.mq5` to `MQL5/Experts` and compile in MetaEditor.
2. Attach the EA to an XAUUSD M1 chart, enable Algo Trading, and allow live trading.
3. Adjust inputs to match your broker (contract size, min lot, spread) and risk tolerance.
4. Forward test or run the Strategy Tester before using on a live account.

## Notes and cautions
- Uses fixed lot sizing; adjust for account size and margin requirements.
- `MaxPositions` counts all open positions in the terminal, not just this symbol/magic.
- Trailing logic depends on broker fill policy; defaults to IOC and 10-point deviation.
- Always validate behavior on your broker’s tick data and with your risk controls.
