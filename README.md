# ATE-Evaluator-MATLAB: 3D轨迹分析与ATE计算工具

## 1. 项目简介

本项目 `ATE-Evaluator-MATLAB` 是一个使用 MATLAB 开发的工具集，用于对带时间戳的3D轨迹数据进行分析和可视化，核心功能是计算绝对轨迹误差（Absolute Trajectory Error, ATE）。它能够自动检测并加载标准格式的轨迹文件，通过 `SE(3)` 变换进行时间关联和空间对齐，并生成一系列符合出版要求的可视化图表和详细的数据报告。

关于ATE概念的详细介绍，请参见 [ATE概念详解](./Docs/ate_introduction.md)。

本工具旨在复现和整合常见的轨迹评估流程，支持多轨迹对比分析，并提供灵活的配置选项，满足代码调试和论文撰写的双重需求。

详细的开发计划和功能清单，请参见 [开发待办清单](./Docs/todolist.md)。

## 2. 文件结构

```
.
├── Data/                           # 存放输入数据文件 (.txt)
│   ├── poses_original.txt          # (必需) 真值轨迹数据
│   ├── poses_corrupted.txt         # (可选) 估计轨迹数据1
│   └── poses_optimized.txt         # (可选) 估计轨迹数据2
├── Docs/                           # 存放项目文档
│   └── todolist.md                 # 开发计划与功能清单
├── Results/                        # 存放所有输出的结果
│   └── 2025-09-08_10-50/           # (示例) 带时间戳的结果文件夹
│       ├── trajectory_comparison_corrupted.png
│       ├── ate_timeseries_corrupted.png
│       ├── ate_metrics_corrupted.json
│       ├── ate_details_corrupted.csv
│       ├── aligned_trajectory_corrupted.txt
│       ├── aligned_trajectory_corrupted.mat
│       └── ...                     # 其他结果文件
├── Src/                            # 存放所有 MATLAB 源代码 (.m)
│   ├── config.m                  # 配置文件
│   ├── main_runAnalysis.m          # 主程序脚本
│   ├── readTrajectory.m            # 数据读取函数
│   ├── alignAndComputeATE.m        # 核心对齐与ATE计算函数
│   ├── plotTrajectories.m          # 轨迹可视化函数
│   ├── plotATE.m                   # ATE分析可视化函数
│   └── saveTrajectoryData.m        # 数据保存函数
└── README.md                       # 项目介绍与使用说明
```

## 3. 数据格式要求

### 输入文件格式
所有轨迹文件应为 `.txt` 格式，包含 **4列数据**，以空格分隔：

```
timestamp x y z
0.000000 1.234567 2.345678 3.456789
0.100000 1.244567 2.355678 3.466789
...
```

### 文件命名规范
- `poses_original.txt`: **真值轨迹**（必须存在）
- `poses_corrupted.txt`: **估计轨迹1**（可选，通常为优化前）
- `poses_optimized.txt`: **估计轨迹2**（可选，通常为优化后）

程序会自动检测存在的文件并进行相应的分析。如果两个估计轨迹文件都存在，将分别进行ATE计算和对比。

## 4. 如何使用

### 步骤 1: 准备数据

1. 将你的轨迹数据文件按照上述格式和命名规范放入一个文件夹中。
2. 确保至少有 `poses_original.txt`（真值）和一个估计轨迹文件。
3. 确保所有轨迹的时间戳有合理的重叠范围。

### 步骤 2: 修改配置

所有参数配置都已集中到 `Src/config.m` 文件中，方便统一管理。打开该文件进行修改：

```matlab
function cfg = config()
    % ...
    
    %% === 输入文件配置 ===
    cfg.INPUT_FOLDER = 'Data';
    
    % ... (其他文件名)
    
    %% === 输出控制开关 ===
    cfg.SAVE_FIGURES = true;
    cfg.SAVE_DATA = true;
    
    % ... (其他绘图和算法参数)
end
```

