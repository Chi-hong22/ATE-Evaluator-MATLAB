# CBEE一致性误差评估操作指南

## 1. 模块概述

**CBEE (Consistency-Based Error Evaluation)** 是一个专门用于评估SLAM轨迹优化效果的量化工具。它通过分析同一空间区域的多次测量数据一致性，来回答一个核心问题：**"优化后的轨迹是否让同一片海底区域的多次测量结果变得更加自洽？"**

### 1.1 核心理念

在水下SLAM系统中，同一空间区域往往被多个子地图覆盖。理想情况下，这些重叠区域的点云数据应该高度一致。CBEE通过以下方式量化这种一致性：

- 将多子图数据投影到统一的XY栅格中 *(`buildCbeeErrorGrid()` 栅格投影)*
- 对每个栅格格子，计算来自不同子图的点云之间的空间一致性 *(`buildCbeeErrorGrid()` 邻域一致性评估)*
- 生成直观的**一致性误差热力图**和精确的**RMS一致性误差指标** *(可视化由 `main_cbee_evaluation`, RMS计算由 `computeRmsConsistencyError()`)*

### 1.2 输入输出

**输入数据：**

- **子地图目录**: 包含`.pcd`或`.pdc`格式的点云文件（文件名格式：`submap_#_frame.pcd`）
- **原始轨迹**: `poses_original.txt`（TUM格式）
- **优化轨迹**: `poses_optimized.txt`（TUM格式）

**输出产物：**

- **`cbee_error_map.png`**: 一致性误差热力图，以颜色编码显示空间分布
- **`cbee_rms.txt`**: RMS一致性误差数值（核心量化指标）
- **`cbee_error_grid.csv`**: 每个栅格的误差详细数据
- **`cbee_results.mat`**: 完整的计算结果数据

## 2. 数据管线流程

CBEE评估遵循以下六步工作流程：

```text
[原始数据] → [数据加载] → [坐标转换] → [栅格化] → [误差计算] → [结果导出]
     ↓           ↓           ↓          ↓         ↓              ↓
  PCD文件  loadAllSubmaps  全局坐标  buildCbeeErrorGrid   RMS指标/可视化图表
  轨迹文件      ↓           系变换       ↓         ↓             ↓
            可选生成优化      ↓       邻域聚合   采样评估     保存文件
            子地图文件    visualizeSubmaps
```

### 2.1 详细流程说明

1. **数据加载与预处理** *→ 实现函数: `loadAllSubmaps()`, `generateOptimizedSubmaps()`*
   - 自动扫描子地图目录，支持`.pcd`和`.pdc`混合格式 *(`loadAllSubmaps()`)*
   - 解析轨迹文件，建立`poseid → pose`映射关系 *(`readTrajectory()`, `generateOptimizedSubmaps()`)*
   - 可选择是否生成基于优化轨迹的新子地图文件 *(`generateOptimizedSubmaps()`)*

2. **坐标系统一** *→ 实现函数: `loadAllSubmaps()`, `body2World()`*
   - 子地图点云数据通常存储在局部坐标系 *(`readSinglePcdFileWithPose()`)*
   - 使用PCD文件头中的`VIEWPOINT`信息进行局部→全局坐标变换 *(`body2World()`)*
   - 确保所有子图在同一全局坐标系下进行比较 *(`loadAllSubmaps()` 参数 `TransformToGlobal=true`)*

3. **栅格化与邻域聚合** *→ 实现函数: `buildCbeeErrorGrid()`*
   - 将全局点云投影到统一的XY栅格（默认0.5m×0.5m） *(`buildCbeeErrorGrid()` 栅格投影部分)*
   - 对每个格子收集其3×3邻域内所有子图的点云数据 *(`buildCbeeErrorGrid()` 邻域聚合部分)*
   - 为后续一致性计算准备邻域数据集

4. **一致性误差计算** *→ 实现函数: `buildCbeeErrorGrid()`*
   - 对每个格子进行多次蒙特卡洛采样（默认10次） *(`buildCbeeErrorGrid()` 采样循环)*
   - 计算采样点在其他子图邻域中的最近邻距离 *(`knnsearch()` 或 `pdist2()` 调用)*
   - 取最坏情况（最大距离）并平均，得到该格子的一致性误差

