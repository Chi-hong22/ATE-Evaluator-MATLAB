%% main_evaluateCBEE 执行CBEE（Cross-Submap Bundle Error Evaluation）一致性误差评估的运行脚本
%
% ================================ 项目概述 ================================
% CBEE (Cross-Submap Bundle Error Evaluation) 是一种用于评估多子图SLAM系统
% 一致性的创新方法。通过分析不同子图在重叠区域的点云一致性，CBEE能够
% 量化SLAM系统的局部精度和全局一致性表现。
%
% 该脚本是MB-SLAM评估工具包的核心组件，专门用于：
% • 评估多子图SLAM系统的空间一致性误差
% • 生成基于栅格的一致性误差热力图
% • 计算RMS一致性误差指标用于定量分析
% • 提供完整的可视化和数据导出功能
%
% =============================== 算法原理 ===============================
% CBEE算法的核心思想是在栅格化空间中，对每个格子：
% 1. 收集该格子及其邻域内所有子图的点云数据
% 2. 对当前格子中的每个子图，随机采样其点云
% 3. 计算采样点到其他子图邻域点云的最近邻距离
% 4. 取所有子图最近邻距离的最大值作为该次采样的误差
% 5. 重复采样多次并取平均值，得到该格子的一致性误差
% 6. 汇总所有有效格子的误差，计算整体RMS一致性误差
%
% =============================== 工作流程 ===============================
% 该脚本集成了CBEE评估的完整工作流程，从数据加载到结果导出，按照以下步骤执行：
%   1. 初始化和配置 - 加载配置文件，设置算法参数
%   2. 并行池管理与配置摘要 - 初始化并行计算环境
%   3. 生成优化子地图（可选）- 基于优化轨迹重新生成子地图
%   4. 加载子地图数据 - 读取原始或优化后的子地图点云
%   5. 构建CBEE一致性误差栅格 - 执行核心CBEE算法
%   6. 计算RMS一致性误差 - 统计分析误差分布
%   7. 一致性误差热力图可视化 - 生成误差空间分布图
%   8. 高程地图可视化与保存 - 生成栅格高程图
%   9. 数据导出与持久化 - 保存结果数据和统计报告
%   10. 环境清理与完成 - 清理临时文件，输出总结
%
% =============================== 技术特点 ===============================
% • 稀疏存储优化：采用压缩结构数组，高效处理大规模稀疏栅格
% • 并行加速支持：支持格级并行计算，显著提升处理速度
% • 多种距离算法：支持暴力搜索和KD-Tree两种最近邻查询方式
% • 灵活参数配置：通过config.m统一管理所有算法参数
% • 丰富可视化：提供误差热力图、高程图等多种可视化形式
% • 完整数据导出：支持CSV、MAT、PNG、EPS等多种格式输出
%
% ================================ 使用说明 ================================
% 用法:
%   直接运行此脚本: run('Src/main_evaluateCBEE.m')
%   或在MATLAB命令窗口中: main_evaluateCBEE
%
% 前置条件:
%   1. MATLAB版本建议 R2018b 或更高（支持并行计算工具箱）
%   2. 已正确配置 config.m 中的路径和参数
%   3. 子地图数据格式为 .pcd 文件，位于指定目录
%   4. 位姿数据格式为标准的 poses_*.txt 文件
%
% 运行时配置参数:
%   在运行脚本前可以在工作空间设置以下变量：
%     skip_optimized_submaps - 是否跳过优化子地图生成 (默认: false)
%                             设为true可直接使用原始子地图进行评估
%     verbose_output        - 是否显示详细输出 (默认: true)
%                             设为false可减少终端输出信息
%
% ================================ 输出文件 ================================
% 生成的文件（Src\config.m 中 cfg.cbee.paths 设置）:
%   误差分析文件:
%     - cbee_error_map_RMS_[value].png/eps    : 一致性误差热力图
%     - cbee_elevation_map_RMS_[value].png/eps: 高程分布图  
%     - cbee_error_grid_RMS_[value].csv       : 误差栅格数据（行列索引+误差值）
%     - cbee_elevation_grid_RMS_[value].csv   : 高程栅格数据（行列索引+高程值）
%   
%   统计报告文件:
%     - cbee_rms_complete_RMS_[value].txt     : 完整统计报告（网格统计、误差分布等）
%     - cbee_results_RMS_[value].mat          : 完整结果数据（可用于后续分析）
%   
%   其他输出:
%     - [timestamp]_optimized_submaps/        : 优化后的子地图目录（如果生成）
%
% 关键输出指标:
%   • RMS一致性误差：整体空间一致性的定量指标
%   • 有效格比例：参与计算的栅格占比，反映数据覆盖度
%   • 误差分布统计：最小值、最大值、均值、标准差、分位数等
%   • 空间误差分布：热力图形式的误差空间变化模式
%
% =============================== 使用示例 ===============================
% 示例 1: 基本使用（默认配置）
%   run('Src/main_evaluateCBEE.m')
%
% 示例 2: 自定义运行时参数
%   skip_optimized_submaps = true;    % 跳过优化子地图生成，直接使用原始子地图
%   verbose_output = false;           % 关闭详细输出，仅显示关键信息
%   run('Src/main_evaluateCBEE.m')
%
% 示例 3: 修改算法参数（需修改config.m）
%   % 在config.m中设置：
%   % cfg.cbee.cell_size_xy = 0.5;           % 更精细的栅格分辨率
%   % cfg.cbee.neighborhood_size = 5;        % 更大的邻域尺寸
%   % cfg.cbee.nbr_averages = 20;            % 更多的蒙特卡洛采样次数
%   % cfg.cbee.use_parallel = true;          % 启用并行计算加速
%   % cfg.cbee.options.distance_method = 'kdtree'; % 使用KD-Tree加速
%   run('Src/main_evaluateCBEE.m')
%
% ============================== 性能优化建议 ==============================
% • 对于大规模数据，建议启用并行计算（cfg.cbee.use_parallel = true）
% • 当邻域点数较多时，推荐使用KD-Tree加速（distance_method = 'kdtree'）
% • 可通过调整cell_size_xy平衡计算精度与速度
% • nbr_averages参数影响结果稳定性，建议根据数据特点调整
%
% =============================== 故障排除 ===============================
% 常见问题及解决方案:
% 1. 内存不足：减小cell_size_xy或启用稀疏存储优化
% 2. 计算速度慢：启用并行计算或使用KD-Tree加速
% 3. 结果异常：检查子地图数据质量和坐标系一致性
% 4. 文件路径错误：确认config.m中的路径配置正确
%
% 另请参阅: config, buildCbeeErrorGrid, computeRmsConsistencyError, 
%           loadAllSubmaps, generateOptimizedSubmaps, visualizeSubmaps
%
% ================================ 版本信息 ================================
% 项目: MB-SLAM评估工具包 (Multi-Bundle SLAM Evaluation Toolkit)
% 模块: CBEE一致性误差评估
% 版本: v2.1 (2025-09-26)
% 作者: CBEE评估工具包开发团队
% 许可: 根据项目许可证使用
% 
% 更新日志:
% v2.1 (2025-09-26): 优化稀疏存储，完善注释文档，增加KD-Tree支持
% v2.0 (2025-09-22): 重构代码架构，统一配置管理，增强并行支持
% v1.5 (2025-09-15): 添加高程地图功能，优化可视化效果
% v1.0 (2025-08-30): 初始版本发布
clear; close all; clc;
%% 脚本配置参数

