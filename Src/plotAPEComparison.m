function fig_handle = plotAPEComparison(varargin)
% plotAPEComparison - 绘制两组路径（NESP vs Comb）的XY平面绝对位置误差（APE）对比曲线
%
% 从四个路径文件中读取两组路径（SLAM 与对应 GT）并计算 XY 平面绝对位置误差（Absolute Position Error, APE） sqrt(x^2 + y^2)。
% 两条误差曲线（NESP 与 Comb/传统梳状）绘制在同一图窗，使用固定配色。
%
% 语法:
%   fig_handle = plotAPEComparison('nespSLAM', slam_file1, 'nespGT', gt_file1, ...
%                                      'combSLAM', slam_file2, 'combGT', gt_file2)
%   fig_handle = plotAPEComparison(..., 'Name', Value)
%
% Name-Value 参数:
%   nespSLAM      - (string) NESP SLAM 路径文件路径
%   nespGT        - (string) NESP GT 路径文件路径  
%   combSLAM      - (string) Comb SLAM 路径文件路径
%   combGT        - (string) Comb GT 路径文件路径
%   align         - (logical, 默认 true) 是否对 SLAM 到 GT 进行时间插值对齐
%   save          - (logical, 默认 false) 是否保存图像（仅导出 PNG）
%   outputDir     - (string, 可选) 保存目录；默认 cfg.RESULTS_DIR_BASE/<timestamp>_ape_error/
%   colors        - (2×3 double, 可选) 两条曲线颜色；默认 NESP 深蓝，Comb 深红
%   lineWidth     - (double, 默认 1.8) 线宽
%   legendLabels  - (cellstr, 默认 {'NESP', 'Comb'}) 图例标签
%   cfg           - (struct, 可选) 配置结构体；未提供时自动调用 config()
%
% 输出:
%   fig_handle - 图窗句柄
%
% 示例:
%   % 基本用法
%   fig = plotAPEComparison('nespSLAM', 'Data/nesp_slam.txt', ...
%                               'nespGT', 'Data/nesp_gt.txt', ...
%                               'combSLAM', 'Data/comb_slam.txt', ...
%                               'combGT', 'Data/comb_gt.txt');
%
%   % 保存图像
%   fig = plotAPEComparison('nespSLAM', 'Data/nesp_slam.txt', ...
%                               'nespGT', 'Data/nesp_gt.txt', ...
%                               'combSLAM', 'Data/comb_slam.txt', ...
%                               'combGT', 'Data/comb_gt.txt', ...
%                               'save', true);

    %% === 样式常量定义（统一集中管理） ===
    % 颜色常量
    COLOR_NESP = [ 51, 115, 179]/255;  % 深蓝 rgb(51,115,179)
    COLOR_COMB = [191,  64,  64]/255;  % 深红 rgb(191,64,64)
    
    % 线型与宽度
    DEFAULT_LINE_WIDTH = 1.8;
    
    % 标记（默认关闭）
    DEFAULT_MARKER = 'none';
    MARKER_SIZE = 16;
    MARKER_FACE_ALPHA = 0.85;
    
    % 网格与坐标（默认关闭，但提供参数）
    GRID_COLOR = [0.75, 0.75, 0.75];
    GRID_LINE_WIDTH = 1.0;
    GRID_LINE_STYLE = '--';
    AXES_LINE_WIDTH = 1.2;
    
    % 导出设置
    EXPORT_TYPE = 'png';

    %% === 参数解析 ===
    p = inputParser;
    addParameter(p, 'nespSLAM', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'nespGT', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'combSLAM', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'combGT', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'align', true, @islogical);
    addParameter(p, 'save', false, @islogical);
    addParameter(p, 'outputDir', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'colors', [COLOR_NESP; COLOR_COMB], @(x) isnumeric(x) && size(x,1)==2 && size(x,2)==3);
    addParameter(p, 'lineWidth', DEFAULT_LINE_WIDTH, @isnumeric);
    addParameter(p, 'legendLabels', {'NESP', 'Comb'}, @iscell);
    addParameter(p, 'cfg', [], @isstruct);
    
    parse(p, varargin{:});
    
    % 提取参数
    nesp_slam_file = char(p.Results.nespSLAM);
    nesp_gt_file = char(p.Results.nespGT);
    comb_slam_file = char(p.Results.combSLAM);
    comb_gt_file = char(p.Results.combGT);
    do_align = p.Results.align;
    do_save = p.Results.save;
    output_dir = char(p.Results.outputDir);
    curve_colors = p.Results.colors;
    line_width = p.Results.lineWidth;
    legend_labels = p.Results.legendLabels;
    cfg = p.Results.cfg;
    
    % 验证必需参数
    if isempty(nesp_slam_file) || isempty(nesp_gt_file) || ...
       isempty(comb_slam_file) || isempty(comb_gt_file)
        error('必须提供所有四个文件路径：nespSLAM, nespGT, combSLAM, combGT');
    end
    
    % 获取配置
    if isempty(cfg)
        cfg = config();
    end
    
    %% === 数据加载 ===
    fprintf('正在加载路径数据...\n');
    
    % 读取 NESP 路径
    [nesp_slam_timestamps, nesp_slam_trajectory] = readTrajectory(nesp_slam_file);
    [nesp_gt_timestamps, nesp_gt_trajectory] = readTrajectory(nesp_gt_file);
    
    % 读取 Comb 路径
    [comb_slam_timestamps, comb_slam_trajectory] = readTrajectory(comb_slam_file);
    [comb_gt_timestamps, comb_gt_trajectory] = readTrajectory(comb_gt_file);
    
    fprintf('数据加载完成。\n');
    
    %% === 时间对齐与误差计算（APE） ===
    fprintf('正在计算XY平面 APE...\n');
    
    % 计算 NESP 误差
    [nesp_error, nesp_time_axis] = computeAPE(nesp_slam_timestamps, nesp_slam_trajectory, ...
                                                  nesp_gt_timestamps, nesp_gt_trajectory, do_align);
    
    % 计算 Comb 误差
    [comb_error, comb_time_axis] = computeAPE(comb_slam_timestamps, comb_slam_trajectory, ...
                                                  comb_gt_timestamps, comb_gt_trajectory, do_align);
    
    fprintf('APE 计算完成。NESP: %d 点，Comb: %d 点\n', length(nesp_error), length(comb_error));
    
    %% === 绘图 ===
    fprintf('正在绘制 APE 对比曲线...\n');
    
    % 创建图窗
    fig_handle = figure('Name', 'XY Planar APE Comparison', 'NumberTitle', 'off');
    
    % 设置图窗尺寸
    fig_width = cfg.FIGURE_WIDTH_CM * cfg.FIGURE_SIZE_MULTIPLE;
    fig_height = cfg.FIGURE_HEIGHT_CM * cfg.FIGURE_SIZE_MULTIPLE/2;
    set(fig_handle, 'Units', 'centimeters');
    set(fig_handle, 'Position', [2, 2, fig_width, fig_height]);
    set(fig_handle, 'PaperUnits', 'centimeters');
    set(fig_handle, 'PaperSize', [fig_width, fig_height]);
    set(fig_handle, 'PaperPosition', [0, 0, fig_width, fig_height]);
    
    % 绘制两条误差曲线
    hold on;
    plot(nesp_time_axis, nesp_error, 'Color', curve_colors(1,:), 'LineWidth', line_width, ...
         'Marker', DEFAULT_MARKER, 'DisplayName', legend_labels{1});
    plot(comb_time_axis, comb_error, 'Color', curve_colors(2,:), 'LineWidth', line_width, ...
         'Marker', DEFAULT_MARKER, 'DisplayName', legend_labels{2});
    hold off;
    
    % 设置坐标轴属性
    ax = gca;
    set(ax, 'LineWidth', AXES_LINE_WIDTH);
    set(ax, 'Box', 'on');
    
    % 网格设置（默认关闭，但保留代码）
    % grid on;
    % set(ax, 'GridColor', GRID_COLOR);
    % set(ax, 'GridLineStyle', GRID_LINE_STYLE);
    % set(ax, 'GridAlpha', 1.0);
    % set(ax, 'MinorGridLineStyle', GRID_LINE_STYLE);
    % set(ax, 'MinorGridAlpha', 0.5);
    
    % 字体设置
    font_axis = cfg.FONT_SIZE_BASE * cfg.FONT_SIZE_MULTIPLE;
    font_title = round(font_axis);
    set(ax, 'FontSize', font_axis);
    set(ax, 'FontName', cfg.FONT_NAME);
    
    % 轴标签与标题
    xlabel('Keyframe Index', 'FontSize', font_axis, 'FontName', cfg.FONT_NAME);
    ylabel('Absolute Position Error (m)', 'FontSize', font_axis, 'FontName', cfg.FONT_NAME);
    title('Position Error Evolution across Submaps', 'FontSize', font_title, 'FontName', cfg.FONT_NAME);
    
    % 图例
    legend('show', 'Location', 'best', 'FontSize', font_axis, 'FontName', cfg.FONT_NAME);
    
    fprintf('绘图完成。\n');
    
    %% === 保存图像 ===
    if do_save
        fprintf('正在保存图像...\n');
        
        % 确定输出目录
        if isempty(output_dir)
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            output_dir = fullfile(cfg.RESULTS_DIR_BASE, [timestamp '_APE_visualization']);
        end
        
        % 创建输出目录
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        % 保存图像
        output_file = fullfile(output_dir, 'APE_error.png');
        print(fig_handle, output_file, ['-d' EXPORT_TYPE], ['-r' num2str(cfg.DPI)]);
        
        fprintf('图像已保存至: %s\n', output_file);
    end
    
    fprintf('XY平面 APE 对比绘制完成。\n');
