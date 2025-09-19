function output_folder = generateOptimizedSubmaps(gt_pcd_folder, poses_original_txt, poses_optimized_txt, output_base_folder, varargin)
% GENERATEOPTIMIZEDSUBMAPS 基于优化轨迹生成新的子地图文件
%
% 功能描述:
%   基于优化轨迹生成新的子地图文件，复用 loadAllSubmaps 的数据加载功能。
%   采用策略：保持点数据为局部坐标，仅更新 VIEWPOINT 为优化位姿。
%   
% 设计原则:
%   ✅ 复用已有功能: 避免重复实现PCD文件读取、VIEWPOINT解析、坐标变换等功能
%   ✅ 专注核心任务: 只实现"轨迹间变换"这一核心功能  
%   ✅ 保持一致性: 生成的文件与现有数据加载/可视化流程完全兼容
%
% 输入:
%   gt_pcd_folder       - 原始子地图目录（包含 submap_*.pcd 或 *.pdc 文件）
%   poses_original_txt  - 原始轨迹文件路径
%   poses_optimized_txt - 优化轨迹文件路径
%   output_base_folder  - 输出目录
%   varargin           - 可选参数:
%       'MaxFiles'     - 最大文件数限制 (默认: 无限制)
%       'Verbose'      - 是否显示详细信息 (默认: true)
%       'UseParallel'  - 是否使用并行处理 (默认: false)
%       'Verify'       - 是否验证生成结果 (默认: true)
%
% 输出:
%   output_folder - 生成的优化子地图目录路径
%
% 示例:
%   output_dir = generateOptimizedSubmaps(...
%       'Data/CBEE/smallTest/submaps', ...
%       'Data/CBEE/smallTest/poses_original.txt', ...
%       'Data/CBEE/smallTest/poses_optimized.txt', ...
%       'Results/CBEE', ...
%       'MaxFiles', 10, 'UseParallel', true);
%
% 作者: Chihong (游子昂)
% 单位: 哈尔滨工程大学
% 版本: v1.0
% 日期: 2025-09-19

    % 参数解析
    p = inputParser;
    addRequired(p, 'gt_pcd_folder', @(x) ischar(x) || isstring(x));
    addRequired(p, 'poses_original_txt', @(x) ischar(x) || isstring(x));
    addRequired(p, 'poses_optimized_txt', @(x) ischar(x) || isstring(x));
    addRequired(p, 'output_base_folder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MaxFiles', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'UseParallel', false, @islogical);
    addParameter(p, 'Verify', true, @islogical);
    parse(p, gt_pcd_folder, poses_original_txt, poses_optimized_txt, output_base_folder, varargin{:});
    
    % 提取参数
    max_files = p.Results.MaxFiles;
    verbose = p.Results.Verbose;
    use_parallel = p.Results.UseParallel;
    verify = p.Results.Verify;
    
    % 确保 transform 工具在路径上
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'transform')));
    
    % 转换为字符数组
    gt_pcd_folder = char(gt_pcd_folder);
    poses_original_txt = char(poses_original_txt);
    poses_optimized_txt = char(poses_optimized_txt);
    output_base_folder = char(output_base_folder);
    
    if verbose
        fprintf('\n=== 开始生成优化子地图 ===\n');
        fprintf('原始子地图目录: %s\n', gt_pcd_folder);
        fprintf('原始轨迹文件: %s\n', poses_original_txt);
        fprintf('优化轨迹文件: %s\n', poses_optimized_txt);
        fprintf('输出基础目录: %s\n', output_base_folder);
    end
    
    % 验证输入路径
    if ~exist(gt_pcd_folder, 'dir')
        error('原始子地图目录不存在: %s', gt_pcd_folder);
    end
    if ~isfile(poses_original_txt)
        error('原始轨迹文件不存在: %s', poses_original_txt);
    end
    if ~isfile(poses_optimized_txt)
        error('优化轨迹文件不存在: %s', poses_optimized_txt);
    end
    
    % 创建输出目录
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_folder = fullfile(output_base_folder, sprintf('%s_optimized_submaps', timestamp));
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
        if verbose
            fprintf('创建输出目录: %s\n', output_folder);
        end
    end
    
    try
        % 步骤1: 读取轨迹数据
        if verbose
            fprintf('\n--- 步骤1: 读取轨迹数据 ---\n');
        end
        [original_poses, optimized_poses] = loadTrajectoryMappings(poses_original_txt, poses_optimized_txt, verbose);
        
        % 步骤2: 获取文件列表
        if verbose
            fprintf('\n--- 步骤2: 扫描子地图文件 ---\n');
        end
        file_list = getSubmapFileList(gt_pcd_folder, max_files, verbose);
        
        % 步骤3: 处理子地图文件
        if verbose
            fprintf('\n--- 步骤3: 生成优化子地图 ---\n');
        end
        processSubmapFiles(file_list, gt_pcd_folder, output_folder, original_poses, optimized_poses, use_parallel, verbose);
        
        % 步骤4: 验证结果（可选）
        if verify
            if verbose
                fprintf('\n--- 步骤4: 验证生成结果 ---\n');
            end
            verifyGeneratedSubmaps(output_folder, verbose);
        end
        
        if verbose
            fprintf('\n=== 优化子地图生成完成 ===\n');
            fprintf('输出目录: %s\n', output_folder);
        end
        
    catch ME
        error('生成优化子地图时出错: %s', ME.message);
    end
