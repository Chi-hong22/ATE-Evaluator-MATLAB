function [fig_timeseries, fig_histogram, fig_cdf] = plotATEData(ate_metrics, cfg)
% plotATEData - 创建三个独立的图窗来可视化ATE指标
%
% 输入:
%   ate_metrics  - (struct) alignAndComputeATE 返回的ATE指标结构体
%   cfg          - (struct) 配置参数结构体 (可选)
%
% 输出:
%   fig_timeseries - (figure handle) ATE 时序图的图窗句柄
%   fig_histogram  - (figure handle) ATE 直方图的图窗句柄
%   fig_cdf        - (figure handle) ATE CDF图的图窗句柄

    % 如果没有提供配置，使用默认值
    if nargin < 2
        cfg = config();
    end

    % --- 准备通用统计文本（不用于标题，仅保留以备扩展） ---
    stats_text = sprintf('RMSE: %.4f, Mean: %.4f, Median: %.4f, Std: %.4f (m)', ...
                         ate_metrics.rmse, ate_metrics.mean, ...
                         ate_metrics.median, ate_metrics.std);

    % --- 1. 创建 ATE 时序图 ---
    fig_timeseries = figure('Name', 'ATE vs. Time');
    plot(ate_metrics.errors, 'r-');
    grid on;
    xlabel('Frame Index', 'FontName', cfg.global.visual.font_name);
    ylabel('ATE (m)', 'FontName', cfg.global.visual.font_name);
    set(gca, 'FontName', cfg.global.visual.font_name);
    % 不设置标题
    
    % --- 2. 创建 ATE 直方图 ---
    fig_histogram = figure('Name', 'ATE Histogram');
    nbins = 50;
    if isfield(cfg,'ate') && isfield(cfg.ate,'histogram_bins')
        nbins = cfg.ate.histogram_bins;
    end
    histogram(ate_metrics.errors, nbins);
    grid on;
    xlabel('ATE (m)', 'FontName', cfg.global.visual.font_name);
    ylabel('Frequency', 'FontName', cfg.global.visual.font_name);
    set(gca, 'FontName', cfg.global.visual.font_name);
    % 不设置标题
    
    % --- 3. 创建 ATE 累积分布函数 (CDF) ---
    fig_cdf = figure('Name', 'ATE CDF');
    cdfplot(ate_metrics.errors);
    % 清除cdfplot自动添加的标题
    title('');
    grid on;
    xlabel('ATE (m)', 'FontName', cfg.global.visual.font_name);
    ylabel('Cumulative Probability', 'FontName', cfg.global.visual.font_name);
    set(gca, 'FontName', cfg.global.visual.font_name);
    % 不设置标题
    
end