5. **全局指标与可视化** *→ 实现函数: `computeRmsConsistencyError()`, `main_cbee_evaluation`*
   - 计算RMS一致性误差：$RMS = \sqrt{\frac{1}{N}\sum_{i,j} value(i,j)^2}$ *(`computeRmsConsistencyError()`)*
   - 生成伪彩色热力图，直观展示空间误差分布 *(`main_cbee_evaluation` 可视化部分)*
   - 导出量化指标和详细数据 *(`main_cbee_evaluation` 保存部分)*

## 3. 函数依赖关系

```text
main_cbee_evaluation (顶层脚本)
├── config() - 配置管理
├── setupParallelPool() - 并行池管理
├── generateOptimizedSubmaps() [可选] - 生成优化子地图
│   ├── readTrajectory() - 轨迹文件解析
│   └── 文件I/O操作
├── loadAllSubmaps() - 批量加载子地图
│   ├── readSinglePcdFileWithPose() - 单文件解析
│   └── body2World() - 坐标变换
├── visualizeSubmaps() [可选] - 数据可视化
├── buildCbeeErrorGrid() - 核心误差栅格构建
│   ├── 栅格投影与邻域聚合
│   ├── 蒙特卡洛采样
│   └── 最近邻距离计算
├── computeRmsConsistencyError() - RMS指标计算
└── 结果导出（图片、CSV、TXT、MAT）
```

### 3.1 核心函数详解

#### `loadAllSubmaps()` - 数据加载模块

**功能**: 从目录批量加载子地图并转换到全局坐标系

```matlab
measurements = loadAllSubmaps(pcd_folder, varargin)
% 关键参数:
%   'TransformToGlobal' - 是否转换到全局坐标系 (默认: true)
%   'UseParallel' - 是否并行加载 (默认: false)
%   'MaxFiles' - 最大文件数限制
%   'Verbose' - 是否显示详细信息
```

#### `buildCbeeErrorGrid()` - 核心计算模块

**功能**: 构建CBEE一致性误差栅格

```matlab
[value_grid, overlap_mask, grid_meta] = buildCbeeErrorGrid(measurements, gridParams)
% 关键参数:
%   gridParams.cell_size_xy - 栅格大小 (建议: 0.5-2.0米)
%   gridParams.neighborhood_size - 邻域尺寸 (建议: 3或5)
%   gridParams.nbr_averages - 采样次数 (建议: 10)
%   gridParams.min_points_per_cell - 最小点数阈值 (建议: 3)
```

#### `computeRmsConsistencyError()` - 统计分析模块

**功能**: 基于误差栅格计算RMS指标及详细统计

```matlab
result = computeRmsConsistencyError(value_grid, overlap_mask)
% 返回完整统计结构体，包含:
%   result.rms_value - RMS一致性误差值
%   result.grid_stats - 栅格统计信息
%   result.error_stats - 误差分布统计
```

## 4. 核心实现逻辑

### 4.1 坐标变换逻辑 *→ 实现函数: `body2World()`, `quaternion2RotationMatrix()`*

**问题**: 子地图点云数据存储在局部坐标系，需要转换到全局坐标系进行比较。

**数学模型**:

设子地图中一个点在局部坐标系下的坐标为 $\mathbf{p}_{local} = [x_l, y_l, z_l]^T$，对应的全局位姿为：
- 平移向量：$\mathbf{t} = [t_x, t_y, t_z]^T$
- 四元数：$\mathbf{q} = [q_w, q_x, q_y, q_z]^T$（归一化：$\|\mathbf{q}\| = 1$）

则该点在全局坐标系下的坐标为：

$$\mathbf{p}_{global} = \mathbf{R}(\mathbf{q}) \cdot \mathbf{p}_{local} + \mathbf{t}$$

其中旋转矩阵 $\mathbf{R}(\mathbf{q})$ 由四元数转换得到：

