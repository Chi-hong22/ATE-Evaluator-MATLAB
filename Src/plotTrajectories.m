function plotTrajectories(ax, gt_traj, varargin)
% plotTrajectories - 在指定的坐标轴上绘制3D轨迹的2D俯视图对比
%
% 用法1（对齐轨迹对比）:
%   plotTrajectories(ax, gt_traj, aligned_est_traj, cfg)
%
% 用法2（原始轨迹绘制）:
%   plotTrajectories(ax, gt_traj, corrupted_traj, optimized_traj, cfg, 'raw')
%
% 输入:
%   ax                - (axes handle) 用于绘图的坐标轴句柄
%   gt_traj           - (Nx3 double) 地面真实轨迹 [x, y, z]
%   
%   用法1的其他输入:
%     aligned_est_traj  - (Nx3 double) 对齐后的估计轨迹 [x, y, z]
%     cfg               - (struct) 配置参数结构体 (可选)
%
%   用法2的其他输入:
%     corrupted_traj    - (Nx3 double) corrupted估计轨迹 [x, y, z] (可为空)
%     optimized_traj    - (Nx3 double) optimized估计轨迹 [x, y, z] (可为空)
%     cfg               - (struct) 配置参数结构体 (可选)
%     mode              - (string) 模式标识，'raw' 表示原始轨迹模式

    %% === 轨迹样式配置（可在此修改） ===
    % Ground Truth 样式
    gt_style.color = [25, 158, 34]/255; % 绿色rgb(25, 158, 34)
    gt_style.linestyle = '-';               % 实线
    gt_style.linewidth = 1.5;               % 线宽
    
    % Corrupted 样式  
    corrupted_style.color = [255, 66, 37]/255;  % 红色rgb(255, 66, 37)
    corrupted_style.linestyle = '--';           % 虚线
    corrupted_style.linewidth = 1.5;            % 线宽
    
    % Optimized 样式
    optimized_style.color = [58, 104, 231]/255;      % 蓝色rgb(58, 104, 231)
    optimized_style.linestyle = '-';            % 实线
    optimized_style.linewidth = 1.5;            % 线宽
    %% =======================================

    % 解析输入参数
    if length(varargin) >= 4 && ischar(varargin{end}) && strcmp(varargin{end}, 'raw')
        % 原始轨迹模式: plotTrajectories(ax, gt_traj, corrupted_traj, optimized_traj, cfg, 'raw')
        corrupted_traj = varargin{1};
        optimized_traj = varargin{2};
        if length(varargin) >= 4
            cfg = varargin{3};
        else
            cfg = config();
        end
        mode = 'raw';
    else
        % 对齐轨迹对比模式: plotTrajectories(ax, gt_traj, aligned_est_traj, cfg)
        aligned_est_traj = varargin{1};
        if length(varargin) >= 2
            cfg = varargin{2};
        else
            cfg = config();
        end
        mode = 'aligned';
    end

    % 在指定的 axes 上绘图 (只使用X和Y坐标)
    hold(ax, 'on');
    
    if strcmp(mode, 'raw')
        % 原始轨迹模式（使用内部样式配置）
        
        % Ground Truth
        plot(ax, gt_traj(:, 1), gt_traj(:, 2), ...
            'Color', gt_style.color, ...
            'LineStyle', gt_style.linestyle, ...
            'LineWidth', gt_style.linewidth);

        % Estimated - corrupted（若存在）
        if ~isempty(corrupted_traj)
            plot(ax, corrupted_traj(:, 1), corrupted_traj(:, 2), ...
                'Color', corrupted_style.color, ...
                'LineStyle', corrupted_style.linestyle, ...
                'LineWidth', corrupted_style.linewidth);
        end

        % Estimated - optimized（若存在）
        if ~isempty(optimized_traj)
            plot(ax, optimized_traj(:, 1), optimized_traj(:, 2), ...
                'Color', optimized_style.color, ...
                'LineStyle', optimized_style.linestyle, ...
                'LineWidth', optimized_style.linewidth);
        end
        
    else
        % 对齐轨迹对比模式
        
        % 绘制地面真实轨迹
        plot(ax, gt_traj(:, 1), gt_traj(:, 2), [cfg.GT_COLOR '-'], 'LineWidth', cfg.TRAJECTORY_LINE_WIDTH);
        
        % 绘制对齐后的估计轨迹
        plot(ax, aligned_est_traj(:, 1), aligned_est_traj(:, 2), [cfg.EST_COLOR cfg.EST_LINE_STYLE], 'LineWidth', cfg.TRAJECTORY_LINE_WIDTH);
    end
    
    hold(ax, 'off');
    
    % 设置坐标轴样式
    axis(ax, 'equal'); % 保持x, y轴比例一致
    grid(ax, 'off');   % 不显示网格
    box(ax, 'on');
    
    % 添加标签
    xlabel(ax, 'X (m)');
    ylabel(ax, 'Y (m)');

end