% 设置默认值（允许在运行前由工作区覆盖）
if ~exist('skip_optimized_submaps', 'var')
    skip_optimized_submaps = false;  % 是否跳过优化子地图生成
end
if ~exist('verbose_output', 'var')
    verbose_output = true;           % 是否显示详细输出
end

% 为了保持代码兼容性，将新变量名映射到原变量名
skipOptimizedSubmaps = skip_optimized_submaps;
verbose = verbose_output;

%% 1. 初始化和配置
startTime = tic;
if verbose
    fprintf('\n=== CBEE一致性误差评估开始 ===\n');
    fprintf('初始化环境...\n');
end

% 添加Src目录到MATLAB路径
addpath(genpath('Src'));

% 加载配置参数
if verbose
    fprintf('加载配置...\n');
end
cfg = config();

% 强制覆盖配置选项（根据输入参数）
if skipOptimizedSubmaps
    cfg.cbee.options.generate_optimized_submaps = false;
    if verbose
        fprintf('已禁用优化子地图生成\n');
    end
end

% 检查配置结构体关键字段
required_path_fields = {'gt_pcd_dir','poses_original','poses_optimized','output_data_results','output_optimized_submaps'};
for i = 1:numel(required_path_fields)
    f = required_path_fields{i};
    if ~isfield(cfg, 'cbee') || ~isfield(cfg.cbee, 'paths') || ~isfield(cfg.cbee.paths, f)
        error('配置缺少路径字段 cfg.cbee.paths.%s', f);
    end
