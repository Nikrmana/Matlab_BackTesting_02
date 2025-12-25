\# BackTesting\_02 - Cryptocurrency Trading Backtesting System



A MATLAB-based backtesting system for crypt# BackTesting\_02 - Cryptocurrency Trading Backtesting System



A MATLAB-based backtesting system for cryptocurrency trading that uses volume-based asymmetric smoothing and peak/trough detection to optimize trading strategies on historical Binance data.



\## Overview



This system implements a two-phase approach:

1\. \*\*Historical Optimization\*\*: Fetches historical data from Binance, optimizes trading parameters using surrogate optimization, and runs simulations

2\. \*\*Historical Playback\*\*: Simulates trading on historical data using optimized parameters with real-time visualization



\## Requirements



\### MATLAB Toolboxes

\- \*\*Global Optimization Toolbox\*\* (required for `surrogateopt`)

\- \*\*Optimization Toolbox\*\* (required for `optimoptions`)

\- \*\*Signal Processing Toolbox\*\* (optional, only needed if using `'Findpeaks'` detection method)



\### MATLAB Base

\- MATLAB R2017a or later (for `smoothdata` function)

\- Internet connection (for Binance API access)



\## Quick Start



1\. Ensure all `.m` files are in your MATLAB path

2\. Run the main function:

   BackTesting\_02()

   The system will automatically:

\- Fetch historical data from Binance

\- Optimize trading parameters

\- Run a simulation with visualization



\## Main Function: `BackTesting\\\_02()`



This is the entry point for the backtesting system. It coordinates both optimization and simulation phases.



\### User Parameters



Modify these parameters at the beginning of `BackTesting\\\_02.m`:



| Parameter | Description | Example Value |

|-----------|-------------|---------------|

| `symbol` | Trading pair symbol | `'BTCUSDT'` |

| `interval` | Kline interval | `'5m'` (5 minutes) |

| `OptimiserIterations` | Number of optimization iterations | `10` |

| `TransactionPercent` | Transaction fee percentage | `0.115` (0.115%) |

| `StopLoss` | Stop-loss percentage (0-1) | `0.1` (10%) |

| `OptimisationDays` | Number of days of historical data | `10` |

| `lb` | Lower bounds `\\\[leftScope, rightScope, detectSpeed]` | `\\\[10000, 20000, 1]` |

| `ub` | Upper bounds `\\\[leftScope, rightScope, detectSpeed]` | `\\\[20000, 40000, 1]` |

| `SmoothPar` | Additional smoothing parameter (0.1-1) | `0.5` |

| `optimMethod` | Extreme detection method | `'CustomAsymetric'` |

| `simulationMethod` | Simulation detection method | `'CustomAsymetric'` |

| `pauseTime` | Pause between iterations (seconds) | `0` |

| `FinalOptimisationDate` | End date for optimization | `'30.7.2024'` |



\### Supported Intervals

\- `'1m'`, `'3m'`, `'5m'`, `'15m'`, `'30m'`, `'1h'`



\### Detection Methods

\- `'CustomAsymetric'`: Custom volume-based asymmetric peak/trough detection (recommended)

\- `'Findpeaks'`: MATLAB's built-in `findpeaks` function (requires Signal Processing Toolbox)

\- `'Derivative'`: Zero-crossing derivative method



\## Core Functions



\### `runHistoricalOptimization(userParams)`

Fetches historical data from Binance, optimizes trading parameters, and runs initial simulation.



\*\*Input:\*\*

\- `userParams`: Structure containing all user-defined parameters



\*\*Outputs:\*\*

\- `optimizedParams`: Optimized parameter vector `\\\[leftScope, rightScope, detectSpeed]`

\- `lastState`: Final simulation state (holding, position, entryPrice, tradeLog)

\- `historicalBuffer`: Historical data (prices, volumes, times, cumVol)



\*\*Process:\*\*

1\. Calculates data range based on `FinalOptimisationDate` and `OptimisationDays`

2\. Fetches kline data from Binance API in batches (960 points per fetch)

3\. Parses data (uses high-low average as price)

4\. Runs `surrogateopt` optimization to find best parameters

5\. Runs simulation with optimized parameters

6\. Displays results table and generates plot



\### `simulateTrading(prices, volumes, times, leftScope, rightScope, detect\\\_speed, Fee, StopLoss, ExtrDetType, SmoothPar)`

