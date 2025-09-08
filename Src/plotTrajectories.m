function plotTrajectories(ax, gt_traj, aligned_est_traj, cfg)
% plotTrajectories - 在指定的坐标轴上绘制3D轨迹的2D俯视图对比
%
% 输入:
%   ax                - (axes handle) 用于绘图的坐标轴句柄
%   gt_traj           - (Nx3 double) 地面真实轨迹 [x, y, z]
%   aligned_est_traj  - (Nx3 double) 对齐后的估计轨迹 [x, y, z]
%   cfg               - (struct) 配置参数结构体 (可选)

    % 如果没有提供配置，使用默认值
    if nargin < 4
        cfg = config();
    end

    % 在指定的 axes 上绘图 (只使用X和Y坐标)
    hold(ax, 'on');
    
    % 绘制地面真实轨迹
    plot(ax, gt_traj(:, 1), gt_traj(:, 2), [cfg.GT_COLOR '-'], 'LineWidth', cfg.TRAJECTORY_LINE_WIDTH);
    
    % 绘制对齐后的估计轨迹
    plot(ax, aligned_est_traj(:, 1), aligned_est_traj(:, 2), [cfg.EST_COLOR cfg.EST_LINE_STYLE], 'LineWidth', cfg.TRAJECTORY_LINE_WIDTH);
    
    hold(ax, 'off');
    
    % 设置坐标轴样式
    axis(ax, 'equal'); % 保持x, y轴比例一致
    grid(ax, 'on');
    box(ax, 'on');
    
    % 添加图例和标签
    legend(ax, 'Ground Truth', 'Estimated (Aligned)', 'Location', 'best');
    xlabel(ax, 'X (m)');
    ylabel(ax, 'Y (m)');
    title(ax, 'Trajectory Comparison (2D Top-Down View)');

end
