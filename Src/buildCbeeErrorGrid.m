function [value_grid, overlap_mask, grid_meta] = buildCbeeErrorGrid(measurements, gridParams)
% BUILDCBEEERRORGRID 基于CBEE的贡献栅格构建与一致性误差图
%
% 本函数在已获得"全局坐标系下"的多子图点云集合基础上，构建二维XY栅格，
% 对每个格子评估"跨子图局部一致性误差"，形成一幅空间分布图。
%
% 输入:
%   measurements : {M}，每个元素为一幅子图的点集合 [N_m×3]，应为全局坐标
%                  （来自 loadAllSubmaps(...,'TransformToGlobal',true)）
%   gridParams   : 结构体，主要字段如下（含默认值建议）
%       .cell_size_xy       (double, 必需)  栅格边长，单位米；建议 0.5（0.5~2.0）
%       .neighborhood_size  (odd int,=3)    邻域尺寸k（k×k），奇数；建议 3/5
%       .nbr_averages       (int,=10)       单格重复采样次数（蒙特卡洛平均）
%       .min_points_per_cell(int,=3)        单格最小点数（不足视为无效，返回NaN）
%       .use_parallel       (bool,=false)   是否在格级并行（parfor）
%       .random_seed        (double|[],=[]) 复现实验的随机种子（[]表示不固定）
%
% 输出:
%   value_grid  : [H×W double]，单格多图一致性误差；无效/无重叠返回NaN
%   overlap_mask: [H×W logical]，标记 value_grid 有效（~isnan）的位置
%   grid_meta   : struct，{x_min,y_min,grid_w,grid_h,cell_size_xy}
%
% 原理：
%   在每个格子(i,j)，对各子图当前格内点进行随机采样；对每个被采样的点，
%   计算其在其它子图"邻域点集"上的最近邻距离；取"最坏最近邻"（max over submaps），
%   并在重复采样中取平均，得到该格的一致性误差值。
%
% 基本用法示例：
%   % 1. 加载子地图数据（全局坐标系）
%   measurements = loadAllSubmaps('Data/CBEE/smallTest/submaps', ...
%       'TransformToGlobal', true, 'Verbose', false);
%   
%   % 2. 设置CBEE参数
%   gridParams = struct(...
%       'cell_size_xy', 0.5, ...           % 栅格边长0.5米
%       'neighborhood_size', 3, ...        % 3x3邻域
%       'nbr_averages', 10, ...            % 蒙特卡洛采样10次
%       'min_points_per_cell', 3, ...      % 最小点数阈值
%       'use_parallel', false, ...         % 是否并行处理
%       'random_seed', 42);                % 随机种子（可复现）
%   
%   % 3. 构建CBEE一致性误差栅格
%   [value_grid, overlap_mask, grid_meta] = buildCbeeErrorGrid(measurements, gridParams);
%   
%   % 4. 可视化结果
%   figure; 
%   display_grid = value_grid; display_grid(~overlap_mask) = NaN;
%   imagesc([grid_meta.x_min, grid_meta.x_min + grid_meta.grid_w * grid_meta.cell_size_xy], ...
%           [grid_meta.y_min, grid_meta.y_min + grid_meta.grid_h * grid_meta.cell_size_xy], ...
%           display_grid);
%   axis image; colormap(jet); colorbar; title('CBEE一致性误差图');
%   xlabel('X (m)'); ylabel('Y (m)'); set(gca, 'YDir', 'normal');

% 版权信息
% Author: CBEE Project Team
% Date: 2025-09-21
% Version: 1.0

%% 1. 输入参数验证和默认值设置
if nargin < 2
    error('buildCbeeErrorGrid:NotEnoughInputs', '需要至少2个输入参数：measurements 和 gridParams');
end

% 验证 measurements
if ~iscell(measurements)
    error('buildCbeeErrorGrid:InvalidMeasurements', 'measurements 必须是 cell 数组');
end

if isempty(measurements)
    warning('buildCbeeErrorGrid:EmptyMeasurements', '输入的 measurements 为空');
    value_grid = [];
    overlap_mask = [];
    grid_meta = struct();
    return;
end

