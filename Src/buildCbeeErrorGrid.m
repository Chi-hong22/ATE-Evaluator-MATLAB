function [value_grid, overlap_mask, grid_meta, map_grid] = buildCbeeErrorGrid(measurements, gridParams)
    % BUILDCBEEERRORGRID  CBEE 栅格构建 (压缩结构数组 + 可选 KD-Tree)
    %
    % 【定位】
    %   基于稀疏存储结构的CBEE一致性误差计算。采用一次性排序 + 压缩结构数组 (compact) 布局：
    %   Map<key,entry> 方式，而是升级为一次性排序 + 压缩结构数组 (compact) 布局：
    %     - 通过全量 linear_id 排序把同一格子的不同子图点聚集到连续内存
    %     - 每格用 (submap_ids, offsets, points) 描述分段，减少 cell/Map 额外指针与碎片
    %
    % 【适用场景】
    %   - 子图数量多 (>= O(10^2)) 且场景范围大，dense 分配 (grid_w*grid_h*num_submaps) OOM
    %   - 点总体较大，但非空格子占比显著低于 100%
    %   - 需要更紧凑的缓存友好访问提升遍历效率
    %
    % 【数据结构】(与 Map 版差异)
    %   cells(k):
    %     .linear_id    uint64    -> i + (j-1)*grid_w (1-based)
    %     .submap_ids   uint32[S] -> 含点子图 ID 升序
    %     .offsets      uint32[S+1] -> 分段起始位置; 第 s 段点为 points(offsets(s):offsets(s+1)-1,:)
    %     .points       double[N_k x 3] -> 该格所有点 (按 submap_ids 分段)
    %   邻域查询: 线性索引 -> Map<uint64,uint32>(id2index) -> cells(idx)
    %
    % 【与稠密/Map版保持一致的语义】
    %   - 网格尺寸、坐标边界计算
    %   - 邻域定义 (neighborhood_size 的 k×k)
    %   - 采样策略: 每个当前格子中存在的子图随机采样点 -> 对其它子图邻域点求最近距离 -> 取“每次采样的最大最近邻” -> 多次平均
    %   - 输出矩阵 value_grid / overlap_mask / map_grid / grid_meta
    %
    % 【新增/预留参数】(从 main_evaluateCBEE 传入; 默认值参考 config.cbee.options)
    %   gridParams:
    %       .cell_size_xy        (double, 必需)
    %       .neighborhood_size   (odd int, 默认 3)
    %       .nbr_averages        (int, 默认 10)
    %       .min_points_per_cell (int, 默认 3)
    %       .random_seed         (double|[], 默认 [])
    %       .elevation_method    ('mean'|'median'|'max'|'min', 默认 'mean')
    %       .elevation_interp    ('none'|'linear'|'nearest'|'natural', 默认 'linear')
    %       .elevation_smooth_win(int, 默认 0)
    %       .elevation_mask_enable(bool, 默认 true)  % 是否启用距离掩码，避免过度插值
    %       .elevation_mask_radius(double, 默认 2.0) % 掩码半径：只保留距离真实数据点该距离内的插值结果(单位:格子)
    %       .use_parallel        (bool, 默认 false)  -- 当前主循环仍为串行
    %       .distance_method     ('bruteforce'|'kdtree', 默认 'bruteforce')  % 已实现: 局部 per-submap KD 树
    %       .kdtree_min_points   (int, 构建 KD 树最少点数, 默认 20)        % 已实现: 小于阈值回退暴力
    %       .strict_random       (bool, 默认 false; 并行复现预留)          % 预留
    %
    % 【输出】
    %   value_grid   [H x W] double  一致性误差 (NaN=无效)
    %   overlap_mask [H x W] logical 有效格 (~isnan(value_grid))
    %   grid_meta    struct {x_min,y_min,grid_w,grid_h,cell_size_xy,x_max,y_max}
    %   map_grid     [H x W] double  高程 (NaN=无点或插值失败)
    %
    % 【复杂度】
    %   预处理: 排序 O(P log P)  (P 为总点数)  vs Map 版 O(P) 插入 + 额外 cell 开销
    %   主循环: O(C * (S_c * nbr_averages * cost_nn))  (C=非空格子数, S_c=该格子子图数)
    %   暴力最近邻 cost_nn = O(邻域点总数), 后续可用 KD-Tree 将其近似降为 O(log M)
    %
    % 【局限与后续】
    %   - KD-Tree 目前为“按当前格邻域、逐子图”单独构建: 重复率高时可优化为缓存/批量
    %   - 未对超大范围执行 Tile/分块: 仍一次性加载全部点, 未来可按瓦片 streaming
    %   - 并行化 (parfor) 仍未启用: 需结合 strict_random / 线程安全随机策略
    %   - 最近邻仍为 single nearest; 可扩展支持 K>1 或统计分布 (如中位数 NN)
    %   - 可选添加距离裁剪 (max_radius) 以跳过超远子图
    %   - 仍缺自动化基准 (accuracy vs dense, time, memory) 脚本

    % 版本: 1.2  (2025-09-25)  增补 KD-Tree 实现与局限说明
    % 作者: 稀疏化实现自动生成 (已调整注释)

    
    %% 1. 参数与输入校验 (复用稀疏版本逻辑)
    if nargin < 2; error('NotEnoughInputs'); end
    if ~iscell(measurements); error('measurements 必须是 cell'); end
    if ~isstruct(gridParams); error('gridParams 必须是 struct'); end
    if ~isfield(gridParams,'cell_size_xy') || isempty(gridParams.cell_size_xy)
        error('缺少 cell_size_xy');
    end
    cell_size_xy = gridParams.cell_size_xy;
    if cell_size_xy <= 0; error('cell_size_xy 必须 >0'); end
    
    % (原占位函数 getF 已移除: 未被使用)
    if isfield(gridParams,'neighborhood_size') && ~isempty(gridParams.neighborhood_size)
        neighborhood_size = gridParams.neighborhood_size; else; neighborhood_size = 3; end
    if isfield(gridParams,'nbr_averages') && ~isempty(gridParams.nbr_averages)
        nbr_averages = gridParams.nbr_averages; else; nbr_averages = 10; end
    if isfield(gridParams,'min_points_per_cell') && ~isempty(gridParams.min_points_per_cell)
        min_points_per_cell = gridParams.min_points_per_cell; else; min_points_per_cell = 3; end
    if isfield(gridParams,'random_seed') && ~isempty(gridParams.random_seed)
        rng(gridParams.random_seed); end
    if isfield(gridParams,'elevation_method') && ~isempty(gridParams.elevation_method)
        elevation_method = gridParams.elevation_method; else; elevation_method = 'mean'; end
    if isfield(gridParams,'elevation_interp') && ~isempty(gridParams.elevation_interp)
        elevation_interp = gridParams.elevation_interp; else; elevation_interp = 'linear'; end
    if isfield(gridParams,'elevation_smooth_win') && ~isempty(gridParams.elevation_smooth_win)
        elevation_smooth_win = gridParams.elevation_smooth_win; else; elevation_smooth_win = 0; end
    if isfield(gridParams,'elevation_mask_enable') && ~isempty(gridParams.elevation_mask_enable)
        elevation_mask_enable = gridParams.elevation_mask_enable; else; elevation_mask_enable = true; end
    if isfield(gridParams,'elevation_mask_radius') && ~isempty(gridParams.elevation_mask_radius)
        elevation_mask_radius = gridParams.elevation_mask_radius; else; elevation_mask_radius = 2.0; end
    if mod(neighborhood_size,2)==0; error('neighborhood_size 必须为奇数'); end
    if nbr_averages < 1; error('nbr_averages >=1'); end
    if min_points_per_cell < 1; error('min_points_per_cell >=1'); end

    % KD-Tree / 距离方式参数解析 (若不存在则给默认值)
    distance_method = 'bruteforce';
    if isfield(gridParams,'distance_method') && ~isempty(gridParams.distance_method)
        distance_method = lower(string(gridParams.distance_method));
    end
    kdtree_min_points = 20;
    if isfield(gridParams,'kdtree_min_points') && ~isempty(gridParams.kdtree_min_points)
        kdtree_min_points = double(gridParams.kdtree_min_points);
    end
    if ~ismember(distance_method, ["bruteforce","kdtree"])
        warning('distance_method=%s 不支持, 回退 bruteforce', distance_method);
        distance_method = "bruteforce";
    end
    
    %% 2. 过滤与统计范围
    valid_measurements = {};
    for i = 1:numel(measurements)
        pts = measurements{i};
        if ~isempty(pts) && size(pts,2)>=3
            valid_measurements{end+1} = pts; %#ok<AGROW>
        end
    end
    num_submaps = numel(valid_measurements);
    if num_submaps < 2
        warning('子图数量不足, 返回空');
        value_grid=[]; overlap_mask=[]; grid_meta=struct(); map_grid=[]; 
        return; 
    end
    
    all_xy = [];
    counts = zeros(num_submaps,1);
    for m=1:num_submaps
        pts = valid_measurements{m};
        counts(m) = size(pts,1);
        all_xy = [all_xy; pts(:,1:2)]; %#ok<AGROW>
    end
    x_min = min(all_xy(:,1)); x_max = max(all_xy(:,1));
    y_min = min(all_xy(:,2)); y_max = max(all_xy(:,2));
    
    grid_w = ceil((x_max - x_min)/cell_size_xy);
    grid_h = ceil((y_max - y_min)/cell_size_xy);
    x_max_aligned = x_min + grid_w * cell_size_xy;
    y_max_aligned = y_min + grid_h * cell_size_xy;
    
    grid_meta = struct('x_min',x_min,'y_min',y_min,'grid_w',grid_w,'grid_h',grid_h,...
        'cell_size_xy',cell_size_xy,'x_max',x_max_aligned,'y_max',y_max_aligned);
    
    %% 3. 展平所有点并计算 linear_id
    P_total = sum(counts);
    XYZ = zeros(P_total,3);
    submap_id_vec = zeros(P_total,1,'uint32');
    linear_id_vec = zeros(P_total,1,'uint64');
    idx = 1;
    for m=1:num_submaps
        pts = valid_measurements{m};
        n = size(pts,1);
        if n==0; continue; end
        range = idx:idx+n-1;
        XYZ(range,:) = pts(:,1:3);
        submap_id_vec(range) = m;
        i_idx = floor((pts(:,1)-x_min)/cell_size_xy) + 1;
        j_idx = floor((pts(:,2)-y_min)/cell_size_xy) + 1;
        i_idx = max(1, min(grid_w, i_idx));
        j_idx = max(1, min(grid_h, j_idx));
        linear_id_vec(range) = uint64(i_idx + (j_idx-1)*grid_w);
        idx = idx + n;
    end
    if idx-1 ~= P_total; error('点计数不匹配'); end
    
    %% 4. 排序 (linear_id, submap_id)
    [~, order] = sortrows([double(linear_id_vec), double(submap_id_vec)]); % 返回排序索引
    linear_id_vec = linear_id_vec(order);
    submap_id_vec = submap_id_vec(order);
    XYZ = XYZ(order,:);
    
    %% 5. 定位 cell 边界
    [cell_ids, cell_first_idx, ~] = unique(linear_id_vec,'first');
    [~, cell_last_idx] = unique(linear_id_vec,'last');
    num_cells = numel(cell_ids);
    
    % 预分配结构数组
    cells(num_cells,1) = struct('linear_id',uint64(0),'submap_ids',[],'offsets',[],'points',[]);
    
    %% 6. 为每个 cell 构建子图分段 (利用 submap_id_vec 已排序)
    for c = 1:num_cells
        rng_indices = cell_first_idx(c):cell_last_idx(c);
        subvec = submap_id_vec(rng_indices);
        pts_local = XYZ(rng_indices,:);
        [uniq_sub, first_pos] = unique(subvec,'first');
        % [~, last_pos] = unique(subvec,'last'); % 未使用
        % 构建 offsets: 长度 = |uniq_sub|+1
        offsets = zeros(numel(uniq_sub)+1,1,'uint32');
        offsets(1:end-1) = first_pos; % 相对当前 cell 段起始
        offsets(end) = numel(subvec)+1;
        % 需要把 first_pos 转换为局部起点(1-based)
        % 此处 first_pos 已相对于 cell 段 1 开始
    
        cells(c).linear_id = cell_ids(c);
        cells(c).submap_ids = uint32(uniq_sub);
        cells(c).offsets = uint32(offsets);
        cells(c).points = pts_local; % 分段由 offsets 描述
    end
    
    fprintf('[COMPACT] 非空格子数: %d (占比 %.2f%%)\n', num_cells, num_cells/(grid_w*grid_h)*100);
    
    %% 7. 预计算邻域偏移
    half_n = floor(neighborhood_size/2);
    [nbr_dx, nbr_dy] = meshgrid(-half_n:half_n, -half_n:half_n);
    nbr_offsets = [nbr_dx(:), nbr_dy(:)];
    
    %% 8. 主输出矩阵
    value_grid = NaN(grid_h, grid_w);
    map_grid   = NaN(grid_h, grid_w);
    
    %% 9. 构建 cell_id -> 索引 映射 (便于邻域 O(1) 查找)
    % 使用 containers.Map(uint64->int32) 只保存映射, 内存较小; 也可改为 sparse
    id2index = containers.Map('KeyType','uint64','ValueType','uint32');
    for c = 1:num_cells
        id2index(cells(c).linear_id) = uint32(c);
    end
    
    progress_interval = max(1, floor(num_cells/20));
    
    %% 10. 遍历 cells 计算
    for ci = 1:num_cells
        cell_struct = cells(ci);
        lin = double(cell_struct.linear_id);
        i = mod(lin-1, grid_w) + 1;   % 列
        j = floor((lin-1)/grid_w) + 1; % 行
    
        % 高程: 所有点
        z_all = cell_struct.points(:,3);
        map_grid(j,i) = computeElevation(z_all, elevation_method);
    
        if size(cell_struct.points,1) < min_points_per_cell
            if mod(ci,progress_interval)==0
                fprintf('[COMPACT] 进度 %.1f%% (%d/%d)\n', ci/num_cells*100, ci, num_cells);
            end
            continue; % 保持 NaN
        end
    
        % 收集邻域点, 分子图聚合
        neighbor_points_by_submap = cell(1, num_submaps);
        for oi = 1:size(nbr_offsets,1)
            di = nbr_offsets(oi,1); dj = nbr_offsets(oi,2);
            ni = i + di; nj = j + dj;
            if ni < 1 || ni > grid_w || nj < 1 || nj > grid_h; continue; end
            nbr_lin = uint64(ni + (nj-1)*grid_w);
            if ~isKey(id2index, nbr_lin); continue; end
            nbr_idx = id2index(nbr_lin);
            nbr_cell = cells(nbr_idx);
            sub_ids = nbr_cell.submap_ids;
            offs = double(nbr_cell.offsets);
            for s = 1:numel(sub_ids)
                sid = sub_ids(s);
                local_seg = nbr_cell.points(offs(s):offs(s+1)-1,:);
                if isempty(neighbor_points_by_submap{sid})
                    neighbor_points_by_submap{sid} = local_seg;
                else
                    neighbor_points_by_submap{sid} = [neighbor_points_by_submap{sid}; local_seg]; %#ok<AGROW>
                end
            end
        end
    
        % 当前格子按子图分段
        cur_sub_ids = cell_struct.submap_ids;
        offs_self = double(cell_struct.offsets);
    
        % 若使用 KD-Tree: 为邻域中每个子图(点数>=阈值)构建局部 KD 树
        kdtree_structs = [];
        use_kdtree_this_cell = (distance_method == "kdtree");
        if use_kdtree_this_cell
            kdtree_structs = cell(1, num_submaps);
            for sid_tmp = 1:num_submaps
                pts_all = neighbor_points_by_submap{sid_tmp};
                if ~isempty(pts_all) && size(pts_all,1) >= kdtree_min_points
                    % 使用 MATLAB KDTreeSearcher (Statistics and Machine Learning Toolbox)
                    try
                        kdtree_structs{sid_tmp} = KDTreeSearcher(pts_all(:,1:3));
                    catch ME
                        warning('buildCbeeErrorGrid:KDTreeBuildFailed','KDTreeSearcher 构建失败: %s (回退 bruteforce)', ME.message);
                        kdtree_structs = [];
                        use_kdtree_this_cell = false;
                        break;
                    end
                end
            end
        end

        error_samples = [];
        for sample_idx = 1:nbr_averages
            max_err_this_sample = 0;
            for s = 1:numel(cur_sub_ids)
                sid = cur_sub_ids(s);
                pts_seg = cell_struct.points(offs_self(s):offs_self(s+1)-1,:);
                if isempty(pts_seg); continue; end
                rnd_idx = randi(size(pts_seg,1));
                sample_point = pts_seg(rnd_idx,:);
                min_dist_other = inf; found_other=false;
                for other_sid = 1:num_submaps
                    if other_sid == sid; continue; end
                    nbr_pts = neighbor_points_by_submap{other_sid};
                    if isempty(nbr_pts); continue; end
                    if use_kdtree_this_cell && ~isempty(kdtree_structs) && ~isempty(kdtree_structs{other_sid})
                        % KD-Tree 最近邻距离
                        try
                            md = knnsearch(kdtree_structs{other_sid}, sample_point(1:3), 'K',1);
                        catch
                            % 防御性: 若 knnsearch 异常回退暴力
                            d = nbr_pts - sample_point;
                            dist2 = d(:,1).^2 + d(:,2).^2 + d(:,3).^2;
                            md = sqrt(min(dist2));
                        end
                    else
                        % 暴力距离
                        d = nbr_pts - sample_point;
                        dist2 = d(:,1).^2 + d(:,2).^2 + d(:,3).^2;
                        md = sqrt(min(dist2));
                    end
                    if md < min_dist_other; min_dist_other = md; end
                    found_other = true;
                end
                if found_other && isfinite(min_dist_other)
                    if min_dist_other > max_err_this_sample
                        max_err_this_sample = min_dist_other;
                    end
                end
            end
            if max_err_this_sample > 0 && isfinite(max_err_this_sample)
                error_samples(end+1) = max_err_this_sample; %#ok<AGROW>
            end
        end
        if ~isempty(error_samples)
            value_grid(j,i) = mean(error_samples);
        end
    
        if mod(ci,progress_interval)==0
            fprintf('[COMPACT] 进度 %.1f%% (%d/%d)\n', ci/num_cells*100, ci, num_cells);
        end
    end
    
    %% 11. 输出 mask / 统计
    overlap_mask = isfinite(value_grid);
    vc = sum(overlap_mask(:));
    if vc>0
        fprintf('[COMPACT] 有效误差格: %d  平均误差: %.4f\n', vc, mean(value_grid(overlap_mask)));
    else
        fprintf('[COMPACT] 无有效误差格\n');
    end
    
    %% 12. 高程插值与平滑
    if ~strcmpi(elevation_interp,'none')
        fprintf('[Elevation] 进行高程插值...\n');
        [H,W] = size(map_grid); %#ok<ASGLU>
        [Xc,Yc] = meshgrid(1:grid_w, 1:grid_h); % 使用格索引空间
        known = ~isnan(map_grid);
        if any(known(:)) && any(~known(:))
            try
                F = scatteredInterpolant(Xc(known), Yc(known), map_grid(known), elevation_interp, 'none');
                filled = map_grid;
                filled(~known) = F(Xc(~known), Yc(~known));
                
                % 应用距离掩码：先插值再删除过度外推区域
                if elevation_mask_enable && elevation_mask_radius > 0
                    % 计算每个插值点到最近已知点的距离
                    unknown_indices = find(~known);
                    num_unknown = length(unknown_indices);
                    
                    if num_unknown > 0
                        [unknown_i, unknown_j] = ind2sub([grid_h, grid_w], unknown_indices);
                        [known_i, known_j] = ind2sub([grid_h, grid_w], find(known));
                        
                        % 选择并行化策略：大数据集使用向量化，小数据集使用parfor
                        use_vectorized = (num_unknown * length(known_i)) > 50000; % 阈值可调
                        
                        if use_vectorized
                            % 向量化计算：批量计算距离矩阵（内存友好版）
                            try
                                % 使用pdist2进行批量距离计算
                                unknown_coords = [unknown_i, unknown_j];
                                known_coords = [known_i, known_j];
                                
                                % 分批处理以控制内存使用
                                batch_size = min(1000, num_unknown);
                                for batch_start = 1:batch_size:num_unknown
                                    batch_end = min(batch_start + batch_size - 1, num_unknown);
                                    batch_idx = batch_start:batch_end;
                                    
                                    % 计算当前批次到所有已知点的距离
                                    batch_coords = unknown_coords(batch_idx, :);
                                    distances_matrix = pdist2(batch_coords, known_coords);
                                    min_distances = min(distances_matrix, [], 2);
                                    
                                    % 应用距离掩码
                                    mask_batch = min_distances > elevation_mask_radius;
                                    if any(mask_batch)
                                        batch_indices = unknown_indices(batch_idx);
                                        masked_indices = batch_indices(mask_batch);
                                        filled(masked_indices) = NaN;
                                    end
                                end
                            catch ME
                                warning('buildCbeeErrorGrid:VectorizedFailed', '向量化距离计算失败，回退到并行循环: %s', ME.message);
                                use_vectorized = false;
                            end
                        end
                        
                        if ~use_vectorized
                            % 并行循环方式（适用于中等规模数据）
                            mask_results = false(num_unknown, 1);
                            
                            % 检查是否有可用的并行池
                            try
                                pool = gcp('nocreate');
                                use_parfor = ~isempty(pool) && (num_unknown > 100);
                            catch
                                use_parfor = false;
                            end
                            
                            if use_parfor
                                % 使用parfor并行计算
                                parfor idx = 1:num_unknown
                                    ui = unknown_i(idx); uj = unknown_j(idx);
                                    distances = sqrt((known_i - ui).^2 + (known_j - uj).^2);
                                    min_dist = min(distances);
                                    mask_results(idx) = (min_dist > elevation_mask_radius);
                                end
                            else
                                % 回退到串行for循环
                                for idx = 1:num_unknown
                                    ui = unknown_i(idx); uj = unknown_j(idx);
                                    distances = sqrt((known_i - ui).^2 + (known_j - uj).^2);
                                    min_dist = min(distances);
                                    mask_results(idx) = (min_dist > elevation_mask_radius);
                                end
                            end
                            
                            % 应用掩码结果
                            if any(mask_results)
                                masked_indices = unknown_indices(mask_results);
                                filled(masked_indices) = NaN;
                            end
                        end
                    end
                end
                
                map_grid = filled;
            catch ME
                warning('buildCbeeErrorGrid:ElevationInterpFailed','%s (保持原 NaN)', ME.message);
            end
        end
    end
    if elevation_smooth_win>=3 && mod(elevation_smooth_win,2)==1
        try
            map_grid = movmean(map_grid, [floor(elevation_smooth_win/2) floor(elevation_smooth_win/2)],1,'omitnan');
            map_grid = movmean(map_grid, [floor(elevation_smooth_win/2) floor(elevation_smooth_win/2)],2,'omitnan');
        catch
        end
    end
    fprintf('[Elevation] 高程插值完成\n');
    end
    
    function elev = computeElevation(z_values, method)
    if isempty(z_values); elev=NaN; return; end
    switch lower(method)
        case 'mean';   elev = mean(z_values);
        case 'median'; elev = median(z_values);
        case 'max';    elev = max(z_values);
        case 'min';    elev = min(z_values);
        otherwise;     elev = mean(z_values);
    end
    end
    