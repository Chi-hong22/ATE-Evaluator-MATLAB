%% main_evaluateCBEE - CBEE一致性误差评估执行脚本
% main_evaluateCBEE 执行CBEE一致性误差评估的顶层脚本
%
% 该脚本集成了CBEE评估的完整工作流程，从数据加载到结果导出，按照以下步骤执行：
%   1. 加载并初始化配置
%   2. 生成优化子地图（可选）
%   3. 加载子地图数据（原始或优化后的）
%   4. 构建CBEE一致性误差栅格
%   5. 计算RMS一致性误差
%   6. 可视化与导出结果
%
% 用法:
%   直接运行此脚本: run('Src/main_evaluateCBEE.m')
%   或在MATLAB命令窗口中: main_evaluateCBEE
%
% 配置参数:
%   在运行脚本前可以在工作空间设置以下变量：
%     skip_optimized_submaps - 是否跳过优化子地图生成 (默认: false)
%     verbose_output        - 是否显示详细输出 (默认: true)
%
% 输出:
%   生成的文件:
%     - cbee_error_map.png: 一致性误差热力图
%     - cbee_rms.txt: RMS一致性误差数值
%     - cbee_error_grid.csv: 误差栅格数据
%     - cbee_results.mat: 完整结果数据
%
% 示例:
%   % 基本使用（默认配置）
%   run('Src/main_evaluateCBEE.m')
%
%   % 自定义配置示例
%   skip_optimized_submaps = true;    % 跳过优化子地图生成
%   verbose_output = false;           % 关闭详细输出
%   run('Src/main_evaluateCBEE.m')
%
% 另请参阅: config, buildCbeeErrorGrid, computeRmsConsistencyError
%
% 作者: CBEE评估工具包
% 日期: 2025-09-22

%% 脚本配置参数
% 在运行前可以在工作空间设置以下变量来自定义行为

clear; close all; clc;

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
required_path_fields = {'gt_pcd_dir','poses_original','poses_optimized','output_dir'};
for i = 1:numel(required_path_fields)
    f = required_path_fields{i};
    if ~isfield(cfg, 'paths') || ~isfield(cfg.paths, f)
        error('配置缺少路径字段 cfg.paths.%s', f);
    end
end
if ~isfield(cfg, 'cbee')
    error('配置缺少 cfg.cbee 段');
end

% 构建关键文件路径（使用任务六定义的字段）
pcd_folder = cfg.paths.gt_pcd_dir;
original_poses_file = cfg.paths.poses_original;
optimized_poses_file = cfg.paths.poses_optimized;

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
TIMESTAMP = datestr(now, 'yyyymmdd_HHMMSS');
RESULTS_DIR_TIMESTAMPED = fullfile(cfg.paths.output_dir, [TIMESTAMP, '_CBEE_evaluation']);
if ~exist(RESULTS_DIR_TIMESTAMPED, 'dir')
    mkdir(RESULTS_DIR_TIMESTAMPED);
    if verbose
        fprintf('创建结果目录: %s\n', RESULTS_DIR_TIMESTAMPED);
    end
end
cfg.paths.output_dir = RESULTS_DIR_TIMESTAMPED;
% 确保输出子地图目录存在（如需使用）
if ~isfield(cfg.paths, 'output_submaps_dir') || isempty(cfg.paths.output_submaps_dir)
    cfg.paths.output_submaps_dir = fullfile(cfg.paths.output_dir, 'submaps');
end

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

%% 3. 生成优化子地图（可选）
opt_pcd_dir = cfg.paths.gt_pcd_dir;  % 默认使用原始子地图
temp_opt_dir = '';
used_temp_submaps_dir = false;

if isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'generate_optimized_submaps') && cfg.cbee.options.generate_optimized_submaps
    try
        if verbose
            fprintf('生成优化子地图...\n');
        end
        % 选择输出目录：根据是否持久化决定输出到正式目录或临时目录
    target_submaps_dir = cfg.paths.output_submaps_dir;
    save_to_disk = (isfield(cfg.cbee.options,'save_optimized_submaps') && cfg.cbee.options.save_optimized_submaps);
        if ~save_to_disk
            used_temp_submaps_dir = true;
        end

    opt_pcd_dir = generateOptimizedSubmaps(cfg.paths.gt_pcd_dir, ...
                                            cfg.paths.poses_original, ...
                                            cfg.paths.poses_optimized, ...
                                            target_submaps_dir, ...
                        'UseParallel', actualUseParallel, ...
                                            'Verbose', verbose, ...
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
                   'UseParallel', actualUseParallel, ...
                   'Verbose', verbose);

