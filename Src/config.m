function cfg = config()
% config - 返回ATE分析工具的配置参数
%
% 输出:
%   cfg - (struct) 包含所有配置参数的结构体

    cfg = struct();
    
    %% === 输入文件配置 ===
    % 输入文件夹路径 (请修改为您的数据文件夹)
    cfg.INPUT_FOLDER = 'Data\250828_NESP_noINS_seed40_yaw_0.05_0.005rad';
    % cfg.INPUT_FOLDER = 'Data\250905_noNESP_noINS_seed40_yaw_0.05_0.005rad';
    % cfg.INPUT_FOLDER = 'Data\250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5';
    
    % 标准文件名
    cfg.GT_FILE_NAME = 'poses_original.txt';        % 真值轨迹文件名
    cfg.EST_CORRUPTED_FILE_NAME = 'poses_corrupted.txt';  % 估计轨迹文件名1
    cfg.EST_OPTIMIZED_FILE_NAME = 'poses_optimized.txt';  % 估计轨迹文件名2
    
    %% === 输出控制开关 ===
    cfg.SAVE_FIGURES = true;  % 设置为 false 则只显示图像，不保存
    cfg.SAVE_DATA = true;     % 设置为 false 则不保存数据文件
    
    %% === 结果保存配置 ===
    cfg.RESULTS_DIR_BASE = 'Results';  % 结果保存的基础目录
    
    %% === 绘图参数配置 ===
    % 基础参数
    cfg.FONT_NAME = 'Arial';       % 全局字体名称
    cfg.FONT_SIZE_BASE = 9;        % 基础字体大小 (pt)
    cfg.FIGURE_WIDTH_CM = 4.4;     % 图窗宽度 (cm)
    cfg.FIGURE_HEIGHT_CM = 4.4;    % 图窗高度 (cm)
    cfg.DPI = 600;                 % 图像分辨率
    
    % 倍数调整参数
    cfg.FONT_SIZE_MULTIPLE = 3;    % 字体大小倍数
    cfg.FIGURE_SIZE_MULTIPLE = 3;  % 图窗尺寸倍数
    
    %% === 算法参数配置 ===
    cfg.ALIGNMENT_TYPE = 'SE3';    % 对齐类型: 'SE3' 或 'SIM3'
    cfg.INTERPOLATION_METHOD = 'linear';  % 插值方法: 'linear', 'cubic', etc.
    
    %% === 可视化参数配置 ===
    % Ground Truth 样式
    cfg.GT_COLOR = [25, 158, 34]/255;     % 绿色rgb(25, 158, 34)
    cfg.GT_LINE_STYLE = '-';              % 实线
    cfg.GT_LINE_WIDTH = 1.5;                % 线宽
    
    % Corrupted 样式  
    cfg.CORRUPTED_COLOR = [255, 66, 37]/255;  % 红色rgb(255, 66, 37)
    cfg.CORRUPTED_LINE_STYLE = '-';           % 实线
    cfg.CORRUPTED_LINE_WIDTH = 1.5;             % 线宽
    
    % Optimized 样式
    cfg.OPTIMIZED_COLOR = [58, 104, 231]/255; % 蓝色rgb(58, 104, 231)
    cfg.OPTIMIZED_LINE_STYLE = '-';           % 实线
    cfg.OPTIMIZED_LINE_WIDTH = 1.5;             % 线宽
    
    % Aligned模式估计轨迹样式（保持向后兼容）
    cfg.EST_COLOR = [255, 66, 37]/255;    % 估计轨迹颜色（红色，与corrupted一致）
    cfg.EST_LINE_STYLE = '-';             % 估计轨迹线型
    cfg.TRAJECTORY_LINE_WIDTH = 1.5;        % 轨迹线宽（统一线宽）
    
    % 其他可视化参数
    cfg.ATE_HISTOGRAM_BINS = 50;          % ATE直方图的bins数量

end
