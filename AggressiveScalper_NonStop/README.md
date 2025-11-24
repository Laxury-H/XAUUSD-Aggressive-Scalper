# XAUUSD Aggressive Scalper – Non-Stop (MT5)

Hyper-aggressive variant that fires on every Stochastic (5,3,3) crossover on the **M1** timeframe. It keeps only a one-trade-per-candle limiter and a high position cap—no overbought/oversold filter and no spread guard are enforced in code.

## Strategy logic
- Buys when %K crosses above %D; sells when %K crosses below %D (no zone filter).
- Runs on every tick; limits to one entry per candle using the last candle time.
- Allows up to 10 concurrent positions; uses IOC filling and 20-point deviation.
- **No spread filter in code** (although an input exists); it will trade through wide spreads.
- Trailing inputs are declared but not implemented in this version.

## Inputs (defaults)
- `FixedLot` (0.5): Fixed position size; reduce if your balance is smaller.
- `StopLossPoints` (300): Stop loss distance in points.
- `TakeProfitPoints` (150): Take profit distance in points.
- `MaxPositions` (10): Maximum open positions (all symbols).
- `TrailingStart` (30): Declared but not used (trailing not implemented).
- `TrailingStep` (10): Declared but not used (trailing not implemented).
- `MaxSpreadPoints` (200): Declared but not used (no spread filter in code).
- `MagicNumber` (999999): EA magic number for identification.

## File
- `AggressiveScalper_NonStop/Aggressive_Scalper_NonStop.mq5`

## Install and run
1. Copy `Aggressive_Scalper_NonStop.mq5` to `MQL5/Experts`.
2. Compile it in MetaEditor.
3. Attach the EA to an XAUUSD/GOLD **M1** chart, enable Algo Trading, and allow live trading.
4. Adjust inputs for your broker (contract size, minimum volume, stops/freeze levels, spread) and risk.
5. Forward test in the Strategy Tester and on a demo account before going live.

## Notes and cautions
- Extremely frequent trading: no overbought/oversold or spread filters; expect activity in all conditions.
- Size conservatively: a common guideline is ≤0.01 lots per $1,000, then scale only after verified performance.
- If you need spread control or trailing stops, add code to enforce `MaxSpreadPoints` and the trailing inputs.
- The EA calls `PlaySound("ok.wav")`; ensure the sound file exists or remove the call if unwanted.
- Scalping outcomes depend heavily on spread, execution speed, and slippage; monitor risk closely on live accounts.
