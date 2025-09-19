function main_plotBoxViolin()
% main_plotBoxViolin - 入口脚本,用于终端调用或直接运行
%
% 该脚本会自动加载配置,并调用 plotATEDistributions 函数.
% 用户可以在此脚本中预定义文件和标签,否则将以交互方式选择.
%

    % =========================================================================
    %                           == 统一配置管理 ==
    %
    % 配置文件路径和标签现在由 config.m 统一管理
    % 如需修改文件路径和标签，请编辑 Src/config.m 文件
    % =========================================================================
    clear; clc;

    fprintf('=== ATE 统计数据对比绘制 ===\n');
    fprintf('开始时间: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    % 确保 Src 目录在路径中
    if isempty(strfind(path, 'Src'))
        addpath(genpath('Src'));
    end

    % 加载统一配置
    cfg_data = config();
    
    % 从配置中获取文件路径和标签
    files_to_plot = cfg_data.BOXVIOLIN_FILES;
    labels_for_plot = cfg_data.BOXVIOLIN_LABELS;
    
    % 调用核心绘图函数，使用统一配置的参数
    plotATEDistributions('cfg', cfg_data, ...
                           'files', files_to_plot, ...
                           'labels', labels_for_plot, ...
                           'save', cfg_data.BOXVIOLIN_SAVE_RESULTS);
    
    fprintf('Plot generation complete.\n');

end
