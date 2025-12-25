function [optimizedParams, lastState, historicalBuffer] = runHistoricalOptimization(userParams)
% runHistoricalOptimization - Performs historical optimisation and simulation.
%
% This function uses a structure of user parameters (userParams) that must include:
%    symbol              - e.g., 'BTCUSDT'
%    interval            - e.g., '5m'
%    OptimiserIterations - e.g., 50
%    TransactionPercent  - e.g., 0.115
%    StopLoss            - e.g., 0.1
%    OptimisationDays    - e.g., 30  (Total historical days to fetch)
%    lb                  - lower bounds for parameters [init_s_left, init_xDistance, detect_speed]
%    ub                  - upper bounds for parameters [init_s_left, init_xDistance, detect_speed]
%    SmoothPar           - additional smoothing parameter (0.1 to 1)
%    Fee                 - fee as fraction (e.g., TransactionPercent/100)
%    optimMethod         - extreme detection method for optimisation, e.g., 'CustomAsymetric'
%
% The simulation start date is set to the current time, meaning that the data fetched
% will span from (current time - OptimisationDays) to now.
%
% Outputs:
%   optimizedParams  - Optimised parameters vector.
%   optimMethod      - The extreme detection method used for optimisation.
%   lastState        - Structure with final simulation state (currentHolding, position,
%                      entryPrice, tradeLog).
%   historicalBuffer - Structure with fields: prices, volumes, times, cumVol.

    %% Unpack User Parameters for Optimisation
    symbol              = userParams.symbol;
    interval            = userParams.interval;
    OptimiserIterations = userParams.OptimiserIterations;
    TransactionPercent  = userParams.TransactionPercent;
    StopLoss            = userParams.StopLoss;
    OptimisationDays    = userParams.OptimisationDays;
    lb                  = userParams.lb;
    ub                  = userParams.ub;
    SmoothPar           = userParams.SmoothPar;
    optimMethod         = userParams.optimMethod;
    
    Fee = TransactionPercent/100;


    % Use the supplied FinalOptimisationDate as the simulation end date
    if ~isfield(userParams, 'FinalOptimisationDate')
        error('User parameter "FinalOptimisationDate" is missing.');
    end
    simulationEndDate = datetime(userParams.FinalOptimisationDate, 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm:ss');
    currentTime = simulationEndDate;  
    optStartDate = currentTime - days(userParams.OptimisationDays);
    simulationStartDate = optStartDate;  % Use the start of the window as the simulation start date.


    % Set simulationStartDate to current time (UTC)
                        % simulationStartDate = datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss');

    
    %% Define Data Lengths Based on OptimisationDays
    barsPerDay = getBarsPerDay(interval);
    TotalPoints = OptimisationDays * barsPerDay;
    OptimisationLength = floor(TotalPoints);      
 
    
    %% Calculate the Data Fetch Start Time
    % The start date is (FinalOptimisationDate - OptimisationDays)
                        % currentTime = datetime('now','TimeZone','UTC');
                        % optStartDate = currentTime - days(OptimisationDays);
    startTime = posixtime(optStartDate) * 1000;  % convert to milliseconds
    
    %% Fetch Historical Data from Binance
    limit = 960;  % Number of points per fetch
    DataSetsNumber = ceil(TotalPoints / limit);
    url = 'https://api.binance.com/api/v3/klines';
    options = weboptions('Timeout', 100);
    
    % Preallocate cell array to hold fetched data.
    allDataPre = cell(DataSetsNumber * limit, 1);
    dataCounter = 0;
    currentStartTime = startTime;
    
    for k = 1:DataSetsNumber
        paramsK = {'symbol', symbol, 'interval', interval, 'startTime', num2str(floor(currentStartTime)), 'limit', num2str(limit)};
        dataK = webread(url, paramsK{:}, options);
        if isempty(dataK)
            warning('No data returned for segment %d. Possibly out of range.', k);
            break;
        end
        nDataK = numel(dataK);
        allDataPre(dataCounter+1 : dataCounter+nDataK) = dataK;
        dataCounter = dataCounter + nDataK;
        lastCloseTime = dataK{end}{7};
        currentStartTime = lastCloseTime + 1;
    end
    
    allData = allDataPre(1:dataCounter);
    if numel(allData) > TotalPoints
        allData = allData(1:TotalPoints);
    end
    combinedData = allData;
    totalPoints = size(combinedData, 1);
    
    fprintf('Fetched %d data points from Binance.\n', totalPoints);
    if totalPoints < TotalPoints
        warning('Fetched fewer data points than expected: %d instead of %d.', totalPoints, TotalPoints);
    end
    
    %% Parse Data into Numeric Arrays
    openTimes = zeros(totalPoints, 1);
    volumes   = zeros(totalPoints, 1);
    prices    = zeros(totalPoints, 1);
    
    for i = 1:totalPoints
        row = combinedData{i};
        openTimes(i) = row{1};
        hi = str2double(row{3});
        lo = str2double(row{4});
        prices(i) = (hi + lo) / 2;
        volumes(i) = str2double(row{6});
    end
    
    times = datetime(openTimes/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    cumVol = cumsum(volumes);
    
    %% Define Optimization Segments
    % Use all data for optimization.
    pricesOpt = prices(1:OptimisationLength);
    volumesOpt = volumes(1:OptimisationLength);
    timesOpt = times(1:OptimisationLength);
    % Calculate cumulative volume 
    cumVolOpt = cumVol(1:OptimisationLength);
    
    %% Run Optimization with surrogateopt
    opts = optimoptions('surrogateopt', 'Display','none', ...
                        'MaxFunctionEvaluations', OptimiserIterations, 'OutputFcn', @myOutputFcn);
    % Define anonymous function handle for the objective.
    objFunLocal = @(params) objectiveFunction(params, pricesOpt, volumesOpt, timesOpt, Fee, StopLoss, optimMethod, SmoothPar);
    [optimizedParams, bestfval, exitflag, output] = surrogateopt(objFunLocal, lb, ub, opts);
    

    %% Run Simulation on the Optimisation Segment
    if isempty(pricesOpt)
        error('No simulation data available.');
    end
    [finalHolding, TradeList] = simulateTrading(pricesOpt, volumesOpt, timesOpt, optimizedParams(1), optimizedParams(2), optimizedParams(3), Fee, StopLoss, optimMethod, SmoothPar);
    
    OptLeftScope   = optimizedParams(1);
    OptRightScope  = optimizedParams(2);
    OptDetectSpeed = optimizedParams(3);

    %% Compute smoothed signal for plotting
    [smoothedFull, pointCounts] = asymmetricSmoothVol(pricesOpt, cumVolOpt, OptLeftScope, OptRightScope);
    avgPointCount = mean(pointCounts);
    % Additional smoothing using moving average 
    SmoothWindowSize = SmoothPar*avgPointCount;   % tole je približek, lahko se zgodi da seže window size v prihodnost! Preveri!
    smoothedFull = smoothdata(smoothedFull, 'movmean', SmoothWindowSize);

    %% Plot Optimisation Results Using Cumulative Volume
    figure;
    plot(cumVolOpt, smoothedFull, 'LineWidth', 2, 'Color', [0.7 0.7 0.7]);
    hold on;
    plot(cumVolOpt, pricesOpt, 'Color', [0.3 0.3 0.3]); hold on;
    title(sprintf('Historical Simulation (%s)', optimMethod));
    subtitle(sprintf('Final Holding: %.2f', finalHolding));
    xlabel('Cumulative Volume'); ylabel('Price');
    
    % Plot trade markers if any trades occurred.
    if ~isempty(TradeList)
        nTrades = size(TradeList, 2);
        for j = 1:nTrades
            tradeVol = TradeList(1, j);
            % Shift trade volume to match the x-axis (relative cumulative volume)
            % tradeVolShift = tradeVol;% - cSim(1);
            buyPrice = TradeList(2, j);
            sellPrice = TradeList(3, j);
            if buyPrice > 0
                plot(tradeVol, buyPrice, 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
            elseif sellPrice > 0
                plot(tradeVol, sellPrice, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
            end
        end
    end
    hold off;



    
    
    %% Display Results in a Table
    resultsTable = table({symbol}, {interval}, OptimiserIterations, OptimisationDays, {simulationStartDate}, {optimizedParams}, finalHolding, size(TradeList,2), ...
        'VariableNames', {'Symbol','Interval','OptimiserIterations','OptimisationDays','SimulationStartDate','OptimizedParams','FinalHolding','NumTrades'});
    disp(resultsTable);
    
    %% Prepare Output Structures
    historicalBuffer.prices = prices;
    historicalBuffer.volumes = volumes;
    historicalBuffer.times = times;
    historicalBuffer.cumVol = cumVol;
    
    lastState.currentHolding = finalHolding;
    lastState.position = 'none';  % Assuming simulation closed all positions.
    lastState.entryPrice = NaN;
    lastState.tradeLog = TradeList;
end

function bars = getBarsPerDay(interval)
% getBarsPerDay - Returns the number of bars per day for a given interval.
    switch interval
        case '1m'
            bars = 1440;
        case '3m'
            bars = 480;
        case '5m'
            bars = 288;
        case '15m'
            bars = 96;
        case '30m'
            bars = 48;
        case '1h'
            bars = 24;
        otherwise
            error('Unsupported interval: %s', interval);
    end
end