$$\mathbf{R}(\mathbf{q}) = \begin{bmatrix}
1-2(q_y^2+q_z^2) & 2(q_xq_y-q_wq_z) & 2(q_xq_z+q_wq_y) \\
2(q_xq_y+q_wq_z) & 1-2(q_x^2+q_z^2) & 2(q_yq_z-q_wq_x) \\
2(q_xq_z-q_wq_y) & 2(q_yq_z+q_wq_x) & 1-2(q_x^2+q_y^2)
\end{bmatrix}$$

**解决方案**:

```matlab
% PCD文件结构:
% VIEWPOINT tx ty tz qw qx qy qz  (全局位姿)
% DATA                           (局部坐标点云)

% 坐标变换: (实现在 body2World() 函数中)
p_global = R * p_local + t
% 其中 R 由四元数 [qw qx qy qz] 转换得到 (quaternion2RotationMatrix())
%     t = [tx ty tz]
```

**注意事项**:

- PCD四元数格式：`[qw qx qy qz]` *(标准PCD格式)*
- 轨迹文件格式：`[qx qy qz qw]` *(TUM格式)*
- 函数会自动处理格式转换 *(`readTrajectory()` 中的四元数重排)*
- 旋转矩阵满足正交性：$\mathbf{R}^T\mathbf{R} = \mathbf{I}$，$\det(\mathbf{R}) = 1$

### 4.2 一致性误差计算逻辑 *→ 实现函数: `buildCbeeErrorGrid()`*

**核心算法**: 多子图邻域RMS方法 *(完整实现在 `buildCbeeErrorGrid()` 函数中)*

**数学模型**:

设有 $M$ 个子地图 $\{S_1, S_2, ..., S_M\}$，全局空间被划分为 $H \times W$ 的二维栅格，每个栅格 $(i,j)$ 的边长为 $\delta_{xy}$。

**1. 栅格投影**

对于子地图 $S_m$ 中的点 $\mathbf{p} = [x, y, z]^T$，其栅格索引为：
$$i = \lfloor \frac{x - x_{min}}{\delta_{xy}} \rfloor, \quad j = \lfloor \frac{y - y_{min}}{\delta_{xy}} \rfloor$$

定义栅格点集：$G_{i,j}^{(m)} = \{\mathbf{p} \in S_m : \mathbf{p} \text{ 投影到栅格 } (i,j)\}$

**2. 邻域聚合**

对于栅格 $(i,j)$，定义其 $k \times k$ 邻域（$k$ 为奇数，默认 $k=3$）：
$$\mathcal{N}_{i,j}^{(k)} = \{(i', j') : |i'-i| \leq \lfloor k/2 \rfloor, |j'-j| \leq \lfloor k/2 \rfloor\}$$

子地图 $m$ 在栅格 $(i,j)$ 邻域内的点集：
$$\mathcal{P}_{i,j}^{(m)} = \bigcup_{(i',j') \in \mathcal{N}_{i,j}^{(k)}} G_{i',j'}^{(m)}$$

**3. 蒙特卡洛采样一致性误差**

对于栅格 $(i,j)$，重复 $C$ 次采样（默认 $C=10$），每次采样计算：

```math
e_c = \max_{m: G_{i,j}^{(m)} \neq \emptyset} \left( \min_{n \neq m: \mathcal{P}_{i,j}^{(n)} \neq \emptyset} \min_{\mathbf{q} \in \mathcal{P}_{i,j}^{(n)}} \|\mathbf{p}_c^{(m)} - \mathbf{q}\|_2 \right)
```

其中 $\mathbf{p}_c^{(m)}$ 是从 $G_{i,j}^{(m)}$ 中随机采样的点。

栅格 $(i,j)$ 的一致性误差为：
$$\text{value}(i,j) = \frac{1}{C} \sum_{c=1}^{C} e_c$$

**4. 有效性过滤**

