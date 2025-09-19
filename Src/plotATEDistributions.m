function fig_handles = plotATEDistributions(varargin)
% plotATEDistributions - 绘制多组ATE数据的箱线图与小提琴图
%
% 用法:
%   fig_handles = plotATEDistributions('Name', Value, ...)
%
% Name-Value 选项:
%   'files'      - (cellstr) 数据文件路径; 若为空则弹窗多选
%   'labels'     - (cellstr) 横坐标标签; 若为空则用文件名且可编辑
%   'column'     - (double/string) ATE数据列号或列名
%   'save'       - (logical) 是否保存图像 (PNG)
%   'outputDir'  - (string)  输出目录
%   'colors'     - (Nx6 double) 自定义颜色 [填充, 边框]
%   'cfg'        - (struct)  config.m 返回的配置结构体

    %% 1. 样式与常量定义 (仿附图风格)
    % =========================================================================
    COLOR_A_FILL  = [179, 214, 242]/255;  % 浅蓝 rgb(179,214,242)
    COLOR_A_EDGE  = [ 51, 115, 179]/255;  % 深蓝 rgb(51,115,179)
    COLOR_B_FILL  = [245, 179, 179]/255;  % 浅红 rgb(245,179,179)
    COLOR_B_EDGE  = [191,  64,  64]/255;  % 深红 rgb(191,64,64)
    COLOR_C_FILL  = [187, 219, 179]/255;  % 浅绿 rgb(187,219,179)
    COLOR_C_EDGE  = [ 64, 153,  90]/255;  % 深绿 rgb(64,153,90)
    COLOR_D_FILL  = [209, 194, 230]/255;  % 浅紫 rgb(209,194,230)
    COLOR_D_EDGE  = [128,  90, 179]/255;  % 深紫 rgb(128,90,179)
    COLOR_E_FILL  = [250, 204, 153]/255;  % 浅橙 rgb(250,204,153)
    COLOR_E_EDGE  = [217, 128,  38]/255;  % 深橙 rgb(217,128,38)

    fill_colors = [COLOR_A_FILL; COLOR_B_FILL; COLOR_C_FILL; COLOR_D_FILL; COLOR_E_FILL];
    edge_colors = [COLOR_A_EDGE; COLOR_B_EDGE; COLOR_C_EDGE; COLOR_D_EDGE; COLOR_E_EDGE];

    % 其他绘图参数
    STYLE.fillAlpha         = 0.35;
    STYLE.boxEdgeWidth      = 1.8;
    STYLE.whiskerLineWidth  = 1.3;
    STYLE.medianLineWidth   = 1.6;
    STYLE.violinEdgeWidth   = 1.8;
    STYLE.gridColor         = [0.75, 0.75, 0.75];
    STYLE.gridLineWidth     = 1.0;
    STYLE.gridLineStyle     = '--';
    STYLE.axesLineWidth     = 1.2;
    STYLE.marker            = 'o';
    STYLE.markerSize        = 8; % 散点大小 
    STYLE.markerFaceAlpha   = 0.75;
    STYLE.markerEdgeLineWidth = 0.8;
    STYLE.jitterWidth       = 0.08;

    %% 2. 输入解析
    % =========================================================================
    parser = inputParser;
    parser.addParameter('files', {});
    parser.addParameter('labels', {});
    parser.addParameter('column', 'ate_error');
    parser.addParameter('save', false);
    parser.addParameter('outputDir', '');
    parser.addParameter('colors', []);
    parser.addParameter('cfg', []);
    parser.parse(varargin{:});
    opt = parser.Results;

    % 加载配置
    if isempty(opt.cfg)
        cfg = config();
    else
        cfg = opt.cfg;
    end

    %% 3. 数据加载与预处理
    % =========================================================================
    if isempty(opt.files)
        [file_names, path_name] = uigetfile({'*.txt;*.csv','ATE Files (*.txt, *.csv)'}, ...
            'Select ATE Data Files', 'MultiSelect','on');
        if ~iscell(file_names) && isequal(file_names,0), fig_handles = []; return; end
        if ~iscell(file_names), file_names = {file_names}; end
        opt.files = fullfile(path_name, file_names);
    end

    num_groups = length(opt.files);
    all_data = cell(1, num_groups);
    
    for i = 1:num_groups
        try
            read_opts = detectImportOptions(opt.files{i});
            var_names = lower(read_opts.VariableNames);
            
            col_idx = find(strcmp(var_names, lower(opt.column)), 1);
            if isempty(col_idx)
                col_idx = find(contains(var_names, 'ate'), 1);
            end
            if isempty(col_idx)
                var_types = read_opts.VariableTypes;
                col_idx = find(strcmp(var_types, 'double'), 1, 'first');
            end

            read_opts.SelectedVariableNames = read_opts.VariableNames(col_idx);
            tbl = readtable(opt.files{i}, read_opts);
            all_data{i} = tbl{:,1};
        catch E
            warning('Failed to read file "%s": %s', opt.files{i}, E.message);
            all_data{i} = [];
        end
    end

    % 处理标签
    labels = opt.labels;
    if isempty(labels) || length(labels) ~= num_groups
        [~, default_labels] = cellfun(@fileparts, opt.files, 'UniformOutput', false);
        prompt = cell(1, num_groups);
        for i=1:num_groups
            prompt{i} = sprintf('Label for %s:', default_labels{i});
        end
        labels = inputdlg(prompt, 'Enter Group Labels', [1, 50], default_labels);
        if isempty(labels), fig_handles = []; return; end
    end

    %% 4. 绘图
    % =========================================================================
    if ~isempty(opt.colors)
        fill_colors = opt.colors(:, 1:3);
        edge_colors = opt.colors(:, 4:6);
    end

    % --- 4.1 箱线图 ---
    h_box = figure;
    hold on;
    
    y_data_vector = [];
    group_vector = [];
    
    for i = 1:num_groups
        data_i = all_data{i}(isfinite(all_data{i}));
        if isempty(data_i), continue; end
        
        y_data_vector = [y_data_vector; data_i(:)];
        group_vector = [group_vector; repmat(i, length(data_i), 1)];
        
        % 散点
        jitter_vals = (rand(size(data_i))-0.5) * 2 * STYLE.jitterWidth;
        scatter(i + jitter_vals, data_i, STYLE.markerSize, ...
            'MarkerFaceColor', fill_colors(i,:), 'MarkerEdgeColor', edge_colors(i,:), ...
            'MarkerFaceAlpha', STYLE.markerFaceAlpha, 'LineWidth', STYLE.markerEdgeLineWidth);
    end

    % 使用 boxchart（按数值组索引绘制，避免分类轴冲突）
    if exist('boxchart', 'file')
        for i = 1:num_groups
            idx = (group_vector == i);
            if any(idx)
                boxchart(i * ones(sum(idx),1), y_data_vector(idx), ...
                    'BoxFaceColor', fill_colors(i,:), ...
                    'BoxFaceAlpha', STYLE.fillAlpha, ...
                    'LineWidth', STYLE.boxEdgeWidth, ...
                    'BoxEdgeColor', edge_colors(i,:), ...
                    'WhiskerLineColor', [0 0 0], ...
                    'MarkerStyle', 'none');
            end
        end
        xticks(1:num_groups);
        xticklabels(labels);
    else % Fallback to boxplot
        boxplot(y_data_vector, group_vector, 'Labels', labels, 'Colors', edge_colors, ...
            'Symbol', 'o', 'Widths', 0.5);
    end
    
    setupAxes(cfg, STYLE, 'Distribution of Absolute Position Error');
    hold off;

    % --- 4.2 小提琴图 ---
    h_violin = figure;
    hold on;
    for i = 1:num_groups
        data_i = all_data{i};
        if isempty(data_i), continue; end
        
        % 1. 先画小提琴图 (只画填充和边框, 不画中心线)
        violin_handles = violinPlot(i, data_i, fill_colors(i,:), edge_colors(i,:), ...
            'FaceAlpha', STYLE.fillAlpha, 'LineWidth', STYLE.violinEdgeWidth, 'ShowCenterStats', false);
        
        % 2. 再画散点 (中间层)
        jitter_vals = (rand(size(data_i))-0.5) * 2 * STYLE.jitterWidth;
        scatter(i + jitter_vals, data_i, STYLE.markerSize, ...
            'MarkerFaceColor', fill_colors(i,:), 'MarkerEdgeColor', edge_colors(i,:), ...
            'MarkerFaceAlpha', STYLE.markerFaceAlpha, 'LineWidth', STYLE.markerEdgeLineWidth);

        % 3. 最后画中心线 (最顶层)
        med_val = median(data_i(isfinite(data_i)));
        mu_val = mean(data_i(isfinite(data_i)));
        line([i-0.15, i+0.15], [med_val, med_val], 'Color', [0 0 0], 'LineWidth', 2.2, 'LineStyle', '-');
        line([i-0.10, i+0.10], [mu_val, mu_val], 'Color', [0 0 0], 'LineWidth', 2.4, 'LineStyle', ':');

    end
    xticks(1:num_groups);
    xticklabels(labels);
    setupAxes(cfg, STYLE, 'ATE Distribution by Path Planning Method');
    hold off;

    fig_handles = [h_box, h_violin];

    %% 5. 保存
    % =========================================================================
    if opt.save
        if isempty(opt.outputDir)
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            output_dir = fullfile(cfg.RESULTS_DIR_BASE, [timestamp '_ATE_distributions']);
        else
            output_dir = opt.outputDir;
        end
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        
        % 保存箱线图
        saveas(h_box, fullfile(output_dir, '_ATE_error_boxplot.png'));
        saveas(h_box, fullfile(output_dir, '_ATE_error_boxplot.eps'), 'epsc');

        % 保存小提琴图
        saveas(h_violin, fullfile(output_dir, '_ATE_error_violin.png'));
        saveas(h_violin, fullfile(output_dir, '_ATE_error_violin.eps'), 'epsc');
        
        fprintf('Figures saved to: %s\n', output_dir);
    end

