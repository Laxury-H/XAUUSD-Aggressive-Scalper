# XAUUSD Aggressive Scalper (MT5)

MQL5 Expert Advisor for scalping XAUUSD on the M1 timeframe. It trades fast Stochastic (5,3,3) crossovers with on-tick execution, a strict spread filter, one-entry-per-candle control, fixed lot sizing, hard SL/TP, and an optional breakeven plus trailing stop.

## Strategy logic
- Buy when %K crosses above %D and %K is below 20 (oversold); sell when %K crosses below %D and %K is above 80 (overbought).
- Runs on every tick but limits entries to one per candle using the last candle time.
- Filters: skip trading if current spread exceeds `MaxSpreadPoints` or if open positions reach `MaxPositions` (counts all open positions in the terminal).
- Orders are sent with IOC filling and 10-point deviation.

## Inputs (defaults)
- `FixedLot` (0.5): Fixed position size.
- `StopLossPoints` (300): Stop loss distance in points.
- `TakeProfitPoints` (150): Take profit distance in points.
- `MaxPositions` (3): Maximum open positions (all symbols).
- `TrailingStart` (50): Profit in points to move stop to breakeven.
- `TrailingStep` (20): Additional gain in points required to advance the trailing stop again.
- `MaxSpreadPoints` (40): Maximum allowed spread to permit entries.
- `MagicNumber` (123456): EA magic number for identification.

## File
- `AggressiveScalper.mq5`

## Install and run
1. Copy `AggressiveScalper.mq5` to `MQL5/Experts`.
2. Compile it in MetaEditor.
3. Attach the EA to an XAUUSD M1 chart, enable Algo Trading, and allow live trading.
4. Adjust inputs for your broker (contract size, minimum volume, stops/freeze levels, spread) and risk settings.
5. Forward test in the Strategy Tester and on a demo account before going live.

## Notes and cautions
- Uses fixed lot sizing; size positions to your balance, margin, and risk tolerance.
- Verify broker constraints: volume min/step, stop distance, freeze levels, and typical spreads.
- Trailing logic: moves stop to breakeven once profit reaches `TrailingStart`, then trails only when price moves at least `TrailingStep` beyond the current stop.
- `MaxPositions` is terminal-wide; adjust code if you need a per-symbol or per-magic limit.
- Scalping results depend heavily on spread, execution speed, and slippage; monitor performance and risk controls closely.
