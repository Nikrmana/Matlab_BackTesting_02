function barsPerDay = getBarsPerDay(interval)
%GETBARSPERDAY Return number of k‑line bars per 24h for a given Binance interval.
%   barsPerDay = GETBARSPERDAY(interval)
%   Interval must be one of: '1d','12h','8h','6h','4h','2h','1h','30m',...
%   '15m','5m','3m','1m'.

    % Define supported intervals & their durations (days)
    iv = {'1d','12h','8h','6h','4h','2h','1h','30m','15m','5m','3m','1m'}; 
    durDays = [1, 1/2, 1/3, 1/4, 1/6, 1/12, 1/24, 1/48, 1/96, 1/288, 1/480, 1/1440];

    % Lookup
    idx = strcmp(interval, iv);
    if ~any(idx)
        error('Unsupported interval: "%s".', interval)
    end

    % Compute bars per day
    barsPerDay = round(1 / durDays(idx));
end
