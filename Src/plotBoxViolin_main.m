function plotBoxViolin_main()
% plotBoxViolin_main - 入口脚本,用于终端调用或直接运行
%
% 该脚本会自动加载配置,并调用 plotErrorDistributions 函数.
% 用户可以在此脚本中预定义文件和标签,否则将以交互方式选择.
%

    % =========================================================================
    %                           == 用户配置区 ==
    %
    % 预定义文件路径和标签. 如果 files_to_plot 留空 {}, 将会弹出文件选择对话框.
    % 示例:
    % files_to_plot = {
    %     'Data\ate_A.csv', ...
    %     'Data\ate_B.csv'
    % };
    % labels_for_plot = {'Method A', 'Method B'};
    % =========================================================================
    
    files_to_plot   =   {'Results\250828_NESP_noINS_seed40_yaw_0.05_0.005rad\ate_details_optimized.csv',...
'Results\250905_noNESP_noINS_seed40_yaw_0.05_0.005rad\ate_details_optimized.csv'}; % <--- 在这里填入文件路径 (相对或绝对)
    labels_for_plot = {'NESP','noNESP'}; % <--- 在这里填入对应的标签

    % 确保 Src 目录在路径中
    if isempty(strfind(path, 'Src'))
        addpath(genpath('Src'));
    end

    % 加载配置
    cfg_data = config();
    
    % 调用核心绘图函数
    plotErrorDistributions('cfg', cfg_data, ...
                           'files', files_to_plot, ...
                           'labels', labels_for_plot, ...
                           'save', true);
    
    fprintf('Plot generation complete.\n');

end
