function [value_grid, overlap_mask, grid_meta, map_grid] = buildCbeeErrorGrid_sparse(measurements, gridParams)
% BUILDCBEEERRORGRID_SPARSE  基于稀疏存储的 CBEE 一致性误差栅格构建
%
% 说明:
%   本函数是原始 buildCbeeErrorGrid 的稀疏内存版本。它仅为“实际包含点的格子”
%   存储数据，避免创建 (grid_w*grid_h * num_submaps) 的稠密 cell 矩阵，从而显著降低
%   在子图数量较多 & 范围较大 & cell_size_xy 较小时的内存峰值。
%
% 输入:
%   measurements : {M} cell, 每个元素为一幅子图点云 [N_i x 3] (全局坐标)
%   gridParams   : struct，与旧版兼容的参数字段:
%       .cell_size_xy        (double, 必需)
%       .neighborhood_size   (odd int, 默认 3)
%       .nbr_averages        (int, 默认 10)
%       .min_points_per_cell (int, 默认 3)
%       .random_seed         (double|[], 默认 [])
%       .elevation_method    ('mean'|'median'|'max'|'min', 默认 'mean')
%       .elevation_interp    ('none'|'linear'|'nearest'|'natural', 默认 'linear')
%       .elevation_smooth_win(int, 默认 0)
%       .use_parallel        (bool, 默认 false)  -- 当前版本未对主循环并行化
%       .distance_method     ('bruteforce'|'kdtree', 默认 'bruteforce')
%       .kdtree_min_points   (int, 构建KD树所需最少点数, 默认 20)
%       .strict_random       (bool, 默认 false; 未来用于并行复现, 此处预留)
%
% 输出:
%   value_grid   : [H x W] double  一致性误差 (NaN=无效)
%   overlap_mask : [H x W] logical 有效格标记 (~isnan(value_grid))
%   grid_meta    : struct {x_min,y_min,grid_w,grid_h,cell_size_xy}
%   map_grid     : [H x W] double  高程栅格 (NaN=无点)
%
% 稀疏设计说明:
%   使用 containers.Map<uint64, entry> 存储仅包含点的格子:
%     key   = uint64(i + (j-1)*grid_w)
%     entry = struct('submap_ids',[s1..sK], 'points',{P1..PK})
%   其中每个 Pk 为 [n_k x 3] double。
%
% 与稠密版本的一致性:
%   - 采用同样的边界与网格尺寸计算逻辑
%   - 邻域收集包含当前格及周围 (neighborhood_size x neighborhood_size)
%   - 采样策略仍然: 对当前格每个存在点的子图进行随机点采样, 对其它子图邻域点集合
%     计算最近距离, 聚合得到“最坏最近邻”并在多次采样后平均。
%
% 版本: 1.0  (2025-09-25)
% 作者: 稀疏化实现自动生成

%% 1. 输入校验与参数获取
if nargin < 2
    error('buildCbeeErrorGrid_sparse:NotEnoughInputs', '需要 measurements 和 gridParams');
end
if ~iscell(measurements)
    error('buildCbeeErrorGrid_sparse:InvalidMeasurements', 'measurements 必须是 cell');
end
if ~isstruct(gridParams)
    error('buildCbeeErrorGrid_sparse:InvalidGridParams', 'gridParams 必须是 struct');
end

% 必需参数: cell_size_xy
if ~isfield(gridParams,'cell_size_xy') || isempty(gridParams.cell_size_xy)
    error('buildCbeeErrorGrid_sparse:MissingCellSize','gridParams.cell_size_xy 必须提供');
end
cell_size_xy = gridParams.cell_size_xy;
if ~isnumeric(cell_size_xy) || ~isscalar(cell_size_xy) || cell_size_xy <= 0
    error('buildCbeeErrorGrid_sparse:InvalidCellSize','cell_size_xy 必须为正标量');
end

