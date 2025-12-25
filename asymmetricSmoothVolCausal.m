%% Subfunctions for Causal Smoothing 

function [smoothed, pointCounts] = asymmetricSmoothVolCausal(prices, cumVol, leftScope, rightScope)
% asymmetricSmoothVolCausal - Causal version that only uses historical data
%
% This version only uses data points up to the current point (no future data)
% For points near the end where rightScope cannot be satisfied, uses only available data
%
% Inputs:
%   prices    : Price data vector
%   cumVol    : Cumulative volume vector
%   leftScope : Left-side volume threshold
%   rightScope: Right-side volume threshold
%
% Outputs:
%   smoothed    : Smoothed price vector (causal - no future data)
%   pointCounts : Number of points used for each smoothed value

    N = length(prices);
    smoothed = zeros(N,1);
    pointCounts = zeros(N,1);
    
    for ii = 1:N
        idx = [];
        % Collect indices on the left within threshold (historical data only)
        for j = 1:ii
            if (cumVol(ii) - cumVol(j)) <= leftScope
                idx(end+1) = j; %#ok<AGROW>
            end
        end
        
        % Collect indices on the right, but ONLY up to current point (causal)
        % For points near the end, we may not have enough future data
        for k = ii:N
            if (cumVol(k) - cumVol(ii)) <= rightScope
                idx(end+1) = k; %#ok<AGROW>
            end
        end
        
        idx = unique(idx);
        if ~isempty(idx)
            smoothed(ii) = mean(prices(idx));
            pointCounts(ii) = numel(idx);
        else
            smoothed(ii) = prices(ii);  % Fallback to raw price if no neighbors
            pointCounts(ii) = 1;
        end
    end
end