end
if ~isfield(cfg, 'cbee')
    error('配置缺少 cfg.cbee 段');
end

% 构建关键文件路径（使用层次化配置）
pcd_folder = cfg.cbee.paths.gt_pcd_dir;
original_poses_file = cfg.cbee.paths.poses_original;
optimized_poses_file = cfg.cbee.paths.poses_optimized;

% 条件化存在性检查
pcd_folder_exists = exist(pcd_folder, 'dir') == 7;
if ~pcd_folder_exists
    error('未找到子地图目录: %s', pcd_folder);
end

% 仅当需要生成优化子地图或后续流程显式使用轨迹时，检查轨迹文件
need_poses = isfield(cfg.cbee, 'options') && isfield(cfg.cbee.options, 'generate_optimized_submaps') && cfg.cbee.options.generate_optimized_submaps;
if need_poses
    if ~isfile(original_poses_file)
        error('未找到原始位姿文件: %s', original_poses_file);
    end
    if ~isfile(optimized_poses_file)
        error('未找到优化位姿文件: %s', optimized_poses_file);
    end
end

if verbose
    fprintf('检测到的输入:\n');
    fprintf('  子地图目录: %s\n', pcd_folder);
    if need_poses
        fprintf('  原始位姿: %s\n', original_poses_file);
        fprintf('  优化位姿: %s\n', optimized_poses_file);
    end
end

% 严格校验CBEE配置必需字段
required_cbee_fields = {'cell_size_xy','neighborhood_size','nbr_averages','min_points_per_cell','use_parallel'};
for i = 1:numel(required_cbee_fields)
    f = required_cbee_fields{i};
    if ~isfield(cfg.cbee, f)
        error('配置缺少字段 cfg.cbee.%s', f);
    end
end

% 值域与类型检查
if ~(isnumeric(cfg.cbee.cell_size_xy) && isscalar(cfg.cbee.cell_size_xy) && cfg.cbee.cell_size_xy > 0)
    error('cfg.cbee.cell_size_xy 必须为正标量');
end
if ~(isnumeric(cfg.cbee.neighborhood_size) && isscalar(cfg.cbee.neighborhood_size) && cfg.cbee.neighborhood_size >= 1 && mod(cfg.cbee.neighborhood_size,2)==1)
    error('cfg.cbee.neighborhood_size 必须为奇数且>=1');
end
if ~(isnumeric(cfg.cbee.nbr_averages) && isscalar(cfg.cbee.nbr_averages) && cfg.cbee.nbr_averages >= 1)
    error('cfg.cbee.nbr_averages 必须为>=1的标量');
end
if ~(isnumeric(cfg.cbee.min_points_per_cell) && isscalar(cfg.cbee.min_points_per_cell) && cfg.cbee.min_points_per_cell >= 1)
    error('cfg.cbee.min_points_per_cell 必须为>=1的标量');
end
if ~(islogical(cfg.cbee.use_parallel) || (isnumeric(cfg.cbee.use_parallel) && isscalar(cfg.cbee.use_parallel)))
    error('cfg.cbee.use_parallel 必须为逻辑值');
end
if ~(isempty(cfg.cbee.num_workers) || (isnumeric(cfg.cbee.num_workers) && isscalar(cfg.cbee.num_workers) && cfg.cbee.num_workers > 0))
    error('cfg.cbee.num_workers 必须为空或正整数');
end

% 校验 options（如存在）
if isfield(cfg.cbee, 'options') && ~isstruct(cfg.cbee.options)
    error('cfg.cbee.options 必须为 struct');
end
% 校验 visualize（如存在）
if isfield(cfg.cbee, 'visualize') && ~isstruct(cfg.cbee.visualize)
    error('cfg.cbee.visualize 必须为 struct');
end

