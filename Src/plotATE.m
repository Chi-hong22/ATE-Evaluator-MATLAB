function [fig_timeseries, fig_histogram, fig_cdf] = plotATE(ate_metrics, cfg)
% plotATE - 创建三个独立的图窗来可视化ATE指标
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

    % --- 准备通用标题 ---
    stats_text = sprintf('RMSE: %.4f, Mean: %.4f, Median: %.4f, Std: %.4f (m)', ...
                         ate_metrics.rmse, ate_metrics.mean, ...
                         ate_metrics.median, ate_metrics.std);

    % --- 1. 创建 ATE 时序图 ---
    fig_timeseries = figure('Name', 'ATE vs. Time');
    plot(ate_metrics.errors, 'r-');
    grid on;
    xlabel('Frame Index');
    ylabel('ATE (m)');
    title({'ATE vs. Time', stats_text});
    
    % --- 2. 创建 ATE 直方图 ---
    fig_histogram = figure('Name', 'ATE Histogram');
    histogram(ate_metrics.errors, cfg.ATE_HISTOGRAM_BINS);
    grid on;
    xlabel('ATE (m)');
    ylabel('Frequency');
    title({'ATE Histogram', stats_text});
    
    % --- 3. 创建 ATE 累积分布函数 (CDF) ---
    fig_cdf = figure('Name', 'ATE CDF');
    cdfplot(ate_metrics.errors);
    grid on;
    xlabel('ATE (m)');
    ylabel('Cumulative Probability');
    title({'ATE Cumulative Distribution', stats_text});
    
end
