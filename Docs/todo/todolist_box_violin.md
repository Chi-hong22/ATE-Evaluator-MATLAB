# 箱线图(Box Plot)与小提琴图(Violin Plot) 功能开发待办清单

- 版本: 0.1.0  (草案)
- 更新时间: 2025-09-10 15:46:54

## 1. 目标与范围

- 从手动选择的多个文件中读取 ATE 误差数据，每个文件代表一个横坐标分组（一个标签）。
- 生成两类分布可视化：
  - 箱线图（Box Plot）
  - 小提琴/花瓶图（Violin Plot，基于核密度）
- 支持为每个文件设置自定义横坐标名称（标签）；支持颜色方案、显示顺序等基础样式控制。
- 支持开关式保存功能：PNG/SVG/FIG 到统一的时间戳目录下，且不影响现有主流程，函数可独立调用。

## 2. 交互与 API 设计（草案）

- 函数名（独立、可复用）：`plotErrorDistributions.m`
- 位置建议：`Src/`（主函数同级）；辅助函数放在 `Src/utils/` 下。
- MATLAB 命名约定：函数小驼峰；变量蛇形；常量全大写蛇形。
- 建议签名（Name-Value 形式，便于扩展）：
  - `function fig_handles = plotErrorDistributions(varargin)`
  - 关键 Name-Value：
    - `files` (string/cellstr，可选)：已选文件路径列表；未提供则弹出对话框多选。
    - `labels` (cellstr，可选)：每个文件对应的横坐标名称；默认使用去扩展名的文件名，运行时可在输入框中编辑。
    - `column` (double/string，可选)：当文件多列时指定 ATE 列（列号或列名）；默认自动：优先匹配列名 `ate_error`，其次 `ate`（均不区分大小写），否则取首个数值列。
    - `save` (logical, 默认 false)：是否保存图像（仅导出 PNG）。
    - `outputDir` (string，可选)：保存目录；默认 `cfg.RESULTS_DIR_BASE/<timestamp>_distributions/`。
    - `colors` (n×3 double，可选)：自定义配色；未提供则使用标准 colormap。
    - `showOutliers` (logical, 默认 true)：箱线图是否显示离群点（若使用 `boxchart` 则等效配置）。
    - `logScaleY` (logical, 默认 false)：不采用 y 轴对数坐标（保持关闭）。
    - `sortBy` (string, 默认 'none')：不采用按中位数或均值排序（固定为 `none`）。
    - `maxPoints` (double, 默认 Inf)：单组数据上限，用于极大数据集时的可视化抽样。
    - `cfg` (struct, 可选)：配置结构体；未提供时函数内部自动调用 `config()` 以获取 `DPI/字体/尺寸/结果目录` 等参数。

## 3. 数据格式假设与待确认

- 支持 `.txt`/`.csv`；每行至少一列数值，若多列则通过 `column` 指定或自动检测 `ate_error`/`ate` 列（示例表头：`timestamp, ate_error`）。
- 允许存在表头；会自动跳过非数值列。
- 支持 `NaN/Inf`，但在统计前会自动剔除。
- 单位默认米（m）；请确认是否存在其他单位或需要在图上标注单位。
- MATLAB 版本与工具箱：
  - 必需：Statistics and Machine Learning Toolbox（用于 `ksdensity` 小提琴图）。
  - `boxchart` 建议 R2020a+；否则回退使用 `boxplot`。

## 4. 技术实现要点

- 文件选择：`uigetfile({'*.txt;*.csv','ATE Files'}, '选择 ATE 数据文件', 'MultiSelect','on')`。
- 标签输入：若 `labels` 未提供或长度不匹配，用 `inputdlg` 引导用户输入；默认使用文件基名。
- 数据加载：优先 `readmatrix` + `detectImportOptions`；带表头时用列名匹配 `ate`，否则取首个数值列或 `column` 指定列。
- 统计量：`median`、`mean`、分位数 `prctile([25,50,75,5,95])`、IQR、1.5×IQR 触须计算。
- 箱线图：优先 `boxchart`（R2020a+），不满足则 `boxplot`；支持 `showOutliers`。
- 小提琴图：`Src/utils/violinPlot.m`
  - 用 `ksdensity` 对每组数据计算核密度；x 轴为组索引，y 轴为数值；密度作为宽度左右对称填充。
  - 宽度归一化到统一最大值；可叠加中位数、均值、四分位线。
  - 不使用对数 y 轴。
- 排序：根据 `sortBy` 计算排序索引，对 `files/labels/data` 一次性重排。
- 保存：当 `save=true` 时，创建 `Results/<timestamp>_distributions/`，分别保存：
  - `error_boxplot.png`
  - `error_violin.png`

