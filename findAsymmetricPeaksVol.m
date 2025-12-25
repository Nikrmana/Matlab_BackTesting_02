%% Subfunction for Peak Detection


function peaks = findAsymmetricPeaksVol(data, cumVol, leftBTC, rightBTC)
% findAsymmetricPeaksVol - Detects peaks using volume-based criteria.
%
% Output:
%   peaks : Indices of detected peaks

    peaks = [];
    N = length(data);
    for ii = 1:N
        left_idx = find(cumVol(ii)-cumVol(1:ii)<=leftBTC);
        left_idx = left_idx(left_idx < ii);
        right_idx = find(cumVol(ii+1:end)-cumVol(ii)<=rightBTC) + ii;
        if isempty(left_idx) || isempty(right_idx)
            continue;
        end
        if data(ii) > max(data(left_idx)) && data(ii) > max(data(right_idx))
            peaks(end+1) = ii; %#ok<AGROW>
        end
    end
    peaks = peaks(:);
end
