# Multi-Timeframe EMA Trend Expert Advisor

## Indicators

### EmaSlopeTrend

An advanced multi-timeframe indicator that calculates EMA slopes to determine trend direction. Features:

- Dual timeframe analysis with customizable periods
- Color-changing EMA lines based on slope direction:
  - Green: Uptrend
  - Red: Downtrend
  - Gray: Neutral/sideways
- Trend change dots appear exactly where the slope changes direction
- Uses ATR for dynamic threshold adjustment

#### Parameters

- **EmaPeriodHigher**: Higher timeframe EMA period
- **EmaPeriodLower**: Lower timeframe EMA period
- **HigherTimeframe**: Higher timeframe setting
- **LowerTimeframe**: Lower timeframe setting
- **SlopeWindow**: Window size for slope calculation
- **AtrPeriod**: ATR period for threshold calculation
- **AtrMultiplier**: Multiplier for ATR threshold

#### Usage

Add to chart and adjust parameters to match your trading style. Watch for alignment between higher and lower timeframe trends, and pay special attention to trend change dots which can signal potential entry or exit points.