Simulates trading on provided data using specified parameters.



\*\*Inputs:\*\*

\- `prices`: Price vector (column vector)

\- `volumes`: Volume vector (column vector)

\- `times`: Time vector (column vector)

\- `leftScope`: Left-side volume scope for smoothing

\- `rightScope`: Right-side volume scope for smoothing

\- `detect\\\_speed`: Detection speed multiplier for left scope

\- `Fee`: Transaction fee as fraction (e.g., 0.00115 for 0.115%)

\- `StopLoss`: Stop-loss percentage (e.g., 0.1 for 10%)

\- `ExtrDetType`: Extreme detection type (`'CustomAsymetric'`, `'Findpeaks'`, `'Derivative'`)

\- `SmoothPar`: Additional smoothing parameter (0.1-1)



\*\*Outputs:\*\*

\- `finalHolding`: Final USDT holding after all trades

\- `TradeList`: 3×N matrix where:

  - Row 1: Cumulative volume at trade

  - Row 2: Buy price (0 if sell)

  - Row 3: Sell price (0 if buy)



\*\*Process:\*\*

1\. Computes cumulative volume

2\. Applies asymmetric volume-based smoothing

3\. Applies additional moving average smoothing

4\. Detects peaks and troughs using selected method

5\. Simulates trading: buys at troughs, sells at peaks

6\. Applies stop-loss logic at every data point

7\. Closes all positions at final price



\### `objectiveFunction(params, prices, volumes, times, Fee, StopLoss, ExtrDetType, SmoothPar)`

Objective function for optimization. Returns negative final holding (to maximize via minimization).



\*\*Inputs:\*\*

\- `params`: Parameter vector `\\\[leftScope, rightScope, detectSpeed]`

\- Other inputs: Same as `simulateTrading`



\*\*Output:\*\*

\- `negHolding`: Negative of final holding value



\## Supporting Functions



\### `asymmetricSmoothVol(prices, cumVol, leftScope, rightScope)`

Performs volume-based asymmetric smoothing on price data.



\*\*Algorithm:\*\*

\- For each point, collects all data points within `leftScope` volume to the left and `rightScope` volume to the right

\- Computes mean price of collected points

\- Returns smoothed signal and point counts



\### `findAsymmetricPeaksVol(data, cumVol, leftBTC, rightBTC)`

Detects peaks using volume-based asymmetric criteria.



\*\*Algorithm:\*\*

\- A point is a peak if it's higher than all points within `leftBTC` volume to the left AND `rightBTC` volume to the right



\### `findAsymmetricTroughsVol(data, cumVol, leftBTC, rightBTC)`

Detects troughs using volume-based asymmetric criteria.



\*\*Algorithm:\*\*

\- A point is a trough if it's lower than all points within `leftBTC` volume to the left AND `rightBTC` volume to the right



\### `myOutputFcn(x, optimValues, state, varargin)`

Output function for `surrogateopt` optimization (currently minimal, can be extended for progress tracking)



\## Trading Strategy



\### Signal Generation

1\. \*\*Smoothing\*\*: Two-stage smoothing process

   - Primary: Volume-based asymmetric smoothing (adapts to volume patterns)

   - Secondary: Moving average smoothing (window size = `SmoothPar × avgPointCount`)



2\. \*\*Extreme Detection\*\*: Identifies peaks (sell signals) and troughs (buy signals) using selected method



3\. \*\*Trade Execution\*\*:

   - Trough detected → Buy (go long) after shifting by `rightScope` volume

   - Peak detected → Sell (go short) after shifting by `rightScope` volume

   - Always closes opposite position before opening new one



\### Position Management

\- \*\*Initial Capital\*\*: 100 USDT

\- \*\*Long Position\*\*: All USDT converted to BTC

\- \*\*Short Position\*\*: BTC sold, short position opened

\- \*\*Stop-Loss\*\*: Monitored at every data point

  - Long: Triggers if price drops below `entryPrice × (1 - StopLoss)`

  - Short: Triggers if price rises above `entryPrice × (1 + StopLoss)`

\- \*\*Fees\*\*: Applied on both entry and exit (percentage specified by `TransactionPercent`)



\### Trade Timing

\- Trades are executed after a volume shift (`rightScope`) from the detected extreme point

\- This delay helps avoid premature entries at noisy extremes