你可以在此文件中轻松修改输入文件夹、控制是否保存文件、调整绘图样式（如颜色、线宽）和算法参数。

### 步骤 3: 运行分析

直接在 MATLAB 中运行 `Src/main_runAnalysis.m` 脚本。**你不再需要修改主脚本的任何内容。**

程序将自动：
- 检测输入文件夹中的轨迹文件
- 对每个估计轨迹计算ATE
- 生成可视化结果
- 保存详细的分析数据

## 5. 输出结果说明

### 5.1 可视化结果（PNG图像）
- `trajectory_comparison_[name].png`: 2D俯视图轨迹对比
- `ate_timeseries_[name].png`: ATE随时间变化图
- `ate_histogram_[name].png`: ATE误差分布直方图  
- `ate_cdf_[name].png`: ATE累积分布函数图

### 5.2 数据文件
- **JSON指标摘要** (`ate_metrics_[name].json`): 包含RMSE、均值、中位数、标准差、最大值、最小值以及各分位数统计
- **CSV详细数据** (`ate_details_[name].csv`): 包含每个时间点的ATE误差值
- **TXT轨迹数据** (`aligned_trajectory_[name].txt`): 包含真值、原始估计和对齐后轨迹的完整数据
- **MAT轨迹数据** (`aligned_trajectory_[name].mat`): MATLAB格式的完整轨迹数据，便于后续分析

### 5.3 JSON指标摘要示例
```json
{
  "timestamp": "2025-09-08 10:30:00",
  "alignment_type": "SE3",
  "num_poses": 1000,
  "metrics": {
    "rmse": 0.1234,
    "mean": 0.1100,
    "median": 0.0987,
    "std": 0.0543,
    "max": 0.4567,
    "min": 0.0012
  },
  "statistics": {
    "percentile_25": 0.0654,
    "percentile_75": 0.1543,
    "percentile_95": 0.2876,
    "percentile_99": 0.3987
  }
}
```

## 6. 函数说明

-   `config.m`: **配置文件**。集中管理所有用户可调参数，如文件路径、保存开关、绘图样式等。
-   `main_runAnalysis.m`: **主程序脚本**。负责整个分析流程，从配置文件加载参数，然后执行文件检测、数据加载、ATE计算、可视化和结果保存。
-   `readTrajectory.m`: **数据读取函数**。从4列格式的轨迹文件中读取时间戳和3D坐标。
-   `alignAndComputeATE.m`: **核心计算函数**。执行时间关联、SE(3)对齐和ATE计算。
-   `plotTrajectories.m`: **轨迹绘图函数**。生成2D俯视图的轨迹对比。
-   `plotATE.m`: **ATE分析函数**。生成三个独立的ATE分析图窗。
-   `saveTrajectoryData.m`: **数据保存函数**。保存JSON、CSV、TXT和MAT格式的分析结果。

## 7. 核心算法

关于时间关联和空间对齐的详细数学原理和实现步骤，请参见独立的算法逻辑文档：

[**核心算法逻辑详解](./Docs/algorithm_details.md)**

### 7.1 时间关联
程序自动找到真值轨迹和估计轨迹的时间重叠区间，并使用线性插值将估计轨迹的数据点对齐到真值轨迹的时间戳上。

### 7.2 空间对齐
使用Horn方法（基于SVD分解）计算最优的SE(3)变换（旋转+平移），将估计轨迹对齐到真值轨迹的坐标系中。

### 7.3 ATE计算
计算对齐后估计轨迹与真值轨迹之间的欧几里得距离，并统计各种误差指标。

## 8. 注意事项

- 请确保MATLAB当前工作目录位于本项目的根目录下。
- 输入的数据文件必须严格按照4列格式：`timestamp x y z`。
- 确保真值轨迹和估计轨迹有足够的时间重叠，否则无法进行有效的对齐计算。
- 本工具目前支持SE(3)刚体变换对齐，未来可扩展支持Sim(3)相似变换。
- 轨迹可视化采用2D俯视图（X-Y平面投影），便于观察轨迹形状。