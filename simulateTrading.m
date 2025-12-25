%% Subfunctions for trading simulation 

function [finalHolding, TradeList] = simulateTrading(prices, volumes, times, leftScope, rightScope, detect_speed, Fee, StopLoss, ExtrDetType, SmoothPar)
    % Initial setup and calculations (keep as is)
    leftExtrScope = leftScope * detect_speed;
    
    % SmoothPar = additional Smoothing parameter between 0.1 and 1
 
    % Ensure we have enough data
    if numel(prices) < 2
        error('simulateTrading:NotEnoughData',...
              'PRICES must have at least 2 elements for 1:end-1 indexing.');
    end    

    % Force inputs to be column vectors
    prices = prices(:);
    volumes = volumes(:);
    times = times(:);

    % Compute cumulative volume (used as x-axis)
    cumVol = cumsum(volumes);

    % Smoothing using custom asymmetric smoothing
    [smoothed_full, pointCounts] = asymmetricSmoothVol(prices, cumVol, leftScope, rightScope);
    avgPointCount = mean(pointCounts);
    % fprintf('Average point count: %.2f\n', avgPointCount);

    % Additional smoothing using moving average 
    % window size = number of points * Smoothing parameter
    SmoothWindowSize = SmoothPar * avgPointCount; 
    smoothed_full = smoothdata(smoothed_full, 'movmean', SmoothWindowSize);

    %%% Peak/Trough detection based on ExtrDetType %%%
    switch ExtrDetType
        case 'CustomAsymetric'
            peaks   = findAsymmetricPeaksVol(smoothed_full, cumVol, leftExtrScope, rightScope);
            troughs = findAsymmetricTroughsVol(smoothed_full, cumVol, leftExtrScope, rightScope);

        case 'Findpeaks'
            % Use MATLAB built‐in findpeaks with the x vector smoothed_x.
            [~, peakX] = findpeaks(smoothed_full, cumVol, 'MinPeakDistance', rightScope);
            % Convert the x-values back to indices (assuming smoothed_x is monotonic)
            peaks = arrayfun(@(x) find(cumVol >= x, 1, 'first'), peakX);
            
            [~, troughX] = findpeaks(-smoothed_full, cumVol, 'MinPeakDistance', rightScope);
            troughs = arrayfun(@(x) find(cumVol >= x, 1, 'first'), troughX);

        case 'Derivative'
            % Use derivative zero‐crossing method
            d_signal = diff(smoothed_full);
            zeroCrossings = find(d_signal(1:end-1) .* d_signal(2:end) < 0) + 1;
            peaks = [];
            troughs = [];
            for i = 1:length(zeroCrossings)
                idx = zeroCrossings(i);
                if idx > 1 && d_signal(idx-1) > 0 && d_signal(idx) < 0
                    peaks(end+1) = idx; %#ok<AGROW>
                end
                if idx > 1 && d_signal(idx-1) < 0 && d_signal(idx) > 0
                    troughs(end+1) = idx; %#ok<AGROW>
                end
            end
        otherwise
            error('simulateTrading:UnknownExtrDetType', 'Unknown extreme detection type: %s', ExtrDetType);
    end

    % Trading Simulation Initialization
    BTC      = 0;
    BTCshort = 0;
    USDT     = 100;

    % Position tracking for stop-loss
    position   = 'none';  
    entryPrice = NaN;   

    % Build events vector and corresponding type cell array
    nPeaks   = length(peaks);
    nTroughs = length(troughs);
    nEvents  = nPeaks + nTroughs;
    
    events     = zeros(1, nEvents);
    eventTypes = cell(1, nEvents);
    
    % Fill peaks
    events(1:nPeaks)         = peaks;
    eventTypes(1:nPeaks)     = repmat({"peak"}, 1, nPeaks);
    
    % Fill troughs
    events(nPeaks+1:end)     = troughs;
    eventTypes(nPeaks+1:end) = repmat({"trough"}, 1, nTroughs);

    [sortedEvents, sortIdx] = sort(events);
    sortedTypes = eventTypes(sortIdx);

    % Keep track of the next event to process
    nextEventIdx = 1;
    
    % Preallocate TradeList based on maximum possible trades:
    % Estimate: 2 trades per event + 2 for final close trades
    maxTrades = 2 * nEvents + 2;
    TradeList = zeros(3, maxTrades);
    TradeCount = 0;
    
    % Main simulation loop over ALL data points to implement continuous stop-loss checking
    for idx = 1:length(prices)
        currentPrice = prices(idx);
        
        % Check for stop-loss first at every data point
        if strcmp(position, 'long') && (currentPrice < entryPrice * (1 - StopLoss))
            % Stop loss triggered for a long position
            lossPercentage = ((entryPrice - currentPrice) / entryPrice) * 100;
            
            % Sell BTC (and initiate a short position)
            USDT = USDT + BTC * currentPrice * (1 - Fee);
            BTCshort = BTCshort + BTC;
            USDT = USDT + BTC * currentPrice * (1 - Fee);
            BTC = 0;
            
            TradeCount = TradeCount + 1;
            Trade = [cumVol(idx); 0; currentPrice];  % Record as a sell trade
            TradeList(:, TradeCount) = Trade;
            
            % Update position: we now have a short position
            position = 'short';
            entryPrice = currentPrice;
            
            % Log the stop-loss
            fprintf('Stop loss triggered at index %d: Sold at %.2f (%.2f%% loss)\n', ...
                    idx, currentPrice, lossPercentage);
                
        elseif strcmp(position, 'short') && (currentPrice > entryPrice * (1 + StopLoss))
            % Stop loss triggered for a short position
            lossPercentage = ((currentPrice - entryPrice) / entryPrice) * 100;
            
            % Buy to cover short (and go long)
            USDT = USDT - BTCshort * currentPrice * (1 + Fee);
            BTCshort = 0;
            newBTC = USDT / currentPrice * (1 - Fee);
            BTC = BTC + newBTC;
            USDT = 0;
            
            TradeCount = TradeCount + 1;
            Trade = [cumVol(idx); currentPrice; 0];  % Record as a buy trade
            TradeList(:, TradeCount) = Trade;
            
            % Update position: we now have a long position
            position = 'long';
            entryPrice = currentPrice;
            
            % Log the stop-loss
            fprintf('Stop loss triggered at index %d: Bought at %.2f (%.2f%% loss)\n', ...
                    idx, currentPrice, lossPercentage);
        end
        
        % Now check if we are at an event (peak or trough)
        if nextEventIdx <= length(sortedEvents) && idx == sortedEvents(nextEventIdx)
            % We are at an event
            currentEventType = sortedTypes{nextEventIdx};
            
            % Determine next event type (if there is one)
            %nextEventType = '';
            %if nextEventIdx < length(sortedEvents)
            %    nextEventType = sortedTypes{nextEventIdx + 1};
            %end
            
            % Shift the actual trade point further in volume by init_xDistance
            volTrans = cumVol(idx) + rightScope;
            tradeIdx = idx;
            while tradeIdx < length(cumVol) && (cumVol(tradeIdx) < volTrans)
                tradeIdx = tradeIdx + 1;
            end
            
            % Only execute if we haven't run out of data
            if tradeIdx <= length(prices)
                priceTrans = prices(tradeIdx);
                
                % Execute trade based on event type and current position
                if strcmp(currentEventType, 'trough') && ~strcmp(position, 'long')
                    % At a trough: close any short position and buy (go long)
                    USDT = USDT - BTCshort * priceTrans * (1 + Fee); 
                    BTCshort = 0;
                    newBTC = USDT / priceTrans * (1 - Fee);
                    BTC = BTC + newBTC;
                    USDT = 0;
                    
                    TradeCount = TradeCount + 1;
                    Trade = [cumVol(tradeIdx); priceTrans; 0];   % Buy
                    TradeList(:, TradeCount) = Trade;
                    
                    % Update position info
                    position = 'long';
                    entryPrice = priceTrans;
                    
                elseif strcmp(currentEventType, 'peak') && ~strcmp(position, 'short')
                    % At a peak: sell (and short)
                    USDT = USDT + BTC * priceTrans * (1 - Fee);
                    BTCshort = BTCshort + BTC;
                    USDT = USDT + BTC * priceTrans * (1 - Fee);
                    BTC = 0;
                    
                    TradeCount = TradeCount + 1;
                    Trade = [cumVol(tradeIdx); 0; priceTrans];   % Sell
                    TradeList(:, TradeCount) = Trade;
                    
                    % Update position info
                    position = 'short';
                    entryPrice = priceTrans;
                end
            end
            
            % Move to the next event
            nextEventIdx = nextEventIdx + 1;
        end
    end

    % Close out all positions at the final price
    if isempty(prices)
       error('orig_prices is empty. Not enough data for final close.');
    end
    finalPrice = prices(end);

    % Sell any BTC, pay back any short
    USDT = USDT + BTC * finalPrice * (1 - Fee) - BTCshort * finalPrice * (1 + Fee);
    BTC = 0;
    BTCshort = 0;

    finalHolding = USDT;
    
    % Trim unused preallocated columns; if no trades occurred, return an empty 3×0 matrix
    if TradeCount == 0
        TradeList = zeros(3,0);
    else
        TradeList = TradeList(:, 1:TradeCount);
    end
end