\## Output and Visualization



\### Console Output

\- Number of data points fetched

\- Stop-loss trigger notifications

\- Results table with:

  - Symbol, Interval, Iterations, Days

  - Optimized parameters

  - Final holding value

  - Number of trades executed



\### Plots

1\. \*\*Optimization Results Plot\*\*:

   - Smoothed signal (gray line)

   - Raw prices (dark gray line)

   - Buy markers (green circles)

   - Sell markers (red circles)

   - Final holding displayed in subtitle



2\. \*\*Historical Playback Plot\*\* (real-time during simulation):

   - Smoothed signal (cyan line)

   - Raw prices (blue line)

   - Buy markers (green circles)

   - Sell markers (red circles)

   - Current holding updated in subtitle



\## Optimization Parameters Explained



\### Parameter Vector: `\\\[leftScope, rightScope, detectSpeed]`



\- \*\*leftScope\*\*: Volume threshold for left-side smoothing and detection

  - Larger values = more historical data used, smoother signal

  - Smaller values = more responsive to recent changes

 

\- \*\*rightScope\*\*: Volume threshold for right-side smoothing and detection, and trade execution delay

  - Affects both signal smoothness and trade timing

  - Larger values = more conservative (trades later)

 

\- \*\*detectSpeed\*\*: Multiplier for left scope in extreme detection

  - `leftExtrScope = leftScope × detectSpeed`

  - Controls asymmetry in peak/trough detection

  - Value of 1 = symmetric detection



\### Smoothing Parameter: `SmoothPar`

\- Range: 0.1 to 1.0

\- Controls window size of secondary moving average

\- `windowSize = SmoothPar × avgPointCount`

\- Recommended value: 0.5



\## Data Source



Historical data is fetched from Binance REST API:

\- Endpoint: `https://api.binance.com/api/v3/klines`

\- Data fetched in batches of 960 points

\- Price calculation: `(high + low) / 2`

\- All times in UTC



\## Notes



\- The system uses cumulative volume as the x-axis (rather than time) to better account for market activity

\- Optimization can be time-consuming; adjust `OptimiserIterations` based on needs

\- The `pauseTime` parameter allows slowing down the playback visualization

\- All positions are closed at the end of the simulation

\- The system currently uses historical data playback; real-time trading integration is separate



\## File Structure

ocurrency trading that uses volume-based asymmetric smoothing and peak/trough detection to optimize trading strategies on historical Binance data.



\## Overview



This system implements a two-phase approach:

1\. \*\*Historical Optimization\*\*: Fetches historical data from Binance, optimizes trading parameters using surrogate optimization, and runs simulations

2\. \*\*Historical Playback\*\*: Simulates trading on historical data using optimized parameters with real-time visualization



\## Requirements



\### MATLAB Toolboxes

\- \*\*Global Optimization Toolbox\*\* (required for `surrogateopt`)

\- \*\*Optimization Toolbox\*\* (required for `optimoptions`)

\- \*\*Signal Processing Toolbox\*\* (optional, only needed if using `'Findpeaks'` detection method)



\### MATLAB Base

\- MATLAB R2017a or later (for `smoothdata` function)

\- Internet connection (for Binance API access)



\## Quick Start



1\. Ensure all `.m` files are in your MATLAB path

2\. Run the main function:

   BackTesting\_02()

   The system will automatically:

\- Fetch historical data from Binance

\- Optimize trading parameters

\- Run a simulation with visualization



\## Main Function: `BackTesting\\\_02()`



This is the entry point for the backtesting system. It coordinates both optimization and simulation phases.



\### User Parameters



Modify these parameters at the beginning of `BackTesting\\\_02.m`:



| Parameter | Description | Example Value |

|-----------|-------------|---------------|

| `symbol` | Trading pair symbol | `'BTCUSDT'` |

| `interval` | Kline interval | `'5m'` (5 minutes) |

| `OptimiserIterations` | Number of optimization iterations | `10` |

| `TransactionPercent` | Transaction fee percentage | `0.115` (0.115%) |

| `StopLoss` | Stop-loss percentage (0-1) | `0.1` (10%) |

| `OptimisationDays` | Number of days of historical data | `10` |

| `lb` | Lower bounds `\\\[leftScope, rightScope, detectSpeed]` | `\\\[10000, 20000, 1]` |

