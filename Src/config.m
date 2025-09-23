function cfg = config()
% config - 返回分析工具的配置参数（全新分层：global/ate/ape/cbee）
%
% 输出:
%   cfg - (struct) 包含所有配置参数的结构体

    cfg = struct();
    
%% === global（全局：含可视化、通用保存） ===
    cfg.global = struct();

    % 可视化参数（全局共享）
    cfg.global.visual = struct();
    cfg.global.visual.font_name           = 'Arial';
    cfg.global.visual.font_size_base      = 9;      % pt
    cfg.global.visual.figure_width_cm     = 8.8;    % cm
    cfg.global.visual.figure_height_cm    = 8.8;    % cm
    cfg.global.visual.font_size_multiple  = 3;      % 倍数
    cfg.global.visual.figure_size_multiple= 3;      % 倍数

    % 轨迹样式（全局共享）
    cfg.global.visual.gt_color            = [25, 158, 34]/255;  % 绿色 rgb(25,158,34)
    cfg.global.visual.gt_line_style       = '-';
    cfg.global.visual.gt_line_width       = 1.5;

    cfg.global.visual.corrupted_color     = [255, 66, 37]/255;  % 红色 rgb(255,66,37)
    cfg.global.visual.corrupted_line_style= '-';
    cfg.global.visual.corrupted_line_width= 1.5;

    cfg.global.visual.optimized_color     = [58, 104, 231]/255;  % 蓝色 rgb(58,104,231)
    cfg.global.visual.optimized_line_style= '-';
    cfg.global.visual.optimized_line_width= 1.5;

    cfg.global.visual.est_color           = cfg.global.visual.corrupted_color;  % 与corrupted_color相同
    cfg.global.visual.est_line_style      = '-';
    cfg.global.visual.trajectory_line_width = 1.5;

    % 通用保存
    cfg.global.save = struct();
    cfg.global.save.enable    = true;
    cfg.global.save.figures   = true;
    cfg.global.save.data      = true;
    cfg.global.save.formats   = {'png','eps'};
    cfg.global.save.dpi       = 600;
    cfg.global.save.timestamp = 'yyyyMMdd_HHmmss';  % 格式：yyyyMMdd_HHmmss

%% === ate（ATE 模块） ===
    cfg.ate = struct();

    % 输入与辅助参数
    cfg.ate.paths = struct();

    % ATE 主流程输入文件夹与标准文件名
    % cfg.ate.paths.input_folder = 'Data\250828_NESP_noINS_seed40_yaw_0.05_0.005rad';
    % cfg.ate.paths.input_folder = 'Data\250905_noNESP_noINS_seed40_yaw_0.05_0.005rad';
    cfg.ate.paths.input_folder         = 'Data\250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5';

    cfg.ate.paths.gt_file_name         = 'poses_original.txt';
    cfg.ate.paths.est_corrupted_name   = 'poses_corrupted.txt';
    cfg.ate.paths.est_optimized_name   = 'poses_optimized.txt';
    
    % ATE 输出路径配置
    cfg.ate.paths.output_data = 'Results/ATE/ATE_data';
    cfg.ate.paths.output_distributions = 'Results/ATE/ATE_distributions';
    
    % 可视化/分析参数
    cfg.ate.histogram_bins = 50;

    % ATE 分布（BoxViolin）输入
    cfg.ate.paths.boxviolin_files      = {
        'Results\250828_NESP_noINS_seed40_yaw_0.05_0.005rad\ate_details_optimized.csv', ...
        'Results\250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5\ate_details_optimized.csv'
    };

    % 标签/绘图辅助
    cfg.ate.labels = {'NESP', 'Comb'};

    % 保存
    cfg.ate.save = struct();
    cfg.ate.save.enable = true;