% 标准化输出目录：带时间戳子目录
TIMESTAMP = datestr(now, cfg.global.save.timestamp);
% 使用CBEE模块配置的输出路径
RESULTS_DIR_TIMESTAMPED = fullfile(cfg.cbee.paths.output_data_results, [TIMESTAMP, '_CBEE_evaluation']);
if ~exist(RESULTS_DIR_TIMESTAMPED, 'dir')
    mkdir(RESULTS_DIR_TIMESTAMPED);
    if verbose
        fprintf('创建结果目录: %s\n', RESULTS_DIR_TIMESTAMPED);
    end
end
cfg.cbee.paths.output_dir = RESULTS_DIR_TIMESTAMPED;
% 优化子地图输出路径直接使用基础配置路径，让generateOptimizedSubmaps函数处理时间戳
cfg.cbee.paths.output_submaps_dir = cfg.cbee.paths.output_optimized_submaps;

%% 2. 并行池管理与配置摘要
actualUseParallel = false; 
poolInfo = struct();
if cfg.cbee.use_parallel
    if verbose
        fprintf('初始化并行池...\n');
    end
    seedVal = [];
    if isfield(cfg.cbee,'random_seed') && ~isempty(cfg.cbee.random_seed)
        seedVal = cfg.cbee.random_seed;
    end
    [actualUseParallel, poolInfo] = setupParallelPool(true, cfg.cbee.num_workers, seedVal, verbose);
end

% 打印配置摘要（便于复现）
if verbose
    fprintf('配置摘要:\n');
    fprintf('  cell_size_xy=%.3f, neighborhood=%dx%d, nbr_averages=%d, min_pts=%d\n', ...
        cfg.cbee.cell_size_xy, cfg.cbee.neighborhood_size, cfg.cbee.neighborhood_size, ...
        cfg.cbee.nbr_averages, cfg.cbee.min_points_per_cell);
    if isfield(poolInfo,'size')
        numWorkersText = mat2str(poolInfo.size);
    else
        numWorkersText = mat2str(cfg.cbee.num_workers);
    end
    randSeedText = mat2str([]);
    if isfield(cfg.cbee,'random_seed')
        randSeedText = mat2str(cfg.cbee.random_seed);
    end
    fprintf('  use_parallel=%d, num_workers=%s, random_seed=%s\n', ...
        actualUseParallel, numWorkersText, randSeedText);
    if isfield(cfg.cbee, 'options')
        go = 0; so = 0; sc = 0; lo = 0;
        if isfield(cfg.cbee.options,'generate_optimized_submaps'); go = cfg.cbee.options.generate_optimized_submaps; end
        if isfield(cfg.cbee.options,'save_optimized_submaps');     so = cfg.cbee.options.save_optimized_submaps;     end
        if isfield(cfg.cbee.options,'save_CBEE_data_results');     sc = cfg.cbee.options.save_CBEE_data_results;     end
        if isfield(cfg.cbee.options,'load_only');                   lo = cfg.cbee.options.load_only;                  end
        fprintf('  options: generate_optimized_submaps=%d, save_optimized_submaps=%d, save_CBEE_data_results=%d, load_only=%d\n', ...
            go, so, sc, lo);
    end
end

%% 3. 生成优化子地图
opt_pcd_dir = cfg.cbee.paths.gt_pcd_dir;  % 默认使用原始子地图
temp_opt_dir = '';
used_temp_submaps_dir = false;

if isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'generate_optimized_submaps') && cfg.cbee.options.generate_optimized_submaps
    try
        if verbose
            fprintf('生成优化子地图...\n');
        end
        % 选择输出目录：根据是否持久化决定输出到正式目录或临时目录
    target_submaps_dir = cfg.cbee.paths.output_submaps_dir;
    save_to_disk = (isfield(cfg.cbee.options,'save_optimized_submaps') && cfg.cbee.options.save_optimized_submaps);
        if ~save_to_disk
            used_temp_submaps_dir = true;
        end

    opt_pcd_dir = generateOptimizedSubmaps(cfg.cbee.paths.gt_pcd_dir, ...
                                            cfg.cbee.paths.poses_original, ...
                                            cfg.cbee.paths.poses_optimized, ...
                                            target_submaps_dir, ...
                                            'UseParallel',actualUseParallel, ...
                                            'Verbose', verbose, ...
                                            'Verify', true, ...
                                            'cfg', cfg, ...
                                            'SaveToDisk', save_to_disk);
        % 若未持久化保存，则记录临时目录以便后续清理
        if ~save_to_disk
            temp_opt_dir = opt_pcd_dir;
        end

        if verbose
            fprintf('优化子地图已生成至: %s\n', opt_pcd_dir);
        end
    catch ME
        warning('生成优化子地图失败: %s\n回退使用原始子地图...\n', string(ME.message));
    end
