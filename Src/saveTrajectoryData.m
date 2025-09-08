function saveTrajectoryData(results_dir, traj_name, ate_metrics, traj_data)
% saveTrajectoryData - 保存轨迹分析的各种数据文件
%
% 输入:
%   results_dir  - (string) 结果保存目录
%   traj_name    - (string) 轨迹名称 (如 'corrupted', 'optimized')
%   ate_metrics  - (struct) ATE指标结构体
%   traj_data    - (struct) 轨迹数据结构体，包含：
%                  .timestamps - 时间戳
%                  .original_estimated - 原始估计轨迹
%                  .aligned_estimated - 对齐后估计轨迹
%                  .ground_truth - 真值轨迹
%                  .alignment_type - 对齐类型

    % --- 1. 保存JSON指标摘要 ---
    json_data = struct();
    json_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    json_data.alignment_type = traj_data.alignment_type;
    json_data.num_poses = length(ate_metrics.errors);
    
    % 基本指标
    json_data.metrics = struct();
    json_data.metrics.rmse = ate_metrics.rmse;
    json_data.metrics.mean = ate_metrics.mean;
    json_data.metrics.median = ate_metrics.median;
    json_data.metrics.std = ate_metrics.std;
    json_data.metrics.max = max(ate_metrics.errors);
    json_data.metrics.min = min(ate_metrics.errors);
    
    % 统计分位数
    json_data.statistics = struct();
    json_data.statistics.percentile_25 = prctile(ate_metrics.errors, 25);
    json_data.statistics.percentile_75 = prctile(ate_metrics.errors, 75);
    json_data.statistics.percentile_95 = prctile(ate_metrics.errors, 95);
    json_data.statistics.percentile_99 = prctile(ate_metrics.errors, 99);
    
    json_filename = fullfile(results_dir, sprintf('ate_metrics_%s.json', traj_name));
    json_str = jsonencode(json_data, 'PrettyPrint', true);
    fid = fopen(json_filename, 'w');
    fprintf(fid, '%s', json_str);
    fclose(fid);
    
    % --- 2. 保存CSV详细数据 ---
    csv_filename = fullfile(results_dir, sprintf('ate_details_%s.csv', traj_name));
    csv_data = [traj_data.timestamps, ate_metrics.errors];
    csvwriteWithHeader(csv_filename, csv_data, {'timestamp', 'ate_error'});
    
    % --- 3. 保存对齐后轨迹数据 (TXT格式) ---
    txt_filename = fullfile(results_dir, sprintf('aligned_trajectory_%s.txt', traj_name));
    fid = fopen(txt_filename, 'w');
    fprintf(fid, '%% Aligned Trajectory Data - %s\n', traj_name);
    fprintf(fid, '%% Format: timestamp x_gt y_gt z_gt x_est y_est z_est x_aligned y_aligned z_aligned\n');
    for j = 1:length(traj_data.timestamps)
        fprintf(fid, '%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f\n', ...
            traj_data.timestamps(j), ...
            traj_data.ground_truth(j, 1), traj_data.ground_truth(j, 2), traj_data.ground_truth(j, 3), ...
            traj_data.original_estimated(j, 1), traj_data.original_estimated(j, 2), traj_data.original_estimated(j, 3), ...
            traj_data.aligned_estimated(j, 1), traj_data.aligned_estimated(j, 2), traj_data.aligned_estimated(j, 3));
    end
    fclose(fid);
    
    % --- 4. 保存对齐后轨迹数据 (MAT格式) ---
    mat_filename = fullfile(results_dir, sprintf('aligned_trajectory_%s.mat', traj_name));
    save_data = struct();
    save_data.timestamps = traj_data.timestamps;
    save_data.original_estimated = traj_data.original_estimated;
    save_data.aligned_estimated = traj_data.aligned_estimated;
    save_data.ground_truth = traj_data.ground_truth;
    save_data.alignment_type = traj_data.alignment_type;
    save_data.ate_metrics = ate_metrics;
    save(mat_filename, '-struct', 'save_data');

end

function csvwriteWithHeader(filename, data, headers)
% csvwriteWithHeader - 写入带表头的CSV文件
%
% 输入:
%   filename - (string) 文件名
%   data     - (matrix) 数据矩阵
%   headers  - (cell array) 表头字符串数组

    fid = fopen(filename, 'w');
    
    % 写入表头
    for i = 1:length(headers)
        fprintf(fid, '%s', headers{i});
        if i < length(headers)
            fprintf(fid, ',');
        end
    end
    fprintf(fid, '\n');
    
    % 写入数据
    for i = 1:size(data, 1)
        for j = 1:size(data, 2)
            fprintf(fid, '%.6f', data(i, j));
            if j < size(data, 2)
                fprintf(fid, ',');
            end
        end
        fprintf(fid, '\n');
    end
    
    fclose(fid);
end
