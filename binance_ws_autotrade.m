%% Binance Auto‑Trader via WebSocketClient — MATLAB

% === CONFIG ===
apiKey    = "pue4G0kkYusmjORtgA9aKG8XUbu8yzw2eo5oigmJXAqb44W4NErL5YUyCwhi9c7K";
apiSecret = "1uUdOWQFNehWlQQUWUbqcEJ1jfCitaFkdXO6aSuYG5BrwQHiLvg2GxCpwFYV9G0d";
symbol    = "BTCUSDT";
quantity  = 0.002;
interval  = 30;

latestPrice = [];
prevPrice   = [];

% Open WebSocketClient
uri = matlab.net.URI("wss://stream.binance.testnet.com:9443/ws/" + lower(symbol) + "@trade");
ws  = matlab.net.http.WebSocketClient(uri);
ws.open();

fprintf("Listening on WebSocket for %s trades...\n", symbol);

while ws.isOpen()
    msg = ws.readMessage();              % blocking read
    data = jsondecode(char(msg.Data));   
    latestPrice = str2double(data.p);
    fprintf("[%s] Price: %.2f\n", string(datetime('now','Format','HH:mm:ss')), latestPrice);

    pause(interval)
    if ~isempty(prevPrice)
        if latestPrice > prevPrice
            placeOrder("SELL", quantity);
        else
            placeOrder("BUY",  quantity);
        end
    end
    prevPrice = latestPrice;
end

ws.close();

%% Place Market Order (same as before)
function placeOrder(side, qty)
    baseURL  = "https://testnet.binance.vision";
    srvTime  = webread(baseURL + "/api/v3/time");
    ts       = num2str(srvTime.serverTime, '%.0f');
    params   = sprintf("symbol=BTCUSDT&side=%s&type=MARKET&quantity=%.6f&timestamp=%s", side, qty, ts);
    sig      = HMACSHA256("YOUR_API_SECRET", params);
    fullUrl  = sprintf("%s/api/v3/order?%s&signature=%s", baseURL, params, sig);

    import matlab.net.http.*
    req  = RequestMessage('POST', HeaderField("X-MBX-APIKEY","YOUR_API_KEY"));
    resp = req.send(URI(fullUrl));
    data = resp.Body.Data;

    if resp.StatusCode == StatusCode.OK
        fprintf("→ %s order placed. OrderId=%d\n", side, data.orderId);
    else
        fprintf("ERROR %d: %s\n", data.code, data.msg);
    end
end

%% HMAC Helper
function sig = HMACSHA256(secret, msg)
    import javax.crypto.Mac; import javax.crypto.spec.SecretKeySpec
    key = uint8(char(secret)); text = uint8(char(msg));
    mac = Mac.getInstance('HmacSHA256');
    mac.init(SecretKeySpec(key,'HmacSHA256'));
    sig = lower(dec2hex(typecast(mac.doFinal(text),'uint8'))');
end