% 可选参数及默认值
neighborhood_size     = getField(gridParams,'neighborhood_size',3);
nbr_averages          = getField(gridParams,'nbr_averages',10);
min_points_per_cell   = getField(gridParams,'min_points_per_cell',3);
use_parallel          = getField(gridParams,'use_parallel',false); %#ok<NASGU> (预留)
random_seed           = getField(gridParams,'random_seed',[]);
elevation_method      = getField(gridParams,'elevation_method','mean');
elevation_interp      = getField(gridParams,'elevation_interp','linear');
elevation_smooth_win  = getField(gridParams,'elevation_smooth_win',0);
distance_method       = lower(getField(gridParams,'distance_method','kdtree'));
kdtree_min_points     = getField(gridParams,'kdtree_min_points',10);
strict_random         = getField(gridParams,'strict_random',false); %#ok<NASGU>  % 预留

if ~ismember(distance_method, {'bruteforce','kdtree'})
    warning('未知 distance_method=%s, 回退为 bruteforce', distance_method);
    distance_method = 'bruteforce';
end

if mod(neighborhood_size,2)==0 || neighborhood_size < 1
    error('buildCbeeErrorGrid_sparse:InvalidNeighborhood','neighborhood_size 必须为正奇数');
end
if nbr_averages < 1
    error('buildCbeeErrorGrid_sparse:InvalidNbrAverages','nbr_averages 必须 >=1');
end
if min_points_per_cell < 1
    error('buildCbeeErrorGrid_sparse:InvalidMinPoints','min_points_per_cell 必须 >=1');
end

if ~isempty(random_seed)
    rng(random_seed);
end

%% 2. 过滤空子图并统计范围
valid_measurements = {};
for i = 1:numel(measurements)
    pts = measurements{i};
    if ~isempty(pts) && size(pts,2) >= 3
        valid_measurements{end+1} = pts; %#ok<AGROW>
    end
end
num_submaps = numel(valid_measurements);
if num_submaps == 0
    warning('buildCbeeErrorGrid_sparse:NoValidMeasurements','没有有效子图');
    value_grid = []; overlap_mask = []; grid_meta = struct(); map_grid = [];
    return;
end
if num_submaps < 2
    warning('buildCbeeErrorGrid_sparse:InsufficientSubmaps','需要 >=2 个子图以计算一致性');
    value_grid = []; overlap_mask = []; grid_meta = struct(); map_grid = [];
    return;
end

% 计算全局 XY 范围
all_xy = [];
for m = 1:num_submaps
    all_xy = [all_xy; valid_measurements{m}(:,1:2)]; %#ok<AGROW>
end
x_min = min(all_xy(:,1)); x_max = max(all_xy(:,1));
y_min = min(all_xy(:,2)); y_max = max(all_xy(:,2));

% 计算栅格尺寸 (与稠密版一致的向上扩展)
grid_w = ceil((x_max - x_min)/cell_size_xy);
grid_h = ceil((y_max - y_min)/cell_size_xy);
% 调整 max 使之对齐网格边界
% 记录对齐后的范围 (用于后续可能的 ROI 参考)
x_max_aligned = x_min + grid_w * cell_size_xy; %#ok<NASGU>
y_max_aligned = y_min + grid_h * cell_size_xy; %#ok<NASGU>

grid_meta = struct('x_min',x_min,'y_min',y_min,'grid_w',grid_w,'grid_h',grid_h,'cell_size_xy',cell_size_xy,...
                   'x_max',x_max_aligned,'y_max',y_max_aligned);

fprintf('[SPARSE] 有效子图: %d, 栅格: %d x %d = %d cells\n', num_submaps, grid_w, grid_h, grid_w*grid_h);
fprintf('[SPARSE] 距离计算方式: %s\n', distance_method);

