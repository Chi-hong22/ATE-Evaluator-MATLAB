# 最终项目规划 (todolist.md)

- **版本**: 1.0.0
- **完成时间**: 2025-09-08

## 1. 最终目标与实现

- **核心**: 成功以 MATLAB 实现了一个灵活的、可配置的3D轨迹ATE分析工具。
- **范围**:
    - 支持文件夹输入，自动检测 `poses_original.txt`, `poses_corrupted.txt`, `poses_optimized.txt`。
    - 支持带时间戳的3D轨迹数据 (`timestamp, x, y, z`)。
    - 实现基于时间戳的轨迹关联与插值。
    - 实现基于 `SE(3)` 的空间对齐与ATE计算。
    - 生成多样的可视化结果（2D轨迹俯视图，ATE时序/直方图/CDF）。
    - 输出详细的数据报告（JSON摘要, CSV详情, TXT/MAT轨迹数据）。
    - 所有参数通过 `Src/config.m` 集中管理。

## 2. 最终代码架构规划

### 2.1 配置文件
- **`Src/config.m`**:
    - **职责**: 提供一个统一的结构体 `cfg`，集中管理所有用户可调参数。
    - **内容**: 输入文件夹路径、标准文件名、输出控制开关（保存图像/数据）、绘图样式参数（颜色、线宽、字体、分辨率）、算法参数（对齐类型）。

### 2.2 主程序
- **`Src/main_runAnalysis.m`**:
    - **职责**: 项目的唯一入口点，负责调度整个分析流程。
    - **流程**:
        1.  调用 `config()` 加载配置。
        2.  根据配置自动检测输入文件夹中的轨迹文件。
        3.  循环处理每一个检测到的估计轨迹。
        4.  调用 `readTrajectory.m` 加载数据。
        5.  调用 `alignAndComputeATE.m` 执行核心计算。
        6.  调用 `plotTrajectories.m` 和 `plotATE.m` 生成所有可视化图窗。
        7.  (如果开启) 调用 `saveTrajectoryData.m` 保存所有数据文件。
        8.  (如果开启) 循环所有图窗，应用统一配置并保存图像。
        9.  在命令行输出最终的ATE统计摘要。

### 2.3 功能模块 (函数)
- **数据接口层**:
    - **`Src/readTrajectory.m`**: 从 `.txt` 文件读取4列（`timestamp, x, y, z`）数据，并返回分离的时间戳和3D坐标。
- **核心算法层**:
    - **`Src/alignAndComputeATE.m`**:
        1.  根据时间戳进行轨迹关联与线性插值。
        2.  使用Horn方法（SVD）计算 `SE(3)` 变换。
        3.  对齐轨迹并计算ATE，返回详细的误差指标。
- **可视化层**:
    - **`Src/plotTrajectories.m`**: 接收3D轨迹数据，但在坐标轴上绘制其2D俯视图（X-Y平面）。
    - **`Src/plotATE.m`**: 接收ATE指标，并创建三个独立的图窗分别展示ATE时序、直方图和CDF。
- **数据输出层**:
    - **`Src/saveTrajectoryData.m`**: 接收分析结果，并负责生成和保存所有数据文件：
        - `ate_metrics_[name].json`
        - `ate_details_[name].csv`
        - `aligned_trajectory_[name].txt`
        - `aligned_trajectory_[name].mat`

## 3. 最终任务完成清单

-   [x] **项目初始化**: 创建 `Src`, `Data`, `Results`, `Docs` 文件夹。
-   [x] **配置文件**: 创建 `Src/config.m` 用于参数管理。
-   [x] **数据接口层**:
    -   [x] `Src/readTrajectory.m` 支持读取带时间戳的3D轨迹。
-   [x] **核心算法层**:
    -   [x] `Src/alignAndComputeATE.m` 支持时间关联和 `SE(3)` 对齐。
-   [x] **可视化层**:
    -   [x] `Src/plotTrajectories.m` 支持绘制3D轨迹的2D俯视图。
    -   [x] `Src/plotATE.m` 支持生成三个独立的ATE分析图。
-   [x] **数据输出层**:
    -   [x] `Src/saveTrajectoryData.m` 支持输出JSON, CSV, TXT, MAT文件。
-   [x] **主程序与集成**:
    -   [x] `Src/main_runAnalysis.m` 实现了完整的自动化分析流程，并与所有模块正确集成。
-   [x] **文档**:
    -   [x] `README.md` 全面更新，反映最终功能和使用方法。
    -   [x] `Docs/todolist.md` (本文件) 更新为最终的项目规划总结。

## 4. 验收标准 (已满足)

-   [x] **自动化**: 能够通过修改 `config.m` 和运行 `main_runAnalysis.m` 自动完成整个分析。
-   [x] **功能完整性**: 实现了所有规划的核心功能，包括文件检测、3D ATE计算和多格式数据输出。
-   [x] **代码质量**: 代码模块化、封装良好，主次分明，易于维护和扩展。
-   [x] **文档质量**: `README.md` 清晰易懂，能够指导用户快速上手。
-   [x] **输出规范**: 所有输出的图像和数据文件均符合预定义的格式和出版要求。
