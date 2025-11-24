# Quantum Math AI V5.0

Quantum Math AI V5.0 is a sophisticated Expert Advisor (EA) for MetaTrader 5 that utilizes advanced statistical analysis and linear regression models to identify high-probability mean reversion and trend-following setups.

## Core Strategy

The EA calculates a Linear Regression Channel in real-time to determine the market's direction and volatility.

-   **Trend Identification:** Uses the slope of the Linear Regression line to identify the dominant trend direction.
-   **Quality Filter:** Utilizes the R-Squared ($R^2$) coefficient to measure the reliability of the trend. Trades are only taken when the market structure is statistically significant.
-   **Entry Logic:**
    -   **Buy:** When the trend is up (Positive Slope) and price dips below the Lower Deviation Channel (Oversold) but closes back inside (Rejection).
    -   **Sell:** When the trend is down (Negative Slope) and price spikes above the Upper Deviation Channel (Overbought) but closes back inside (Rejection).

## Key Features

### 1. Quantum Math Core
-   **Linear Regression:** Dynamic calculation of slope and intercept.
-   **Standard Deviation Channels:** Adaptive bands based on market volatility.
-   **R-Squared Filter:** Filters out noise and low-quality market conditions.

### 2. Advanced Risk Management
-   **Dynamic Lot Sizing:** Calculates lot size based on a percentage of account equity and the distance to the Stop Loss.
-   **ATR Stop Loss:** Stop Loss is placed dynamically based on the Average True Range (ATR) to adapt to current volatility.

### 3. Trade Management
-   **Mean Reversion Targets:** Primary target is the Mean (Regression Line).
-   **Partial Close:** Automatically closes a percentage of the position (default 50%) when price reaches the Mean Reversion line.
-   **Breakeven:** Moves Stop Loss to Breakeven after the partial close.
-   **Trailing Stop:** Trails the remaining position using an ATR-based mechanism to maximize profits on runners.

### 4. Filters
-   **Time Window:** Configurable Start and End hours to trade only during specific sessions.
-   **Spread Filter:** Prevents trading during high spread events.

## Input Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| **--- Quantum Math Core ---** | | |
| `InpLRPeriod` | 50 | Period for Linear Regression calculation |
| `InpSlopeThreshold` | 0.2 | Minimum slope required to define a trend |
| `InpRSquaredMin` | 0.7 | Minimum R-Squared value (0.0 - 1.0) for trade validity |
| `InpChannelDev` | 2.0 | Standard Deviation multiplier for channel bands |
| **--- Risk Management ---** | | |
| `InpRiskPercent` | 1.0 | Risk percentage of equity per trade |
| `InpATRPeriod` | 14 | Period for ATR calculation |
| `InpATRMulti` | 2.0 | Multiplier for ATR-based Stop Loss |
| **--- Trade Management ---** | | |
| `InpUsePartial` | true | Enable partial closing at TP1 |
| `InpPartialPct` | 50.0 | Percentage of volume to close at TP1 |
| `InpUseTrailing` | true | Enable trailing stop for the remaining position |
| **--- Time & Filters ---** | | |
| `InpStartHour` | 8 | Trading start hour (Server Time) |
| `InpEndHour` | 20 | Trading end hour (Server Time) |
| `InpMaxSpread` | 100 | Maximum allowed spread in points |

## Installation

1.  Copy the `QuantumMathAI_V5.mq5` file to your MQL5 Experts folder (usually `MQL5\Experts`).
2.  Compile the file in MetaEditor.
3.  Attach the EA to a chart (Recommended: XAUUSD, M15 or H1).
4.  Ensure "Algo Trading" is enabled in MT5.

## Disclaimer

Trading Forex and CFDs carries a high level of risk and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to trade, you should carefully consider your investment objectives, level of experience, and risk appetite.