end

%% ========== 辅助函数 ==========

function [original_poses, optimized_poses] = loadTrajectoryMappings(poses_original_txt, poses_optimized_txt, verbose)
    % 加载轨迹数据并构建poseid到位姿的映射
    
    if verbose
        fprintf('读取原始轨迹: %s\n', poses_original_txt);
    end
    [ids_o, pos_o, quat_o] = readTrajectory(poses_original_txt, 'Mode', 'full');
    
    if verbose
        fprintf('读取优化轨迹: %s\n', poses_optimized_txt);
    end
    [ids_p, pos_p, quat_p] = readTrajectory(poses_optimized_txt, 'Mode', 'full');
    
    % 构建映射表 (poseid -> [position, quaternion])
    original_poses = containers.Map('KeyType', 'double', 'ValueType', 'any');
    optimized_poses = containers.Map('KeyType', 'double', 'ValueType', 'any');
    
    for i = 1:length(ids_o)
        original_poses(ids_o(i)) = struct('position', pos_o(i,:), 'quaternion', quat_o(i,:));
    end
    
    for i = 1:length(ids_p)
        optimized_poses(ids_p(i)) = struct('position', pos_p(i,:), 'quaternion', quat_p(i,:));
    end
    
    if verbose
        fprintf('原始轨迹: %d 个位姿\n', length(ids_o));
        fprintf('优化轨迹: %d 个位姿\n', length(ids_p));
        fprintf('重叠位姿: %d 个\n', length(intersect(ids_o, ids_p)));
    end
end

function file_list = getSubmapFileList(gt_pcd_folder, max_files, verbose)
    % 获取子地图文件列表
    
    pcd_files = dir(fullfile(gt_pcd_folder, 'submap_*.pcd'));
    pdc_files = dir(fullfile(gt_pcd_folder, 'submap_*.pdc'));
    file_list = [pcd_files; pdc_files];
    
    if isempty(file_list)
        error('未找到匹配文件（submap_*.pcd / .pdc）: %s', gt_pcd_folder);
    end
    
    if ~isempty(max_files) && length(file_list) > max_files
        file_list = file_list(1:max_files);
        if verbose
            fprintf('限制文件数量: %d -> %d\n', length([pcd_files; pdc_files]), max_files);
        end
    end
    
    if verbose
        fprintf('找到 %d 个子地图文件\n', length(file_list));
    end
end