| `ub` | Upper bounds `\\\[leftScope, rightScope, detectSpeed]` | `\\\[20000, 40000, 1]` |

| `SmoothPar` | Additional smoothing parameter (0.1-1) | `0.5` |

| `optimMethod` | Extreme detection method | `'CustomAsymetric'` |

| `simulationMethod` | Simulation detection method | `'CustomAsymetric'` |

| `pauseTime` | Pause between iterations (seconds) | `0` |

| `FinalOptimisationDate` | End date for optimization | `'30.7.2024'` |



\### Supported Intervals

\- `'1m'`, `'3m'`, `'5m'`, `'15m'`, `'30m'`, `'1h'`



\### Detection Methods

\- `'CustomAsymetric'`: Custom volume-based asymmetric peak/trough detection (recommended)

\- `'Findpeaks'`: MATLAB's built-in `findpeaks` function (requires Signal Processing Toolbox)

\- `'Derivative'`: Zero-crossing derivative method



\## Core Functions



\### `runHistoricalOptimization(userParams)`

Fetches historical data from Binance, optimizes trading parameters, and runs initial simulation.



\*\*Input:\*\*

\- `userParams`: Structure containing all user-defined parameters



\*\*Outputs:\*\*

\- `optimizedParams`: Optimized parameter vector `\\\[leftScope, rightScope, detectSpeed]`

\- `lastState`: Final simulation state (holding, position, entryPrice, tradeLog)

\- `historicalBuffer`: Historical data (prices, volumes, times, cumVol)



\*\*Process:\*\*

1\. Calculates data range based on `FinalOptimisationDate` and `OptimisationDays`

2\. Fetches kline data from Binance API in batches (960 points per fetch)

3\. Parses data (uses high-low average as price)

4\. Runs `surrogateopt` optimization to find best parameters

5\. Runs simulation with optimized parameters

6\. Displays results table and generates plot



\### `simulateTrading(prices, volumes, times, leftScope, rightScope, detect\\\_speed, Fee, StopLoss, ExtrDetType, SmoothPar)`

Simulates trading on provided data using specified parameters.



\*\*Inputs:\*\*

\- `prices`: Price vector (column vector)

\- `volumes`: Volume vector (column vector)

\- `times`: Time vector (column vector)

\- `leftScope`: Left-side volume scope for smoothing

\- `rightScope`: Right-side volume scope for smoothing

\- `detect\\\_speed`: Detection speed multiplier for left scope

\- `Fee`: Transaction fee as fraction (e.g., 0.00115 for 0.115%)

\- `StopLoss`: Stop-loss percentage (e.g., 0.1 for 10%)

\- `ExtrDetType`: Extreme detection type (`'CustomAsymetric'`, `'Findpeaks'`, `'Derivative'`)

\- `SmoothPar`: Additional smoothing parameter (0.1-1)



\*\*Outputs:\*\*

\- `finalHolding`: Final USDT holding after all trades

\- `TradeList`: 3×N matrix where:

  - Row 1: Cumulative volume at trade

  - Row 2: Buy price (0 if sell)

  - Row 3: Sell price (0 if buy)



\*\*Process:\*\*

1\. Computes cumulative volume

2\. Applies asymmetric volume-based smoothing

3\. Applies additional moving average smoothing

4\. Detects peaks and troughs using selected method

5\. Simulates trading: buys at troughs, sells at peaks

6\. Applies stop-loss logic at every data point

7\. Closes all positions at final price



\### `objectiveFunction(params, prices, volumes, times, Fee, StopLoss, ExtrDetType, SmoothPar)`

Objective function for optimization. Returns negative final holding (to maximize via minimization).



\*\*Inputs:\*\*

\- `params`: Parameter vector `\\\[leftScope, rightScope, detectSpeed]`

\- Other inputs: Same as `simulateTrading`



\*\*Output:\*\*

\- `negHolding`: Negative of final holding value



\## Supporting Functions



\### `asymmetricSmoothVol(prices, cumVol, leftScope, rightScope)`

Performs volume-based asymmetric smoothing on price data.



\*\*Algorithm:\*\*

\- For each point, collects all data points within `leftScope` volume to the left and `rightScope` volume to the right

\- Computes mean price of collected points

\- Returns smoothed signal and point counts



\### `findAsymmetricPeaksVol(data, cumVol, leftBTC, rightBTC)`

