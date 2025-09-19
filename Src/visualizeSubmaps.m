function visualizeSubmaps(measurements, varargin)
% VISUALIZESUBMAPS 可视化已加载的子地图集合
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

    % 输入参数解析
    p = inputParser;
    addRequired(p, 'measurements', @(x) iscell(x));
    addParameter(p, 'SampleRate', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
    addParameter(p, 'ColorBy', 'z', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MarkerSize', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'ShowIndividual', false, @islogical);
    addParameter(p, 'Title', 'Aggregated Submaps', @(x) ischar(x) || isstring(x));
    addParameter(p, 'UseParallel', false, @islogical);
    
    parse(p, measurements, varargin{:});
    
    sample_rate = p.Results.SampleRate;
    color_by = char(p.Results.ColorBy);
    marker_size = p.Results.MarkerSize;
    show_individual = p.Results.ShowIndividual;
    plot_title = char(p.Results.Title);
    use_parallel = p.Results.UseParallel;
    
    % 验证输入
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
    
    % 如果要分别显示各个子地图
    if show_individual
        visualizeIndividualSubmaps(valid_measurements, sample_rate, marker_size);
        return;
    end
    
    % 聚合所有点云数据
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
    
    % 创建可视化
    fprintf('创建可视化...\n');
    tic;
    
    % 确定着色方案
    switch lower(color_by)
        case 'z'
            color_data = all_points(:, 3);  % 使用Z坐标着色
            colormap_name = 'jet';
        case 'submap'
            color_data = submap_labels;
            colormap_name = 'lines';
        case 'random'
            color_data = rand(size(all_points, 1), 1);
            colormap_name = 'hsv';
        otherwise
            warning('未知的着色方式: %s, 使用默认的Z坐标着色', color_by);
            color_data = all_points(:, 3);
            colormap_name = 'jet';
    end
    
    % 创建图像
    figure('Name', 'Submap Visualization', 'NumberTitle', 'off');
    
    % 使用pcshow进行可视化 (注意: 此函数依赖 Computer Vision Toolbox)
    pcshow(all_points, color_data, 'MarkerSize', marker_size);
    % % 使用scatter3进行可视化（更通用，不依赖Computer Vision Toolbox）
    % scatter3(all_points(:, 1), all_points(:, 2), all_points(:, 3), ...
    %     marker_size, color_data, 'filled');
    
    % 设置图像属性
    title(plot_title, 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('X (m)', 'FontSize', 12);
    ylabel('Y (m)', 'FontSize', 12);
    zlabel('Z (m)', 'FontSize', 12);
    
    % 设置颜色映射和颜色条
    colormap(colormap_name);
    cb = colorbar;
    
    switch lower(color_by)
        case 'z'
            cb.Label.String = 'Z Coordinate (m)';
        case 'submap'
            cb.Label.String = 'Submap Index';
        case 'random'
            cb.Label.String = 'Random Color';
    end
    
    cb.Label.FontSize = 11;
    
    % 设置坐标轴
    axis equal;
    grid on;
    
    % 设置视角
    view(45, 30);
    
    % 添加统计信息到图像
    stats_text = sprintf('子地图数: %d\n总点数: %d\n采样率: %.1f%%', ...
                        num_submaps, size(all_points, 1), sample_rate * 100);
    
    % 添加文本框
    annotation('textbox', [0.02, 0.02, 0.3, 0.15], 'String', stats_text, ...
               'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    fprintf('可视化完成 (耗时: %.2f 秒)\n', toc);
    
    % 显示数据范围信息
    fprintf('\n数据范围信息:\n');
    fprintf('  X: [%.2f, %.2f] m\n', min(all_points(:,1)), max(all_points(:,1)));
    fprintf('  Y: [%.2f, %.2f] m\n', min(all_points(:,2)), max(all_points(:,2)));
    fprintf('  Z: [%.2f, %.2f] m\n', min(all_points(:,3)), max(all_points(:,3)));
end

function visualizeIndividualSubmaps(measurements, sample_rate, marker_size)
% VISUALIZEINDIVIDUALSUBMAPS 分别显示各个子地图
%
% 输入:
%   measurements: 子地图集合
%   sample_rate: 采样率
%   marker_size: 点大小

    num_submaps = length(measurements);
    fprintf('分别显示 %d 个子地图...\n', num_submaps);
    
    % 计算子图布局
    n_cols = ceil(sqrt(num_submaps));
    n_rows = ceil(num_submaps / n_cols);
    
    % 创建大图像
    figure('Name', 'Individual Submaps', 'NumberTitle', 'off', ...
           'Position', [100, 100, 200*n_cols, 200*n_rows]);
    
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
        
        % 绘制点云
        scatter3(submap_points(:, 1), submap_points(:, 2), submap_points(:, 3), ...
                 marker_size, submap_points(:, 3), 'filled');
        
        title(sprintf('Submap %d (%d pts)', i, size(submap_points, 1)), 'FontSize', 10);
        xlabel('X'); ylabel('Y'); zlabel('Z');
        axis equal; grid on;
        colormap('jet');
        
        % 设置合适的视角
        view(45, 30);
    end
    
    % 调整子图间距
    sgtitle('Individual Submap Visualization', 'FontSize', 14, 'FontWeight', 'bold');
end
