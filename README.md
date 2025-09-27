
<div align="center">

# MB-SLAM-EvalToolkit

**专业的AUV多波束SLAM性能评估与可视化分析工具箱**

*基于MATLAB的水下SLAM系统综合评测解决方案*

</div>

<div align="center">

![MATLAB](https://img.shields.io/badge/MATLAB-R2018b+-FF8C00?style=flat-square) ![License](https://img.shields.io/badge/License-MIT-0080FF?style=flat-square) ![Version](https://img.shields.io/badge/Version-v2.1-32CD32?style=flat-square)

![Evaluation](https://img.shields.io/badge/Evaluation-ATE-DC143C?style=flat-square) ![Evaluation](https://img.shields.io/badge/Evaluation-APE-FF8C00?style=flat-square) ![Evaluation](https://img.shields.io/badge/Evaluation-CBEE-0080FF?style=flat-square)

![Domain](https://img.shields.io/badge/Domain-Underwater%20SLAM-20B2AA?style=flat-square) ![Docs](https://img.shields.io/badge/Docs-Complete-32CD32?style=flat-square)

[![zread](https://img.shields.io/badge/Ask_Zread-_.svg?style=flat-square&color=00b0aa&labelColor=000000&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTQuOTYxNTYgMS42MDAxSDIuMjQxNTZDMS44ODgxIDEuNjAwMSAxLjYwMTU2IDEuODg2NjQgMS42MDE1NiAyLjI0MDFWNC45NjAxQzEuNjAxNTYgNS4zMTM1NiAxLjg4ODEgNS42MDAxIDIuMjQxNTYgNS42MDAxSDQuOTYxNTZDNS4zMTUwMiA1LjYwMDEgNS42MDE1NiA1LjMxMzU2IDUuNjAxNTYgNC45NjAxVjIuMjQwMUM1LjYwMTU2IDEuODg2NjQgNS4zMTUwMiAxLjYwMDEgNC45NjE1NiAxLjYwMDFaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00Ljk2MTU2IDEwLjM5OTlIMi4yNDE1NkMxLjg4ODEgMTAuMzk5OSAxLjYwMTU2IDEwLjY4NjQgMS42MDE1NiAxMS4wMzk5VjEzLjc1OTlDMS42MDE1NiAxNC4xMTM0IDEuODg4MSAxNC4zOTk5IDIuMjQxNTYgMTQuMzk5OUg0Ljk2MTU2QzUuMzE1MDIgMTQuMzk5OSA1LjYwMTU2IDE0LjExMzQgNS42MDE1NiAxMy43NTk5VjExLjAzOTlDNS42MDE1NiAxMC42ODY0IDUuMzE1MDIgMTAuMzk5OSA0Ljk2MTU2IDEwLjM5OTlaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik0xMy43NTg0IDEuNjAwMUgxMS4wMzg0QzEwLjY4NSAxLjYwMDEgMTAuMzk4NCAxLjg4NjY0IDEwLjM5ODQgMi4yNDAxVjQuOTYwMUMxMC4zOTg0IDUuMzEzNTYgMTAuNjg1IDUuNjAwMSAxMS4wMzg0IDUuNjAwMUgxMy43NTg0QzE0LjExMTkgNS42MDAxIDE0LjM5ODQgNS4zMTM1NiAxNC4zOTg0IDQuOTYwMVYyLjI0MDFDMTQuMzk4NCAxLjg4NjY0IDE0LjExMTkgMS42MDAxIDEzLjc1ODQgMS42MDAxWiIgZmlsbD0iI2ZmZiIvPgo8cGF0aCBkPSJNNCAxMkwxMiA0TDQgMTJaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00IDEyTDEyIDQiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgo8L3N2Zz4K&logoColor=ffffff)](https://zread.ai/Chi-hong22/MB-SLAM-EvalToolkit)

</div>

## 1. 项目简介

**MB-SLAM-EvalToolkit** 是一个专为 **AUV（自主水下航行器）多波束声呐SLAM** 设计的 **MATLAB** 评测与可视化工具箱。
它提供了一套从数据加载、误差计算到结果可视化的完整解决方案，旨在**自动化处理 SLAM 输出的轨迹文件，并生成标准化的评测报告与可视化图表，为算法迭代提供可靠的数据支持。**

本工具箱的核心特性包括：

- **核心指标计算**: 自动计算 **ATE (绝对轨迹误差)**、**APE (绝对位姿误差)** 和 **CBEE (一致性误差评估)**，这些是评估SLAM系统性能的关键指标。
- **CBEE一致性评估**: 创新性的多子图一致性误差评估方法，通过分析重叠区域的点云一致性来量化SLAM系统的空间精度和全局一致性表现。
- **误差分布对比**: 支持将多次实验的 ATE 结果绘制成 **箱线图 (Box Plot)** 和 **小提琴图 (Violin Plot)**，方便横向比较不同算法或参数设置的优劣。
- **轨迹可视化**: 能够将估计轨迹与真值轨迹在空间上自动对齐（SE(3)），并生成 2D 俯视图和 3D 轨迹对比图，可以直观地检查轨迹的吻合程度。
- **一致性热力图**: 生成基于栅格的一致性误差热力图，直观展示空间误差分布，便于识别系统性能薄弱区域。
- **数据与报告导出**: 自动保存计算出的关键指标（如 RMSE、均值等）到 JSON/CSV 文件，并生成用于论文或报告的 PNG 图表。

## 2. 文件结构

```
.
├── Data/                           # 存放输入数据文件 (.txt)
│   ├── poses_original.txt          # (必需) 真值轨迹数据
│   ├── poses_corrupted.txt         # (可选) 估计轨迹数据1
│   ├── poses_optimized.txt         # (可选) 估计轨迹数据2
│   └── submaps/                    # (CBEE必需) 子地图目录
│       ├── submap_1_frame.pcd      # 子地图点云文件
│       ├── submap_2_frame.pcd      # (格式: submap_#_frame.pcd)
│       └── ...                     # 更多子地图文件
├── Docs/                           # 存放项目文档
│   ├── main_calculateATE.md        # main_calculateATE.m 模块文档
│   ├── main_plotAPE.md             # main_plotAPE.m 模块文档
│   ├── main_plotBoxViolin.md       # main_plotBoxViolin.m 模块文档
│   ├── main_evaluateCBEE.md        # main_evaluateCBEE.m 模块文档
│   ├── ATE_introduction.md         # ATE概念详解
│   └── algorithm_details.md        # 核心算法逻辑详解
├── Results/                        # 存放所有输出的结果
│   └── ...                         # (示例) 带时间戳的结果文件夹
├── Src/                            # 存放所有 MATLAB 源代码 (.m)
│   ├── config.m                    # 配置文件
│   ├── main_calculateATE.m         # ATE/APE分析主程序脚本
│   ├── main_plotAPE.m              # APE对比绘图入口脚本
│   ├── main_plotBoxViolin.m        # ATE分布对比入口脚本
│   ├── main_evaluateCBEE.m         # CBEE一致性误差评估入口脚本
│   ├── buildCbeeErrorGrid.m        # CBEE核心计算函数
│   ├── computeRmsConsistencyError.m # RMS一致性误差计算
│   ├── loadAllSubmaps.m            # 子地图批量加载
│   ├── generateOptimizedSubmaps.m  # 优化子地图生成
│   └── ...                         # 其他核心函数
└── README.md                       # 项目介绍与使用说明
```

## 3. 数据格式要求

所有轨迹文件应为 `.txt` 格式，包含 **4列数据**，以空格分隔：`timestamp/pose_id x y z`。

-   `poses_original.txt`: **真值轨迹**（必须存在）
-   `poses_corrupted.txt`: **估计轨迹1**（可选，通常为优化前）
-   `poses_optimized.txt`: **估计轨迹2**（可选，通常为优化后）

## 4. 核心模块与使用方法

本项目包含四个主要的执行入口脚本，分别用于不同的分析任务。

### 4.1 `main_calculateATE.m` - 核心 ATE/轨迹分析模块

这是项目最核心、功能最全面的脚本，用于对单个或多个估计轨迹进行完整的 ATE（绝对轨迹误差）/APE 分析。它会自动处理数据加载、时间对齐、空间对齐、误差计算、多维度可视化和结果保存的全过程。

**输入:**
-   **轨迹文件**: 位于 `config.m` 中 `INPUT_FOLDER` 指定的目录下，包含真值及估计轨迹。
-   **配置文件**: `Src/config.m` 中定义的所有参数。

**输出:**
-   **结果文件夹**: 在 `Results/` 目录下创建一个以时间戳命名的文件夹，包含所有输出。
-   **命令行报告**: 在MATLAB终端输出ATE的核心统计指标总结。
-   **详细输出说明**:
    -   **可视化图表 (PNG)**:
        -   `trajectories_raw.png`: 所有原始轨迹在对齐前的对比图。
        -   `trajectory_comparison_[name].png`: 2D俯视图轨迹对比，直观展示对齐后估计轨迹与真值轨迹的吻合程度。
  -   `ate_timeseries_[name].png`: ATE随时间变化图，用于识别误差主要发生在轨迹的哪个部分。
        -   `ate_histogram_[name].png`: ATE误差分布直方图，显示不同误差大小的频率分布。
        -   `ate_cdf_[name].png`: ATE累积分布函数图，展示误差小于特定值的点的百分比。
    -   **数据文件**:
        -   `ate_metrics_[name].json`: 包含RMSE、均值、中位数、标准差等核心统计指标。
        -   `ate_details_[name].csv`: 包含每个时间点的ATE误差值。
        -   `aligned_trajectory_[name].txt`/`.mat`: 包含真值、原始估计和对齐后轨迹的完整数据。

**使用流程:**
1.  **配置数据**: 打开 `Src/config.m`，设置 `INPUT_FOLDER` 以及轨迹文件名。
2.  **运行脚本**: 在MATLAB中直接运行 `Src/main_calculateATE.m`。

> **详细说明请参阅**: **[./Docs/main.md](./Docs/main.md)**

### 4.2 `main_plotAPE.m` - APE 对比模块

该脚本专门用于对比两种不同方法在XY平面上的APE（绝对位姿误差），生成对比误差曲线图。

**输入:**
-   **轨迹文件**: 在 `Src/main_plotAPE.m` 脚本内部直接指定的四条轨迹文件路径（两组SLAM与GT）。

**输出:**
-   **可视化图表**: 在 `Results/` 目录下创建一个带时间戳的文件夹，并保存一张名为 `APE_error.png` 的对比图。

**使用流程:**
1.  **配置数据**: 打开 `Src/main_plotAPE.m`，在脚本内部修改两组轨迹的文件路径。
2.  **运行脚本**: 在MATLAB中运行 `Src/main_plotAPE.m`。

**终端调用:**
核心函数 `plotAPEComparison` 支持参数化调用，方便集成到自动化脚本中。
```powershell
# 示例:
matlab -batch "addpath(genpath('Src')); plotAPEComparison('nespSLAM','Data/nesp.txt', 'nespGT','Data/gt.txt', 'combSLAM','Data/comb.txt', 'combGT','Data/gt2.txt', 'save',true)"
```

> **详细说明请参阅**: **[./Docs/main_plotAPE.md](./Docs/main_plotAPE.md)**

### 4.3 `main_plotBoxViolin.m` - ATE 分布对比模块（箱线/小提琴）

此脚本用于对多份ATE分析结果（通常是 `.csv` 文件）进行横向比较，通过箱形图和小提琴图直观地展示各组数据的统计分布特性。

**输入:**
-   **ATE数据文件**: 在 `Src/main_plotBoxViolin.m` 脚本内部 `files_to_plot` 中指定的一个或多个 `.csv` 文件路径。

**输出:**
-   **可视化图表**: 在 `Results/` 目录下创建一个带时间戳的文件夹，并保存 `_ATE_error_boxplot.png` 和 `_ATE_error_violin.png` 两张对比图。

**使用流程:**
1.  **配置数据**: 打开 `Src/main_plotBoxViolin.m`，在脚本内部填入ATE误差数据文件的路径和对应的标签。
2.  **运行脚本**: 在MATLAB中运行 `Src/main_plotBoxViolin.m`。

**终端调用:**
核心函数 `plotATEDistributions` 同样支持参数化调用。
```powershell
# 示例:
matlab -batch "addpath(genpath('Src')); plotATEDistributions('files',{'Results/file1.csv','Results/file2.csv'}, 'labels',{'Method A','Method B'}, 'save',true)"
```

> **详细说明请参阅**: **[./Docs/main_plotBoxViolin.md](./Docs/main_plotBoxViolin.md)**

### 4.4 `main_evaluateCBEE.m` - CBEE 一致性误差评估模块

这是项目最先进的评估模块，专门用于量化SLAM系统的空间一致性表现。CBEE (Consistency-Based Error Evaluation) 通过分析多子图在重叠区域的点云一致性，评估轨迹优化的效果。

**输入:**
-   **子地图目录**: 包含`.pcd`或`.pdc`格式的点云文件，文件名格式为`submap_#_frame.pcd`。
-   **原始轨迹**: `poses_original.txt`（TUM格式：timestamp tx ty tz qx qy qz qw）
-   **优化轨迹**: `poses_optimized.txt`（TUM格式）
-   **配置文件**: `Src/config.m` 中定义的CBEE相关参数。

**输出:**
-   **结果文件夹**: 在 `Results/` 目录下创建一个以时间戳命名的文件夹，包含所有输出。
-   **命令行报告**: 在MATLAB终端输出RMS一致性误差及详细统计信息。
-   **详细输出说明**:
    -   **可视化图表 (PNG/EPS)**:
        -   `cbee_error_map_RMS_[value].png`: 一致性误差热力图，以颜色编码显示空间分布。
        -   `cbee_elevation_map_RMS_[value].png`: 高程分布图，展示栅格化的地形信息。
    -   **数据文件**:
        -   `cbee_rms_complete_RMS_[value].txt`: 完整统计报告，包含RMS值、网格统计、误差分布等。
        -   `cbee_error_grid_RMS_[value].csv`: 误差栅格详细数据（行列索引+误差值）。
        -   `cbee_elevation_grid_RMS_[value].csv`: 高程栅格详细数据（行列索引+高程值）。
        -   `cbee_results_RMS_[value].mat`: 完整的计算结果数据，可用于后续分析。
    -   **核心指标**:
        -   **RMS一致性误差**: 整体空间一致性的定量指标（单位：米）。
        -   **有效栅格比例**: 参与计算的栅格占比，反映数据覆盖度。
        -   **误差分布统计**: 最小值、最大值、均值、标准差、分位数等详细统计。

**核心算法原理:**
CBEE采用栅格化分析方法，将全局空间划分为二维栅格（默认0.5m×0.5m），对每个栅格：
1. 收集该栅格及其邻域内所有子图的点云数据。
2. 进行多次蒙特卡洛采样（默认10次），计算采样点到其他子图邻域点云的最近邻距离。
3. 取所有子图最近邻距离的最大值作为该次采样的误差，多次采样取平均值。
4. 汇总所有有效栅格的误差，计算整体RMS一致性误差。

**使用流程:**
1.  **配置数据**: 打开 `Src/config.m`，设置 `cfg.cbee.paths` 中的子地图目录和轨迹文件路径。
2.  **调整参数**: 根据需要调整栅格大小(`cell_size_xy`)、邻域尺寸(`neighborhood_size`)、采样次数(`nbr_averages`)等。
3.  **运行脚本**: 在MATLAB中直接运行 `Src/main_evaluateCBEE.m`。

**运行时参数:**
```matlab
% 可在运行前设置以下变量：
skip_optimized_submaps = true;    % 跳过优化子地图生成，直接使用原始子地图
verbose_output = false;           % 关闭详细输出，仅显示关键信息
run('Src/main_evaluateCBEE.m')
```

**性能优化建议:**
- 对于大规模数据，建议启用并行计算（`cfg.cbee.use_parallel = true`）
- 当邻域点数较多时，推荐使用KD-Tree加速（`distance_method = 'kdtree'`）
- 可通过调整`cell_size_xy`平衡计算精度与速度
- `nbr_averages`参数影响结果稳定性，建议根据数据特点调整

> **详细说明请参阅**: **[./Docs/main_evaluateCBEE.md](./Docs/main_evaluateCBEE.md)**

## 5. 函数与算法说明

### 5.1 主要函数说明
-   `config.m`: **配置文件**。集中管理所有用户可调参数。
-   `main_calculateATE.m`: **核心 ATE/APE 分析入口**。
-   `main_plotAPE.m`: **APE对比绘图入口**。
-   `main_plotBoxViolin.m`: **ATE分布对比入口**。
-   `main_evaluateCBEE.m`: **CBEE一致性误差评估入口**。
-   `readTrajectory.m`: **数据读取函数**。
-   `alignAndComputeATE.m`: **核心计算函数**，执行时间关联、SE(3)对齐和ATE计算。
-   `buildCbeeErrorGrid.m`: **CBEE核心计算函数**，构建一致性误差栅格。
-   `computeRmsConsistencyError.m`: **RMS一致性误差计算函数**。
-   `loadAllSubmaps.m`: **子地图批量加载函数**。
-   `generateOptimizedSubmaps.m`: **优化子地图生成函数**。
-   `plotTrajectories.m`, `plotATEData.m`, `plotAPEComparison.m`, `plotATEDistributions.m`: 各类**可视化函数**。
-   `saveTrajectoryData.m`: **数据保存函数**。

### 5.2 核心算法
-   **时间关联**: 使用线性插值将估计轨迹的数据点对齐到真值轨迹的时间戳上。
-   **空间对齐**: 使用Horn方法（基于SVD分解）计算最优的SE(3)变换。
-   **ATE计算**: 计算对齐后轨迹间的欧几里得距离。
-   **CBEE一致性评估**: 基于栅格化和蒙特卡洛采样的多子图一致性误差评估算法。
    - **栅格投影**: 将多子图点云投影到统一的XY栅格中。
    - **邻域聚合**: 考虑相邻栅格的影响，收集k×k邻域内的点云数据。
    - **蒙特卡洛采样**: 通过多次随机采样计算一致性误差，减少计算结果的随机性。
    - **最近邻距离**: 计算采样点到其他子图邻域点云的最近邻距离，取最大值作为该次采样的误差。
    - **RMS统计**: 汇总所有有效栅格的误差值，计算均方根一致性误差。

## 6. 关键文档
- **模块文档**:
  - [`main_calculateATE.m` 模块详解](./Docs/main_calculateATE.md)
  - [`main_plotBoxViolin.m` 模块详解](./Docs/main_plotBoxViolin.md)
  - [`main_plotAPE.m` 模块详解](./Docs/main_plotAPE.md)
  - [`main_evaluateCBEE.m` 模块详解](./Docs/main_evaluateCBEE.md)
- **概念与算法**:
  - [ATE 概念详解](./Docs/ATE_introduction.md)
  - [核心算法逻辑详解](./Docs/algorithm_details.md)

## 7. 注意事项
- 请确保MATLAB当前工作目录位于本项目的根目录下。
- 确保真值轨迹和估计轨迹有足够的时间重叠。
- 本工具目前支持SE(3)刚体变换对齐。
- CBEE模块要求子地图文件名格式为 `submap_#_frame.pcd`，其中`#`为子地图编号。
- 子地图文件头需包含正确的`VIEWPOINT`信息（位姿：tx ty tz qw qx qy qz）。
- 对于大规模数据集，建议启用并行计算以提高处理效率。

## 8. 引用与致谢

本仓库评测对象主要面向基于多波束声呐的水下 SLAM 实践，相关 SLAM 框架参考并在此基础上修改的实现如下：

- 原项目（参考）：[https://github.com/ignaciotb/bathymetric_slam](https://github.com/ignaciotb/bathymetric_slam)
- 修改版本（本作者）：[https://github.com/Chi-hong22/bathymetric_slam](https://github.com/Chi-hong22/bathymetric_slam)

### 相关项目引用
- **[MB-SeabedSim](https://github.com/Chi-hong22/MB-SeabedSim)**: 用于生成水下地形的 MATLAB 工具。
- **[MB-TerrainSim](https://github.com/Chi-hong22/MB-TerrainSim)**: 多波束声呐海底地形采集仿真工具，可为本项目提供输入数据。
