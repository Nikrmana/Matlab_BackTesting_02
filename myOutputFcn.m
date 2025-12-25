%% Output function for surrogateopt
function stop = myOutputFcn(x, optimValues, state, varargin)
    stop = false; % Continue optimization
    switch state
        case 'init'
            % disp('Starting surrogateopt optimization...');
        case 'iter'
            if isfield(optimValues, 'iteration')
                itNum = optimValues.iteration;
            else
                itNum = NaN;
            end
            if isfield(optimValues, 'bestfval')
                bestVal = optimValues.bestfval;
            elseif isfield(optimValues, 'fval')
                bestVal = optimValues.fval;
            else
                bestVal = NaN;
            end
            if isfield(optimValues, 'bestx')
                bestX = optimValues.bestx;
            else
                bestX = x;
            end
            bestXStr = sprintf('%g ', bestX);
            bestXStr = strtrim(bestXStr);
            % fprintf('Iter %d: bestfval=%g, bestx=[%s]\n', itNum, bestVal, bestXStr);
        case 'done'
            % disp('Finished surrogateopt optimization.');
    end
end