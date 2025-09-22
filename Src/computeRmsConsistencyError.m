function result = computeRmsConsistencyError(value_grid, overlap_mask)
% COMPUTERMSCONSISTENCYERROR 计算均方根一致性误差及完整统计信息
%
% 基于CBEE一致性误差栅格计算全局RMS一致性误差，作为轨迹优化效果的
% 单一量化指标。数值越小表示重叠区域的跨子图一致性越好。
%
% 语法:
%   result = computeRmsConsistencyError(value_grid, overlap_mask)
%
% 输入参数:
%   value_grid   [H×W double] - 来自buildCbeeErrorGrid的单格多图一致性误差
%                               可能包含NaN值表示无效格子
%   overlap_mask [H×W logical] - 有效格掩膜，true表示有重叠覆盖且点数足够的格子
%
% 输出参数:
%   result       [struct] - 包含完整统计信息的结构体，字段包括:
%     .rms_value     - RMS一致性误差值 (若无有效格则为NaN)
%     .grid_stats    - 格子统计信息
%       .total_cells     - 总格子数
%       .valid_cells     - 有效格子数
%       .valid_ratio     - 有效格子比例 (0-1)
%       .finite_cells    - 有限误差值格子数
%       .finite_ratio    - 有限格子比例 (相对于有效格子)
%     .error_stats   - 误差值统计信息
%       .min         - 最小误差值
%       .max         - 最大误差值
%       .mean        - 平均误差值
%       .std         - 误差值标准差
%       .median      - 误差值中位数
%       .p25         - 25%分位数
%       .p75         - 75%分位数
%     .validity      - 有效性指标
%       .is_valid    - 是否成功计算RMS
%       .has_overlap - 是否有重叠区域
%       .all_finite  - 是否所有有效值都是有限的
%     .metadata      - 计算元信息
%       .computation_time - 计算耗时(秒)
%       .timestamp        - 计算时间戳
%
% 数学定义:
%   设有效格集合为 Ω = {(i,j) | overlap_mask(i,j) == true}
%   RMS = sqrt((1/|Ω|) * ∑_{(i,j)∈Ω} value_grid(i,j)²)
%
% 示例:
%   % 假设已有value_grid和overlap_mask
%   result = computeRmsConsistencyError(value_grid, overlap_mask);
%   fprintf('RMS一致性误差: %.4f\n', result.rms_value);
%   fprintf('有效格子比例: %.1f%%\n', result.grid_stats.valid_ratio * 100);
%   disp(result.error_stats);  % 显示误差统计
%
% 另请参阅: buildCbeeErrorGrid
%
% 作者: CBEE评估工具包
% 日期: 2025-09-22

    %% 计算开始时间
    start_time = tic;
    
    %% 输入验证
    if nargin < 2
        error('computeRmsConsistencyError:NotEnoughInputs', ...
              '需要两个输入参数：value_grid 和 overlap_mask');
    end
    
    % 检查输入类型
    if ~isnumeric(value_grid)
        error('computeRmsConsistencyError:InvalidInput', ...
              'value_grid 必须是数值矩阵');
    end
    
    if ~islogical(overlap_mask) && ~isempty(overlap_mask)
        error('computeRmsConsistencyError:InvalidInput', ...
              'overlap_mask 必须是逻辑矩阵');
    end
    
    % 检查维度一致性
    try
        if ~isequal(size(value_grid), size(overlap_mask))
            error('computeRmsConsistencyError:DimensionMismatch', ...
                  'value_grid 和 overlap_mask 的维度必须相同\nvalue_grid: [%d×%d], overlap_mask: [%d×%d]', ...
                  size(value_grid,1), size(value_grid,2), ...
                  size(overlap_mask,1), size(overlap_mask,2));
        end
    catch ME
        if contains(ME.identifier, 'sizeDimensionsMustMatch') || contains(ME.identifier, 'DimensionMismatch')
            error('computeRmsConsistencyError:DimensionMismatch', ...
                  'value_grid 和 overlap_mask 的维度必须相同');
        else
            rethrow(ME);
        end
    end
    
    %% 数据预处理和有效性检查
    
    % 基本网格统计
    total_cells = numel(value_grid);
    num_valid_cells = sum(overlap_mask(:));
    
    % 初始化结果结构体
    result = struct();
    
    % 网格统计信息
    result.grid_stats = struct();
    result.grid_stats.total_cells = total_cells;
    result.grid_stats.valid_cells = num_valid_cells;
    result.grid_stats.valid_ratio = num_valid_cells / total_cells;
    
    % 有效性指标
    result.validity = struct();
    result.validity.has_overlap = num_valid_cells > 0;
    result.validity.is_valid = false;  % 默认为false，后面会更新
    result.validity.all_finite = false;  % 默认为false，后面会更新
    
    % 检查是否有有效格子
    if num_valid_cells == 0
        warning('computeRmsConsistencyError:NoValidCells', ...
                '没有有效的重叠区域格子，无法计算RMS一致性误差');
        result.rms_value = NaN;
        result.grid_stats.finite_cells = 0;
        result.grid_stats.finite_ratio = 0;
        result.error_stats = createEmptyErrorStats();
        result.metadata = createMetadata(start_time);
        return;
    end
    
    % 提取有效格子的误差值
    valid_errors = value_grid(overlap_mask);
    
    % 检查有效误差值中是否包含异常值
    finite_mask = isfinite(valid_errors);
    num_finite = sum(finite_mask);
    
    % 更新格子统计
    result.grid_stats.finite_cells = num_finite;
    result.grid_stats.finite_ratio = num_finite / num_valid_cells;
    result.validity.all_finite = (num_finite == num_valid_cells);
    
    if num_finite == 0
        warning('computeRmsConsistencyError:NoFiniteValues', ...
                '所有有效格子的误差值都是NaN或Inf，无法计算RMS一致性误差');
        result.rms_value = NaN;
        result.error_stats = createEmptyErrorStats();
        result.metadata = createMetadata(start_time);
        return;
    elseif num_finite < num_valid_cells
        warning('computeRmsConsistencyError:SomeInfiniteValues', ...
                '检测到%d个非有限误差值，将被忽略（共%d个有效格子）', ...
                num_valid_cells - num_finite, num_valid_cells);
    end
    
    % 过滤掉非有限值
    finite_errors = valid_errors(finite_mask);
    
    %% RMS一致性误差计算
    
    % 数学定义: RMS = sqrt((1/N) * ∑(error²))
    % 其中N是有限有效误差值的数量
    squared_errors = finite_errors .^ 2;
    mean_squared_error = mean(squared_errors);
    rms_value = sqrt(mean_squared_error);
    
    % 数值有效性检查
    if ~isfinite(rms_value) || rms_value < 0
        warning('computeRmsConsistencyError:InvalidResult', ...
                '计算得到的RMS值异常: %.6f', rms_value);
        rms_value = NaN;
        result.validity.is_valid = false;
    else
        result.validity.is_valid = true;
    end
    
    %% 构建完整结果结构体
    
    % RMS值
    result.rms_value = rms_value;
    
    % 误差统计信息
    result.error_stats = calculateErrorStats(finite_errors);
    
    % 元信息
    result.metadata = createMetadata(start_time);
    
    %% 可选的详细输出显示
    if nargout == 0  % 没有输出参数时显示详细信息
        displayDetailedResults(result);
    end