栅格 $(i,j)$ 被标记为有效当且仅当：
- 存在至少两个不同子地图在该栅格有点：$|\{m : G_{i,j}^{(m)} \neq \emptyset\}| \geq 2$
- 总点数满足最小阈值：$\sum_m |G_{i,j}^{(m)}| \geq N_{min}$（默认 $N_{min}=3$）

**算法伪代码**:

```matlab
% 对每个栅格格子 (i,j): (主循环在 buildCbeeErrorGrid() 中)
for c = 1:nbr_averages  % 蒙特卡洛采样循环
    maxm_c = 0;
    for 每个子图 m:
        if 格子(i,j)在子图m中有点:
            p = 随机采样一个点;  % randsample() 调用
            for 每个其他子图 n:
                d_nn = p到子图n邻域点集的最近邻距离;  % knnsearch() 或 pdist2()
                maxm_c = max(maxm_c, d_nn);  % 最坏情况
            end
        end
    end
    累加 maxm_c;
end
value(i,j) = (1/nbr_averages) * 总累加值;  % 平均
```

**设计思想**:

- **多次采样**: 减少随机性影响，提高结果稳定性 *(蒙特卡洛采样循环)*
- **邻域策略**: 考虑相邻格子的影响，增强空间连续性 *(邻域聚合算法)*
- **最坏情况**: 取最大最近邻距离，突出不一致区域 *(max() 操作)*

**理论意义**:

- $\text{value}(i,j) = 0$ 表示完美一致性（不同子图测量完全重合）
- $\text{value}(i,j)$ 越大表示该区域不同子图间的测量差异越大
- 该指标对轨迹漂移和建图误差敏感，适合评估SLAM系统质量

### 4.3 RMS一致性误差计算 *→ 实现函数: `computeRmsConsistencyError()`*

**数学模型**:

基于栅格误差值 $\{\text{value}(i,j)\}$ 和有效性掩膜 $\{\text{mask}(i,j)\}$，RMS一致性误差定义为：

**1. 有效栅格集合**

$$\Omega = \{(i,j) : \text{mask}(i,j) = \text{true} \land \text{isfinite}(\text{value}(i,j))\}$$

其中有效栅格需满足：
- 存在重叠覆盖（至少2个子图有数据）
- 误差值为有限数值（非NaN、非Inf）

**2. RMS一致性误差**

$$\text{RMS} = \sqrt{\frac{1}{|\Omega|} \sum_{(i,j) \in \Omega} \text{value}(i,j)^2}$$

其中 $|\Omega|$ 是有效栅格的总数。

**3. 统计指标**

除RMS外，还计算以下统计量：

- **最小值**: $\text{E}_{min} = \min_{(i,j) \in \Omega} \text{value}(i,j)$
- **最大值**: $\text{E}_{max} = \max_{(i,j) \in \Omega} \text{value}(i,j)$
- **均值**: $\bar{E} = \frac{1}{|\Omega|} \sum_{(i,j) \in \Omega} \text{value}(i,j)$
- **标准差**: $\sigma_E = \sqrt{\frac{1}{|\Omega|-1} \sum_{(i,j) \in \Omega} (\text{value}(i,j) - \bar{E})^2}$
- **中位数**: $\text{E}_{median} = \text{median}\{\text{value}(i,j) : (i,j) \in \Omega\}$

**4. 覆盖率指标**

- **有效栅格比例**: $\rho_{valid} = \frac{|\Omega|}{H \times W}$
- **重叠覆盖比例**: $\rho_{overlap} = \frac{|\{(i,j) : \text{mask}(i,j) = \text{true}\}|}{H \times W}$

**理论特性**:

- **单位**: RMS误差与原始点云数据具有相同的长度单位（通常为米）
- **下界**: $\text{RMS} \geq 0$，当且仅当所有有效栅格误差为0时等号成立
- **鲁棒性**: 通过有效性过滤，自动排除无重叠区域和数据稀疏区域
- **敏感性**: 对大误差敏感（平方运算），适合检测严重的一致性问题

### 4.4 并行计算策略 *→ 实现函数: `setupParallelPool()`, 各函数的并行分支*

**智能并行阈值**:

