function [timestamps, trajectory] = readTrajectory(file_path)
% readTrajectory - 从 .txt 文件中读取 3D 轨迹数据
%
% 支持多种轨迹文件格式:
%   - 3列格式: [x, y, z] - 仅位置，自动生成时间戳
%   - 4列格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置
%   - 7列格式: [x, y, z, qx, qy, qz, qw] - 仅位置+四元数，自动生成时间戳
%   - 8列格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿数据
%
% 注意: 四元数信息会被忽略，只返回位置信息用于ATE计算
%
% 输入:
%   file_path - (string) 数据文件的路径
%
% 输出:
%   timestamps - (Nx1 double) 时间戳向量
%   trajectory - (Nx3 double) 包含 [x, y, z] 坐标的轨迹数据

    % 检查文件是否存在
    if ~isfile(file_path)
        error('文件不存在: %s', file_path);
    end

    % 使用 readmatrix 读取数据
    try
        data = readmatrix(file_path);
    catch ME
        error('无法读取文件 %s: %s', file_path, ME.message);
    end

    % 获取数据维度
    [num_rows, num_cols] = size(data);
    
    % 根据列数确定数据格式并提取时间戳和轨迹
    switch num_cols
        case 3
            % 格式: [x, y, z] - 仅位置
            fprintf('检测到3列格式: [x, y, z] - 仅位置数据\n');
            timestamps = (1:num_rows)'; % 生成序列索引作为时间戳
            trajectory = data;
            
        case 4
            % 格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置
            fprintf('检测到4列格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置数据\n');
            timestamps = data(:, 1);
            trajectory = data(:, 2:4);
            
        case 7
            % 格式: [x, y, z, qx, qy, qz, qw] - 仅位置+四元数
            fprintf('检测到7列格式: [x, y, z, qx, qy, qz, qw] - 位置+四元数数据（忽略旋转）\n');
            timestamps = (1:num_rows)'; % 生成序列索引作为时间戳
            trajectory = data(:, 1:3);
            
        case 8
            % 格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿
            fprintf('检测到8列格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿数据（忽略旋转）\n');
            timestamps = data(:, 1);
            trajectory = data(:, 2:4);
            
        otherwise
            error('不支持的文件格式！数据应为3、4、7或8列，但实际为%d列\n支持的格式:\n  3列: [x, y, z]\n  4列: [timestamp, x, y, z]\n  7列: [x, y, z, qx, qy, qz, qw]\n  8列: [timestamp, x, y, z, qx, qy, qz, qw]', num_cols);
    end
    
    % 验证提取的数据
    if size(trajectory, 2) ~= 3
        error('轨迹数据必须为3列 [x, y, z]，但提取到 %d 列', size(trajectory, 2));
    end
    
    fprintf('成功读取轨迹数据: %d 个数据点\n', num_rows);

end
