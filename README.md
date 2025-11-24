# XAUUSD Aggressive Scalper Suite (MT5)

Two EA variants for scalping XAUUSD on the **M1** timeframe:
- **AggressiveScalper**: Baseline with spread filter and overbought/oversold logic (Stochastic 5,3,3).
- **AggressiveScalper_NonStop**: Hyper-aggressive “non-stop” mode that trades every crossover, with a high position cap and no spread filter enforced in code.

## Files and docs
- Baseline EA: `AggressiveScalper/AggressiveScalper.mq5`
  - Docs: `AggressiveScalper/UserGuide_EN.md`, `AggressiveScalper/UserGuide_VI.md`, `AggressiveScalper/README.md`
- Non-Stop EA: `AggressiveScalper_NonStop/Aggressive_Scalper_NonStop.mq5`
  - Docs: `AggressiveScalper_NonStop/README.md`

## Quick install (both variants)
1. Copy the desired `.mq5` into `MQL5/Experts`.
2. Compile in MetaEditor.
3. Attach to an XAUUSD/GOLD **M1** chart.
4. In the EA settings: allow Algo Trading, adjust inputs to your balance/broker.
5. Ensure the MT5 toolbar `Algo Trading` button is enabled (green).

## Pick your mode
- Use **AggressiveScalper** if you want spread control and only trade at Stochastic extremes.
- Use **AggressiveScalper_NonStop** if you want maximum frequency and accept trading through wide spreads; size down risk accordingly.

## Risk notes
- Forward-test on demo first; M1 scalping is sensitive to spread, execution, and slippage.
- Size conservatively (e.g., ≤0.01 lots per $1,000 balance) and respect your broker’s min/step and stop-distance rules.