%% 3. 构建“压缩结构数组” (cells) 取代 containers.Map
% 设计:
%   聚合所有点 -> 生成 (lin_id, submap_id, xyz) 三元组 -> 按 (lin_id, submap_id) 排序
%   -> 分段生成 cells(k):
%       .key        (uint64) 线性格索引
%       .submap_ids (row vec) 参与该格的子图ID (升序)
%       .offsets    (int32 vec) 长度 = length(submap_ids)+1, 第 i 到 i+1-1 为该子图点段
%       .points     (N x 3 double) 拼接后的点
%   附加: cell_index_map(uint64_lin) -> cells 下标 (0=空)

all_lin_ids = uint64([]);
all_submap_ids = [];
all_points = zeros(0,3);

for m = 1:num_submaps
    pts = valid_measurements{m};
    if isempty(pts); continue; end
    i_idx = floor((pts(:,1)-x_min)/cell_size_xy) + 1;
    j_idx = floor((pts(:,2)-y_min)/cell_size_xy) + 1;
    i_idx = max(1, min(grid_w, i_idx));
    j_idx = max(1, min(grid_h, j_idx));
    lin_idx = uint64(i_idx + (j_idx-1)*grid_w);
    all_lin_ids = [all_lin_ids; lin_idx]; %#ok<AGROW>
    all_submap_ids = [all_submap_ids; repmat(m, numel(lin_idx),1)]; %#ok<AGROW>
    all_points = [all_points; pts(:,1:3)]; %#ok<AGROW>
end

if isempty(all_lin_ids)
    non_empty_cells = 0;
    cells = struct('key',{},'submap_ids',{},'offsets',{},'points',{});
else
    % 排序 (lin_id -> submap_id)
    sort_matrix = [double(all_lin_ids), double(all_submap_ids)];
    [~, order] = sortrows(sort_matrix,[1 2]);
    all_lin_ids = all_lin_ids(order);
    all_submap_ids = all_submap_ids(order);
    all_points = all_points(order,:);

    % 找唯一格子
    [unique_lin, ~, icell] = unique(all_lin_ids,'stable'); %#ok<ASGLU>
    num_cells = numel(unique_lin);
    cells(num_cells,1) = struct('key',uint64(0),'submap_ids',[],'offsets',[],'points',[]); %#ok<AGROW>

    % 为快速定位构建线性索引边界
    % 使用 diff 找到分段边界
    lin_double = double(all_lin_ids); % for diff
    change_flags = [true; diff(lin_double)~=0];
    segment_starts = find(change_flags);
    segment_ends = [segment_starts(2:end)-1; numel(all_lin_ids)];

    for c = 1:num_cells
        s = segment_starts(c); e = segment_ends(c);
        cells(c).key = all_lin_ids(s); % uint64
        slice_subs = all_submap_ids(s:e);
        slice_points = all_points(s:e,:);
        % 子图内已按 submap_id 排序; 找子图分段
        sub_change = [true; diff(slice_subs)~=0];
        sub_starts = find(sub_change);
        sub_ends = [sub_starts(2:end)-1; numel(slice_subs)];
        usubs = slice_subs(sub_starts); % 升序且唯一
        counts = sub_ends - sub_starts + 1;
        offsets = zeros(1, numel(usubs)+1, 'int32');
        cum = 1;
        for u = 1:numel(usubs)
            offsets(u) = cum;
            cum = cum + counts(u);
        end
        offsets(end) = cum; % sentinel
        cells(c).submap_ids = usubs';
        cells(c).offsets = offsets; % offsets(i):offsets(i+1)-1
        cells(c).points = slice_points; % 已按 submap_id 分块
    end
    non_empty_cells = num_cells;
end

% 构建线性索引 -> cells 下标 映射 (uint32)
cell_index_map = zeros(grid_w*grid_h,1,'uint32');
for c = 1:non_empty_cells
    cell_index_map(double(cells(c).key)) = c;