end

%% 4. 加载子地图数据
if verbose
    fprintf('加载子地图数据...\n');
end

measurements = loadAllSubmaps(opt_pcd_dir, ...
                   'TransformToGlobal', true, ...
                   'UseParallel', false, ...
                   'Verbose', verbose);

% 如果需要，可视化加载的子地图
if isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable
    if verbose
        fprintf('可视化子地图...\n');
    end
    sample_rate_val = cfg.cbee.visualize.sample_rate;
    if isfield(cfg.cbee.visualize,'sample_rate'); sample_rate_val = cfg.cbee.visualize.sample_rate; end
    show_individual = false;
    if isfield(cfg.cbee.visualize,'plot_individual_submaps')
        show_individual = logical(cfg.cbee.visualize.plot_individual_submaps);
    end
    visualizeSubmaps(measurements, ...
                    'ColorBy', 'z', ...
                    'SampleRate', sample_rate_val, ...
                    'ShowIndividual', show_individual, ...
                    'GlobalVisual', cfg.global.visual);
    drawnow;
end

%% 5. 构建CBEE一致性误差栅格
if isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'load_only') && cfg.cbee.options.load_only
    if verbose
        fprintf('仅加载模式，跳过CBEE计算...\n');
    end
    return;
end

if verbose
    fprintf('构建CBEE一致性误差栅格...\n');
end

% 准备网格参数
gridParams = struct();
gridParams.cell_size_xy = cfg.cbee.cell_size_xy;
gridParams.neighborhood_size = cfg.cbee.neighborhood_size;
gridParams.nbr_averages = cfg.cbee.nbr_averages;
gridParams.min_points_per_cell = cfg.cbee.min_points_per_cell;
gridParams.use_parallel = actualUseParallel;
if isfield(cfg.cbee,'random_seed')
    gridParams.random_seed = cfg.cbee.random_seed;
end
% 距离查询/加速方式 (若配置中存在)
if isfield(cfg.cbee,'options')
    if isfield(cfg.cbee.options,'distance_method') && ~isempty(cfg.cbee.options.distance_method)
        gridParams.distance_method = cfg.cbee.options.distance_method; % 'bruteforce' | 'kdtree'
    end
    if isfield(cfg.cbee.options,'kdtree_min_points') && ~isempty(cfg.cbee.options.kdtree_min_points)
        gridParams.kdtree_min_points = cfg.cbee.options.kdtree_min_points;
    end
end
% 传递高程相关配置（若存在则覆盖默认）
if isfield(cfg.cbee,'elevation_method');     gridParams.elevation_method = cfg.cbee.elevation_method; end
if isfield(cfg.cbee,'elevation_interp');     gridParams.elevation_interp = cfg.cbee.elevation_interp; end
if isfield(cfg.cbee,'elevation_smooth_win'); gridParams.elevation_smooth_win = cfg.cbee.elevation_smooth_win; end
if isfield(cfg.cbee,'elevation_mask_enable'); gridParams.elevation_mask_enable = cfg.cbee.elevation_mask_enable; end
if isfield(cfg.cbee,'elevation_mask_radius'); gridParams.elevation_mask_radius = cfg.cbee.elevation_mask_radius; end

% 执行栅格构建
if verbose
    fprintf('构建CBEE一致性误差栅格...\n');
end
[value_grid, overlap_mask, grid_meta, map_grid] = buildCbeeErrorGrid(measurements, gridParams);

%% 6. 计算RMS一致性误差
if verbose
    fprintf('计算RMS一致性误差...\n');
end

% 计算RMS并获取完整统计信息
rms_result = computeRmsConsistencyError(value_grid, overlap_mask);

% 显示主要结果
fprintf('\n--- CBEE评估结果 ---\n');
fprintf('RMS一致性误差: %.6f\n', rms_result.rms_value);
fprintf('有效格比例: %.1f%% (%d/%d)\n', ...
        rms_result.grid_stats.valid_ratio * 100, ...
        rms_result.grid_stats.valid_cells, ...
        rms_result.grid_stats.total_cells);
