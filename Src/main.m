%% ATE 分析主脚本
clear; close all; clc;

%% --- 1. 配置 ---
% 添加Src目录到MATLAB路径
addpath(genpath('Src'));

% 加载配置参数
cfg = config();

% 构建完整文件路径
gt_file_path = fullfile(cfg.INPUT_FOLDER, cfg.GT_FILE_NAME);
est_corrupted_path = fullfile(cfg.INPUT_FOLDER, cfg.EST_CORRUPTED_FILE_NAME);
est_optimized_path = fullfile(cfg.INPUT_FOLDER, cfg.EST_OPTIMIZED_FILE_NAME);

% 检查文件存在性
gt_exists = isfile(gt_file_path);
corrupted_exists = isfile(est_corrupted_path);
optimized_exists = isfile(est_optimized_path);

% 验证输入
if ~gt_exists
    error('未找到真值轨迹文件: %s', gt_file_path);
end

if ~corrupted_exists && ~optimized_exists
    error('未找到任何估计轨迹文件 (%s 或 %s)', est_corrupted_path, est_optimized_path);
end

fprintf('检测到的文件:\n');
fprintf('  真值轨迹: %s\n', gt_file_path);
if corrupted_exists
    fprintf('  估计轨迹(corrupted): %s\n', est_corrupted_path);
end
if optimized_exists
    fprintf('  估计轨迹(optimized): %s\n', est_optimized_path);
end

% 定义结果保存路径
TIMESTAMP = datestr(now, 'yyyy-mm-dd_HH-MM');
RESULTS_DIR_TIMESTAMPED = fullfile(cfg.RESULTS_DIR_BASE, TIMESTAMP);

if (cfg.SAVE_FIGURES || cfg.SAVE_DATA) && ~exist(RESULTS_DIR_TIMESTAMPED, 'dir')
    mkdir(RESULTS_DIR_TIMESTAMPED);
end

%% --- 2. 加载真值轨迹 ---
fprintf('\n正在加载真值轨迹数据...\n');
try
    [gt_timestamps, gt_traj] = readTrajectory(gt_file_path);
    fprintf('真值轨迹加载成功，共 %d 个数据点。\n', size(gt_traj, 1));
catch ME
    error('加载真值轨迹失败: %s', ME.message);
end
raw_gt_traj = gt_traj;

%% --- 3. 处理估计轨迹并计算ATE ---
trajectory_results = {}; % 存储所有轨迹的结果
trajectory_names = {}; % 存储轨迹名称
trajectory_data = {}; % 存储完整的轨迹数据用于保存

% 处理 corrupted 轨迹
if corrupted_exists
    fprintf('\n正在处理 corrupted 轨迹...\n');
    try
        [est_timestamps, est_traj] = readTrajectory(est_corrupted_path);
        raw_corr_traj = est_traj;
        [ate_metrics, aligned_est_traj, gt_associated_traj] = alignAndComputeATE(gt_timestamps, gt_traj, est_timestamps, est_traj);
        
        trajectory_results{end+1} = struct('ate_metrics', ate_metrics, 'aligned_est_traj', aligned_est_traj, 'gt_associated_traj', gt_associated_traj);
        trajectory_names{end+1} = 'corrupted';
        
        % 存储完整数据
        trajectory_data{end+1} = struct(...
            'timestamps', gt_timestamps(gt_timestamps >= est_timestamps(1) & gt_timestamps <= est_timestamps(end)), ...
            'original_estimated', interp1(est_timestamps, est_traj, gt_timestamps(gt_timestamps >= est_timestamps(1) & gt_timestamps <= est_timestamps(end)), 'linear'), ...
            'aligned_estimated', aligned_est_traj, ...
            'ground_truth', gt_associated_traj, ...
            'alignment_type', 'SE3');
        
        fprintf('Corrupted 轨迹 ATE 计算完成。RMSE: %.4f m\n', ate_metrics.rmse);
    catch ME
        warning('MATLAB:trajectory:corrupted', '处理 corrupted 轨迹失败: %s', ME.message);
    end
end

% 处理 optimized 轨迹
if optimized_exists
    fprintf('\n正在处理 optimized 轨迹...\n');
    try
        [est_timestamps, est_traj] = readTrajectory(est_optimized_path);
        raw_opt_traj = est_traj;
        [ate_metrics, aligned_est_traj, gt_associated_traj] = alignAndComputeATE(gt_timestamps, gt_traj, est_timestamps, est_traj);
        
        trajectory_results{end+1} = struct('ate_metrics', ate_metrics, 'aligned_est_traj', aligned_est_traj, 'gt_associated_traj', gt_associated_traj);
        trajectory_names{end+1} = 'optimized';
        
        % 存储完整数据
        trajectory_data{end+1} = struct(...
            'timestamps', gt_timestamps(gt_timestamps >= est_timestamps(1) & gt_timestamps <= est_timestamps(end)), ...
            'original_estimated', interp1(est_timestamps, est_traj, gt_timestamps(gt_timestamps >= est_timestamps(1) & gt_timestamps <= est_timestamps(end)), 'linear'), ...
            'aligned_estimated', aligned_est_traj, ...
            'ground_truth', gt_associated_traj, ...
            'alignment_type', 'SE3');
        
        fprintf('Optimized 轨迹 ATE 计算完成。RMSE: %.4f m\n', ate_metrics.rmse);
    catch ME
        warning('MATLAB:trajectory:optimized', '处理 optimized 轨迹失败: %s', ME.message);
    end
