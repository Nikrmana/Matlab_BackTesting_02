%% Subfunction for Trough Detection


function troughs = findAsymmetricTroughsVol(data, cumVol, leftBTC, rightBTC)
% findAsymmetricTroughsVol - Detects troughs using volume-based criteria.
%
% Output:
%   troughs : Indices of detected troughs

    troughs = [];
    N = length(data);
    for ii = 1:N
        left_idx = find(cumVol(ii)-cumVol(1:ii)<=leftBTC);
        left_idx = left_idx(left_idx < ii);
        right_idx = find(cumVol(ii+1:end)-cumVol(ii)<=rightBTC) + ii;
        if isempty(left_idx) || isempty(right_idx)
            continue;
        end
        if data(ii) < min(data(left_idx)) && data(ii) < min(data(right_idx))
            troughs(end+1) = ii; %#ok<AGROW>
        end
    end
    troughs = troughs(:);
end