%% Binance Auto‑Trading (Testnet) — MATLAB

%% Configuration
apiKey    = "pue4G0kkYusmjORtgA9aKG8XUbu8yzw2eo5oigmJXAqb44W4NErL5YUyCwhi9c7K";
apiSecret = "1uUdOWQFNehWlQQUWUbqcEJ1jfCitaFkdXO6aSuYG5BrwQHiLvg2GxCpwFYV9G0d";

baseURL   = "https://testnet.binance.vision";
symbol    = "BTCUSDT";
quantity  = 0.002;
interval  = 5;  % seconds

%% TIME SYNC
srvTime    = webread(baseURL + "/api/v3/time");
timeOffset = srvTime.serverTime - posixtime(datetime('now'))*1000;

prevPrice = [];

while true
    try
        % FETCH PRICE
        ticker    = webread(baseURL + "/api/v3/ticker/price", "symbol", symbol);
        currPrice = str2double(ticker.price);
        ts        = datetime('now','Format','HH:mm:ss');

        if ~isempty(prevPrice)
            side = "BUY";
            if currPrice > prevPrice
                side = "SELL";
            end
            placeOrder(side);
        else
            fprintf("[%s] Initial price = %.2f\n", string(ts), currPrice);
        end

        prevPrice = currPrice;
    catch ME
        fprintf("[%s] ERROR: %s\n", string(datetime('now','Format','HH:mm:ss')), ME.message);
    end

    pause(interval);
end

%% ORDER FUNCTION
function placeOrder(side)
    persistent apiKey apiSecret baseURL symbol quantity timeOffset
    if isempty(apiKey)
        % Initialize persistent config
        apiKey    = evalin('base','apiKey');
        apiSecret = evalin('base','apiSecret');
        baseURL   = evalin('base','baseURL');
        symbol    = evalin('base','symbol');
        quantity  = evalin('base','quantity');
        timeOffset= evalin('base','timeOffset');
    end

    % Build timestamp (apply offset)
    ts = num2str(posixtime(datetime('now'))*1000 + timeOffset, '%.0f');

    params  = sprintf("symbol=%s&side=%s&type=MARKET&quantity=%.6f&timestamp=%s", ...
                      symbol, side, quantity, ts);
    sig     = HMACSHA256(apiSecret, params);
    url     = sprintf("%s/api/v3/order?%s&signature=%s", baseURL, params, sig);

    % Send POST via webwrite (no body)
    opts = weboptions("HeaderFields",["X-MBX-APIKEY" apiKey], "MediaType","application/x-www-form-urlencoded");
    resp = webwrite(url, opts);

    if isfield(resp,"orderId")
        fprintf("[%s] → %s order placed. OrderId=%d\n", string(datetime('now','Format','HH:mm:ss')), side, resp.orderId);
    else
        fprintf("[%s] Binance ERROR: %s\n", string(datetime('now','Format','HH:mm:ss')), resp.msg);
    end
end

%% HMAC HELPER
function sig = HMACSHA256(secret, msg)
    import javax.crypto.Mac; import javax.crypto.spec.SecretKeySpec
    key = uint8(char(secret)); text = uint8(char(msg));
    mac = Mac.getInstance('HmacSHA256');
    mac.init(SecretKeySpec(key,'HmacSHA256'));
    raw = mac.doFinal(text);
    sig = lower(dec2hex(typecast(raw,'uint8'))');
end