end

%% === 辅助函数 ===
function setupAxes(cfg, STYLE, title_str)
    grid on;
    ax = gca;
    ax.GridColor = STYLE.gridColor;
    ax.GridLineWidth = STYLE.gridLineWidth;
    ax.GridLineStyle = STYLE.gridLineStyle;
    ax.LineWidth = STYLE.axesLineWidth;
    box on;
    
    font_axis = cfg.FONT_SIZE_BASE * cfg.FONT_SIZE_MULTIPLE;
    font_title = round(1.2 * font_axis);
    
    title(title_str, 'FontSize', font_title, 'FontName', cfg.FONT_NAME);
    ylabel('Absolute Trajectory Error (m)', 'FontSize', font_axis, 'FontName', cfg.FONT_NAME);
    xlabel('Path Planning Method', 'FontSize', font_axis, 'FontName', cfg.FONT_NAME);
    set(ax, 'FontSize', font_axis * 0.9, 'FontName', cfg.FONT_NAME);
    
    fig = gcf;
    fig.PaperUnits = 'centimeters';
    fig.PaperSize = [cfg.FIGURE_WIDTH_CM, cfg.FIGURE_HEIGHT_CM] * cfg.FIGURE_SIZE_MULTIPLE;
    fig.PaperPosition = [0 0 fig.PaperSize];