function processSubmapFiles(file_list, gt_pcd_folder, output_folder, original_poses, optimized_poses, use_parallel, verbose)
    % 处理子地图文件，生成优化版本
    
    n_files = length(file_list);
    success_count = 0;
    skip_count = 0;
    error_count = 0;
    
    % 选择处理方式
    if use_parallel && n_files > 4
        if verbose
            fprintf('使用并行处理 (%d 个文件)...\n', n_files);
        end
        % 并行处理
        results = cell(n_files, 1);
        parfor i = 1:n_files
            results{i} = processSingleFile(file_list(i), gt_pcd_folder, output_folder, original_poses, optimized_poses, false);
        end
        % 统计结果
        for i = 1:n_files
            switch results{i}
                case 'success'
                    success_count = success_count + 1;
                case 'skip'
                    skip_count = skip_count + 1;
                case 'error'
                    error_count = error_count + 1;
            end
        end
    else
        if verbose
            fprintf('使用串行处理 (%d 个文件)...\n', n_files);
        end
        % 串行处理
        for i = 1:n_files
            if verbose && mod(i, 10) == 0
                fprintf('进度: %d/%d (%.1f%%)\n', i, n_files, 100*i/n_files);
            end
            result = processSingleFile(file_list(i), gt_pcd_folder, output_folder, original_poses, optimized_poses, verbose);
            switch result
                case 'success'
                    success_count = success_count + 1;
                case 'skip'
                    skip_count = skip_count + 1;
                case 'error'
                    error_count = error_count + 1;
            end
        end
    end
    
    if verbose
        fprintf('处理完成: 成功 %d, 跳过 %d, 错误 %d\n', success_count, skip_count, error_count);
    end
end

function result = processSingleFile(file_info, gt_pcd_folder, output_folder, original_poses, optimized_poses, verbose)
    % 处理单个子地图文件
    
    try
        src_file = fullfile(gt_pcd_folder, file_info.name);
        dst_file = fullfile(output_folder, file_info.name);
        
        % 提取 poseid
        [success, poseid] = extractPoseIdFromFilename(file_info.name);
        
        if ~success
            % 回退策略：从文件的 VIEWPOINT 匹配最近的原始轨迹位姿
            poseid = fallbackMatchByPosition(src_file, original_poses);
            if isempty(poseid)
                if verbose
                    fprintf('跳过文件 (无法确定poseid): %s\n', file_info.name);
                end
                result = 'skip';
                return;
            end
        end
        
        % 查找优化位姿
        if optimized_poses.isKey(poseid)
            opt_pose = optimized_poses(poseid);
        elseif original_poses.isKey(poseid)
            % 回退到原始位姿
            opt_pose = original_poses(poseid);
            if verbose
                fprintf('警告: 使用原始位姿 (poseid=%d): %s\n', poseid, file_info.name);
            end
        else
            if verbose
                fprintf('跳过文件 (poseid=%d 不存在): %s\n', poseid, file_info.name);
            end
            result = 'skip';
            return;
        end
        
        % 更新 VIEWPOINT 并复制文件
        rewritePcdViewpoint(src_file, dst_file, opt_pose.position, opt_pose.quaternion);
        result = 'success';
        
    catch ME
        if verbose
            fprintf('错误处理文件 %s: %s\n', file_info.name, ME.message);
        end
        result = 'error';
    end
end

function [success, poseid] = extractPoseIdFromFilename(filename)
    % 从文件名中提取 poseid
    % 规则: submap_#_frame.pcd 中的 # - 1 = poseid
    
    success = false;
    poseid = [];
    
    % 正则表达式匹配 submap_数字_frame
    pattern = 'submap_(\d+)_frame\.(pcd|pdc)$';
    tokens = regexp(filename, pattern, 'tokens');
    
    if ~isempty(tokens)
        file_number = str2double(tokens{1}{1});
        poseid = file_number - 1;  % 根据约定: # - 1 = poseid
        success = true;
    end
end