- 文件数 > 4 且 `UseParallel=true` 时启用并行加载 *(`loadAllSubmaps()` 并行判断)*
- 栅格数较大时启用并行误差计算 *(`buildCbeeErrorGrid()` parfor循环)*
- 自动回退机制：并行失败时自动切换为串行 *(`setupParallelPool()` 异常处理)*

**内存优化**:

- 预分配cell数组，避免动态扩展 *(各函数的预分配策略)*
- 批量处理，减少数据拷贝开销 *(向量化操作)*
- 渐进式错误处理，单个失败不影响整体 *(try-catch包装)*

## 5. 参数配置指南

### 5.1 核心参数详解

#### 栅格参数
```matlab
% cell_size_xy: 栅格边长 (米)
%   - 取值范围: 0.2 - 2.0
%   - 默认值: 0.5
%   - 调节原则: 
%     * 太小 → 计算量大，可能噪声敏感
%     * 太大 → 空间分辨率低，细节丢失
%     * 建议: 根据点云密度和覆盖区域大小调节
```

#### 邻域参数
```matlab
% neighborhood_size: 邻域尺寸 (格子数)
%   - 取值: 3, 5, 7 (奇数)
%   - 默认值: 3 (3×3邻域)
%   - 调节原则:
%     * 3×3: 适合精细分析，对局部变化敏感
%     * 5×5: 更好的空间平滑，适合噪声数据
%     * 7×7: 大范围平滑，可能掩盖细节差异
```

#### 采样参数
```matlab
% nbr_averages: 蒙特卡洛采样次数
%   - 取值范围: 5 - 50
%   - 默认值: 10
%   - 调节原则:
%     * 太小 → 结果不稳定，随机性大
%     * 太大 → 计算时间长，收益递减
%     * 建议: 10-20次对大多数情况足够
```

#### 过滤参数
```matlab
% min_points_per_cell: 单格最小点数
%   - 取值范围: 1 - 10
%   - 默认值: 3
%   - 调节原则:
%     * 太小 → 包含稀疏噪声区域
%     * 太大 → 排除边缘有效区域
%     * 建议: 确保至少来自2个子图的测量
```

### 5.2 性能参数

#### 并行配置
```matlab
% use_parallel: 并行开关
%   - 建议: 大数据集(>100个子图)时启用
%   - 注意: 需要Parallel Computing Toolbox

% num_workers: 并行进程数
%   - 默认: [] (自动检测)
%   - 建议: 不超过CPU核心数

% random_seed: 随机种子
%   - 默认: [] (不固定)
%   - 用途: 确保实验可复现
```

### 5.3 配置文件模板

在`config.m`中添加CBEE配置：

```matlab
function cfg = config()
    % ... 其他配置 ...
    
    %% CBEE一致性误差评估配置
    cfg.cbee = struct();
    
    % 核心参数
    cfg.cbee.cell_size_xy = 0.5;           % 栅格大小(米)
    cfg.cbee.neighborhood_size = 3;        % 邻域尺寸(3x3)
    cfg.cbee.nbr_averages = 10;            % 采样次数
    cfg.cbee.min_points_per_cell = 3;      % 最小点数阈值
    
    % 性能参数
    cfg.cbee.use_parallel = false;         % 并行开关
    cfg.cbee.num_workers = [];             % 自动检测worker数
    cfg.cbee.random_seed = 42;             % 固定随机种子
    
    % 保存选项
    cfg.cbee.options = struct();
    cfg.cbee.options.save_optimized_submaps = false;   % 是否保存优化子地图
    cfg.cbee.options.save_CBEE_data_results = true;    % 是否保存CBEE结果
    
    % 可视化选项
    cfg.cbee.visualize = struct();
    cfg.cbee.visualize.enable = true;      % 是否显示图形
    cfg.cbee.visualize.color_map = 'parula'; % 热力图色彩方案
end
```

## 6. 操作示例

### 6.1 快速开始 *→ 主要脚本: `main_cbee_evaluation.m`*

