# Multi-Timeframe EMA Trend Expert Advisor

The MultiTF-EMATrend EA is a sophisticated trading system that identifies market trends using Exponential Moving Averages (EMAs) across multiple timeframes. By analyzing EMA slopes on both higher and lower timeframes, it generates high-probability trading signals when trend directions align.

## Trading Strategy

### Core Concept
The EA uses the slope (rate of change) of EMAs to determine trend direction on two different timeframes. When both timeframes show the same trend direction, a trading signal is generated.

### Signal Logic
- **Buy Signal**: Both higher and lower timeframe EMA slopes are positive (uptrend)
- **Sell Signal**: Both higher and lower timeframe EMA slopes are negative (downtrend)
- **No Signal**: EMA slopes on different timeframes disagree on trend direction

### Trading Modes
The EA supports two distinct trading modes:
- **Trend-Following**: Trade in the direction of the detected trend (default)
- **Counter-Trend**: Trade against the detected trend (reverses signals - buy becomes sell and vice versa)

### Entry & Exit Rules
- **Entry**: New position opened when trends align in the same direction
- **Exit**: Position closed when an opposite signal appears (trends align in opposite direction)
- **Stop Loss**: ATR-based stop loss applied to manage risk
- **Take Profit**: Set as multiple of stop loss distance (risk-reward ratio)
- **Trailing Stop**: Optional trailing stop that moves only in favorable direction

## Features

- **Multi-Timeframe Analysis**: Monitors two separate timeframes for stronger confirmation
- **Flexible Trading Modes**: Choose between trend-following or counter-trend trading approaches
- **Time-Based Trading Filter**: Restrict trading to specific hours of the day
- **Dynamic Volatility Adaptation**: ATR-based stop loss adjusts to current market conditions
- **Risk Management**: 
  - Position sizing based on account risk percentage
  - Configurable risk-reward ratio
  - ATR-based stop loss and trailing stop
- **Visual Indicators**:
  - Buy/sell arrows at signal points
  - Trading session time lines on chart
  - Trailing stop trendline visualization
  - Chart comments showing current trend status
- **Trade Management**: Fully automated entry, exit, and position management

## Parameters

### EMA Trend Settings
- **EmaPeriodHigher**: EMA period for the higher timeframe (default: 14)
- **EmaPeriodLower**: EMA period for the lower timeframe (default: 14)
- **HigherTimeframe**: The higher timeframe to analyze (default: H1)
- **LowerTimeframe**: The lower timeframe to analyze (default: M15)
- **SlopeWindow**: Number of bars to calculate slope (default: 5)
- **AtrPeriod**: Period for ATR calculation (default: 14)
- **AtrMultiplier**: Multiplier for trend detection threshold (default: 0.1)
- **EnableComments**: Display information on chart (default: true)

### Arrow Settings
- **DrawArrows**: Enable/disable signal arrows (default: true)
- **BuyArrowColor**: Color for buy signals (default: lime)
- **SellArrowColor**: Color for sell signals (default: red)
- **ArrowSize**: Size of signal arrows (default: 1)

### Trading Settings
- **EnableTrading**: Allow the EA to place trades (default: true)
- **RiskPercent**: Account balance percentage to risk per trade (default: 1.0%)
- **FixedLotSize**: Lot size when risk percentage is disabled (default: 0.01)
- **MagicNumber**: Unique identifier for EA's trades (default: 953164)
- **TradeOppositeSignal**: Trade in the opposite direction of detected signals (default: false)

### Trading Hours
- **EnableTimeFilter**: Restrict trading to specific hours (default: false)
- **TradingStartHour**: Hour to start trading (0-23) (default: 8)
- **TradingStartMinute**: Minute to start trading (0-59) (default: 30)
- **TradingEndHour**: Hour to stop trading (0-23) (default: 16)
- **TradingEndMinute**: Minute to stop trading (0-59) (default: 30)
- **UseServerTime**: Use server time instead of local time (default: true)
- **ShowTimeLines**: Show vertical time lines on chart (default: true)
- **TimeLinesColor**: Color for time lines (default: DarkGray)

### Risk Management
- **UseStopLoss**: Enable ATR-based stop loss (default: true)
- **SlAtrMultiplier**: ATR multiplier for stop loss distance (default: 2.0)
- **RiskRewardRatio**: Take profit as multiple of stop loss (default: 1.0)
- **RiskAtrPeriod**: ATR period for risk calculations (default: 14)
- **EnableTrailingStop**: Activate trailing stop functionality (default: true)
- **ShowTrailingStop**: Display trailing stop line on chart (default: true)

## Installation

1. Copy the entire `MultiTF-EMATrend` folder to your MetaTrader 5 `Experts/Jivita-Expert-Advisors` directory
2. Restart MetaTrader 5 or refresh the Navigator panel
3. Drag the EA onto your chart
4. Adjust parameters in the inputs tab
5. Ensure "Allow automated trading" is enabled in MT5

## Trading Strategies

### Trend Following
The default mode of operation uses aligned EMA slopes to enter in the direction of the trend:
- When both timeframe EMAs show rising slopes, buy
- When both timeframe EMAs show falling slopes, sell

### Counter-Trend Trading
By enabling `TradeOppositeSignal`, you can employ a counter-trend approach:
- Buy when the system detects a sell signal (both EMA slopes negative)
- Sell when the system detects a buy signal (both EMA slopes positive)
- This mode can be effective in ranging or overbought/oversold markets

## Performance Optimization

For best results:
- Test different EMA periods to match the instrument's volatility
- Adjust AtrMultiplier based on the instrument's price action
- Use higher timeframes for longer-term trends (H4/D1) and lower for shorter-term confirmation (H1/M30)
- The EA performs best on trending instruments and major pairs with decent volatility
- Consider increasing the SlAtrMultiplier in high volatility conditions
- Test both trend-following and counter-trend modes to see which works best for your specific market

## Implementation Details

The EA consists of several key components:
1. **EmaSlopeTrend**: Core indicator class that calculates EMA slopes and determines trend direction
2. **TradeManager**: Handles all trade entry, exit, and risk management functions
3. **TimeFilter**: Controls trading hours restrictions and visual time line representation
4. **NewBarDetector**: Ensures the EA only processes new bars to prevent redundant operations

All signals are analyzed at the completion of a bar, rather than during its formation, for more reliable signals.

## License

Copyright © 2025 Jivita Expert Advisors by Malinda Rasingolla