% 如果需要，可视化加载的子地图
if isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable ...
    && isfield(cfg.cbee.visualize,'plot_individual_submaps') && cfg.cbee.visualize.plot_individual_submaps
    if verbose
        fprintf('可视化子地图...\n');
    end
    sample_rate_val = 0.05;
    if isfield(cfg.cbee.visualize,'sample_rate'); sample_rate_val = cfg.cbee.visualize.sample_rate; end
    visualizeSubmaps(measurements, ...
                    'ColorBy', 'z', ...
                    'SampleRate', sample_rate_val, ...
                    'UseParallel', actualUseParallel, ...
                    'Title', '加载的子地图点云');
    drawnow;
end

%% 5. 构建一致性误差栅格
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

% 执行栅格构建
[value_grid, overlap_mask, grid_meta] = buildCbeeErrorGrid(measurements, gridParams);

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

%% 7. 可视化与导出结果
if verbose
    fprintf('生成结果可视化与导出文件...\n');
end

% 仅在需要保存图像或需要显示时创建图窗
if (isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'save_CBEE_data_results') && cfg.cbee.options.save_CBEE_data_results) ...
    || (isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable)
    % 7.1 热力图（透明显示无效格）
    fig = figure('Color', 'w');
    imagesc(value_grid);
    axis image;
    if isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'colormap')
        colormap(cfg.cbee.visualize.colormap);
    else
        colormap(parula);
    end
    colorbar;
    title(sprintf('CBEE一致性误差图 (RMS=%.4f)', rms_result.rms_value));

    % 将无效格置为透明
    alpha_data = ~isnan(value_grid);
    hold on;
    set(gca, 'ALim', [0 1]);
    set(get(gca,'Children'), 'AlphaData', alpha_data);

    % 添加信息文本框
    dim = [0.15 0.15 0.3 0.3];
    str = sprintf(['有效格数: %d (%.1f%%)\n', ...
                  'RMS值: %.4f\n', ...
                  '误差范围: [%.4f, %.4f]'], ...
                  rms_result.grid_stats.valid_cells, ...
                  rms_result.grid_stats.valid_ratio * 100, ...
                  rms_result.rms_value, ...
                  rms_result.error_stats.min, ...
                  rms_result.error_stats.max);
    annotation('textbox', dim, 'String', str, 'FitBoxToText', true, ...
               'BackgroundColor', 'w', 'EdgeColor', 'k');

    % 保存或关闭
    if isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'save_CBEE_data_results') && cfg.cbee.options.save_CBEE_data_results
        saveas(fig, fullfile(cfg.paths.output_dir, 'cbee_error_map.png'));
        if verbose
            fprintf('  > 已保存热力图: %s\n', fullfile(cfg.paths.output_dir, 'cbee_error_map.png'));
        end
    end
    if ~(isfield(cfg.cbee,'visualize') && isfield(cfg.cbee.visualize,'enable') && cfg.cbee.visualize.enable)
        close(fig);
    end
end

if isfield(cfg.cbee,'options') && isfield(cfg.cbee.options,'save_CBEE_data_results') && cfg.cbee.options.save_CBEE_data_results
    % 7.2 导出栅格CSV（仅导出有效格）
    [H, W] = size(value_grid);
    [J, I] = meshgrid(1:W, 1:H);  % 注意I行、J列
    valid_idx = ~isnan(value_grid);
    T = table(I(valid_idx), J(valid_idx), value_grid(valid_idx), ...
              'VariableNames', {'row', 'col', 'error'});
    writetable(T, fullfile(cfg.paths.output_dir, 'cbee_error_grid.csv'));
    if verbose
        fprintf('  > 已保存栅格数据: %s\n', fullfile(cfg.paths.output_dir, 'cbee_error_grid.csv'));
    end

    % 7.3 导出RMS文本与MAT结果
    fid = fopen(fullfile(cfg.paths.output_dir, 'cbee_rms.txt'), 'w');
    fprintf(fid, 'RMS=%.6f\n', rms_result.rms_value);
    fclose(fid);
    if verbose
        fprintf('  > 已保存RMS值: %s\n', fullfile(cfg.paths.output_dir, 'cbee_rms.txt'));
    end

    % 包含元数据的完整结果保存
    save_data.rms_result = rms_result;
    save_data.grid_meta = grid_meta;
    save_data.config = cfg.cbee;
    save_data.timestamp = datetime('now');
    save(fullfile(cfg.paths.output_dir, 'cbee_results.mat'), '-struct', 'save_data');
    if verbose
        fprintf('  > 已保存完整结果: %s\n', fullfile(cfg.paths.output_dir, 'cbee_results.mat'));
    end
end

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
