function [timestamps, trajectory] = readTrajectory(file_path)
% readTrajectory - 从 .txt 文件中读取带时间戳的 3D 轨迹数据
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

    % 验证数据格式是否正确 (N x 4)
    [~, cols] = size(data);
    if cols ~= 4
        error('输入文件格式错误，应为 N x 4 矩阵 [timestamp, x, y, z]，但实际为 N x %d', cols);
    end
    
    % 分离时间戳和轨迹坐标
    timestamps = data(:, 1);
    trajectory = data(:, 2:4);

end