% 验证并设置 gridParams 默认值
if ~isstruct(gridParams)
    error('buildCbeeErrorGrid:InvalidGridParams', 'gridParams 必须是结构体');
end

% 必需参数
if ~isfield(gridParams, 'cell_size_xy') || isempty(gridParams.cell_size_xy)
    error('buildCbeeErrorGrid:MissingCellSize', 'gridParams 必须包含 cell_size_xy 字段');
end
cell_size_xy = gridParams.cell_size_xy;
if ~isnumeric(cell_size_xy) || cell_size_xy <= 0
    error('buildCbeeErrorGrid:InvalidCellSize', 'cell_size_xy 必须是正数');
end

% 可选参数及默认值
neighborhood_size = getFieldWithDefault(gridParams, 'neighborhood_size', 3);
nbr_averages = getFieldWithDefault(gridParams, 'nbr_averages', 10);
min_points_per_cell = getFieldWithDefault(gridParams, 'min_points_per_cell', 3);
use_parallel = getFieldWithDefault(gridParams, 'use_parallel', false);
random_seed = getFieldWithDefault(gridParams, 'random_seed', []);

% 参数合理性检查
if mod(neighborhood_size, 2) == 0 || neighborhood_size < 1
    error('buildCbeeErrorGrid:InvalidNeighborhoodSize', 'neighborhood_size 必须是正奇数');
end

if nbr_averages < 1 || ~isfinite(nbr_averages)
    error('buildCbeeErrorGrid:InvalidNbrAverages', 'nbr_averages 必须是正整数');
end

% 设置随机种子以实现结果复现
if ~isempty(random_seed)
    rng(random_seed);
    if use_parallel
        % 为并行worker设置独立的随机流
        % 这里我们使用简化方案，在主线程设置种子
        fprintf('注意：并行模式下，随机种子复现可能不完全一致\n');
    end
end

%% 2. 数据预处理：过滤空子图和提取有效点
fprintf('开始CBEE一致性误差栅格构建...\n');
fprintf('参数设置：cell_size=%.2f, neighborhood=%dx%d, averages=%d\n', ...
    cell_size_xy, neighborhood_size, neighborhood_size, nbr_averages);

% 过滤空子图
valid_measurements = {};
total_points = 0;
for i = 1:length(measurements)
    if ~isempty(measurements{i}) && size(measurements{i}, 2) >= 3
        valid_measurements{end+1} = measurements{i}; %#ok<AGROW>
        total_points = total_points + size(measurements{i}, 1);
    end
end

if isempty(valid_measurements)
    warning('buildCbeeErrorGrid:NoValidMeasurements', '没有有效的测量数据');
    value_grid = [];
    overlap_mask = [];
    grid_meta = struct();
    return;
end

num_submaps = length(valid_measurements);
fprintf('有效子图数量：%d，总点数：%d\n', num_submaps, total_points);

if num_submaps < 2
    warning('buildCbeeErrorGrid:InsufficientSubmaps', '需要至少2个子图才能计算一致性误差');
    value_grid = [];
    overlap_mask = [];
    grid_meta = struct();
    return;
end

%% 3. 栅格域定义
fprintf('计算栅格域定义...\n');

% 统计所有点的XY范围
all_points_xy = [];
for i = 1:num_submaps
    points = valid_measurements{i};
    all_points_xy = [all_points_xy; points(:, 1:2)]; %#ok<AGROW>
end

x_min = min(all_points_xy(:, 1));
x_max = max(all_points_xy(:, 1));
y_min = min(all_points_xy(:, 2));
y_max = max(all_points_xy(:, 2));

% 计算栅格尺寸
grid_w = ceil((x_max - x_min) / cell_size_xy);
grid_h = ceil((y_max - y_min) / cell_size_xy);

% 调整边界以确保所有点都能被包含
x_max = x_min + grid_w * cell_size_xy;
y_max = y_min + grid_h * cell_size_xy;

fprintf('数据范围：X[%.2f, %.2f], Y[%.2f, %.2f]\n', x_min, x_max, y_min, y_max);
fprintf('栅格尺寸：%d×%d = %d 格子\n', grid_w, grid_h, grid_w * grid_h);

