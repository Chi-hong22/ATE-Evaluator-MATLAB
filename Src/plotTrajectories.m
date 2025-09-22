%% plotTrajectories - 在指定的坐标轴上绘制3D轨迹的2D俯视图对比
%
% 用法1（对齐轨迹对比模式）:
%   plotTrajectories(ax, gt_traj, aligned_est_traj, 'aligned')
%   plotTrajectories(ax, gt_traj, aligned_est_traj, cfg, 'aligned')
%
% 用法2（原始轨迹绘制模式）:
%   plotTrajectories(ax, gt_traj, corrupted_traj, optimized_traj, 'raw')
%   plotTrajectories(ax, gt_traj, corrupted_traj, optimized_traj, cfg, 'raw')
%
% 输入参数:
%   ax                - (axes handle) 用于绘图的坐标轴句柄
%   gt_traj           - (Nx3 double) 地面真实轨迹 [x, y, z]
%   
%   对齐轨迹对比模式的参数:
%     aligned_est_traj  - (Nx3 double) 对齐后的估计轨迹 [x, y, z]
%     cfg               - (struct) 配置参数结构体 (可选，默认使用config())
%     'aligned'         - (string) 模式标识，必须为'aligned'以启用对齐模式
%
%   原始轨迹绘制模式的参数:
%     corrupted_traj    - (Nx3 double) corrupted估计轨迹 [x, y, z] (可为空[])
%     optimized_traj    - (Nx3 double) optimized估计轨迹 [x, y, z] (可为空[])
%     cfg               - (struct) 配置参数结构体 (可选，默认使用config())
%     'raw'             - (string) 模式标识，必须为'raw'以启用原始轨迹模式

function plotTrajectories(ax, gt_traj, varargin)
%% 样式配置初始化
    % 样式配置已迁移到 config.global.visual 中，确保参数一致性


%% 输入参数解析与验证

    % 初始化变量
    corrupted_traj = [];
    optimized_traj = [];
    aligned_est_traj = [];
    
    % 参数数量检查
    num_args = length(varargin);
    if num_args < 1
        error('plotTrajectories:InsufficientArgs', '至少需要一个轨迹参数');
    end
    
    % 判断使用模式：要求显式指定模式标识
    if num_args < 2 || ~ischar(varargin{end})
        error('plotTrajectories:MissingMode', '必须显式指定模式标识: ''raw'' 或 ''aligned''');
    end
    
    mode_identifier = varargin{end};
    
    if strcmp(mode_identifier, 'raw')
        % === Raw模式参数解析 ===
        mode = 'raw';
        
        % 参数结构: (ax, gt_traj, corrupted_traj, optimized_traj, [cfg], 'raw')
        if num_args < 4  % 最少需要4个参数: corrupted_traj, optimized_traj, cfg, 'raw'
            error('plotTrajectories:InsufficientRawArgs', 'Raw模式至少需要4个参数');
        end
        
        corrupted_traj = varargin{1};
        optimized_traj = varargin{2};
        
        % 配置参数处理
        if num_args >= 5  % 包含cfg参数
            cfg = varargin{3};
        else  % 只有4个参数，使用默认配置
            cfg = config();
        end
        
    elseif strcmp(mode_identifier, 'aligned')
        % === Aligned模式参数解析 ===
        mode = 'aligned';
        
        % 参数结构: (ax, gt_traj, aligned_est_traj, [cfg], 'aligned')
        if num_args < 3  % 最少需要3个参数: aligned_est_traj, cfg, 'aligned'
            error('plotTrajectories:InsufficientAlignedArgs', 'Aligned模式至少需要3个参数');
        end
        
        aligned_est_traj = varargin{1};
        
        % 配置参数处理
        if num_args >= 4  % 包含cfg参数
            cfg = varargin{2};
        else  % 只有3个参数，使用默认配置
            cfg = config();
        end
        
    else
        error('plotTrajectories:InvalidMode', '无效的模式标识: %s。支持的模式: ''raw'' 或 ''aligned''', mode_identifier);
    end
    
    % 参数验证
    if isempty(cfg)
        cfg = config();
    end


