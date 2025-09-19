function [idsOrTimestamps, positions, quatsPCD] = readTrajectory(file_path, varargin)
% readTrajectory - 从 .txt 文件中读取 3D 轨迹数据
%
% 支持多种轨迹文件格式:
%   - 3列格式: [x, y, z] - 仅位置，自动生成时间戳/索引
%   - 4列格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置
%   - 7列格式: [x, y, z, qx, qy, qz, qw] - 仅位置+四元数，自动生成时间戳/索引
%   - 8列格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿数据
%
% 模式说明:
%   - 'Mode','onlypose' (默认): 返回 ids/timestamps 与 positions，忽略四元数；第三个输出为空。
%   - 'Mode','full'    : 返回 ids/timestamps、positions 以及按PCD顺序 [qw qx qy qz] 的四元数。
%
% 使用情景:
%   【onlypose模式】- 适用于只需要位置信息的场景:
%     * ATE/RPE误差计算：只需要轨迹位置进行误差分析
%     * 轨迹可视化：绘制轨迹路径，不涉及姿态显示
%     * 位置统计分析：计算轨迹长度、速度等基于位置的指标
%     * 兼容旧代码：保持与原有只返回位置数据的代码兼容
%     示例: [ids, pos, ~] = readTrajectory('trajectory.txt');  % 传统用法
%
%   【full模式】- 适用于需要完整位姿信息的场景:
%     * 优化子地图生成：需要完整位姿更新PCD文件的VIEWPOINT头部
%     * 坐标变换计算：需要旋转信息进行坐标系转换
%     * 姿态分析：分析机器人/相机的旋转行为
%     * 位姿插值：需要位置和姿态信息进行时间插值
%     示例: [ids, pos, quats] = readTrajectory('trajectory.txt', 'Mode', 'full');
%           % quats格式为PCD标准[qw qx qy qz]，可直接用于VIEWPOINT写入
%
% 输入:
%   file_path - (string) 数据文件的路径
%   Name-Value:
%       'Mode' - char/string，'onlypose' 或 'full'，默认 'onlypose'
%
% 输出:
%   idsOrTimestamps - (Nx1 double) 时间戳或位姿ID
%   positions       - (Nx3 double) [x, y, z]
%   quatsPCD        - (Nx4 double) [qw, qx, qy, qz]，仅在 'full' 模式下非空

    % 检查文件是否存在
    if ~isfile(file_path)
        error('文件不存在: %s', file_path);
    end

    % 解析参数
    mode = 'onlypose';
    if ~isempty(varargin)
        for k = 1:2:numel(varargin)
            key = varargin{k};
            if k+1 > numel(varargin)
                error('参数成对提供: Name-Value');
            end
            val = varargin{k+1};
            switch lower(string(key))
                case 'mode'
                    mode = lower(string(val));
                    if ~ismember(mode, ["onlypose","full"]) %#ok<ISMEMB>
                        error('Unsupported Mode: %s. Use ''onlypose'' or ''full''.', mode);
                    end
                otherwise
                    error('不支持的参数: %s', key);
            end
        end
    end

    % 使用 readmatrix 读取数据
    try
        data = readmatrix(file_path);
    catch ME
        error('无法读取文件 %s: %s', file_path, ME.message);
    end

    % 获取数据维度
    [num_rows, num_cols] = size(data);
    
    % 根据列数确定数据格式并提取基础数据
    switch num_cols
        case 3
            % 格式: [x, y, z] - 仅位置
            fprintf('检测到3列格式: [x, y, z] - 仅位置数据\n');
            idsOrTimestamps = (1:num_rows)'; % 生成序列索引作为ID
            positions = data(:, 1:3);
            rawQuats = []; % 无四元数数据
            
        case 4
            % 格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置
            fprintf('检测到4列格式: [timestamp/pose_id, x, y, z] - 带时间戳的位置数据\n');
            idsOrTimestamps = data(:, 1);
            positions = data(:, 2:4);
            rawQuats = []; % 无四元数数据
            
        case 7
            % 格式: [x, y, z, qx, qy, qz, qw] - 仅位置+四元数
            fprintf('检测到7列格式: [x, y, z, qx, qy, qz, qw] - 位置+四元数数据\n');
            idsOrTimestamps = (1:num_rows)'; % 生成序列索引作为ID
            positions = data(:, 1:3);
            rawQuats = data(:, 4:7); % [qx, qy, qz, qw]
            
        case 8
            % 格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿
            fprintf('检测到8列格式: [timestamp/pose_id, x, y, z, qx, qy, qz, qw] - 完整位姿数据\n');
            idsOrTimestamps = data(:, 1);
            positions = data(:, 2:4);
            rawQuats = data(:, 5:8); % [qx, qy, qz, qw]
            
        otherwise
            error('不支持的文件格式！数据应为3、4、7或8列，但实际为%d列\n支持的格式:\n  3列: [x, y, z]\n  4列: [timestamp, x, y, z]\n  7列: [x, y, z, qx, qy, qz, qw]\n  8列: [timestamp, x, y, z, qx, qy, qz, qw]', num_cols);
    end
    
    % 验证提取的数据
    if size(positions, 2) ~= 3
        error('轨迹数据必须为3列 [x, y, z]，但提取到 %d 列', size(positions, 2));
    end
    
    % 根据模式处理四元数输出
    if mode == "onlypose"
        % onlypose模式：忽略四元数，第三个输出为空
        quatsPCD = [];
        if ~isempty(rawQuats)
            fprintf('onlypose模式：忽略旋转信息\n');
        end
    else
        % full模式：处理四元数并转换为PCD格式
        quatsPCD = processQuaternions(rawQuats, num_rows);
    end

    fprintf('成功读取轨迹数据: %d 个数据点 (Mode=%s)\n', num_rows, mode);

end

function quatsPCD = processQuaternions(rawQuats, num_rows)
    % 处理四元数：转换格式并归一化
    % 输入: rawQuats - [qx, qy, qz, qw] 或 []
    % 输出: quatsPCD - [qw, qx, qy, qz] 格式的归一化四元数
    
    if isempty(rawQuats)
        % 无四元数数据，使用默认单位四元数
        quatsPCD = repmat([1 0 0 0], num_rows, 1);
        return;
    end
    
    % 转换格式：[qx, qy, qz, qw] -> [qw, qx, qy, qz]
    quatsPCD = [rawQuats(:,4), rawQuats(:,1:3)];
    
    % 归一化四元数，确保单位四元数约束
    norms = sqrt(sum(quatsPCD.^2, 2));
    zeroMask = norms < eps;  % 识别无效四元数（范数接近零）
    
    % 处理无效四元数
    if any(zeroMask)
        fprintf('警告: 发现 %d 个无效四元数，已替换为单位四元数\n', nnz(zeroMask));
    end
    
    % 归一化有效四元数
    norms(zeroMask) = 1;  % 防止除零
    quatsPCD(~zeroMask, :) = quatsPCD(~zeroMask, :) ./ norms(~zeroMask);
    
    % 无效四元数设为单位四元数 [qw=1, qx=0, qy=0, qz=0]
    quatsPCD(zeroMask, :) = repmat([1 0 0 0], nnz(zeroMask), 1);
    
    % 验证归一化结果
    final_norms = sqrt(sum(quatsPCD.^2, 2));
    if any(abs(final_norms - 1) > 1e-10)
        warning('四元数归一化可能存在数值问题');
    end
end
