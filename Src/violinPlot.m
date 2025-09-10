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

    % 这部分代码已移至 plotErrorDistributions.m 中绘制, 以确保图层顺序正确
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