function poseid = fallbackMatchByPosition(src_file, original_poses)
    % 回退策略：通过 VIEWPOINT 位置匹配最近的原始轨迹位姿
    
    poseid = [];
    
    try
        % 读取文件的 VIEWPOINT
        viewpoint = readPcdViewpoint(src_file);
        if isempty(viewpoint)
            return;
        end
        
        file_pos = viewpoint.position;
        min_dist = inf;
        best_poseid = [];
        
        % 遍历原始轨迹，找最近的位姿
        pose_ids = keys(original_poses);
        for i = 1:length(pose_ids)
            pose = original_poses(pose_ids{i});
            dist = norm(pose.position - file_pos);
            if dist < min_dist
                min_dist = dist;
                best_poseid = pose_ids{i};
            end
        end
        
        % 只有距离合理才接受（阈值 1 米）
        if min_dist < 1.0
            poseid = best_poseid;
        end
        
    catch
        % 读取失败，返回空
    end
end

function viewpoint = readPcdViewpoint(pcd_file)
    % 读取PCD文件的 VIEWPOINT 信息
    
    viewpoint = [];
    
    try
        fid = fopen(pcd_file, 'r');
        if fid == -1
            return;
        end
        
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line) && startsWith(line, 'VIEWPOINT')
                % 解析 VIEWPOINT 行: VIEWPOINT tx ty tz qw qx qy qz
                tokens = strsplit(line);
                if length(tokens) >= 8
                    position = [str2double(tokens{2}), str2double(tokens{3}), str2double(tokens{4})];
                    quaternion = [str2double(tokens{5}), str2double(tokens{6}), str2double(tokens{7}), str2double(tokens{8})];
                    viewpoint = struct('position', position, 'quaternion', quaternion);
                end
                break;
            end
            % 如果遇到 DATA 行，停止搜索头部
            if ischar(line) && startsWith(line, 'DATA')
                break;
            end
        end
        
        fclose(fid);
        
    catch
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
    end
end

function rewritePcdViewpoint(src_file, dst_file, new_position, new_quaternion)
    % 更新PCD/PDC文件的 VIEWPOINT，保持点数据不变
    
    % 读取源文件
    fid_src = fopen(src_file, 'r');
    if fid_src == -1
        error('无法打开源文件: %s', src_file);
    end
    
    % 创建目标文件
    fid_dst = fopen(dst_file, 'w');
    if fid_dst == -1
        fclose(fid_src);
        error('无法创建目标文件: %s', dst_file);
    end
    
    try
        % 复制文件，但替换 VIEWPOINT 行
        while ~feof(fid_src)
            line = fgetl(fid_src);
            if ischar(line)
                if startsWith(line, 'VIEWPOINT')
                    % 替换 VIEWPOINT 行
                    new_line = sprintf('VIEWPOINT %.6f %.6f %.6f %.6f %.6f %.6f %.6f', ...
                        new_position(1), new_position(2), new_position(3), ...
                        new_quaternion(1), new_quaternion(2), new_quaternion(3), new_quaternion(4));
                    fprintf(fid_dst, '%s\n', new_line);
                else
                    % 保持原行不变
                    fprintf(fid_dst, '%s\n', line);
                end
            end
        end
        
        fclose(fid_src);
        fclose(fid_dst);
        
    catch ME
        fclose(fid_src);
        fclose(fid_dst);
        rethrow(ME);
    end
end

function verifyGeneratedSubmaps(output_folder, verbose)
    % 验证生成的子地图文件
    
    try
        if verbose
            fprintf('验证生成的子地图...\n');
        end
        
        % 使用 loadAllSubmaps 加载验证
        measurements = loadAllSubmaps(output_folder, 'Verbose', false, 'TransformToGlobal', true);
        
        if verbose
            fprintf('验证完成: 成功加载 %d 个子地图\n', length(measurements));
            
            % 可选：快速可视化验证
            try
                if exist('visualizeSubmaps', 'file')
                    fprintf('生成验证可视化...\n');
                    visualizeSubmaps(measurements, 'ColorBy', 'submap', 'SampleRate', 0.1, 'ShowIndividual', false);
                    title('Generated Optimized Submaps - Verification');
                end
            catch
                if verbose
                    fprintf('可视化验证跳过（可能是显示问题）\n');
                end
            end
        end
        
    catch ME
        warning('Verification:Error', '验证过程出错: %s', ME.message);
    end
end