%% === ape（APE 模块） ===
    cfg.ape = struct();

    % 输入路径
    cfg.ape.paths = struct();

    % % NESP数据文件路径
    % cfg.ape.paths.nesp_slam = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.ape.paths.nesp_gt   = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    % cfg.ape.paths.comb_slam = 'Data/250905_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.ape.paths.comb_gt   = 'Data/250905_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    % cfg.ape.paths.comb_slam = 'Data/250828_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.ape.paths.comb_gt   = 'Data/250828_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    % cfg.ape.paths.comb_slam = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.6/poses_optimized.txt';
    % cfg.ape.paths.comb_gt   = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.6/poses_original.txt';
    
    cfg.ape.paths.nesp_slam = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    cfg.ape.paths.nesp_gt   = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';
    
    cfg.ape.paths.comb_slam = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_optimized.txt';
    cfg.ape.paths.comb_gt   = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_original.txt';

    % APE 输出路径配置
    cfg.ape.paths.output_visualization = 'Results/APE/APE_visualization';

    % 选项/绘图
    cfg.ape.options = struct();
    cfg.ape.options.enable_alignment = true;
    cfg.ape.plot = struct();
    cfg.ape.plot.legend_labels = {'NESP', 'Comb'};

    % 保存
    cfg.ape.save = struct();
    cfg.ape.save.enable = true;

    %% === cbee（CBEE 模块） ===
    cfg.cbee = struct();

    % 路径
    cfg.cbee.paths = struct();
    cfg.cbee.paths.gt_pcd_dir       = 'Data/CBEE/smallTest/submaps';
    cfg.cbee.paths.poses_original   = 'Data/CBEE/smallTest/poses_original.txt';
    cfg.cbee.paths.poses_optimized  = 'Data/CBEE/smallTest/poses_optimized.txt';
    
    % CBEE 输出路径配置
    cfg.cbee.paths.output_data_results = 'Results/CBEE/CBEE_data_results';
    cfg.cbee.paths.output_optimized_submaps = 'Results/CBEE/CBEE_optimized_submaps';

    % 算法参数
    cfg.cbee.cell_size_xy        = 0.5;  % 栅格边长(米)。建议 0.5~2.0，越小越精，但计算量增大。
    cfg.cbee.neighborhood_size   = 3; % 误差计算的邻域尺寸(k×k，奇数)。常用 3 或 5。
    cfg.cbee.nbr_averages        = 10; % 单格重复随机采样次数(蒙特卡洛平均)。数值越大越稳定但更慢。
    cfg.cbee.min_points_per_cell = 3; % 参与误差计算的最小点数阈值。小于该值时该格的一致性误差记为 NaN。
    cfg.cbee.use_parallel        = true; % 是否在格级启用并行(parfor)。数据量大时建议开启。
    cfg.cbee.num_workers         = []; % int/[] 并行工作线程数；[] 表示由 MATLAB 自动管理。
    cfg.cbee.random_seed         = 42; % 随机种子，便于复现实验；[] 表示不固定。

    % 可视化
    cfg.cbee.visualize = struct();
    cfg.cbee.visualize.enable                  = true; % 是否在流程中进行可视化
    cfg.cbee.visualize.colormap                = 'jet'; % 误差/高程图的色图(如 'parula'/'jet' 等)
    cfg.cbee.visualize.plot_individual_submaps = false; % 是否单独绘制每幅子地图
    cfg.cbee.visualize.sample_rate             = 0.5; % 子地图可视化采样率，降低绘制点数以提高速度

    % 处理选项
    cfg.cbee.options = struct();
    cfg.cbee.options.generate_optimized_submaps = true; % 是否先基于轨迹生成“优化子地图”
    cfg.cbee.options.save_optimized_submaps     = true; % 是否将优化后的子地图持久化到磁盘
    cfg.cbee.options.save_CBEE_data_results     = true; % 是否导出 CBEE 结果(图片/CSV/MAT)
    cfg.cbee.options.load_only                  = false; % 仅加载数据，不执行 CBEE 计算与导出。

end