fprintf('误差范围: [%.4f, %.4f]\n', ...
        rms_result.error_stats.min, ...
        rms_result.error_stats.max);
fprintf('计算耗时: %.2f秒\n', rms_result.metadata.computation_time);

%% 7. 一致性误差热力图可视化
if verbose
    fprintf('生成结果可视化与导出文件...\n');
end

% 仅在需要保存图像或需要显示时创建图窗
if (isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'save_CBEE_data_results') && cfg.cbee.options.save_CBEE_data_results) ...
    || (isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable)
    % 一致性误差热力图（透明显示无效格）
    gv = cfg.global.visual;
    axis_fs = round(gv.font_size_base * gv.font_size_multiple);
    title_fs = axis_fs; cb_fs = axis_fs;
    fig_w_cm = gv.figure_width_cm * gv.figure_size_multiple;
    fig_h_cm = gv.figure_height_cm * gv.figure_size_multiple;

    fig = figure('Color', 'w', 'Units','centimeters', 'Position', [2, 2, fig_w_cm, fig_h_cm], ...
                 'Name','CBEE Error Map', 'NumberTitle','off');
    % 使用物理坐标范围绘制，并将Y轴正向
    x_range = [grid_meta.x_min, grid_meta.x_min + grid_meta.grid_w * grid_meta.cell_size_xy];
    y_range = [grid_meta.y_min, grid_meta.y_min + grid_meta.grid_h * grid_meta.cell_size_xy];
    himg = imagesc(x_range, y_range, value_grid);
    set(gca, 'YDir', 'normal');
    axis image;
    if isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'colormap')
        colormap(cfg.cbee.visualize.colormap);
    else
        colormap(parula);
    end
    cb = colorbar; cb.Label.String = 'Consistency Error';
    cb.Label.FontSize = cb_fs; cb.Label.FontName = gv.font_name;
    % 不绘制标题，避免信息冗余（RMS写入文件名）

    % 将无效格置为透明
    alpha_data = ~isnan(value_grid);
    set(himg, 'AlphaData', alpha_data);

    % 坐标轴样式与标签
    set(gca, 'FontName', gv.font_name, 'FontSize', axis_fs);
    xlabel('X (m)', 'FontName', gv.font_name, 'FontSize', axis_fs);
    ylabel('Y (m)', 'FontName', gv.font_name, 'FontSize', axis_fs);

    % 终端输出统计信息（替代图内文本框）
    fprintf('\n[CBEE 热力图统计]\n');
    fprintf('  有效格数: %d (%.1f%%%%)\n', rms_result.grid_stats.valid_cells, rms_result.grid_stats.valid_ratio * 100);
    fprintf('  RMS值: %.4f\n', rms_result.rms_value);
    fprintf('  误差范围: [%.4f, %.4f]\n', rms_result.error_stats.min, rms_result.error_stats.max);

