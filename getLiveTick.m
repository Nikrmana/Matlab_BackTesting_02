function tick = getLiveTick(symbol, interval)
    % getLiveTick - Waits until the current interval is finished and then fetches the latest completed candle.
    
    % Get current UTC time.
    nowTime = datetime('now','TimeZone','UTC');
    
    % Calculate the next interval boundary based on the specified interval.
    switch interval
        case '1m'
            nextBoundary = dateshift(nowTime, 'start', 'minute', 'next');
            intervalDuration = 60 * 1000;  % 1 minute in ms.
        case '5m'
            minuteVal = minute(nowTime);
            remainder = mod(minuteVal, 5);
            if remainder == 0 && second(nowTime) < 1
                nextBoundary = dateshift(nowTime, 'start', 'minute');
            else
                nextBoundary = dateshift(nowTime, 'start', 'minute') + minutes(5 - remainder);
            end
            intervalDuration = 5 * 60 * 1000;
        otherwise
            error('Interval %s not implemented in getLiveTick', interval);
    end
    
    % Wait until the next boundary.
    waitTime = seconds(nextBoundary - nowTime);
    fprintf('Waiting %.2f seconds for next %s candle to complete...\n', waitTime, interval);
    pause(waitTime);
    
    % Compute the open time of the finished candle.
    finishedCandleOpenTime = posixtime(nextBoundary - milliseconds(intervalDuration)) * 1000;
    % fprintf('Requesting candle with open time: %d\n', floor(finishedCandleOpenTime));
    
    % Construct the API call.
    url = 'https://api.binance.com/api/v3/klines';
    options = weboptions('Timeout', 100);
    params = {'symbol', symbol, 'interval', interval, 'startTime', num2str(floor(finishedCandleOpenTime)), 'limit', '1'};
    
    % Fetch the data.
    data = webread(url, params{:}, options);
    % disp('Raw API response:');
    % disp(data);
    
    if isempty(data)
        error('No data returned from Binance for the finished candle.');
    end
    

    % Parse the returned candlestick.
    row = data{1};
    hi = str2double(row{3});
    lo = str2double(row{4});
    tick.price = (hi + lo) / 2;
    tick.volume = str2double(row{6});
    
    % Determine the raw open time, handling both numeric and string cases.
    if isnumeric(row{1})
        rawOpenTime = row{1};
    else
        rawOpenTime = str2double(row{1});
    end

    if isnan(rawOpenTime) || rawOpenTime < 1 || rawOpenTime > 1e13
        warning('Received an invalid open time (%f). Using current time instead.', rawOpenTime);
        tick.time = datetime('now','TimeZone','UTC');
    else
        try
            tick.time = datetime(rawOpenTime/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        catch ME
            warning('Error converting rawOpenTime to datetime: %s. Using current time.', ME.message);
            tick.time = datetime('now','TimeZone','UTC');
        end
    end
    
    fprintf('Received tick for interval ending at %s: Price=%.2f, Volume=%.2f\n', ...
            datestr(tick.time), tick.price, tick.volume);
 
end