```matlab
% 1. 添加路径
addpath(genpath('Src'));

% 2. 直接运行完整流程 (调用主要脚本)
run('Src/main_cbee_evaluation.m');

% 结果将保存在 Results/CBEE/ 目录下
```

### 6.2 分步执行示例 *→ 各步骤对应的核心函数*

```matlab
% Step 1: 加载子地图数据 (loadAllSubmaps 函数)
measurements = loadAllSubmaps('Data/CBEE/smallTest/submaps', ...
    'TransformToGlobal', true, 'Verbose', true);

% Step 2: 可视化验证数据 (visualizeSubmaps 函数)
visualizeSubmaps(measurements, 'ColorBy', 'submap', 'SampleRate', 0.1);

% Step 3: 配置CBEE参数 (buildCbeeErrorGrid 函数的输入)
gridParams = struct(...
    'cell_size_xy', 0.5, ...
    'neighborhood_size', 3, ...
    'nbr_averages', 10, ...
    'min_points_per_cell', 3, ...
    'use_parallel', false, ...
    'random_seed', 42);

% Step 4: 构建误差栅格 (buildCbeeErrorGrid 函数)
[value_grid, overlap_mask, grid_meta] = buildCbeeErrorGrid(measurements, gridParams);

% Step 5: 计算RMS指标 (computeRmsConsistencyError 函数)
result = computeRmsConsistencyError(value_grid, overlap_mask);
fprintf('RMS一致性误差: %.6f\n', result.rms_value);

% Step 6: 可视化结果 (MATLAB内置可视化函数)
figure;
imagesc(value_grid); axis image; colormap(jet); colorbar;
title(sprintf('CBEE一致性误差图 (RMS=%.3f)', result.rms_value));
```

### 6.3 自定义配置示例 *→ 针对不同应用场景的参数调优*

```matlab
% 高精度分析配置 (适用于高质量数据)
gridParams_fine = struct(...
    'cell_size_xy', 0.2, ...      % 更小栅格
    'neighborhood_size', 5, ...    % 更大邻域
    'nbr_averages', 20, ...        % 更多采样
    'min_points_per_cell', 5);     % 更严格过滤

% 快速预览配置
gridParams_fast = struct(...
    'cell_size_xy', 1.0, ...      % 更大栅格
    'neighborhood_size', 3, ...
    'nbr_averages', 5, ...         % 更少采样
    'min_points_per_cell', 2);

% 大数据集配置
gridParams_large = struct(...
    'cell_size_xy', 0.5, ...
    'neighborhood_size', 3, ...
    'nbr_averages', 10, ...
    'min_points_per_cell', 3, ...
    'use_parallel', true, ...      % 启用并行
    'random_seed', 42);
```

## 7. 结果解读指南

### 7.1 RMS一致性误差 *→ 数学解释与实际意义*

**数值含义**: 所有有效栅格的一致性误差的均方根值（单位：米）

**数学定义**: 
$$\text{RMS} = \sqrt{\frac{1}{|\Omega|} \sum_{(i,j) \in \Omega} \text{value}(i,j)^2}$$

其中 $\Omega$ 为有效栅格集合，$|\Omega|$ 为有效栅格数量。

**解读标准**:

- **典型范围**: 0.05 - 2.0米（取决于数据质量和系统精度）
- **优秀水平**: RMS < 0.1米（高精度SLAM系统）
- **良好水平**: 0.1米 ≤ RMS < 0.3米（中等精度系统）
- **需要改进**: RMS ≥ 0.5米（存在明显一致性问题）

**统计学意义**:
- RMS对大误差敏感（平方效应），能有效检测严重的一致性问题
- 相比简单平均，RMS更能反映误差分布的"尖锐程度"
- 当误差呈正态分布时，约68%的栅格误差在 $\pm\sigma_E$ 范围内

**优化评估原则**:
- 数值越小 → 轨迹优化效果越好
- 显著下降（>30%）→ 优化成功改善了一致性
- 无明显变化（<10%）→ 优化效果有限，可能需要调整参数

### 7.2 热力图解读 *→ 空间分布模式分析*

