%% setupParallelPool - 统一并行池管理
% 输入:
%   useParallelRequested (logical): 期望是否使用并行
%   numWorkers (numeric|[]): 期望worker数量，空表示默认
%   randomSeed (numeric|[]): 随机种子，空表示不设置
%   verbose (logical): 是否输出信息
% 输出:
%   useParallelEffective (logical): 实际是否启用并行（失败则为false）
%   poolInfo (struct): 并行池信息（size 等），串行时为空结构
function [useParallelEffective, poolInfo] = setupParallelPool(useParallelRequested, numWorkers, randomSeed, verbose)
    useParallelEffective = false;
    poolInfo = struct();

    if ~useParallelRequested
        return;
    end

    try
        if isempty(gcp('nocreate'))
            if isempty(numWorkers)
                parpool('local');
            else
                parpool('local', numWorkers);
            end
        end
        if ~isempty(randomSeed)
            rng(randomSeed);
        end
        p = gcp('nocreate');
        useParallelEffective = ~isempty(p);
        if useParallelEffective
            poolInfo.size = p.NumWorkers;
            if verbose
                fprintf('并行池就绪，workers=%d\n', p.NumWorkers);
            end
        end
    catch ME
        if verbose
            warning('%s', sprintf('并行池初始化失败，将回退为串行：%s', ME.message));
        end
        useParallelEffective = false;
        poolInfo = struct();
    end
end
