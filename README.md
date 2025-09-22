# MB-SLAM-EvalToolkit: AUV多波束SLAM结果评测与可视化工具（MATLAB）

## 1. 项目简介

**MB-SLAM-EvalToolkit** 是一个专为 **AUV（自主水下航行器）多波束声呐SLAM** 设计的 **MATLAB** 评测与可视化工具箱。
它提供了一套从数据加载、误差计算到结果可视化的完整解决方案，旨在**自动化处理 SLAM 输出的轨迹文件，并生成标准化的评测报告与可视化图表，为算法迭代提供可靠的数据支持。**

本工具箱的核心特性包括：

- **核心指标计算**: 自动计算 **ATE (绝对轨迹误差)** 和 **APE (绝对位姿误差)**，这是评估轨迹精度的两个基本指标。
- **误差分布对比**: 支持将多次实验的 ATE 结果绘制成 **箱线图 (Box Plot)** 和 **小提琴图 (Violin Plot)**，方便横向比较不同算法或参数设置的优劣。
- **轨迹可视化**: 能够将估计轨迹与真值轨迹在空间上自动对齐（SE(3)），并生成 2D 俯视图和 3D 轨迹对比图，可以直观地检查轨迹的吻合程度。
- **数据与报告导出**: 自动保存计算出的关键指标（如 RMSE、均值等）到 JSON/CSV 文件，并生成用于论文或报告的 PNG 图表。

## 2. 文件结构

```
.
├── Data/                           # 存放输入数据文件 (.txt)
│   ├── poses_original.txt          # (必需) 真值轨迹数据
│   ├── poses_corrupted.txt         # (可选) 估计轨迹数据1
│   └── poses_optimized.txt         # (可选) 估计轨迹数据2
├── Docs/                           # 存放项目文档
│   ├── main.md                     # main_calculateATE.m 模块文档
│   ├── main_plotAPE.md             # main_plotAPE.m 模块文档
│   ├── main_plotBoxViolin.md       # main_plotBoxViolin.m 模块文档
│   ├── ate_introduction.md         # ATE概念详解
│   └── algorithm_details.md        # 核心算法逻辑详解
├── Results/                        # 存放所有输出的结果
│   └── ...                         # (示例) 带时间戳的结果文件夹
├── Src/                            # 存放所有 MATLAB 源代码 (.m)
│   ├── config.m                  # 配置文件
│   ├── main_calculateATE.m                    # 主程序脚本
│   ├── main_plotAPE.m              # APE对比绘图入口脚本
│   ├── main_plotBoxViolin.m        # ATE分布对比入口脚本
│   └── ...                       # 其他核心函数
└── README.md                       # 项目介绍与使用说明
```

## 3. 数据格式要求

所有轨迹文件应为 `.txt` 格式，包含 **4列数据**，以空格分隔：`timestamp/pose_id x y z`。

-   `poses_original.txt`: **真值轨迹**（必须存在）
-   `poses_corrupted.txt`: **估计轨迹1**（可选，通常为优化前）
-   `poses_optimized.txt`: **估计轨迹2**（可选，通常为优化后）

## 4. 核心模块与使用方法

本项目包含三个主要的执行入口脚本，分别用于不同的分析任务。

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

## 5. 函数与算法说明

### 5.1 主要函数说明
-   `config.m`: **配置文件**。集中管理所有用户可调参数。
-   `main_calculateATE.m`: **核心 ATE/APE 分析入口**。
-   `main_plotAPE.m`: **APE对比绘图入口**。
-   `main_plotBoxViolin.m`: **ATE分布对比入口**。
-   `readTrajectory.m`: **数据读取函数**。
-   `alignAndComputeATE.m`: **核心计算函数**，执行时间关联、SE(3)对齐和ATE计算。
-   `plotTrajectories.m`, `plotATE.m`, `plotAPEComparison.m`, `plotATEDistributions.m`: 各类**可视化函数**。
-   `saveTrajectoryData.m`: **数据保存函数**。

### 5.2 核心算法
-   **时间关联**: 使用线性插值将估计轨迹的数据点对齐到真值轨迹的时间戳上。
-   **空间对齐**: 使用Horn方法（基于SVD分解）计算最优的SE(3)变换。
-   **ATE计算**: 计算对齐后轨迹间的欧几里得距离。

## 6. 关键文档
- **模块文档**:
  - [`main_calculateATE.m` 模块详解](./Docs/main_calculateATE.md)
  - [`main_plotBoxViolin.m` 模块详解](./Docs/main_plotBoxViolin.md)
  - [`main_plotAPE.m` 模块详解](./Docs/main_plotAPE.md)
  - [`main_evaluateCBEE.m` 模块详解](./Docs/main_evaluateCBEE.md)
- **概念与算法**:
  - [ATE 概念详解](./Docs/ate_introduction.md)
  - [核心算法逻辑详解](./Docs/algorithm_details.md)

## 7. 注意事项
- 请确保MATLAB当前工作目录位于本项目的根目录下。
- 确保真值轨迹和估计轨迹有足够的时间重叠。
- 本工具目前支持SE(3)刚体变换对齐。

## 8. 引用与致谢

本仓库评测对象主要面向基于多波束声呐的水下 SLAM 实践，相关 SLAM 框架参考并在此基础上修改的实现如下：

- 原项目（参考）：[https://github.com/ignaciotb/bathymetric_slam](https://github.com/ignaciotb/bathymetric_slam)
- 修改版本（本作者）：[https://github.com/Chi-hong22/bathymetric_slam](https://github.com/Chi-hong22/bathymetric_slam)

### 相关项目引用
- **[MB-SeabedSim](https://github.com/Chi-hong22/MB-SeabedSim)**: 用于生成水下地形的 MATLAB 工具。
- **[MB-TerrainSim](https://github.com/Chi-hong22/MB-TerrainSim)**: 多波束声呐海底地形采集仿真工具，可为本项目提供输入数据。