% 创建栅格元数据
grid_meta = struct(...
    'x_min', x_min, 'y_min', y_min, ...
    'grid_w', grid_w, 'grid_h', grid_h, ...
    'cell_size_xy', cell_size_xy);

%% 4. 点投格与数据结构构建
fprintf('执行点投格操作...\n');

% 使用cell数组存储每个格子每个子图的点
% bins{linear_idx, submap_idx} 存储线性索引为linear_idx的格子中第submap_idx个子图的点
bins = cell(grid_w * grid_h, num_submaps);

% 对每个子图进行点投格
for m = 1:num_submaps
    points = valid_measurements{m};
    
    % 计算每个点的格子索引
    i_indices = floor((points(:, 1) - x_min) / cell_size_xy) + 1;
    j_indices = floor((points(:, 2) - y_min) / cell_size_xy) + 1;
    
    % 边界处理
    i_indices = max(1, min(grid_w, i_indices));
    j_indices = max(1, min(grid_h, j_indices));
    
    % 转换为线性索引
    linear_indices = i_indices + (j_indices - 1) * grid_w;
    
    % 分配点到对应的格子
    for p = 1:length(linear_indices)
        idx = linear_indices(p);
        if isempty(bins{idx, m})
            bins{idx, m} = points(p, :);
        else
            bins{idx, m} = [bins{idx, m}; points(p, :)];
        end
    end
end

%% 5. 邻域收集函数
half_nbr = floor(neighborhood_size / 2);

% 预计算邻域偏移量
nbr_offsets = [];
for di = -half_nbr:half_nbr
    for dj = -half_nbr:half_nbr
        nbr_offsets = [nbr_offsets; di, dj]; %#ok<AGROW>
    end
end

%% 6. 单格误差计算
fprintf('开始计算单格一致性误差...\n');

% 初始化输出矩阵
value_grid = NaN(grid_h, grid_w);
overlap_mask = false(grid_h, grid_w);

% 创建进度显示
total_cells = grid_w * grid_h;
processed_cells = 0;
progress_interval = max(1, floor(total_cells / 20)); % 5%进度间隔

% 根据是否使用并行来选择循环方式
if use_parallel && total_cells > 100 % 小数据集不值得并行化
    fprintf('使用并行计算模式...\n');
    
    % 为并行计算准备数据
    cell_values = NaN(total_cells, 1);
    
    % 并行计算每个格子的误差值
    parfor linear_idx = 1:(grid_w * grid_h)
        cell_values(linear_idx) = computeSingleCellError(...
            linear_idx, bins, grid_w, grid_h, num_submaps, ...
            nbr_offsets, nbr_averages, min_points_per_cell);
    end
    
    % 将结果重新整理为矩阵形式
    for linear_idx = 1:(grid_w * grid_h)
        [i, j] = ind2sub([grid_w, grid_h], linear_idx);
        j_mat = i; i_mat = j; % 转换坐标系
        
        value_grid(i_mat, j_mat) = cell_values(linear_idx);
        overlap_mask(i_mat, j_mat) = isfinite(cell_values(linear_idx));
    end
    
else
    fprintf('使用串行计算模式...\n');
    
    % 串行计算，包含详细进度报告
    for j = 1:grid_h
        for i = 1:grid_w
            linear_idx = i + (j - 1) * grid_w;
            
            % 计算单格误差
            error_value = computeSingleCellError(...
                linear_idx, bins, grid_w, grid_h, num_submaps, ...
                nbr_offsets, nbr_averages, min_points_per_cell);
            
            value_grid(j, i) = error_value;
            overlap_mask(j, i) = isfinite(error_value);
            
            % 进度报告
            processed_cells = processed_cells + 1;
            if mod(processed_cells, progress_interval) == 0
                progress = processed_cells / total_cells * 100;
                fprintf('进度：%.1f%% (%d/%d 格子)\n', progress, processed_cells, total_cells);
            end
        end
    end
end

%% 7. 结果统计和输出
valid_cells = sum(overlap_mask(:));
total_error = sum(value_grid(overlap_mask));
avg_error = total_error / max(1, valid_cells);