end

%% 辅助函数

function error_stats = createEmptyErrorStats()
    % 创建空的误差统计结构体
    error_stats = struct();
    error_stats.min = NaN;
    error_stats.max = NaN;
    error_stats.mean = NaN;
    error_stats.std = NaN;
    error_stats.median = NaN;
    error_stats.p25 = NaN;
    error_stats.p75 = NaN;
end

function error_stats = calculateErrorStats(finite_errors)
    % 计算误差值的详细统计信息
    error_stats = struct();
    
    if isempty(finite_errors)
        error_stats = createEmptyErrorStats();
        return;
    end
    
    % 基本统计
    error_stats.min = min(finite_errors);
    error_stats.max = max(finite_errors);
    error_stats.mean = mean(finite_errors);
    error_stats.std = std(finite_errors);
    error_stats.median = median(finite_errors);
    
    % 分位数
    try
        percentiles = prctile(finite_errors, [25, 75]);
        error_stats.p25 = percentiles(1);
        error_stats.p75 = percentiles(2);
    catch
        % 如果没有Statistics Toolbox，使用近似方法
        sorted_errors = sort(finite_errors);
        n = length(sorted_errors);
        error_stats.p25 = sorted_errors(max(1, round(0.25 * n)));
        error_stats.p75 = sorted_errors(max(1, round(0.75 * n)));
    end
end

function metadata = createMetadata(start_time)
    % 创建计算元信息
    metadata = struct();
    metadata.computation_time = toc(start_time);
    metadata.timestamp = datetime('now');
end

function displayDetailedResults(result)
    % 显示详细的计算结果
    fprintf('\n=== RMS一致性误差计算结果 ===\n');
    
    % 格子统计
    fprintf('格子统计:\n');
    fprintf('  总格子数: %d\n', result.grid_stats.total_cells);
    fprintf('  有效格子数: %d (%.1f%%)\n', result.grid_stats.valid_cells, ...
            result.grid_stats.valid_ratio * 100);
    fprintf('  有限误差值格子数: %d (%.1f%%)\n', result.grid_stats.finite_cells, ...
            result.grid_stats.finite_ratio * 100);
    
    % 有效性指标
    fprintf('有效性:\n');
    if result.validity.has_overlap
        fprintf('  有重叠区域: Yes\n');
    else
        fprintf('  有重叠区域: No\n');
    end
    if result.validity.is_valid
        fprintf('  计算成功: Yes\n');
    else
        fprintf('  计算成功: No\n');
    end
    if result.validity.all_finite
        fprintf('  所有值都有限: Yes\n');
    else
        fprintf('  所有值都有限: No\n');
    end
    
    % 误差统计
    if result.validity.is_valid
        fprintf('误差值统计:\n');
        fprintf('  最小值: %.4f\n', result.error_stats.min);
        fprintf('  最大值: %.4f\n', result.error_stats.max);
        fprintf('  平均值: %.4f\n', result.error_stats.mean);
        fprintf('  中位数: %.4f\n', result.error_stats.median);
        fprintf('  标准差: %.4f\n', result.error_stats.std);
        fprintf('  25%%分位数: %.4f\n', result.error_stats.p25);
        fprintf('  75%%分位数: %.4f\n', result.error_stats.p75);
        fprintf('RMS一致性误差: %.4f\n', result.rms_value);
    else
        fprintf('无法计算有效的误差统计\n');
    end
    
    % 元信息
    fprintf('计算耗时: %.4f 秒\n', result.metadata.computation_time);
    fprintf('计算时间: %s\n', char(result.metadata.timestamp));
    fprintf('========================\n\n');
end
