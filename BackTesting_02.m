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
    
    % Initialize confirmed peaks/troughs storage (for stable detection)
    confirmedPeaks = [];      % Cumulative volume of confirmed peaks
    confirmedTroughs = [];    % Cumulative volume of confirmed troughs
    confirmedPeaksData = [];  % Store [cumVol, price] for confirmed peaks
    confirmedTroughsData = [];% Store [cumVol, price] for confirmed troughs
    
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
    
    % --- Compute the smoothed signal using CAUSAL smoothing (historical data only) ---
    [smoothedSignalSubset, pointCounts] = asymmetricSmoothVolCausal(subsetPrices, subsetCumVol, optimizedParams(1), optimizedParams(2));
    avgPointCount = mean(pointCounts);
    SmoothWindowSize = userParams.SmoothPar * avgPointCount;
    smoothedSignalSubset = smoothdata(smoothedSignalSubset, 'movmean', SmoothWindowSize);
    
    % For plotting purposes, shift the local cumulative volume back to the overall scale.
    overallSubsetCumVol = localCumVol + offset;
    set(plotSmoothed, 'XData', overallSubsetCumVol, 'YData', smoothedSignalSubset);
    
    % --- Find candidate peaks/troughs using causal detection (allowing unconfirmed) ---
    leftExtrScope = optimizedParams(1) * optimizedParams(3);
    candidatePeaks = findAsymmetricPeaksVolCausal(smoothedSignalSubset, subsetCumVol, leftExtrScope, optimizedParams(2), false);
    candidateTroughs = findAsymmetricTroughsVolCausal(smoothedSignalSubset, subsetCumVol, leftExtrScope, optimizedParams(2), false);
    
    % Convert local indices to global cumulative volumes
    currentPeakVols = subsetCumVol(candidatePeaks) + offset;
    currentTroughVols = subsetCumVol(candidateTroughs) + offset;
    
    % Find peaks/troughs that can NOW be confirmed (enough future data has arrived)
    currentVol = currentCumVol(end);
    confirmThreshold = currentVol - optimizedParams(2);  % Need rightScope volume to have passed
    
    % Confirm new peaks
    for i = 1:length(currentPeakVols)
        peakVol = currentPeakVols(i);
        peakLocalIdx = candidatePeaks(i);
        if peakVol <= confirmThreshold && ~ismember(peakVol, confirmedPeaks)
            % Find the trade execution point (shifted by rightScope)
            peakGlobalIdx = newStartIdx + peakLocalIdx - 1;
            volTrans = peakVol + optimizedParams(2);
            tradeIdx = find(currentCumVol >= volTrans, 1, 'first');
            if isempty(tradeIdx)
                tradeIdx = length(currentCumVol);
            end
            tradePrice = currentPrices(tradeIdx);
            confirmedPeaks(end+1) = peakVol; %#ok<AGROW>
            confirmedPeaksData = [confirmedPeaksData; peakVol, tradePrice]; %#ok<AGROW>
        end
    end
    
    % Confirm new troughs
    for i = 1:length(currentTroughVols)
        troughVol = currentTroughVols(i);
        troughLocalIdx = candidateTroughs(i);
        if troughVol <= confirmThreshold && ~ismember(troughVol, confirmedTroughs)
            % Find the trade execution point (shifted by rightScope)
            troughGlobalIdx = newStartIdx + troughLocalIdx - 1;
            volTrans = troughVol + optimizedParams(2);
            tradeIdx = find(currentCumVol >= volTrans, 1, 'first');
            if isempty(tradeIdx)
                tradeIdx = length(currentCumVol);
            end
            tradePrice = currentPrices(tradeIdx);
            confirmedTroughs(end+1) = troughVol; %#ok<AGROW>
            confirmedTroughsData = [confirmedTroughsData; troughVol, tradePrice]; %#ok<AGROW>
        end
    end
    
    % --- Build TradeList from CONFIRMED peaks/troughs only ---
    % Sort all confirmed events by cumulative volume
    newTrade = [];
    if ~isempty(confirmedPeaksData) || ~isempty(confirmedTroughsData)
        % Combine peaks and troughs with type indicator
        allEvents = [];
        if ~isempty(confirmedPeaksData)
            allEvents = [allEvents; confirmedPeaksData, ones(size(confirmedPeaksData,1),1)]; % 1 = peak/sell
        end
        if ~isempty(confirmedTroughsData)
            allEvents = [allEvents; confirmedTroughsData, zeros(size(confirmedTroughsData,1),1)]; % 0 = trough/buy
        end
        
        % Sort by cumulative volume
        allEvents = sortrows(allEvents, 1);
        
        % Find the most recent confirmed event that hasn't been traded yet
        for eventIdx = 1:size(allEvents, 1)
            eventVol = allEvents(eventIdx, 1);
            eventPrice = allEvents(eventIdx, 2);
            eventIsPeak = (allEvents(eventIdx, 3) == 1);
            
            % Check if this event is after the last traded event
            if eventVol > lastTradeCumVol
                % Check that it's different type from last trade
                if ~isempty(accumulatedTradeList)
                    lastTrade = accumulatedTradeList(:, end);
                    lastTradeIsBuy = lastTrade(2) > 0;
                    if (eventIsPeak && lastTradeIsBuy) || (~eventIsPeak && ~lastTradeIsBuy)
                        % Same type, skip
                        continue;
                    end
                end
                
                % This is a valid new trade
                if eventIsPeak
                    newTrade = [eventVol; 0; eventPrice];  % Sell trade
                else
                    newTrade = [eventVol; eventPrice; 0];  % Buy trade
                end
                break;  % Take the first valid new trade
            end
        end
    end
    
    % --- If a new trade candidate is found, update trading state and accumulate the trade ---
    if ~isempty(newTrade)
        candidateIsBuy = newTrade(2) > 0;
        candidateIsSell = newTrade(3) > 0;
        
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
