%% VISUALIZESUBMAPS 可视化已加载的子地图集合
%
% 输入:
%   measurements (cell): `loadAllSubmaps`的输出，每个元胞包含 [N x 3] 点云矩阵
%   varargin: 可选参数对，支持以下选项:
%       'SampleRate' - 采样率，控制显示的点数 (默认: 1.0, 即全部显示)
%       'ColorBy' - 着色方式: 'z', 'submap', 'random' (默认: 'z')
%       'MarkerSize' - 点的大小 (默认: 1)
%       'ShowIndividual' - 是否分别显示各个子地图 (默认: false)
%       'Title' - 图像标题 (默认: 'Aggregated Submaps')
%       'UseParallel' - 是否使用并行处理采样 (默认: false)
%       'GlobalVisual' - 必填，全局可视化参数结构体 cfg.global.visual
%
% 输出:
%   无 (显示图像)
%
% 示例:
%   visualizeSubmaps(measurements);
%   visualizeSubmaps(measurements, 'SampleRate', 0.1, 'ColorBy', 'submap');
%   visualizeSubmaps(measurements, 'ShowIndividual', true);
%
% 作者: Chihong
% 日期: 2025-09-18
function visualizeSubmaps(measurements, varargin)
%% 输入参数解析
    p = inputParser;
    addRequired(p, 'measurements', @(x) iscell(x));
    addParameter(p, 'SampleRate', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
    addParameter(p, 'ColorBy', 'z', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MarkerSize', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'ShowIndividual', false, @islogical);
    addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'UseParallel', false, @islogical);
    addParameter(p, 'GlobalVisual', [], @(x) isstruct(x));
    
    parse(p, measurements, varargin{:});
    
    sample_rate = p.Results.SampleRate;
    color_by = char(p.Results.ColorBy);
    marker_size = p.Results.MarkerSize;
    show_individual = p.Results.ShowIndividual;
    plot_title = char(p.Results.Title);
    use_parallel = p.Results.UseParallel;
    if isempty(p.Results.GlobalVisual)
        error('GlobalVisual 为必填参数，请传入 cfg.global.visual');
    end
    
%% 验证输入
    if isempty(measurements)
        warning('输入的 measurements 为空，无法可视化');
        return;
    end
    
    % 移除空的子地图
    valid_measurements = measurements(~cellfun(@isempty, measurements));
    if isempty(valid_measurements)
        warning('所有子地图都为空，无法可视化');
        return;
    end
    
    num_submaps = length(valid_measurements);
    fprintf('开始可视化 %d 个子地图...\n', num_submaps);
    
%% 如果要分别显示各个子地图
    if show_individual
        visualizeIndividualSubmaps(valid_measurements, sample_rate, marker_size, p.Results.GlobalVisual, plot_title);
        return;
    end
    
%% 聚合所有点云数据
    fprintf('聚合点云数据...\n');
    tic;
    
    if use_parallel && length(valid_measurements) > 4
        % 并行处理采样（适用于大量子地图）
        sampled_submaps = cell(num_submaps, 1);
        submap_colors = cell(num_submaps, 1);
        
        parfor i = 1:num_submaps
            submap_points = valid_measurements{i};
            if sample_rate < 1.0
                num_points = size(submap_points, 1);
                num_sample = max(1, round(num_points * sample_rate));
                sample_indices = randsample(num_points, num_sample);
                sampled_submaps{i} = submap_points(sample_indices, :);
            else
                sampled_submaps{i} = submap_points;
            end
            
            % 生成子地图颜色标识
            if strcmpi(color_by, 'submap')
                submap_colors{i} = i * ones(size(sampled_submaps{i}, 1), 1);
            end
        end
        
        % 聚合结果
        all_points = vertcat(sampled_submaps{:});
        if strcmpi(color_by, 'submap')
            submap_labels = vertcat(submap_colors{:});
        end
    else
        % 串行处理
        all_points_cell = cell(num_submaps, 1);
        submap_labels_cell = cell(num_submaps, 1);
        
        for i = 1:num_submaps
            submap_points = valid_measurements{i};
            
            % 应用采样
            if sample_rate < 1.0
                num_points = size(submap_points, 1);
                num_sample = max(1, round(num_points * sample_rate));
                sample_indices = randsample(num_points, num_sample);
                submap_points = submap_points(sample_indices, :);
            end
            
            all_points_cell{i} = submap_points;
            
            % 生成子地图标签（用于着色）
            if strcmpi(color_by, 'submap')
                submap_labels_cell{i} = i * ones(size(submap_points, 1), 1);
            end
        end
        
        % 聚合所有点
        all_points = vertcat(all_points_cell{:});
        if strcmpi(color_by, 'submap')
            submap_labels = vertcat(submap_labels_cell{:});
        end
    end
    
    fprintf('聚合完成，总点数: %d (耗时: %.2f 秒)\n', size(all_points, 1), toc);
    
    % 检查聚合后的数据
    if isempty(all_points)
        warning('聚合后的点云为空，无法可视化');
        return;
    end
    
%% 创建可视化
    fprintf('创建可视化...\n');
    tic;
    
    % 确定着色方案
    switch lower(color_by)
        case 'z'
            color_data = all_points(:, 3);  % 使用Z坐标着色
            colormap_name = 'jet';
        case 'submap'
            color_data = submap_labels; % 每个点的子地图索引（1..num_submaps）
            % 使用与子地图数量一致的离散调色板，保证相邻索引颜色不同
            colormap_name = lines(num_submaps);
        case 'random'
            color_data = rand(size(all_points, 1), 1);
            colormap_name = 'hsv';
        otherwise
            warning('未知的着色方式: %s, 使用默认的Z坐标着色', color_by);
            color_data = all_points(:, 3);
            colormap_name = 'jet';
    end
    
    % 创建图像（统一使用厘米单位与全局尺寸）
    figure('Name', 'Submap Visualization', 'NumberTitle', 'off', 'Color','w', ...
        'Units','centimeters', 'Position', [2, 2, ...
        p.Results.GlobalVisual.figure_width_cm * p.Results.GlobalVisual.figure_size_multiple, ...
        p.Results.GlobalVisual.figure_height_cm * p.Results.GlobalVisual.figure_size_multiple]);
    
    % 使用二维俯视图绘制（颜色映射 Z）
    scatter(all_points(:, 1), all_points(:, 2), marker_size, color_data, 'filled');
    
    axis_fs = round(p.Results.GlobalVisual.font_size_base * p.Results.GlobalVisual.font_size_multiple);
    title_fs = axis_fs;
    cb_fs = axis_fs;

    % 设置图像属性
    if ~isempty(plot_title)
        title(plot_title, 'FontSize', title_fs, 'FontName', p.Results.GlobalVisual.font_name);
    end
    xlabel('X (m)', 'FontSize', axis_fs, 'FontName', p.Results.GlobalVisual.font_name);
    ylabel('Y (m)', 'FontSize', axis_fs, 'FontName', p.Results.GlobalVisual.font_name);
    % 俯视图不显示 Z 轴标签
    
    % 设置颜色映射和颜色条
    if strcmpi(color_by, 'submap')
        % 离散映射：每个整数索引映射到唯一颜色
        colormap(colormap_name);          % 这里 colormap_name 是一个 N×3 矩阵
        caxis([1, num_submaps]);          % 确保整数索引对齐到调色板行
    else
        colormap(colormap_name);
    end
    cb = colorbar;
    
    switch lower(color_by)
        case 'z'
            cb.Label.String = 'Depth (m)';
        case 'submap'
            cb.Label.String = 'Submap Index';
        case 'random'
            cb.Label.String = 'Random Color';
    end
    
    cb.Label.FontSize = cb_fs;
    cb.Label.FontName = p.Results.GlobalVisual.font_name;
    
    % 设置坐标轴
    axis equal;
    grid off;
    set(gca, 'FontName', p.Results.GlobalVisual.font_name, 'FontSize', axis_fs);
    
    % 俯视图，无需 3D 视角
    
%% 终端输出统计信息（替代图内文本框）
    fprintf('\n可视化统计:\n');
    fprintf('  子地图数: %d\n', num_submaps);
    fprintf('  总点数: %d\n', size(all_points, 1));
    fprintf('  采样率: %.1f%%%\n', sample_rate * 100);
    
    fprintf('可视化完成 (耗时: %.2f 秒)\n', toc);
    
    % 显示数据范围信息
    fprintf('\n数据范围信息:\n');
    fprintf('  X: [%.2f, %.2f] m\n', min(all_points(:,1)), max(all_points(:,1)));
    fprintf('  Y: [%.2f, %.2f] m\n', min(all_points(:,2)), max(all_points(:,2)));
    fprintf('  Z: [%.2f, %.2f] m\n', min(all_points(:,3)), max(all_points(:,3)));
end

%% 辅助函数 - 分别显示各个子地图
function visualizeIndividualSubmaps(measurements, sample_rate, marker_size, GlobalVisual, TitleStr)
% VISUALIZEINDIVIDUALSUBMAPS 分别显示各个子地图
%
% 输入:
%   measurements: 子地图集合
%   sample_rate: 采样率
%   marker_size: 点大小
%   gv: 全局可视化参数（cfg.global.visual）

    % 从全局可视化参数计算样式
    font_name = GlobalVisual.font_name;
    fs_base   = GlobalVisual.font_size_base;
    fs_mul    = GlobalVisual.font_size_multiple;
    fig_w_cm  = GlobalVisual.figure_width_cm * GlobalVisual.figure_size_multiple;
    fig_h_cm  = GlobalVisual.figure_height_cm * GlobalVisual.figure_size_multiple;
    axis_fs = round(fs_base * fs_mul);
    title_fs = max(axis_fs, round(axis_fs * 1.2));

    num_submaps = length(measurements);
    fprintf('分别显示 %d 个子地图...\n', num_submaps);
    
    % 计算子图布局
    n_cols = ceil(sqrt(num_submaps));
    n_rows = ceil(num_submaps / n_cols);
    
    % 创建大图像（统一使用厘米单位与全局尺寸的网格布局）
    figure('Name', 'Individual Submaps', 'NumberTitle', 'off', 'Color','w', ...
        'Units','centimeters', 'Position', [2, 2, fig_w_cm*max(1,n_cols/2), fig_h_cm*max(1,n_rows/2)]);
    
    for i = 1:num_submaps
        subplot(n_rows, n_cols, i);
        
        submap_points = measurements{i};
        
        % 应用采样
        if sample_rate < 1.0 && size(submap_points, 1) > 100
            num_points = size(submap_points, 1);
            num_sample = max(10, round(num_points * sample_rate));
            sample_indices = randsample(num_points, num_sample);
            submap_points = submap_points(sample_indices, :);
        end
        
    % 绘制点云（俯视2D，颜色映射 Z）
    scatter(submap_points(:, 1), submap_points(:, 2), ...
         marker_size, submap_points(:, 3), 'filled');
        
        title(sprintf('Submap %d (%d pts)', i, size(submap_points, 1)), 'FontSize', max(10, axis_fs), 'FontName', font_name);
        xlabel('X','FontSize', max(9, axis_fs), 'FontName', font_name);
        ylabel('Y','FontSize', max(9, axis_fs), 'FontName', font_name);
    % 俯视图不显示 Z 轴标签
    axis equal; grid off;
        colormap('jet');
        set(gca, 'FontName', font_name, 'FontSize', max(9, axis_fs));
        
    % 俯视图，无需 3D 视角
    end
    
    % 调整子图间距
    if exist('TitleStr','var') && ~isempty(TitleStr)
        sgtitle(TitleStr, 'FontSize', title_fs, 'FontWeight', 'bold', 'FontName', font_name);
    end
end