end
fprintf('[SPARSE] 非空格子数: %d (占比 %.2f%%)\n', non_empty_cells, non_empty_cells/(grid_w*grid_h)*100);

%% 4. 预计算邻域偏移
half_n = floor(neighborhood_size/2);
[nbr_dx, nbr_dy] = meshgrid(-half_n:half_n, -half_n:half_n);
nbr_offsets = [nbr_dx(:), nbr_dy(:)];

%% 5. 初始化输出矩阵
value_grid = NaN(grid_h, grid_w);
map_grid   = NaN(grid_h, grid_w);

%% 6. 遍历非空格子计算误差与高程 (压缩结构数组版本)
num_keys = non_empty_cells;
progress_interval = max(1, floor(max(1,num_keys)/20));
for c = 1:num_keys
    key = cells(c).key;
    lin = double(key);
    i = mod(lin-1, grid_w) + 1;
    j = floor((lin-1)/grid_w) + 1;
    pts_all_cell = cells(c).points;
    map_grid(j,i) = computeElevation(pts_all_cell(:,3), elevation_method);
    if size(pts_all_cell,1) < min_points_per_cell
        if mod(c,progress_interval)==0
            fprintf('[SPARSE] 进度 %.1f%% (%d/%d)\n', c/num_keys*100, c, num_keys);
        end
        continue;
    end
    % 邻域聚合
    neighbor_points_by_submap = cell(1, num_submaps);
    for oi = 1:size(nbr_offsets,1)
        di = nbr_offsets(oi,1); dj = nbr_offsets(oi,2);
        ni = i + di; nj = j + dj;
        if ni < 1 || ni > grid_w || nj < 1 || nj > grid_h; continue; end
        nbr_lin = uint64(ni + (nj-1)*grid_w);
        idx_cell = cell_index_map(double(nbr_lin));
        if idx_cell == 0; continue; end
        nbr_entry = cells(idx_cell);
        for s = 1:numel(nbr_entry.submap_ids)
            sid = nbr_entry.submap_ids(s);
            seg_start = nbr_entry.offsets(s);
            seg_end   = nbr_entry.offsets(s+1)-1;
            pts_s = nbr_entry.points(seg_start:seg_end,:);
            if isempty(neighbor_points_by_submap{sid})
                neighbor_points_by_submap{sid} = pts_s;
            else
                neighbor_points_by_submap{sid} = [neighbor_points_by_submap{sid}; pts_s]; %#ok<AGROW>
            end
        end
    end
    % 当前格子按子图拆段
    cur_submap_ids = cells(c).submap_ids;
    cur_points_cell = cell(1, numel(cur_submap_ids));
    for cs = 1:numel(cur_submap_ids)
        seg_start = cells(c).offsets(cs);
        seg_end   = cells(c).offsets(cs+1)-1;
        cur_points_cell{cs} = cells(c).points(seg_start:seg_end,:);
    end
    % 可选 KD-Tree
    use_kdtree_local = strcmp(distance_method,'kdtree');
    kdtree_objs = cell(1, num_submaps);
    if use_kdtree_local
        for osid = 1:num_submaps
            ptsN = neighbor_points_by_submap{osid};
            if isempty(ptsN) || size(ptsN,1) < kdtree_min_points; continue; end
            try
                if exist('createns','file') == 2
                    kdtree_objs{osid} = createns(ptsN(:,1:3), 'NSMethod','kdtree');
                elseif exist('KDTreeSearcher','class') == 8 %#ok<EXIST>
                    kdtree_objs{osid} = KDTreeSearcher(ptsN(:,1:3));
                else
                    kdtree_objs{osid} = [];
                end
            catch
                kdtree_objs{osid} = [];
            end
        end
    end
    error_samples = [];
    for sample_idx = 1:nbr_averages
        max_err_this_sample = 0;
        for cs = 1:numel(cur_submap_ids)
            sid = cur_submap_ids(cs);
            pts_cur = cur_points_cell{cs};
            if isempty(pts_cur); continue; end
            rnd_idx = randi(size(pts_cur,1));
            sample_point = pts_cur(rnd_idx,:);
            min_dist_other = inf; found_other = false;
            for other_sid = 1:num_submaps
                if other_sid == sid; continue; end
                nbr_pts = neighbor_points_by_submap{other_sid};
                if isempty(nbr_pts); continue; end
                if use_kdtree_local && ~isempty(kdtree_objs{other_sid})
                    try
                        [~, md] = knnsearch(kdtree_objs{other_sid}, sample_point(1:3), 'K',1);
                    catch
                        d = nbr_pts - sample_point; dist2 = d(:,1).^2 + d(:,2).^2 + d(:,3).^2; md = sqrt(min(dist2));
                    end
                else
                    d = nbr_pts - sample_point; dist2 = d(:,1).^2 + d(:,2).^2 + d(:,3).^2; md = sqrt(min(dist2));
                end
                if md < min_dist_other; min_dist_other = md; end
                found_other = true;
            end
            if found_other && isfinite(min_dist_other) && min_dist_other > max_err_this_sample
                max_err_this_sample = min_dist_other;
            end
        end
        if max_err_this_sample > 0 && isfinite(max_err_this_sample)
            error_samples(end+1) = max_err_this_sample; %#ok<AGROW>
        end
    end
    if ~isempty(error_samples)
        value_grid(j,i) = mean(error_samples);
    end
    if mod(c,progress_interval)==0
        fprintf('[SPARSE] 进度 %.1f%% (%d/%d)\n', c/num_keys*100, c, num_keys);
    end