end

%% === 辅助函数 ===
function [error_sequence, time_axis] = computeAPE(slam_timestamps, slam_trajectory, ...
                                                      gt_timestamps, gt_trajectory, do_align)
% computeAPE - 计算XY平面绝对位置误差（APE）
%
% 输入:
%   slam_timestamps - SLAM 时间戳
%   slam_trajectory - SLAM 轨迹 [N×3]
%   gt_timestamps   - GT 时间戳  
%   gt_trajectory   - GT 轨迹 [M×3]
%   do_align        - 是否进行时间对齐
%
% 输出:
%   error_sequence - 误差序列
%   time_axis      - 对应的时间轴

    if do_align
        % 时间对齐：以 GT 为基准，对 SLAM 进行插值
        % 找到时间重叠区间
        min_time = max(min(slam_timestamps), min(gt_timestamps));
        max_time = min(max(slam_timestamps), max(gt_timestamps));
        
        % 筛选有效时间范围
        gt_valid_idx = (gt_timestamps >= min_time) & (gt_timestamps <= max_time);
        gt_times_valid = gt_timestamps(gt_valid_idx);
        gt_traj_valid = gt_trajectory(gt_valid_idx, :);
        
        % 对 SLAM 轨迹进行插值到 GT 时间点
        slam_x_interp = interp1(slam_timestamps, slam_trajectory(:,1), gt_times_valid, 'linear', 'extrap');
        slam_y_interp = interp1(slam_timestamps, slam_trajectory(:,2), gt_times_valid, 'linear', 'extrap');
        
        % 计算 XY 平面误差
        dx = slam_x_interp - gt_traj_valid(:,1);
        dy = slam_y_interp - gt_traj_valid(:,2);
        error_sequence = sqrt(dx.^2 + dy.^2);
        
        time_axis = gt_times_valid;
        
    else
        % 按索引对齐：取两者最短长度
        min_length = min(length(slam_timestamps), length(gt_timestamps));
        
        slam_traj_short = slam_trajectory(1:min_length, :);
        gt_traj_short = gt_trajectory(1:min_length, :);
        
        % 计算 XY 平面误差
        dx = slam_traj_short(:,1) - gt_traj_short(:,1);
        dy = slam_traj_short(:,2) - gt_traj_short(:,2);
        error_sequence = sqrt(dx.^2 + dy.^2);
        
        % 使用索引作为时间轴
        time_axis = (1:min_length)';
    end
    
    % 移除 NaN 和 Inf
    valid_idx = isfinite(error_sequence);
    error_sequence = error_sequence(valid_idx);
    time_axis = time_axis(valid_idx);
    
end
