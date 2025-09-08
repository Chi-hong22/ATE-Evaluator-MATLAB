function [ate_metrics, aligned_est_traj, gt_associated_traj] = alignAndComputeATE(gt_timestamps, gt_traj, est_timestamps, est_traj)
% alignAndComputeATE - 关联并对齐两条3D轨迹，然后计算ATE
%
% 输入:
%   gt_timestamps  - (Mx1 double) 地面真实轨迹的时间戳
%   gt_traj        - (Mx3 double) 地面真实轨迹 [x, y, z]
%   est_timestamps - (Nx1 double) 估计轨迹的时间戳
%   est_traj       - (Nx3 double) 估计轨迹 [x, y, z]
%
% 输出:
%   ate_metrics        - (struct) ATE统计指标
%   aligned_est_traj   - (Kx3 double) 对齐后的、与真实轨迹关联的估计轨迹
%   gt_associated_traj - (Kx3 double) 与估计轨迹相关联的真实轨迹子集

    % --- 1. 根据时间戳关联轨迹 ---
    % 我们将估计轨迹插值到真实轨迹的时间戳上
    
    % 找到在 est_timestamps 范围内的 gt_timestamps
    valid_indices = gt_timestamps >= est_timestamps(1) & gt_timestamps <= est_timestamps(end);
    gt_timestamps_associated = gt_timestamps(valid_indices);
    gt_associated_traj = gt_traj(valid_indices, :);
    
    % 线性插值
    est_associated_traj = interp1(est_timestamps, est_traj, gt_timestamps_associated, 'linear');
    
    % K 为关联上的点数
    K = size(gt_associated_traj, 1);
    if K < 2
        error('真实轨迹和估计轨迹之间的时间重叠太少，无法进行计算。');
    end

    % --- 2. 计算质心 ---
    gt_centroid = mean(gt_associated_traj, 1);
    est_centroid = mean(est_associated_traj, 1);
    
    % --- 3. 去中心化 ---
    gt_centered = gt_associated_traj - gt_centroid;
    est_centered = est_associated_traj - est_centroid;
    
    % --- 4. 计算协方差矩阵 H (3x3) ---
    H = est_centered' * gt_centered;
    
    % --- 5. 使用SVD求解旋转矩阵 R (3x3) ---
    [U, ~, V] = svd(H);
    R = V * U';
    
    % --- 6. 处理可能的反射情况 (特殊正交群 SO(3) 约束) ---
    if det(R) < 0
        V(:, 3) = -V(:, 3);
        R = V * U';
    end
    
    % --- 7. 计算平移向量 t (3x1) ---
    t = gt_centroid' - R * est_centroid';
    
    % --- 8. 对齐关联后的估计轨迹 ---
    aligned_est_traj = (R * est_associated_traj' + t)';
    
    % --- 9. 计算ATE ---
    errors = sqrt(sum((aligned_est_traj - gt_associated_traj).^2, 2));
    
    % --- 10. 计算统计指标 ---
    ate_metrics.rmse = sqrt(mean(errors.^2));
    ate_metrics.mean = mean(errors);
    ate_metrics.median = median(errors);
    ate_metrics.std = std(errors);
    ate_metrics.errors = errors;

end