end

%% 7. 计算 overlap_mask & 基本统计
overlap_mask = isfinite(value_grid);
valid_cells = sum(overlap_mask(:));
if valid_cells > 0
    fprintf('[SPARSE] 有效误差格: %d  平均误差: %.4f\n', valid_cells, mean(value_grid(overlap_mask)));
else
    fprintf('[SPARSE] 无有效误差格 (可能重叠不足或阈值过高)\n');
end

%% 8. 高程插值与平滑 (与原版一致逻辑)
if ~strcmpi(elevation_interp,'none')
    [H,W] = size(map_grid);
    [Xc,Yc] = meshgrid(1:W, 1:H);
    known = ~isnan(map_grid);
    if any(known(:)) && any(~known(:))
        try
            F = scatteredInterpolant(Xc(known), Yc(known), map_grid(known), elevation_interp, 'none');
            filled = map_grid;
            filled(~known) = F(Xc(~known), Yc(~known));
            map_grid = filled;
        catch ME
            warning('buildCbeeErrorGrid_sparse:ElevationInterpFailed','%s (保持原 NaN)', ME.message);
        end
    end
end
if isnumeric(elevation_smooth_win) && elevation_smooth_win >=3 && mod(elevation_smooth_win,2)==1
    try
        map_grid = movmean(map_grid, [floor(elevation_smooth_win/2) floor(elevation_smooth_win/2)],1,'omitnan');
        map_grid = movmean(map_grid, [floor(elevation_smooth_win/2) floor(elevation_smooth_win/2)],2,'omitnan');
    catch
        % 旧版本 MATLAB 可能不支持 movmean omitnan, 忽略
    end
end

end % 主函数结束

%% ================= 辅助函数 =================
function val = getField(S, name, defaultVal)
if isfield(S,name) && ~isempty(S.(name))
    val = S.(name);
else
    val = defaultVal;
end
end

function elev = computeElevation(z_values, method)
if isempty(z_values)
    elev = NaN; return; end
switch lower(method)
    case 'mean'
        elev = mean(z_values);
    case 'median'
        elev = median(z_values);
    case 'max'
        elev = max(z_values);
    case 'min'
        elev = min(z_values);
    otherwise
        elev = mean(z_values);
end
end