end

%% --- 4. 可视化 ---
fprintf('\n正在生成可视化结果...\n');
all_figures = [];
figure_names = {};

% 4.0 原始轨迹图
fig_raw = figure('Name', 'Trajectories (Raw)');
ax = gca;

% 准备轨迹数据
corr_traj = [];
opt_traj = [];
if exist('raw_corr_traj', 'var')
    corr_traj = raw_corr_traj;
end
if exist('raw_opt_traj', 'var')
    opt_traj = raw_opt_traj;
end

% 调用合并后的plotTrajectories函数
plotTrajectories(ax, raw_gt_traj, corr_traj, opt_traj, cfg, 'raw');

all_figures(end+1) = fig_raw;
figure_names{end+1} = 'trajectories_raw';

% 为每个轨迹生成可视化
for i = 1:length(trajectory_results)
    result = trajectory_results{i};
    traj_name = trajectory_names{i};
    
    % 4.1 轨迹对比图
    fig_traj = figure('Name', sprintf('Trajectory Comparison - %s', traj_name));
    plotTrajectories(gca, result.gt_associated_traj, result.aligned_est_traj, cfg);
    % 不设置标题
    
    all_figures(end+1) = fig_traj;
    figure_names{end+1} = sprintf('trajectory_comparison_%s', traj_name);
    
    % 4.2 ATE 分析图
    [fig_ate_timeseries, fig_ate_hist, fig_ate_cdf] = plotATE(result.ate_metrics, cfg);
    
    % 不设置总标题
    
    all_figures(end+1:end+3) = [fig_ate_timeseries, fig_ate_hist, fig_ate_cdf];
    figure_names{end+1} = sprintf('ate_timeseries_%s', traj_name);
    figure_names{end+1} = sprintf('ate_histogram_%s', traj_name);
    figure_names{end+1} = sprintf('ate_cdf_%s', traj_name);
end

%% --- 5. 保存数据文件 ---
if cfg.SAVE_DATA
    fprintf('正在保存数据文件...\n');
    
    for i = 1:length(trajectory_results)
        result = trajectory_results{i};
        traj_name = trajectory_names{i};
        traj_data = trajectory_data{i};
        
        % 调用封装的数据保存函数
        saveTrajectoryData(RESULTS_DIR_TIMESTAMPED, traj_name, result.ate_metrics, traj_data);
    end
    
    fprintf('数据文件保存完成。\n');
end

%% --- 6. 应用图像格式配置 ---
fprintf('正在应用图像格式配置...\n');
for i = 1:length(all_figures)
    fig = all_figures(i);
    
    % 设置字体
    set(findall(fig, '-property', 'FontSize'), 'FontSize', cfg.FONT_SIZE_BASE * cfg.FONT_SIZE_MULTIPLE);
    
    % 设置尺寸和位置（从左下角开始）
    set(fig, 'Units', 'centimeters');
    pos = get(fig, 'Position');
    pos(1) = 2;  % X位置：距离屏幕左边2cm
    pos(2) = 2;  % Y位置：距离屏幕底边2cm
    pos(3) = cfg.FIGURE_WIDTH_CM * cfg.FIGURE_SIZE_MULTIPLE;
    pos(4) = cfg.FIGURE_HEIGHT_CM * cfg.FIGURE_SIZE_MULTIPLE;
    set(fig, 'Position', pos);
end
fprintf('图像格式配置完成。\n');

%% --- 7. 保存图像（可选）---
if cfg.SAVE_FIGURES
    fprintf('正在保存图像...\n');
    for i = 1:length(all_figures)
        fig = all_figures(i);
        file_name = fullfile(RESULTS_DIR_TIMESTAMPED, [figure_names{i}, '.png']);
        print(fig, file_name, '-dpng', ['-r', num2str(cfg.DPI)]);
    end
    fprintf('所有图像已保存到 %s 文件夹。\n', RESULTS_DIR_TIMESTAMPED);
else
    fprintf('图像仅作显示，未保存。\n');
end

%% --- 7. 输出统计总结 ---
fprintf('\n=== ATE 分析结果总结 ===\n');
for i = 1:length(trajectory_results)
    result = trajectory_results{i};
    traj_name = trajectory_names{i};
    metrics = result.ate_metrics;
    
    fprintf('%s 轨迹:\n', traj_name);
    fprintf('  RMSE: %.4f m\n', metrics.rmse);
    fprintf('  Mean: %.4f m\n', metrics.mean);
    fprintf('  Median: %.4f m\n', metrics.median);
    fprintf('  Std: %.4f m\n', metrics.std);
    fprintf('  Max: %.4f m\n', max(metrics.errors));
    fprintf('  Min: %.4f m\n', min(metrics.errors));
    fprintf('\n');
end

fprintf('分析完成。\n');
