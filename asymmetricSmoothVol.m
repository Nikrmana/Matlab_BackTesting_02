%% Subfunctions for Smoothing 

function [smoothed, pointCounts] = asymmetricSmoothVol(prices, cumVol, leftScope, rightScope)
% asymmetricSmoothVol - Performs volume-based asymmetric smoothing and counts
% the number of points used for each average.
%
% Inputs:
%   data     : Price data vector
%   cumVol   : Cumulative volume vector
%   leftBTC  : Left-side volume threshold
%   rightBTC : Right-side volume threshold
%
% Outputs:
%   smoothed    : Smoothed price vector
%   pointCounts : Number of points used for each smoothed value

    N = length(prices);
    smoothed = zeros(N,1);
    pointCounts = zeros(N,1);
    for ii = 1:N
        idx = [];
        % Collect indices on the left within threshold
        for j = 1:ii
            if (cumVol(ii) - cumVol(j)) <= leftScope
                idx(end+1) = j; %#ok<AGROW>
            end
        end
        % Collect indices on the right within threshold
        for k = ii:N
            if (cumVol(k) - cumVol(ii)) <= rightScope
                idx(end+1) = k; %#ok<AGROW>
            end
        end
        idx = unique(idx);
        smoothed(ii) = mean(prices(idx));
        pointCounts(ii) = numel(idx);  % Count of points used in smoothing, between leftBTC and rightBTC
    end
end




