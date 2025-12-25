%% Subfunction for Causal Peak Detection

function peaks = findAsymmetricPeaksVolCausal(data, cumVol, leftBTC, rightBTC, confirmedOnly)
% findAsymmetricPeaksVolCausal - Detects peaks using only historical data
%
% Inputs:
%   data         : Signal data vector
%   cumVol       : Cumulative volume vector
%   leftBTC      : Left-side volume threshold
%   rightBTC     : Right-side volume threshold
%   confirmedOnly: if true, only returns peaks that have enough future data to confirm
%                  (i.e., peak at index ii is only returned if ii + rightScope volume has passed)
%
% Output:
%   peaks : Indices of detected peaks

    if nargin < 5
        confirmedOnly = false;
    end
    
    peaks = [];
    N = length(data);
    
    for ii = 1:N
        % Collect left (historical) indices
        left_idx = find(cumVol(ii)-cumVol(1:ii)<=leftBTC);
        left_idx = left_idx(left_idx < ii);
        
        if isempty(left_idx)
            continue;
        end
        
        % Collect right indices, but only up to current point (causal)
        right_idx = [];
        for k = (ii+1):N
            if (cumVol(k) - cumVol(ii)) <= rightBTC
                right_idx(end+1) = k; %#ok<AGROW>
            else
                break;  % Beyond rightScope, stop looking
            end
        end
        
        % If confirmedOnly is true, we need enough right-side data
        if confirmedOnly && isempty(right_idx)
            continue;  % Not enough future data to confirm this peak
        end
        
        if isempty(right_idx)
            continue;
        end
        
        % Check if current point is a peak relative to both sides
        if data(ii) > max(data(left_idx)) && data(ii) > max(data(right_idx))
            peaks(end+1) = ii; %#ok<AGROW>
        end
    end
    
    peaks = peaks(:);
end