% 7.1 保存图形结果与管理
    % 图片保存 gating：需要 CBEE 保存选项 且 全局图像保存开启
    figures_enabled = cfg.global.save.figures;
    save_cbee_opt = (isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'save_CBEE_data_results') && cfg.cbee.options.save_CBEE_data_results);
    if save_cbee_opt && figures_enabled
        % 导出格式/分辨率（使用全局配置）
        formats = cfg.global.save.formats;
        dpi_val = cfg.global.save.dpi;
        dpi_opt = ['-r', num2str(dpi_val)];
        % 文件名追加RMS值后缀
        rms_suffix = sprintf('_RMS_%.4f', rms_result.rms_value);
        base_file = fullfile(cfg.cbee.paths.output_dir, ['cbee_error_map', rms_suffix]);
        for k = 1:numel(formats)
            fmt = lower(formats{k});
            switch fmt
                case 'png'
                    print(fig, [base_file, '.png'], '-dpng', dpi_opt);
                case 'eps'
                    print(fig, [base_file, '.eps'], '-depsc', dpi_opt);
                otherwise
                    warning('Unsupported export format: %s', fmt);
            end
        end
        if verbose
            fprintf('  > 已保存热力图: %s (formats: %s)\n', base_file, strjoin(formats, ','));
        end
    end
    
    % 保存完成后才关闭图形（避免句柄失效）
    if ~(isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable)
        close(fig);
    end
    
    %% 8. 高程地图可视化与保存
    % 创建高程地图图窗
    fig_elevation = figure('Color', 'w', 'Units','centimeters', 'Position', [4, 4, fig_w_cm, fig_h_cm], ...
                          'Name','Elevation Map', 'NumberTitle','off');
    
    % 使用物理坐标范围绘制高程地图
    himg_elev = imagesc(x_range, y_range, map_grid);
    set(gca, 'YDir', 'normal');
    axis image;
    
    % 使用适合高程的颜色映射
    colormap(jet);  % 高程常用jet或terrain颜色映射
    
    cb_elev = colorbar; cb_elev.Label.String = 'Elevation (m)';
    cb_elev.Label.FontSize = cb_fs; cb_elev.Label.FontName = gv.font_name;
    
    % 将无效格置为透明
    alpha_data_elev = ~isnan(map_grid);
    set(himg_elev, 'AlphaData', alpha_data_elev);
    
    % 坐标轴样式与标签
    set(gca, 'FontName', gv.font_name, 'FontSize', axis_fs);
    xlabel('X (m)', 'FontName', gv.font_name, 'FontSize', axis_fs);
    ylabel('Y (m)', 'FontName', gv.font_name, 'FontSize', axis_fs);
    
    % 终端输出高程统计信息
    valid_elevation_data = map_grid(~isnan(map_grid));
    if ~isempty(valid_elevation_data)
        fprintf('\n[高程地图统计]\n');
        fprintf('  有效格数: %d (%.1f%%%%)\n', sum(~isnan(map_grid(:))), sum(~isnan(map_grid(:)))/numel(map_grid)*100);
        fprintf('  高程范围: [%.2f, %.2f] m\n', min(valid_elevation_data), max(valid_elevation_data));
        fprintf('  平均高程: %.2f m\n', mean(valid_elevation_data));
    end
    
    % 保存高程地图（使用相同的保存逻辑）
    if save_cbee_opt && figures_enabled
        % 文件名追加高程地图标识
        elev_base_file = fullfile(cfg.cbee.paths.output_dir, ['cbee_elevation_map', rms_suffix]);
        for k = 1:numel(formats)
            fmt = lower(formats{k});
            switch fmt
                case 'png'
                    print(fig_elevation, [elev_base_file, '.png'], '-dpng', dpi_opt);
                case 'eps'
                    print(fig_elevation, [elev_base_file, '.eps'], '-depsc', dpi_opt);
                otherwise
                    warning('Unsupported export format: %s', fmt);
            end
        end
        if verbose
            fprintf('  > 已保存高程地图: %s (formats: %s)\n', elev_base_file, strjoin(formats, ','));
        end
    end
    
    % 保存完成后才关闭高程图形
    if ~(isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable)
        close(fig_elevation);
    end
end

%% 9. 数据导出与持久化
% 数据保存 gating：需要 CBEE 保存选项 且 全局数据保存开启
data_enabled = cfg.global.save.data;

