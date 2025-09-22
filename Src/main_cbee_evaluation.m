function main_cbee_evaluation(varargin)
% main_cbee_evaluation 执行CBEE一致性误差评估的顶层脚本
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
%   main_cbee_evaluation()                 - 使用config.m中的默认配置
%   main_cbee_evaluation('ConfigFile', 'myconfig.m') - 使用自定义配置文件
%   main_cbee_evaluation('SkipOptimizedSubmaps', true) - 跳过子地图生成
%
% 输入参数:
%   Name-Value对:
%     'ConfigFile'         - 自定义配置文件名 (默认: 使用内置config.m)
%     'SkipOptimizedSubmaps' - 是否跳过优化子地图生成 (默认: false)
%     'Verbose'             - 是否输出详细信息 (默认: true)
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
%   main_cbee_evaluation()
%
%   % 使用自定义配置
%   main_cbee_evaluation('ConfigFile', 'my_cbee_config.m')
%
% 另请参阅: config, buildCbeeErrorGrid, computeRmsConsistencyError
%
% 作者: CBEE评估工具包
% 日期: 2025-09-22

%% 解析输入参数
p = inputParser;
addParameter(p, 'ConfigFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'SkipOptimizedSubmaps', false, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, varargin{:});

configFile = p.Results.ConfigFile;
skipOptimizedSubmaps = p.Results.SkipOptimizedSubmaps;
verbose = p.Results.Verbose;

%% 1. 加载配置
startTime = tic;
if verbose
    fprintf('\n=== CBEE一致性误差评估开始 ===\n');
    fprintf('加载配置...\n');
end

if isempty(configFile)
    cfg = config();
else
    % 动态加载自定义配置
    [~, funcName, ~] = fileparts(configFile);
    addpath(fileparts(which(configFile)));
    cfg = feval(funcName);
end

% 强制覆盖配置选项（根据输入参数）
if skipOptimizedSubmaps
    cfg.cbee.options.generate_optimized_submaps = false;
end

% 确保输出目录存在
if ~exist(cfg.paths.output_dir, 'dir')
    mkdir(cfg.paths.output_dir);
end

%% 2. 并行池管理
if cfg.cbee.use_parallel
    if verbose
        fprintf('初始化并行池...\n');
    end
    
    if isempty(gcp('nocreate'))
        if isempty(cfg.cbee.num_workers)
            parpool('local');
        else
            parpool('local', cfg.cbee.num_workers);
        end
    end
    
    % 设置固定随机种子以确保结果可复现
    if ~isempty(cfg.cbee.random_seed)
        rng(cfg.cbee.random_seed);
    end
end

%% 3. 生成优化子地图（可选）
opt_pcd_dir = cfg.paths.gt_pcd_dir;  % 默认使用原始子地图
temp_opt_dir = '';
used_temp_submaps_dir = false;

if cfg.cbee.options.generate_optimized_submaps
    try
        if verbose
            fprintf('生成优化子地图...\n');
        end
        % 选择输出目录：根据是否持久化决定输出到正式目录或临时目录
        target_submaps_dir = cfg.paths.output_submaps_dir;
        save_to_disk = cfg.cbee.options.save_optimized_submaps; % 默认false
        if ~save_to_disk
            used_temp_submaps_dir = true;
        end

        opt_pcd_dir = generateOptimizedSubmaps(cfg.paths.gt_pcd_dir, ...
                                            cfg.paths.poses_original, ...
                                            cfg.paths.poses_optimized, ...
                                            target_submaps_dir, ...
                                            'UseParallel', cfg.cbee.use_parallel, ...
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
                   'UseParallel', cfg.cbee.use_parallel, ...
                   'Verbose', verbose);

% 如果需要，可视化加载的子地图
if cfg.cbee.visualize.enable && cfg.cbee.visualize.plot_individual_submaps
    if verbose
        fprintf('可视化子地图...\n');
    end
    visualizeSubmaps(measurements, ...
                    'ColorBy', 'z', ...
                    'SampleRate', cfg.cbee.visualize.sample_rate, ...
                    'UseParallel', cfg.cbee.use_parallel, ...
                    'Title', '加载的子地图点云');
    drawnow;
end

%% 5. 构建一致性误差栅格
if cfg.cbee.options.load_only
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
gridParams.use_parallel = cfg.cbee.use_parallel;
gridParams.random_seed = cfg.cbee.random_seed;

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
if cfg.cbee.options.save_CBEE_data_results || cfg.cbee.visualize.enable
    % 7.1 热力图（透明显示无效格）
    fig = figure('Color', 'w');
    imagesc(value_grid);
    axis image;
    colormap(cfg.cbee.visualize.colormap);
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
    if cfg.cbee.options.save_CBEE_data_results
        saveas(fig, fullfile(cfg.paths.output_dir, 'cbee_error_map.png'));
        if verbose
            fprintf('  > 已保存热力图: %s\n', fullfile(cfg.paths.output_dir, 'cbee_error_map.png'));
        end
    end
    if ~cfg.cbee.visualize.enable
        close(fig);
    end
end

if cfg.cbee.options.save_CBEE_data_results
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

end
