% main_plotAPE - XY平面 APE 对比绘制的入口脚本
%
% 此脚本提供了一个简单的入口点来调用 plotAPEComparison 函数
% 可以在 MATLAB 命令行或通过批处理模式运行
%
% 使用方法:
%   1. 在 MATLAB 中直接运行: main_plotAPE
%   2. 命令行批处理: matlab -batch "main_plotAPE"
%
% 注意: 请在运行前修改下面的文件路径为您的实际数据文件路径

clear; clc;

fprintf('=== XY平面 APE 对比绘制 ===\n');
fprintf('开始时间: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

%% === 加载配置 ===
% 获取统一配置
cfg = config();

% 从配置中获取文件路径
nesp_slam_path = cfg.APE_NESP_SLAM_PATH;
nesp_gt_path   = cfg.APE_NESP_GT_PATH;
comb_slam_path = cfg.APE_COMB_SLAM_PATH;
comb_gt_path   = cfg.APE_COMB_GT_PATH;

%% === 检查文件是否存在 ===
files_to_check = {nesp_slam_path, nesp_gt_path, comb_slam_path, comb_gt_path};
file_labels = {'NESP SLAM', 'NESP GT', 'Comb SLAM', 'Comb GT'};

fprintf('正在检查输入文件...\n');
for i = 1:length(files_to_check)
    if ~isfile(files_to_check{i})
        error('文件不存在: %s (%s)', files_to_check{i}, file_labels{i});
    else
        fprintf('✓ %s: %s\n', file_labels{i}, files_to_check{i});
    end
end
fprintf('所有输入文件检查通过。\n\n');

%% === 调用绘图函数 ===
try
    fprintf('正在调用 plotAPEComparison 函数...\n');
    
    % 调用主函数，使用统一配置的参数
    fig_handle = plotAPEComparison(...
        'nespSLAM', nesp_slam_path, ...
        'nespGT', nesp_gt_path, ...
        'combSLAM', comb_slam_path, ...
        'combGT', comb_gt_path, ...
        'align', cfg.APE_ENABLE_ALIGNMENT, ...      % 从配置获取时间对齐设置
        'save', cfg.APE_SAVE_RESULTS, ...           % 从配置获取保存设置
        'legendLabels', cfg.APE_LEGEND_LABELS, ...  % 从配置获取图例标签
        'cfg', cfg);
    
    fprintf('\n=== 执行完成 ===\n');
    fprintf('图窗句柄: Figure %d\n', fig_handle.Number);
    fprintf('结束时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    
catch ME
    fprintf('\n=== 执行出错 ===\n');
    fprintf('错误信息: %s\n', ME.message);
    fprintf('错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
    rethrow(ME);
end