%% 轨迹数据绘制

    % 开始绘图 (只使用X和Y坐标进行2D俯视图绘制)
    hold(ax, 'on');
    
    if strcmp(mode, 'raw')
        % 原始轨迹模式：使用配置文件样式绘制多条轨迹
        
        % 绘制Ground Truth轨迹
        plot(ax, gt_traj(:, 1), gt_traj(:, 2), ...
            'Color', cfg.global.visual.gt_color, ...
            'LineStyle', cfg.global.visual.gt_line_style, ...
            'LineWidth', cfg.global.visual.gt_line_width);

        % 绘制Corrupted轨迹（若存在）
        if ~isempty(corrupted_traj)
            plot(ax, corrupted_traj(:, 1), corrupted_traj(:, 2), ...
                'Color', cfg.global.visual.corrupted_color, ...
                'LineStyle', cfg.global.visual.corrupted_line_style, ...
                'LineWidth', cfg.global.visual.corrupted_line_width);
        end

        % 绘制Optimized轨迹（若存在）
        if ~isempty(optimized_traj)
            plot(ax, optimized_traj(:, 1), optimized_traj(:, 2), ...
                'Color', cfg.global.visual.optimized_color, ...
                'LineStyle', cfg.global.visual.optimized_line_style, ...
                'LineWidth', cfg.global.visual.optimized_line_width);
        end
        
    else
        % 对齐轨迹对比模式：使用配置文件样式绘制对比轨迹
        
        % 绘制地面真实轨迹
        plot(ax, gt_traj(:, 1), gt_traj(:, 2), ...
            'Color', cfg.global.visual.gt_color, ...
            'LineStyle', cfg.global.visual.gt_line_style, ...
            'LineWidth', cfg.global.visual.gt_line_width);
        
        % 绘制对齐后的估计轨迹
        plot(ax, aligned_est_traj(:, 1), aligned_est_traj(:, 2), ...
            'Color', cfg.global.visual.est_color, ...
            'LineStyle', cfg.global.visual.est_line_style, ...
            'LineWidth', cfg.global.visual.trajectory_line_width);
    end
    
    hold(ax, 'off');
    
%% 坐标轴范围优化
    

    % 保持x, y轴比例一致
    axis(ax, 'equal');
    
    % 收集所有轨迹的坐标数据以计算最优显示范围
    all_x = gt_traj(:, 1);
    all_y = gt_traj(:, 2);
    
    if strcmp(mode, 'raw')
        % 原始轨迹模式：收集所有轨迹的坐标
        if ~isempty(corrupted_traj)
            all_x = [all_x; corrupted_traj(:, 1)];
            all_y = [all_y; corrupted_traj(:, 2)];
        end
        if ~isempty(optimized_traj)
            all_x = [all_x; optimized_traj(:, 1)];
            all_y = [all_y; optimized_traj(:, 2)];
        end
    else
        % 对齐轨迹对比模式：添加估计轨迹坐标
        all_x = [all_x; aligned_est_traj(:, 1)];
        all_y = [all_y; aligned_est_traj(:, 2)];
    end
    
    % 计算数据的实际范围
    x_range = max(all_x) - min(all_x);
    y_range = max(all_y) - min(all_y);
    
    % 添加少量边距以避免轨迹贴边（可根据需要调整边距比例）
    margin_ratio = 0.01;  % 1%边距，减少空白区域
    x_margin = x_range * margin_ratio;
    y_margin = y_range * margin_ratio;
    
    % 设置优化后的坐标轴显示范围
    xlim(ax, [min(all_x) - x_margin, max(all_x) + x_margin]);
    ylim(ax, [min(all_y) - y_margin, max(all_y) + y_margin]);
    
    set(ax, 'LooseInset', get(ax, 'TightInset')); % 设置紧凑视图

%% 图形属性设置
    % 设置网格和边框
    grid(ax, 'off');
    box(ax, 'off');
    
    % 设置坐标轴可见性与字体
    set(ax, 'Visible', 'on'); 
    xlabel(ax, 'X (m)', 'FontName', cfg.global.visual.font_name);
    ylabel(ax, 'Y (m)', 'FontName', cfg.global.visual.font_name);
    set(ax, 'FontName', cfg.global.visual.font_name);

end