### 4.1 配色与风格规则

注意:
1. 相关参数要统一放在单独一节之中(`plotErrorDistributions.m`函数中)
2. 颜色要采用"CORRUPTED_COLOR = [255, 66, 37]/255;  % 红色rgb(255, 66, 37)"这种格式

- 调色板（浅色填充 + 稍深边框，按组顺序 A→E）；颜色常量采用 `RGB255/255` 的格式并附中文注释：
  - `COLOR_A_FILL  = [179, 214, 242]/255;  % 浅蓝 rgb(179,214,242)`
  - `COLOR_A_EDGE  = [ 51, 115, 179]/255;  % 深蓝 rgb(51,115,179)`
  - `COLOR_B_FILL  = [245, 179, 179]/255;  % 浅红 rgb(245,179,179)`
  - `COLOR_B_EDGE  = [191,  64,  64]/255;  % 深红 rgb(191,64,64)`
  - `COLOR_C_FILL  = [187, 219, 179]/255;  % 浅绿 rgb(187,219,179)`
  - `COLOR_C_EDGE  = [ 64, 153,  90]/255;  % 深绿 rgb(64,153,90)`
  - `COLOR_D_FILL  = [209, 194, 230]/255;  % 浅紫 rgb(209,194,230)`
  - `COLOR_D_EDGE  = [128,  90, 179]/255;  % 深紫 rgb(128,90,179)`
  - `COLOR_E_FILL  = [250, 204, 153]/255;  % 浅橙 rgb(250,204,153)`
  - `COLOR_E_EDGE  = [217, 128,  38]/255;  % 深橙 rgb(217,128,38)`
  - 组合：
    - `fillColors = [COLOR_A_FILL; COLOR_B_FILL; COLOR_C_FILL; COLOR_D_FILL; COLOR_E_FILL];`
    - `edgeColors = [COLOR_A_EDGE; COLOR_B_EDGE; COLOR_C_EDGE; COLOR_D_EDGE; COLOR_E_EDGE];`
- 透明度与线宽：
  - `fillAlpha = 0.35`
  - `boxEdgeWidth = 1.8`，`whiskerLineWidth = 1.3`，`medianLineWidth = 1.6`
  - 小提琴边框 `violinEdgeWidth = 1.8`
- 网格与坐标：
  - 开启 `grid on`；水平与垂直网格均为灰色虚线：`gridColor = [0.75, 0.75, 0.75]`，`gridLineWidth = 1.0`，`gridLineStyle = '--'`
  - 轴线宽 `axesLineWidth = 1.2`；`box on`
  - 字体建议：`Times New Roman`；字号严格遵从 `Src/config.m` 中的 `FONT_SIZE_BASE/FONT_SIZE_MULTIPLE` 计算规则（见 4.2）。
- 散点叠加（与附图风格一致）：
  - `marker = 'o'`，`markerSize = 28`，`markerFaceAlpha = 0.75`
  - `markerFaceColor = fillColors(i,:)`，`markerEdgeColor = edgeColors(i,:)`，`markerEdgeLineWidth = 0.8`
  - x 方向抖动宽度 `jitter = 0.08`（相对于组间距 1），避免与箱体/小提琴重合
- 箱线图具体映射：
  - `boxchart`：`BoxFaceColor = fillColors(i,:)`，`BoxFaceAlpha = fillAlpha`，`LineWidth = boxEdgeWidth`，`WhiskerLineWidth = whiskerLineWidth`
  - `boxplot` 回退：`'Colors', edgeColors`，`'Symbol','o'`，`'OutlierSize',4`，`'Widths',0.55`；用 `patch` 对箱体区域做浅色填充
  - 中位数以深色实线绘制，`LineWidth = medianLineWidth`
- 小提琴图具体映射：
  - 左右对称 `patch`：`FaceColor = fillColors(i,:)`，`FaceAlpha = fillAlpha`，`EdgeColor = edgeColors(i,:)`，`LineWidth = violinEdgeWidth`
  - 叠加中位数与均值：中位数为实线，均值可用小线段或小方块标记
- 版式一致性：
  - 两类图的 y 轴范围与刻度保持一致，便于横向比较
  - x 轴类目标签加粗（与附图一致），示例：`'GroupA'...'GroupE'`
  - 标题使用大写首字母风格：`'Comparison of Five Experimental'`

### 4.2 全局样式参数（统一集中定义）