**颜色编码**: 冷色(蓝) = 低误差，暖色(红) = 高误差

**空间模式诊断**:

1. **均匀分布模式** ($\sigma_{spatial} / \bar{E} < 0.5$)
   - 特征：误差在空间上相对均匀分布
   - 含义：系统性误差，可能由传感器标定或算法参数引起
   - 建议：检查传感器标定，调整全局优化参数

2. **局部聚集模式** (存在连通的高误差区域)
   - 特征：特定区域误差显著高于周围
   - 含义：局部建图失败或回环检测错误
   - 建议：检查该区域的传感器数据质量和特征密度

3. **边缘高误差模式** (轨迹边界区域误差高)
   - 特征：测量轨迹边缘区域误差较高
   - 含义：轨迹漂移累积效应
   - 建议：增加回环约束，改进轨迹初始化

**空白区域解释**:
- 无重叠覆盖：该区域只有单个子图覆盖，无法评估一致性
- 点数不足：数据稀疏，不满足 $\text{min\_points\_per\_cell}$ 阈值

### 7.3 详细统计信息
```matlab
% 访问详细统计
result = computeRmsConsistencyError(value_grid, overlap_mask);

% 栅格统计
fprintf('有效栅格比例: %.1f%%\n', result.grid_stats.valid_ratio * 100);
fprintf('总栅格数: %d\n', result.grid_stats.total_cells);

% 误差分布
fprintf('误差范围: [%.4f, %.4f]\n', result.error_stats.min, result.error_stats.max);
fprintf('误差中位数: %.4f\n', result.error_stats.median);
fprintf('误差标准差: %.4f\n', result.error_stats.std);
```

## 8. 常见问题与解决方案

### 8.1 数据问题

**问题**: `poseid`对齐失败 *→ 相关函数: `generateOptimizedSubmaps()`*

- **原因**: 文件名格式不符合`submap_#_frame.pcd`规范
- **解决**: 使用基于位置的最近邻回退匹配机制 *(`generateOptimizedSubmaps()` 中的回退策略)*

**问题**: 坐标变换异常 *→ 相关函数: `body2World()`, `readSinglePcdFileWithPose()`*

- **原因**: 四元数格式不一致或VIEWPOINT缺失
- **解决**: 检查PCD文件头格式，确保四元数顺序正确 *(`readTrajectory()` 四元数处理)*

### 8.2 性能问题

**问题**: 内存不足 *→ 相关函数: `buildCbeeErrorGrid()`*

- **解决方案**:
  1. 增大`cell_size_xy`减少栅格数 *(修改 `gridParams.cell_size_xy`)*
  2. 降低`nbr_averages`减少采样次数 *(修改 `gridParams.nbr_averages`)*
  3. 设置`use_parallel=false`使用串行模式 *(避免并行内存开销)*

**问题**: 计算时间过长 *→ 相关函数: `setupParallelPool()`, `buildCbeeErrorGrid()`*

- **解决方案**:
  1. 启用并行计算(`use_parallel=true`) *(`setupParallelPool()` 并行池管理)*
  2. 减少子图数量进行测试 *(`loadAllSubmaps()` MaxFiles参数)*
  3. 使用快速配置参数 *(较大的 `cell_size_xy` 和较小的 `nbr_averages`)*

### 8.3 结果问题

**问题**: RMS为NaN *→ 相关函数: `computeRmsConsistencyError()`*

- **原因**: 无有效重叠区域或所有栅格误差为NaN
- **解决**: 检查数据覆盖范围，调整`min_points_per_cell`参数 *(`buildCbeeErrorGrid()` 过滤逻辑)*

**问题**: 误差值异常大 *→ 相关函数: `loadAllSubmaps()`, `body2World()`*

- **原因**: 轨迹对齐问题或坐标系不一致
- **解决**: 检查输入轨迹质量，验证坐标变换正确性 *(检查 `TransformToGlobal` 设置)*

## 9. 测试与验证

### 9.1 测试数据

