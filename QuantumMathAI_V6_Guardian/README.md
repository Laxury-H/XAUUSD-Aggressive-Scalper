# Quantum Math AI V6.0 (The Guardian)

**Institutional Grade Linear Regression System - Updated for Gold $4000+**

Quantum Math AI V6.0 "The Guardian" is a major evolution of the Quantum Math strategy, specifically adapted for the high volatility and price levels of Gold (XAUUSD) in the $4000+ era. It integrates institutional-grade math with a real-time News Filter to protect capital during high-impact events.

## New in Version 6.01
-   **Auto-News Filter:** Integrated ForexFactory Calendar reader to automatically pause trading before and after High-Impact USD news.
-   **Guardian Mode:** Enhanced risk management adapted for higher Gold prices (wider stops, dynamic ATR multipliers).
-   **R-Squared Quality Filter:** Only trades when the trend structure is statistically significant ($R^2 \ge 0.7$).

## Core Strategy

The EA uses a dynamic Linear Regression Channel to identify mean reversion and trend-following setups.

1.  **Trend Identification:** Calculates the slope of the Linear Regression line over 50 periods.
2.  **Entry Logic:**
    -   **Buy:** Trend is UP (Slope > 0.2) + Price dips to Lower Channel + Rejection.
    -   **Sell:** Trend is DOWN (Slope < -0.2) + Price spikes to Upper Channel + Rejection.
3.  **Validation:** The R-Squared ($R^2$) value must be $\ge 0.7$ to confirm a high-quality trend.

## Key Features

### 1. Auto-News Filter (ForexFactory)
-   Automatically fetches the weekly calendar from ForexFactory.
-   **Pauses trading** 30 minutes before and 30 minutes after High-Impact USD news.
-   **Visual Dashboard:** Shows "PAUSED (NEWS DETECTED)" status on the chart.
-   *Note: Requires "Allow WebRequest" in MT5 Options.*

### 2. Risk Management ($4k Gold Adapted)
-   **Dynamic ATR Stop Loss:** SL is placed at `3.0 x ATR` to withstand higher volatility.
-   **Target Profit:** Primary target at `4.0 x ATR` or the opposite channel band.
-   **Partial Close:** Automatically closes 50% of the position when price reverts to the Mean (Center Line).
-   **Breakeven:** Moves SL to Breakeven after the partial close.

### 3. Trade Management
-   **Trailing Stop:** Locks in profits as price moves in your favor (starts trailing after 20 pips).
-   **Spread Filter:** Prevents trading when spread exceeds 150 points ($1.50).

## Input Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| **--- Quantum Math Settings ---** | | |
| `LRC_Period` | 50 | Linear Regression Lookback Period |
| `Slope_Threshold` | 0.2 | Min Slope to confirm Trend |
| `R_Squared_Min` | 0.7 | Min R-Squared Quality [0.0-1.0] |
| **--- Risk Management ---** | | |
| `RiskPercent` | 1.0 | Risk % per Trade (0 = Use Fixed Lot) |
| `ATR_Multiplier_SL` | 3.0 | Stop Loss Distance (Multiplier of ATR) |
| `ATR_Multiplier_TP` | 4.0 | Take Profit Distance (Multiplier of ATR) |
| **--- Auto News Filter ---** | | |
| `UseAutoNews` | true | Enable Auto-Calendar Fetching |
| `PauseMinsBefore` | 30 | Minutes to pause BEFORE news |
| `PauseMinsAfter` | 30 | Minutes to pause AFTER news |
| **--- Filters & Time ---** | | |
| `StartHour` | 8 | Trading Start Hour (Server Time) |
| `EndHour` | 22 | Trading End Hour (Server Time) |

## Installation & Setup

1.  **File:** Copy `QuantumMathAI_V6_Guardian.mq5` to `MQL5\Experts`.
2.  **WebRequest:** Go to **Tools -> Options -> Expert Advisors**.
    -   Check **"Allow WebRequest for listed URL"**.
    -   Add URL: `https://nfs.faireconomy.media/ff_calendar_thisweek.json`
3.  **Chart:** Attach to **XAUUSD** (Gold) on **M15** or **H1** timeframe.

## Disclaimer

Trading leveraged products like Forex and CFDs carries a high level of risk. The "Guardian" features are designed to mitigate risk but cannot eliminate it entirely. Past performance is not indicative of future results.
