%% Subfunction for Causal Trough Detection

function troughs = findAsymmetricTroughsVolCausal(data, cumVol, leftBTC, rightBTC, confirmedOnly)
% findAsymmetricTroughsVolCausal - Detects troughs using only historical data
%
% Inputs:
%   data         : Signal data vector
%   cumVol       : Cumulative volume vector
%   leftBTC      : Left-side volume threshold
%   rightBTC     : Right-side volume threshold
%   confirmedOnly: if true, only returns troughs that have enough future data to confirm
%
% Output:
%   troughs : Indices of detected troughs

    if nargin < 5
        confirmedOnly = false;
    end
    
    troughs = [];
    N = length(data);
    
    for ii = 1:N
        % Collect left (historical) indices
        left_idx = find(cumVol(ii)-cumVol(1:ii)<=leftBTC);
        left_idx = left_idx(left_idx < ii);
        
        if isempty(left_idx)
            continue;
        end
        
        % Collect right indices (causal - only up to current point)
        right_idx = [];
        for k = (ii+1):N
            if (cumVol(k) - cumVol(ii)) <= rightBTC
                right_idx(end+1) = k; %#ok<AGROW>
            else
                break;
            end
        end
        
        if confirmedOnly && isempty(right_idx)
            continue;
        end
        
        if isempty(right_idx)
            continue;
        end
        
        % Check if current point is a trough
        if data(ii) < min(data(left_idx)) && data(ii) < min(data(right_idx))
            troughs(end+1) = ii; %#ok<AGROW>
        end
    end
    
    troughs = troughs(:);
end

