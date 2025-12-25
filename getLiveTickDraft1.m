function tick = getLiveTickOld(symbol, interval) %#ok<FCONF>
    %baseURL = "https://testnet.binance.vision/api/v3/klines";
    baseURL = 'https://api.binance.com/api/v3/klines';
    raw = webread(baseURL, "symbol", symbol, "interval", interval, "limit", "1");

    % Unwrap the nested cell
    candle = raw{1};    % now a 12×1 cell array

    % Extract fields (cell contents are strings except timestamps)
    closePrice  = str2double(candle{5});
    volume      = str2double(candle{6});
    closeTimeMS = candle{7};

    tick.price  = closePrice;
    tick.volume = volume;
    tick.time   = datetime(closeTimeMS/1000, 'ConvertFrom', 'posixtime');
    tick.time.TimeZone = 'UTC';
end