end

function h = violinPlot(group_index, data_values, face_color, edge_color, varargin)
    % violinPlot - 基于核密度的对称小提琴图绘制（单组）
    %
    % 用法:
    %   h = violinPlot(xIndex, data, faceColor, edgeColor, 'Name', Value, ...)
    %
    % 输入:
    %   group_index  - (double) 组在 x 轴上的位置（如 1,2,3,...）
    %   data_values  - (double vector) 本组数据（会自动去除 NaN/Inf）
    %   face_color   - (1x3 double) 填充颜色 (RGB 0-1)
    %   edge_color   - (1x3 double) 边框颜色 (RGB 0-1)
    %
    % Name-Value 选项:
    %   'FaceAlpha'        - (double) 填充透明度, 默认 0.35
    %   'LineWidth'        - (double) 边框线宽, 默认 1.8
    %   'Bandwidth'        - (double) ksdensity 带宽, 默认 [] 自动
    %   'MaxHalfWidth'     - (double) 半宽度归一化的最大宽度, 默认 0.35
    %   'MedianValue'      - (double) 覆盖中位数, 默认 [] 自动计算
    %   'MeanValue'        - (double) 覆盖均值, 默认 [] 自动计算
    %   'ShowCenterStats'  - (logical) 是否绘制中位数/均值, 默认 true
    %   'YScaleLog'        - (logical) 是否使用对数坐标, 默认 false（此函数不修改坐标系, 仅用于内部计算保护）
    %
    % 输出:
    %   h - 结构体, 含 patch/median/mean 等图元句柄
    
        parser = inputParser;
        parser.addParameter('FaceAlpha', 0.35);
        parser.addParameter('LineWidth', 1.8);
        parser.addParameter('Bandwidth', []);
        parser.addParameter('MaxHalfWidth', 0.35);
        parser.addParameter('MedianValue', []);
        parser.addParameter('MeanValue', []);
        parser.addParameter('ShowCenterStats', true);
        parser.addParameter('YScaleLog', false);
        parser.parse(varargin{:});
        opt = parser.Results;
    
        data_values = data_values(:);
        data_values = data_values(isfinite(data_values));
        if isempty(data_values)
            h = struct('patch', gobjects(1), 'median', gobjects(1), 'mean', gobjects(1));
            return;
        end
    
        % 计算核密度
        y_min = min(data_values);
        y_max = max(data_values);
        if y_min == y_max
            y_grid = linspace(y_min - eps, y_max + eps, 50);
        else
            y_grid = linspace(y_min, y_max, 200);
        end
        [pdf_vals, y] = ksdensity(data_values, y_grid, 'Bandwidth', opt.Bandwidth);
    
        % 归一化宽度
        pdf_vals = pdf_vals(:);
        y = y(:);
        if max(pdf_vals) > 0
            half_width = opt.MaxHalfWidth * (pdf_vals / max(pdf_vals));
        else
            half_width = zeros(size(pdf_vals));
        end
    
        % 构造左右对称轮廓
        x_left  = group_index - half_width;
        x_right = group_index + half_width;
        x_patch = [x_left; flipud(x_right)];
        y_patch = [y;      flipud(y)];
    
        % 绘制主体
        hp = patch('XData', x_patch, 'YData', y_patch, ...
                   'FaceColor', face_color, 'EdgeColor', edge_color, ...
                   'FaceAlpha', opt.FaceAlpha, 'LineWidth', opt.LineWidth);
    
        h = struct('patch', hp, 'median', gobjects(1), 'mean', gobjects(1));
    
        % 这部分代码已移至 主要函数 中绘制, 以确保图层顺序正确
        % if opt.ShowCenterStats
        %     med_val = opt.MedianValue;
        %     if isempty(med_val), med_val = median(data_values); end
        %     mu_val  = opt.MeanValue;
        %     if isempty(mu_val),  mu_val  = mean(data_values);  end
        % 
        %     h.median = line([group_index-0.15, group_index+0.15], [med_val, med_val], ...
        %                     'Color', [0 0 0], 'LineWidth', 2.2, 'LineStyle', '-'); % 加粗实线
        %     h.mean   = line([group_index-0.10, group_index+0.10], [mu_val,  mu_val ], ...
        %                     'Color', [0 0 0], 'LineWidth', 1.8, 'LineStyle', '--'); % 点线
        % end
    end
    