fprintf('CBEE栅格构建完成！\n');
fprintf('有效格子数：%d/%d (%.1f%%)\n', valid_cells, total_cells, valid_cells/total_cells*100);
fprintf('平均一致性误差：%.4f\n', avg_error);

if valid_cells > 0
    fprintf('误差范围：[%.4f, %.4f]\n', min(value_grid(overlap_mask)), max(value_grid(overlap_mask)));
end

end

%% ========== 辅助函数 ==========

function value = getFieldWithDefault(structure, fieldname, defaultValue)
% 获取结构体字段值，如果不存在则返回默认值
if isfield(structure, fieldname) && ~isempty(structure.(fieldname))
    value = structure.(fieldname);
else
    value = defaultValue;
end
end

function error_value = computeSingleCellError(linear_idx, bins, grid_w, grid_h, ...
    num_submaps, nbr_offsets, nbr_averages, min_points_per_cell)
% 计算单个格子的一致性误差值

% 将线性索引转换为2D索引
[i, j] = ind2sub([grid_w, grid_h], linear_idx);

% 收集当前格子中所有子图的点
current_cell_points = cell(num_submaps, 1);
total_points_in_cell = 0;

for m = 1:num_submaps
    if ~isempty(bins{linear_idx, m})
        current_cell_points{m} = bins{linear_idx, m};
        total_points_in_cell = total_points_in_cell + size(bins{linear_idx, m}, 1);
    else
        current_cell_points{m} = [];
    end
end

% 检查是否满足最小点数要求
if total_points_in_cell < min_points_per_cell
    error_value = NaN;
    return;
end

% 收集邻域内所有子图的点
neighbor_points = cell(num_submaps, 1);
for m = 1:num_submaps
    neighbor_points{m} = [];
end

% 遍历邻域
for offset_idx = 1:size(nbr_offsets, 1)
    di = nbr_offsets(offset_idx, 1);
    dj = nbr_offsets(offset_idx, 2);
    
    ni = i + di;
    nj = j + dj;
    
    % 检查邻域索引是否在有效范围内
    if ni >= 1 && ni <= grid_w && nj >= 1 && nj <= grid_h
        nbr_linear_idx = ni + (nj - 1) * grid_w;
        
        % 收集邻域内各子图的点
        for m = 1:num_submaps
            if ~isempty(bins{nbr_linear_idx, m})
                neighbor_points{m} = [neighbor_points{m}; bins{nbr_linear_idx, m}];
            end
        end
    end
end

% 进行随机采样和误差计算
error_samples = [];

for sample_idx = 1:nbr_averages
    max_error_this_sample = 0;
    
    % 对当前格子内有点的每个子图进行采样
    for m = 1:num_submaps
        if ~isempty(current_cell_points{m})
            % 从当前格子的第m个子图中随机采样一个点
            num_points = size(current_cell_points{m}, 1);
            sample_point_idx = randi(num_points);
            sample_point = current_cell_points{m}(sample_point_idx, :);
            
            % 计算此点到其他子图邻域点集的最近邻距离
            min_dist_to_others = inf;
            found_neighbor = false;
            
            for n = 1:num_submaps
                if n ~= m && ~isempty(neighbor_points{n})
                    % 计算最近邻距离
                    neighbor_pts = neighbor_points{n};
                    distances = sqrt(sum((neighbor_pts - sample_point).^2, 2));
                    min_dist = min(distances);
                    
                    if min_dist < min_dist_to_others
                        min_dist_to_others = min_dist;
                    end
                    found_neighbor = true;
                end
            end
            
            % 更新本次采样的最大误差
            if found_neighbor && isfinite(min_dist_to_others)
                max_error_this_sample = max(max_error_this_sample, min_dist_to_others);
            end
        end
    end
    
    % 如果找到了有效的误差值，加入采样结果
    if max_error_this_sample > 0 && isfinite(max_error_this_sample)
        error_samples = [error_samples; max_error_this_sample]; %#ok<AGROW>
    end
end

% 计算平均误差
if isempty(error_samples)
    error_value = NaN; % 无有效重叠区域
else
    error_value = mean(error_samples);
end

end