Detects peaks using volume-based asymmetric criteria.



\*\*Algorithm:\*\*

\- A point is a peak if it's higher than all points within `leftBTC` volume to the left AND `rightBTC` volume to the right



\### `findAsymmetricTroughsVol(data, cumVol, leftBTC, rightBTC)`

Detects troughs using volume-based asymmetric criteria.



\*\*Algorithm:\*\*

\- A point is a trough if it's lower than all points within `leftBTC` volume to the left AND `rightBTC` volume to the right



\### `myOutputFcn(x, optimValues, state, varargin)`

Output function for `surrogateopt` optimization (currently minimal, can be extended for progress tracking)



\## Trading Strategy



\### Signal Generation

1\. \*\*Smoothing\*\*: Two-stage smoothing process

   - Primary: Volume-based asymmetric smoothing (adapts to volume patterns)

   - Secondary: Moving average smoothing (window size = `SmoothPar × avgPointCount`)



2\. \*\*Extreme Detection\*\*: Identifies peaks (sell signals) and troughs (buy signals) using selected method



3\. \*\*Trade Execution\*\*:

   - Trough detected → Buy (go long) after shifting by `rightScope` volume

   - Peak detected → Sell (go short) after shifting by `rightScope` volume

   - Always closes opposite position before opening new one



\### Position Management

\- \*\*Initial Capital\*\*: 100 USDT

\- \*\*Long Position\*\*: All USDT converted to BTC

\- \*\*Short Position\*\*: BTC sold, short position opened

\- \*\*Stop-Loss\*\*: Monitored at every data point

  - Long: Triggers if price drops below `entryPrice × (1 - StopLoss)`

  - Short: Triggers if price rises above `entryPrice × (1 + StopLoss)`

\- \*\*Fees\*\*: Applied on both entry and exit (percentage specified by `TransactionPercent`)



\### Trade Timing

\- Trades are executed after a volume shift (`rightScope`) from the detected extreme point

\- This delay helps avoid premature entries at noisy extremes



\## Output and Visualization



\### Console Output

\- Number of data points fetched

\- Stop-loss trigger notifications

\- Results table with:

  - Symbol, Interval, Iterations, Days

  - Optimized parameters

  - Final holding value

  - Number of trades executed



\### Plots

1\. \*\*Optimization Results Plot\*\*:

   - Smoothed signal (gray line)

   - Raw prices (dark gray line)

   - Buy markers (green circles)

   - Sell markers (red circles)

   - Final holding displayed in subtitle



2\. \*\*Historical Playback Plot\*\* (real-time during simulation):

   - Smoothed signal (cyan line)

   - Raw prices (blue line)

   - Buy markers (green circles)

   - Sell markers (red circles)

   - Current holding updated in subtitle



\## Optimization Parameters Explained



\### Parameter Vector: `\\\[leftScope, rightScope, detectSpeed]`



\- \*\*leftScope\*\*: Volume threshold for left-side smoothing and detection

  - Larger values = more historical data used, smoother signal

  - Smaller values = more responsive to recent changes

 

\- \*\*rightScope\*\*: Volume threshold for right-side smoothing and detection, and trade execution delay

  - Affects both signal smoothness and trade timing

  - Larger values = more conservative (trades later)

 

\- \*\*detectSpeed\*\*: Multiplier for left scope in extreme detection

  - `leftExtrScope = leftScope × detectSpeed`

  - Controls asymmetry in peak/trough detection

  - Value of 1 = symmetric detection



\### Smoothing Parameter: `SmoothPar`

\- Range: 0.1 to 1.0

\- Controls window size of secondary moving average

\- `windowSize = SmoothPar × avgPointCount`

\- Recommended value: 0.5



\## Data Source



Historical data is fetched from Binance REST API:

\- Endpoint: `https://api.binance.com/api/v3/klines`

\- Data fetched in batches of 960 points

\- Price calculation: `(high + low) / 2`

\- All times in UTC



\## Notes



\- The system uses cumulative volume as the x-axis (rather than time) to better account for market activity

\- Optimization can be time-consuming; adjust `OptimiserIterations` based on needs

\- The `pauseTime` parameter allows slowing down the playback visualization

\- All positions are closed at the end of the simulation

\- The system currently uses historical data playback; real-time trading integration is separate



\## File Structure