- 所有样式常量放置于函数顶部单独区域，便于统一调用与维护；分辨率、字号、尺寸均从 `cfg` 读取。
- 仅导出 PNG：`exportType = 'png'`；`dpi = cfg.DPI`。
- 是否显示离群点：`showOutliers = true`。
- y 轴不使用对数坐标：`logScaleY = false`。
- 分组排序：`sortBy = 'none'`。
- 字号映射（示例，最终以现有绘图函数的实现为准）：
  - 轴标签/图例/刻度字号：`fontAxis = cfg.FONT_SIZE_BASE * cfg.FONT_SIZE_MULTIPLE`。
  - 标题字号：`fontTitle = round(1.2 * fontAxis)`。
- 图窗尺寸（厘米）：
  - `figW = cfg.FIGURE_WIDTH_CM  * cfg.FIGURE_SIZE_MULTIPLE`
  - `figH = cfg.FIGURE_HEIGHT_CM * cfg.FIGURE_SIZE_MULTIPLE`
  - 统一用 `paperunits`/`papersize` 设置导出尺寸以匹配其他绘图函数。

## 5. 任务清单（与全局 TODO 对应）

1) 确认输入与环境（ID: `plan-verify-inputs-env`）
   - 明确 ATE 文件格式：是否只有一列？是否有表头/列名？
   - 若多列，确认使用列号或列名。
   - 确认 MATLAB 版本与是否具备 Statistics Toolbox。

2) 设计函数 API 与交互（ID: `design-api-ui`）
   - 最小可用参数集合与默认值。
   - 交互细节：文件多选、标签输入、排序与保存。

3) 实现 `plotErrorDistributions.m`（ID: `impl-boxplot`）
   - 数据加载与清洗、统计量计算、箱线图绘制、排序逻辑、保存逻辑。

4) 实现 `Src/utils/violinPlot.m`（ID: `impl-violin-helper`）
   - 基于 `ksdensity` 的对称密度填充、小提琴宽度归一化、统计量叠加、可选对数坐标。

5) 集成与体验（ID: `impl-integration-ux`）
   - 标注、配色、图例、字号、导出分辨率；异常处理（空数据、全 NaN、单点等）。

6) 撰写 `Docs/plot_distributions.md`（ID: `docs-plot-distributions`）
   - 函数说明、参数解释、示例、注意事项、常见错误。

7) 更新 `README.md`（ID: `docs-readme-ref`）
   - 在功能列表与“如何使用”中新增入口；添加文档链接与示例调用。

## 6. 验收标准

- 通过手动多选 ≥2 个文件并为其命名，可成功生成箱线图与小提琴图两张图。
- 两种图在趋势上保持一致性；统计量与 `CSV`/`JSON` 中的基本一致。
- `save=true` 时，按时间戳新建输出目录并仅生成 PNG（分辨率 `cfg.DPI`，目录根为 `cfg.RESULTS_DIR_BASE`）。
- 函数可在不依赖主流程的情况下独立调用；必要参数最少。
- `README.md` 与 `Docs/plot_distributions.md` 已更新并相互引用。

## 10. 终端与脚本调用

- 入口脚本：`Src/plotBoxViolin_main.m`（负责解析命令行/配置并调用 `plotErrorDistributions`）。
- Windows PowerShell（仅示例，需在项目根目录执行）：

```powershell
# 直接运行入口脚本（无参数，交互式选择文件）
matlab -batch "plotBoxViolin_main"

# 直接调用函数并指定参数（示例）
matlab -batch "plotErrorDistributions('files',{'Data\\ate_A.csv','Data\\ate_B.csv'}, 'labels',{'GroupA','GroupB'}, 'save',true)"
```

- MATLAB 内部脚本调用：

```matlab
% 方式一：入口脚本
% 入口脚本内部会调用 cfg = config(); 并传递给函数，确保字号/分辨率/尺寸一致
plotBoxViolin_main;

% 方式二：直接函数
cfg = config();
plotErrorDistributions('files', {'Data/ate_A.csv','Data/ate_B.csv'}, ...
                       'labels', {'GroupA','GroupB'}, ...
                       'save', true, ...
                       'cfg', cfg);
```

## 7. 风险与依赖

- 依赖 `ksdensity`（Statistics and Machine Learning Toolbox）。如不可用，需要确认是否接受取消小提琴图或引入简化替代方案。
- 版本差异：如无 `boxchart`，需回退 `boxplot`（视觉略有差异）。
- 超大数据集的渲染性能：必要时启用抽样（`maxPoints`）。

## 8. 时间与资源估算

- 预计工作量：实现与文档约 1–2 小时（在输入与环境确认完毕后）。
