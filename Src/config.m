function cfg = config()
% config - 返回ATE分析工具的配置参数
%
% 输出:
%   cfg - (struct) 包含所有配置参数的结构体

    cfg = struct();
    
    %% === 输入文件配置 ===
    % 输入文件夹路径 (请修改为您的数据文件夹)
    % cfg.INPUT_FOLDER = 'Data\250828_NESP_noINS_seed40_yaw_0.05_0.005rad';
    % cfg.INPUT_FOLDER = 'Data\250905_noNESP_noINS_seed40_yaw_0.05_0.005rad';
    cfg.INPUT_FOLDER = 'Data\250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5';
    
    % 标准文件名
    cfg.GT_FILE_NAME = 'poses_original.txt';        % 真值轨迹文件名
    cfg.EST_CORRUPTED_FILE_NAME = 'poses_corrupted.txt';  % 估计轨迹文件名1
    cfg.EST_OPTIMIZED_FILE_NAME = 'poses_optimized.txt';  % 估计轨迹文件名2
    
    %% === 输出控制开关（旧） ===
    cfg.SAVE_FIGURES = true;  % 旧键：图像保存开关（将映射到 cfg.save.global.figures）
    cfg.SAVE_DATA = true;     % 旧键：数据保存开关（将映射到 cfg.save.global.data）

    %% === 结果保存配置（旧） ===
    cfg.RESULTS_DIR_BASE = 'Results';  % 旧键：结果根目录（将映射到 cfg.save.global.base_dir）

    %% === 统一保存配置（新） ===
    % 全局默认
    cfg.save = struct();
    cfg.save.global = struct();
    cfg.save.global.base_dir = cfg.RESULTS_DIR_BASE; % 兼容旧键
    cfg.save.global.enable = true;                    % 总开关
    cfg.save.global.figures = cfg.SAVE_FIGURES;      % 兼容旧键
    cfg.save.global.data = cfg.SAVE_DATA;            % 兼容旧键
    cfg.save.global.formats = {'png'};               % 导出图像格式
    cfg.save.global.dpi = 600;                       % 导出DPI（默认复用 cfg.DPI，稍后覆盖）
    cfg.save.global.timestamp = 'yyyymmdd_HHMMSS';   % 时间戳格式
    cfg.save.global.dir_scheme = 'typed_hierarchy';  % 目录策略标识（供resultsManager使用）

    % ATE 类型（细分到 data/distributions 二级）
    cfg.save.ATE = struct();
    % 可在运行时选择 subType: 'ATE_data' 或 'ATE_distributions'
    cfg.save.ATE.enable = true;        % 缺省继承 global，可单独覆盖
    cfg.save.ATE.figures = [];         % [] 表示继承 global
    cfg.save.ATE.data = [];            % [] 表示继承 global
    cfg.save.ATE.formats = {};         % 空表示继承 global
    cfg.save.ATE.dpi = [];             % 空表示继承 global

    % APE 类型
    cfg.save.APE = struct();
    % 旧键 APE_SAVE_RESULTS 将映射到 cfg.save.APE.enable
    cfg.save.APE.enable = [];          % 空表示继承 global；稍后用旧键覆盖
    cfg.save.APE.figures = [];         % APE 主要输出图像
    cfg.save.APE.data = [];            % 一般无数据导出
    cfg.save.APE.formats = {};         % 继承 global
    cfg.save.APE.dpi = [];             % 继承 global

    % CBEE 类型（细分到 optimized_submaps / data_results 二级）
    cfg.save.CBEE = struct();
    cfg.save.CBEE.enable = [];         % 空表示继承 global
    cfg.save.CBEE.figures = [];        % 继承 global
    cfg.save.CBEE.data = [];           % 继承 global
    cfg.save.CBEE.formats = {};        % 继承 global
    cfg.save.CBEE.dpi = [];            % 继承 global
    
    %% === 绘图参数配置 ===
    % 基础参数
    cfg.FONT_NAME = 'Arial';       % 全局字体名称
    cfg.FONT_SIZE_BASE = 9;        % 基础字体大小 (pt)
    cfg.FIGURE_WIDTH_CM = 8.8;     % 图窗宽度 (cm)
    cfg.FIGURE_HEIGHT_CM = 8.8;    % 图窗高度 (cm)
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
    
    %% === BoxViolin分布图配置 ===
    % ATE数据文件路径
    cfg.BOXVIOLIN_FILES = {
        'Results\250828_NESP_noINS_seed40_yaw_0.05_0.005rad\ate_details_optimized.csv', ...
        'Results\250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5\ate_details_optimized.csv'
    };
    
    % BoxViolin图例标签
    cfg.BOXVIOLIN_LABELS = {'NESP', 'Comb'};
    
    % BoxViolin分析参数
    cfg.BOXVIOLIN_SAVE_RESULTS = true;    % 保存结果

    %% === APE对比分析配置 ===
    % NESP数据文件路径
    cfg.APE_NESP_SLAM_PATH = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    cfg.APE_NESP_GT_PATH   = 'Data/250828_NESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';
    
    % Comb数据文件路径
    % cfg.APE_COMB_SLAM_PATH = 'Data/250905_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.APE_COMB_GT_PATH   = 'Data/250905_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    % cfg.APE_COMB_SLAM_PATH = 'Data/250828_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.APE_COMB_GT_PATH   = 'Data/250828_noNESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    cfg.APE_COMB_SLAM_PATH = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_optimized.txt';
    cfg.APE_COMB_GT_PATH   = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_original.txt';

    % cfg.APE_COMB_SLAM_PATH = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.6/poses_optimized.txt';
    % cfg.APE_COMB_GT_PATH   = 'Data/250911_Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.6/poses_original.txt';

    % APE对比图例标签
    cfg.APE_LEGEND_LABELS = {'NESP', 'Comb'};

    % APE分析参数（旧键保留：用于映射到新保存键）
    cfg.APE_ENABLE_ALIGNMENT = true;      % 启用时间对齐
    cfg.APE_SAVE_RESULTS = true;          % 旧键：保存结果（将映射到 cfg.save.APE.enable）
    
    %% === 统一保存配置覆盖：基于旧键与现有参数进行映射 ===
    % 全局 DPI 与旧键覆盖
    cfg.save.global.dpi = cfg.DPI;
    % APE 旧键 -> 新键
    if ~isempty(cfg.APE_SAVE_RESULTS)
        cfg.save.APE.enable = logical(cfg.APE_SAVE_RESULTS);
    end
    % 结果根目录旧键 -> 新键
    if ~isempty(cfg.RESULTS_DIR_BASE)
        cfg.save.global.base_dir = cfg.RESULTS_DIR_BASE;
    end
    % 图/数据保存开关旧键 -> 新键
    if ~isempty(cfg.SAVE_FIGURES)
        cfg.save.global.figures = logical(cfg.SAVE_FIGURES);
    end
    if ~isempty(cfg.SAVE_DATA)
        cfg.save.global.data = logical(cfg.SAVE_DATA);
    end
    
    %% === CBEE一致性误差评估配置 ===
    % 数据路径配置
    cfg.paths = struct();
    cfg.paths.gt_pcd_dir = 'Data/CBEE/smallTest/submaps';  % 子地图目录
    cfg.paths.poses_original = 'Data/CBEE/smallTest/poses_original.txt';  % 原始轨迹
    cfg.paths.poses_optimized = 'Data/CBEE/smallTest/poses_optimized.txt';  % 优化轨迹
    cfg.paths.output_dir = 'Results/CBEE_test';  % 结果输出目录（过渡期：若存在可作为 CBEE base_dir 覆盖）
    cfg.paths.output_submaps_dir = fullfile(cfg.paths.output_dir, 'submaps');  % 优化子地图输出目录
    
    % CBEE算法参数
    cfg.cbee = struct();
    cfg.cbee.cell_size_xy = 0.5;  % 栅格尺寸（米）
    cfg.cbee.neighborhood_size = 3;  % 邻域大小（3x3）
    cfg.cbee.nbr_averages = 10;  % 单格采样次数
    cfg.cbee.min_points_per_cell = 3;  % 单格最小点数
    cfg.cbee.use_parallel = true;  % 是否使用并行计算
    cfg.cbee.num_workers = [];  % 并行计算工作线程数（空表示自动）
    cfg.cbee.random_seed = 42;  % 随机种子（用于结果复现）
    
    % CBEE可视化参数
    cfg.cbee.visualize = struct();
    cfg.cbee.visualize.enable = true;  % 是否显示中间结果可视化
    cfg.cbee.visualize.colormap = 'parula';  % 热力图颜色映射
    cfg.cbee.visualize.plot_individual_submaps = false;  % 是否单独显示子地图
    cfg.cbee.visualize.sample_rate = 0.05;  % 点云可视化采样率
    
    % CBEE处理选项
    cfg.cbee.options = struct();
    cfg.cbee.options.generate_optimized_submaps = true;  % 是否生成优化子地图
    cfg.cbee.options.save_optimized_submaps = false;      % 是否持久化保存优化子地图（默认关闭）
    cfg.cbee.options.save_CBEE_data_results = false;          % 是否保存最终结果文件（默认关闭）
    cfg.cbee.options.load_only = false;  % 仅加载数据，不执行计算（调试用）
end