if save_cbee_opt && data_enabled
    % 导出栅格CSV（仅导出有效格）
    [H, W] = size(value_grid);
    [J, I] = meshgrid(1:W, 1:H);  % 注意I行、J列
    valid_idx = ~isnan(value_grid);
    T = table(I(valid_idx), J(valid_idx), value_grid(valid_idx), ...
              'VariableNames', {'row', 'col', 'error'});
    rms_suffix = sprintf('_RMS_%.4f', rms_result.rms_value);
    grid_csv_path = fullfile(cfg.cbee.paths.output_dir, ['cbee_error_grid', rms_suffix, '.csv']);
    writetable(T, grid_csv_path);
    if verbose
        fprintf('  > 已保存栅格数据: %s\n', grid_csv_path);
    end
    
    % 导出高程栅格CSV（仅导出有效格）
    valid_elev_idx = ~isnan(map_grid);
    if sum(valid_elev_idx(:)) > 0
        T_elev = table(I(valid_elev_idx), J(valid_elev_idx), map_grid(valid_elev_idx), ...
                      'VariableNames', {'row', 'col', 'elevation'});
        elev_csv_path = fullfile(cfg.cbee.paths.output_dir, ['cbee_elevation_grid', rms_suffix, '.csv']);
        writetable(T_elev, elev_csv_path);
        if verbose
            fprintf('  > 已保存高程栅格数据: %s\n', elev_csv_path);
        end
    end

    % 导出完整统计报告
    rms_txt_path = fullfile(cfg.cbee.paths.output_dir, ['cbee_rms_complete', rms_suffix, '.txt']);
    fid = fopen(rms_txt_path, 'w');
    
    % 写入标题和时间戳
    fprintf(fid, '=== CBEE一致性误差完整统计报告 ===\n');
    fprintf(fid, '生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '文件名后缀RMS值: %.6f\n\n', rms_result.rms_value);
    
    % 1. 主要结果
    fprintf(fid, '--- 主要结果 ---\n');
    fprintf(fid, 'RMS一致性误差: %.6f\n\n', rms_result.rms_value);
    
    % 2. 网格统计信息
    fprintf(fid, '--- 网格统计信息 ---\n');
    fprintf(fid, '总格子数: %d\n', rms_result.grid_stats.total_cells);
    fprintf(fid, '有效格子数: %d\n', rms_result.grid_stats.valid_cells);
    fprintf(fid, '有效格子比例: %.4f (%.2f%%)\n', rms_result.grid_stats.valid_ratio, rms_result.grid_stats.valid_ratio * 100);
    fprintf(fid, '有限误差值格子数: %d\n', rms_result.grid_stats.finite_cells);
    fprintf(fid, '有限格子比例: %.4f (%.2f%%)\n\n', rms_result.grid_stats.finite_ratio, rms_result.grid_stats.finite_ratio * 100);
    
    % 3. 误差值统计信息  
    fprintf(fid, '--- 误差值统计信息 ---\n');
    fprintf(fid, '最小误差值: %.6f\n', rms_result.error_stats.min);
    fprintf(fid, '最大误差值: %.6f\n', rms_result.error_stats.max);
    fprintf(fid, '平均误差值: %.6f\n', rms_result.error_stats.mean);
    fprintf(fid, '误差值标准差: %.6f\n', rms_result.error_stats.std);
    fprintf(fid, '误差值中位数: %.6f\n', rms_result.error_stats.median);
    fprintf(fid, '25%%分位数: %.6f\n', rms_result.error_stats.p25);
    fprintf(fid, '75%%分位数: %.6f\n\n', rms_result.error_stats.p75);
    
    % 4. 有效性指标
    fprintf(fid, '--- 有效性指标 ---\n');
    fprintf(fid, '是否成功计算RMS: %s\n', mat2str(rms_result.validity.is_valid));
    fprintf(fid, '是否有重叠区域: %s\n', mat2str(rms_result.validity.has_overlap));
    fprintf(fid, '所有有效值都是有限的: %s\n\n', mat2str(rms_result.validity.all_finite));
    
    % 5. 计算元信息
    fprintf(fid, '--- 计算元信息 ---\n');
    fprintf(fid, '计算耗时: %.4f 秒\n', rms_result.metadata.computation_time);
    fprintf(fid, '计算时间戳: %s\n', datestr(rms_result.metadata.timestamp, 'yyyy-mm-dd HH:MM:SS.FFF'));
    
    fclose(fid);
    if verbose
        fprintf('  > 已保存完整RMS统计信息: %s\n', rms_txt_path);
    end

    % 保存完整结果数据（包含元数据）
    save_data.rms_result = rms_result;
    save_data.grid_meta = grid_meta;
    save_data.map_grid = map_grid;  % 添加高程地图数据
    save_data.config = cfg.cbee;
    save_data.timestamp = datetime('now');
    results_mat_path = fullfile(cfg.cbee.paths.output_dir, ['cbee_results', rms_suffix, '.mat']);
    save(results_mat_path, '-struct', 'save_data');
    if verbose
        fprintf('  > 已保存完整结果: %s\n', results_mat_path);
    end
end

%% 10. 环境清理与完成
% 若使用了临时优化子地图目录且不需要持久化，清理之
if used_temp_submaps_dir && ~cfg.cbee.options.save_optimized_submaps
    try
        if exist(temp_opt_dir, 'dir')
            rmdir(temp_opt_dir, 's');
            if verbose
                fprintf('已清理临时优化子地图目录: %s\n', temp_opt_dir);
            end
        end
    catch ME
        warning('清理临时优化子地图目录失败: %s', string(ME.message));
    end
end

% 完成
totalTime = toc(startTime);
if verbose
    fprintf('\n=== CBEE评估完成 ===\n');
    fprintf('总耗时: %.2f秒\n\n', totalTime);
end
