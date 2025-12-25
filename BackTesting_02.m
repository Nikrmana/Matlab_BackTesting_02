function BackTesting_02()
%% Phase 1: Historical Optimization and Simulation %%%
    % Run your historical optimization and simulation.
    % Assume runHistoricalOptimization returns not only optimized parameters,
    % but also the final simulation state and a historical buffer.

    %% Define parameters
    userParams.symbol =             'BTCUSDT';
    userParams.interval =           '5m';
    userParams.OptimiserIterations = 10;
    userParams.TransactionPercent  = 0.115;
    userParams.StopLoss            = 0.1;
    userParams.OptimisationDays    = 10;              % (Total historical days to fetch)
    userParams.lb                  = [10000, 20000, 1]; % lower bounds for parameters [init_s_left, init_xDistance, detect_speed]
    userParams.ub                  = [20000, 40000, 1]; % upper bounds for parameters [init_s_left, init_xDistance, detect_speed]
    userParams.SmoothPar           = 0.5;             % additional smoothing parameter (0.1 to 1), 0.5 best so far
    userParams.optimMethod         = 'CustomAsymetric'; % extreme detection method for optimisation 'Findpeaks' 'CustomAsymetric' 'Derivative'
    userParams.simulationMethod    = 'CustomAsymetric';  % For example
    userParams.pauseTime = 10;
    userParams.FinalOptimisationDate = '30.7.2024'; 
    userParams.pauseTime = 0; 


    Fee = userParams.TransactionPercent/100;

    %% Run Optimisation on Historical Data
    [optimizedParams, lastState, historicalBuffer] = runHistoricalOptimization(userParams);
    
    %% Get Starting Position for Real Time trading
    % Extract the final state information:
    % lastState should include fields like currentHolding, position, entryPrice, tradeLog.
    currentHolding = lastState.currentHolding;
    position     = lastState.position;
    entryPrice   = lastState.entryPrice;
    tradeLog     = lastState.tradeLog;
    
    % Use historicalBuffer to initialize your data buffers.
    % historicalBuffer should contain fields: prices, volumes, times, cumVol.
    RealPrices  = historicalBuffer.prices;
    RealVolumes = historicalBuffer.volumes;
    RealTimes   = historicalBuffer.times;
    RealCumVolumes = historicalBuffer.cumVol;
   

 %% Phase 2: Real-Time Simulation Loop %%%
    % komentarji za prejšnjo verzijo:
    % Prehod iz starega seta podatov v novi ni brez napake !!!
    % če se predolgo izvaja optimizacija, lahko nekaj tickov manjka

        

    fprintf('Starting simulation playback on historical dataset...\n'); 
    
    % Open your figure and set up the plots (this remains similar)
    smoothedSignal = NaN(size(RealCumVolumes));
    figure;
    plotSmoothed = plot(RealCumVolumes, smoothedSignal, 'c-', 'LineWidth', 2); hold on;
    plotPrice    = plot(RealCumVolumes, RealPrices, 'b-'); hold on;
    plotTradeLong = plot(NaN, NaN, 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g'); hold on;
    plotTradeShort = plot(NaN, NaN, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); hold on;
    title(sprintf('Historical Playback (%s)', userParams.simulationMethod));
    subTHandle = subtitle(sprintf('Final Holding: %.2f', NaN));
    xlabel('Cumulative Volume'); ylabel('Price');
    
    % Loop through all ticks in the historical dataset
    numTicks = numel(RealTimes);
    % start with second tick


    % Initialize persistent storage before entering the loop
    accumulatedTradeList = []; % Confirmed (locked-in) trades; each column is a trade
    lastTradeCumVol = -inf; % Overall cumulative volume of the last confirmed trade
    
    % Define the margin as three times the sum of left and right scopes 
    margin = 3 * (optimizedParams(1) + optimizedParams(2));

    % Initialize trading state variables (starting with 100 USDT and no positions) 
    USDT = 100;
    BTC = 0;
    BTCshort = 0;
    position = 'none';
    entryPrice = NaN;
    
    for idx = 2:numTicks % --- Get the current full window of data --- 
        currentPrices = RealPrices(1:idx); 
        currentVolumes = RealVolumes(1:idx); 
        currentTimes = RealTimes(1:idx); 
        currentCumVol = RealCumVolumes(1:idx);
    
    %--- Define a subset (window) for processing based on the margin ---%
    % We use the last 'margin' of cumulative volume in this iteration.
    % --- Define the subset window based on the margin ---
    
    
    windowStartVol = currentCumVol(end) - margin;
    windowStartVol = max(windowStartVol, currentCumVol(1));
    newStartIdx = find(currentCumVol >= windowStartVol, 1, 'first');
    
    % Extract subset data from newStartIdx to the end (this is your relevant data scope)
    subsetPrices  = currentPrices(newStartIdx:end);
    subsetVolumes = currentVolumes(newStartIdx:end);
    subsetTimes   = currentTimes(newStartIdx:end);
    subsetCumVol  = currentCumVol(newStartIdx:end);
    
    % Rebase cumulative volume for the subset (so that local calculations are not affected by older data)
    offset = subsetCumVol(1);
    localCumVol = subsetCumVol - offset;
    
    % --- Compute the smoothed signal using the subset only ---
    [smoothedSignalSubset, pointCounts] = asymmetricSmoothVol(subsetPrices, subsetCumVol, optimizedParams(1), optimizedParams(2));
    avgPointCount = mean(pointCounts);
    SmoothWindowSize = userParams.SmoothPar * avgPointCount;
    smoothedSignalSubset = smoothdata(smoothedSignalSubset, 'movmean', SmoothWindowSize);
    
    % For plotting purposes, shift the local cumulative volume back to the overall scale.
    overallSubsetCumVol = localCumVol + offset;
     set(plotSmoothed, 'XData', overallSubsetCumVol, 'YData', smoothedSignalSubset);
    % set(plotPrice,    'XData', overallSubsetCumVol, 'YData', subsetPrices);
    
    % hold on; 
    % plot(overallSubsetCumVol, subsetPrices, 'b-');

    % --- Run simulation on only the subset to get candidate trades ---
    [~, simTradeListSubset] = simulateTrading(subsetPrices, subsetVolumes, subsetTimes, ...
        optimizedParams(1), optimizedParams(2), optimizedParams(3), ...
        Fee, userParams.StopLoss, userParams.simulationMethod, userParams.SmoothPar);
    
    % Adjust the candidate trades’ cumulative volumes back to overall scale.
    if ~isempty(simTradeListSubset)
        simTradeListSubset(1,:) = simTradeListSubset(1,:) + offset;
    end
    
    % --- Determine candidate trade from the subset ---
    newTrade = [];
    if ~isempty(simTradeListSubset)
        candidateIndices = find(simTradeListSubset(1,:) > lastTradeCumVol);
        if ~isempty(candidateIndices)
            % Pick the candidate with the highest cumulative volume (i.e. the most recent new trade)
            candidateTrade = simTradeListSubset(:, candidateIndices(end));
            
            % Determine candidate trade type: buy if candidateTrade(2) > 0; sell if candidateTrade(3) > 0.
            candidateIsBuy = candidateTrade(2) > 0;
            candidateIsSell = candidateTrade(3) > 0;
            
            % (Optional) Check that candidate is of a different type than the last locked trade.
            if ~isempty(accumulatedTradeList)
                lastTrade = accumulatedTradeList(:, end);
                lastTradeIsBuy = lastTrade(2) > 0;
                lastTradeIsSell = lastTrade(3) > 0;
                if (candidateIsBuy && lastTradeIsBuy) || (candidateIsSell && lastTradeIsSell)
                    newTrade = [];
                else
                    newTrade = candidateTrade;
                end
            else
                newTrade = candidateTrade;
            end
        end
    end
    
    % --- If a new trade candidate is found, update trading state and accumulate the trade ---
    if ~isempty(newTrade)
        % newTrade(1) contains the trade's cumulative volume; candidateTrade(2) or (3) is the trade price.
        if candidateIsBuy  % (Trough event): Execute a buy (go long)
            if ~strcmp(position, 'long')
                % If currently short, close short first
                if strcmp(position, 'short')
                    USDT = USDT - BTCshort * newTrade(2) * (1 + Fee);
                    BTCshort = 0;
                end
                % Use all available USDT to buy BTC
                newBTC = USDT / newTrade(2) * (1 - Fee);
                BTC = BTC + newBTC;
                USDT = 0;
                position = 'long';
                entryPrice = newTrade(2);
            end
        elseif candidateIsSell  % (Peak event): Execute a sell (go short)
            if ~strcmp(position, 'short')
                % If currently long, close long first by selling BTC
                if strcmp(position, 'long')
                    USDT = USDT + BTC * newTrade(3) * (1 - Fee);
                    BTCshort = BTCshort + BTC;
                    USDT = USDT + BTC * newTrade(3) * (1 - Fee);
                    BTC = 0;
                end
                position = 'short';
                entryPrice = newTrade(3);
            end
        end
        
        % Append the new trade to the persistent list and update lastTradeCumVol.
        accumulatedTradeList = [accumulatedTradeList, newTrade];
        lastTradeCumVol = newTrade(1);
        
        % Also update the corresponding trade marker on the plot.
        if candidateIsBuy
            oldX = get(plotTradeLong, 'XData');
            oldY = get(plotTradeLong, 'YData');
            set(plotTradeLong, 'XData', [oldX, newTrade(1)], 'YData', [oldY, newTrade(2)]);
        elseif candidateIsSell
            oldX = get(plotTradeShort, 'XData');
            oldY = get(plotTradeShort, 'YData');
            set(plotTradeShort, 'XData', [oldX, newTrade(1)], 'YData', [oldY, newTrade(3)]);
        end
        drawnow;
    end
    
    % --- Calculate current holding based on live state ---
    % Use the latest price in the overall current window as the current market price.
    currentPrice = currentPrices(end);
    % In our simulation holding is given by the sum of any cash on hand plus the value
    % of any long positions minus the liability of any short positions.
    currentHolding = USDT + BTC * currentPrice * (1 - Fee) - BTCshort * currentPrice * (1 + Fee);
    
    % Update the plot subtitle with the current holding.
    subTHandle.String = sprintf('Final Holding: %.2f', currentHolding);
    drawnow;
    
    pause(userParams.pauseTime);


    end








        % Detect events (peaks/troughs) using the chosen simulation method.
        % [eventDetected, eventType, eventIndex] = detectEvent(smoothedSignal, cumVolBuffer, userParams.simulationMethod, optimizedParams);
        
        % Check for stop-loss conditions on the latest tick.
        % currentPrice = tick.price;
        % if strcmp(position, 'long') && (currentPrice < entryPrice * (1 - StopLoss))
        %     [currentHolding, position, entryPrice] = executeStopLoss('long', currentPrice, currentHolding);
        %     tradeLog = logTrade(tradeLog, tick.time, 'stop-loss sell', currentPrice);
        % elseif strcmp(position, 'short') && (currentPrice > entryPrice * (1 + StopLoss))
        %     [currentHolding, position, entryPrice] = executeStopLoss('short', currentPrice, currentHolding);
        %     tradeLog = logTrade(tradeLog, tick.time, 'stop-loss cover', currentPrice);
        % end
        
        % Process detected events to execute trades.
        % if eventDetected
        %     % Determine trade details based on the event (for example, shifting by a volume threshold).
        %     [tradePrice, tradeVolume] = determineTradeDetails(priceBuffer, cumVolBuffer, eventIndex, optimizedParams(2));
        %     if strcmp(eventType, 'trough') && ~strcmp(position, 'long')
        %         [currentHolding, position, entryPrice] = executeTrade('buy', tradePrice, currentHolding);
        %         tradeLog = logTrade(tradeLog, tick.time, 'buy', tradePrice);
        %     elseif strcmp(eventType, 'peak') && ~strcmp(position, 'short')
        %         [currentHolding, position, entryPrice] = executeTrade('sell', tradePrice, currentHolding);
        %         tradeLog = logTrade(tradeLog, tick.time, 'sell', tradePrice);
        %     end
        % end
        
        % Optionally, update real-time visualization.
        % updateRealTimePlot(priceBuffer, tradeLog);
        
   % end
end