- **测试目录**: `Data/CBEE/smallTest/`
- **子地图**: `submaps/` (包含约10-20个PCD文件)
- **轨迹文件**: `poses_original.txt`, `poses_optimized.txt`

### 9.2 验证脚本 *→ 测试函数位置: `Test/` 目录*

```matlab
% 运行完整测试套件 (Test/test_run_cbee_evaluation.m)
run('Test/test_run_cbee_evaluation.m');

% 单独测试各模块
run('Test/test_loadAllSubmaps.m');          % 测试数据加载函数
run('Test/test_buildCbeeErrorGrid.m');      % 测试误差栅格构建
run('Test/test_computeRmsConsistencyError.m'); % 测试RMS计算
```

### 9.3 预期结果

- **成功标志**: 生成完整的热力图和数值结果 *(输出文件检查)*
- **典型RMS值**: 0.1 - 0.5米（测试数据） *(`computeRmsConsistencyError()` 返回值)*
- **执行时间**: 30秒 - 2分钟（取决于配置） *(性能基准)*

---

## 附录A: 数学符号说明

### 基本符号
- $\mathbf{p}, \mathbf{q}$: 三维点向量 $[x, y, z]^T$
- $\mathbf{t}$: 平移向量 $[t_x, t_y, t_z]^T$
- $\mathbf{q}$: 四元数 $[q_w, q_x, q_y, q_z]^T$
- $\mathbf{R}$: $3 \times 3$ 旋转矩阵
- $M$: 子地图总数
- $H, W$: 栅格行数和列数
- $\delta_{xy}$: 栅格边长（米）

### 集合与索引
- $S_m$: 第 $m$ 个子地图点集
- $G_{i,j}^{(m)}$: 子地图 $m$ 在栅格 $(i,j)$ 中的点集
- $\mathcal{N}_{i,j}^{(k)}$: 栅格 $(i,j)$ 的 $k \times k$ 邻域
- $\mathcal{P}_{i,j}^{(m)}$: 子地图 $m$ 在栅格 $(i,j)$ 邻域内的点集
- $\Omega$: 有效栅格索引集合

### 统计量
- $\|\cdot\|_2$: 欧几里得距离（L2范数）
- $\bar{E}$: 误差均值
- $\sigma_E$: 误差标准差
- $\rho_{valid}$: 有效栅格比例
- $|\cdot|$: 集合基数（元素个数）

### 算法参数
- $C$: 蒙特卡洛采样次数（默认10）
- $k$: 邻域尺寸（默认3）
- $N_{min}$: 最小点数阈值（默认3）

## 附录B: 理论基础与相关工作

### 理论背景

CBEE方法基于以下理论假设：

1. **一致性假设**: 在理想情况下，同一物理区域的多次独立测量应该产生一致的几何结果。
2. **局部性假设**: 相邻空间区域的测量质量具有相关性。
3. **统计稳定性**: 通过足够多的采样，可以获得稳定的一致性评估。

### 算法复杂度

- **时间复杂度**: $O(M \cdot H \cdot W \cdot C \cdot \log N)$
  - $M$: 子地图数量
  - $H \times W$: 栅格总数
  - $C$: 采样次数
  - $\log N$: 最近邻搜索复杂度（基于kd-tree）

- **空间复杂度**: $O(M \cdot N + H \cdot W)$
  - $N$: 平均每个子地图的点数

### 与其他方法的比较

| 方法 | 优势 | 劣势 | 适用场景 |
|------|------|------|----------|
| CBEE | 空间分布直观，对轨迹误差敏感 | 需要重叠覆盖，计算复杂度较高 | 多子图SLAM评估 |
| ATE/RPE | 计算简单，标准化程度高 | 需要ground truth，缺乏空间信息 | 轨迹精度评估 |
| ICP残差 | 基于几何匹配，理论清晰 | 受初始对齐影响，局部最优 | 点云配准评估 |

---

**版本信息**  
- 文档版本: v1.0  
- 更新日期: 2025-09-22  
- 兼容性: MATLAB R2019b及以上版本  
- 依赖工具箱: 可选 Parallel Computing Toolbox, Computer Vision Toolbox