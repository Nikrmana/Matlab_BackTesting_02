function negHolding = objectiveFunction(params, prices, volumes, times, Fee, StopLoss, ExtrDetType, SmoothPar)
% objectiveFunction.m
% objectiveFunction - Returns negative final USDT holding.
%   params: [init_s_left, init_xDistance, init_p_left]
%   prices, volumes, times: Data vectors
%
% Since we wish to maximize the final holding, we minimize its negative.

    % Extract parameters
    init_s_left   = params(1);
    init_xDistance = params(2);
    detect_speed   = params(3);
    
    % Run the trading simulation with these parameters.
    finalHolding = simulateTrading(prices, volumes, times, init_s_left, init_xDistance, detect_speed, Fee, StopLoss, ExtrDetType, SmoothPar);
    
    % Return negative final holding.
    negHolding = -finalHolding;
end
