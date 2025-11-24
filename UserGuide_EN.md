# User Guide: XAUUSD Aggressive Scalper (M1)

Welcome! This Expert Advisor (EA) is built for fast scalping on XAUUSD/GOLD in MetaTrader 5. It listens for fast Stochastic (5,3,3) crossovers and enforces strict spread and position controls.

## 1) System & account requirements
- Platform: MetaTrader 5 (desktop).
- Symbol: XAUUSD or GOLD.
- Timeframe: **M1 only**. Any other timeframe will make the logic behave incorrectly.
- Account type: Standard or Ultra Low recommended.
- Recommended balance: $10,000 for the default `FixedLot` of 0.5. If your balance is lower, reduce `FixedLot` (e.g., $1,000 → 0.05 lots).
- Spread guard: The EA will pause entries if `MaxSpreadPoints` is exceeded (default 100 points).

## 2) Install the EA
1. Download `AggressiveScalper.mq5` (or the compiled `.ex5`).
2. In MT5, open `File -> Open Data Folder`.
3. Navigate to `MQL5 -> Experts`.
4. Copy the EA file into this `Experts` folder.
5. Back in MT5, right-click `Navigator -> Experts` and choose `Refresh` (or compile in MetaEditor).

## 3) Launch and enable trading
1. Open an XAUUSD/GOLD chart.
2. Switch the chart timeframe to **M1**.
3. Drag the EA from `Navigator -> Experts` onto the chart.
4. In the settings window:
   - **Common** tab: check `Allow Algo Trading`.
   - **Inputs** tab: adjust parameters as needed (see section 4).
5. Ensure the toolbar `Algo Trading` button is green (enabled).
6. Confirm the chart shows the small mortarboard icon in the top-right and the dashboard text in the top-left.

## 4) Input parameters (defaults)
| Input             | Default | Purpose |
|-------------------|---------|---------|
| `FixedLot`        | 0.5     | Fixed lot size per trade. Lower this if your balance is smaller. |
| `StopLossPoints`  | 300     | Stop loss distance in points (300 pts = 30 pips = ~$3 in gold price). |
| `TakeProfitPoints`| 150     | Take profit distance in points (150 pts = 15 pips = ~$1.5 in gold price). |
| `MaxPositions`    | 3       | Maximum open positions across the terminal. |
| `TrailingStart`   | 50      | Profit (points) before moving stop to breakeven. |
| `TrailingStep`    | 20      | Extra profit (points) needed to trail again after breakeven. |
| `MaxSpreadPoints` | 100     | Max allowed spread (points). If current spread is higher, the EA pauses entries. |
| `MagicNumber`     | 123456  | Magic number to tag this EA’s trades. |

Tip: Press `F7` on the chart to reopen and edit these inputs at any time.

## 5) Reading the on-chart dashboard
- `Current Spread`: updates tick-by-tick. If it is below `MaxSpreadPoints`, trading is allowed.
- `STATUS: [READY TO TRADE]`: all conditions met. `STATUS: [PAUSED]`: spread too high.
- `Stoch Main / Stoch Signal`: current Stochastic values.
- `ZONE`: `OVERSOLD (Waiting for BUY)`, `OVERBOUGHT (Waiting for SELL)`, or `Neutral`.

## 6) Troubleshooting
- EA is not taking trades:
  - Spread too high: compare dashboard spread to `MaxSpreadPoints`. Raise the limit cautiously if your broker’s spread is wider (e.g., 120).
  - Wrong timeframe: ensure the chart is on **M1**.
  - Algo disabled: toolbar `Algo Trading` must be green; EA settings must allow algo trading.
  - Position cap hit: `MaxPositions` stops new orders when the cap is reached.
  - No signal yet: the strategy waits for Stochastic crossovers in extreme zones.
- “Invalid Volume” error:
  - Adjust `FixedLot` to meet your broker’s min/step. Standard accounts often allow 0.01 lots; Micro/cent accounts may differ.

## 7) Risk notes
- Forward-test on a demo for at least two weeks before going live; M1 scalping is sensitive to spread and execution.
- Size conservatively: a common guideline is ≤0.01 lots per $1,000, then scale only after verified performance.
- Monitor broker constraints (min volume, step size, stop/freeze levels, typical spread) and adjust inputs accordingly.
