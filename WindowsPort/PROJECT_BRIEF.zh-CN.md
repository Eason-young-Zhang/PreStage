# Windows 移植项目总说明

Language: [English](PROJECT_BRIEF.md) | 简体中文

最后更新：2026-05-26

## 1. 产品使命

PreStage 是一个轻量级摄影素材预筛选和复制整理工具。它服务于摄影师在导入 Lightroom、Capture One 等大型编辑或目录软件之前，快速检查存储卡或本地文件夹中的文件。

Windows 移植版应保持同样使命：

- 启动迅速。
- 直接浏览文件夹。
- 不强制导入或建立目录库。
- 提供快速视觉审片。
- 写入可互操作的 sidecar 元数据。
- 将选中素材安全复制到有组织的目标文件夹。

## 2. 目标平台

- 主要目标：Windows x86/x64 桌面端。
- 用户指定架构目标：Windows X86 平台。
- 推荐系统基线：Windows 10 22H2 或 Windows 11。
- 使用形态：桌面/笔记本，鼠标键盘优先。
- 性能重点：大摄影文件夹和可移动存储卡。

## 3. 产品身份

- 名称：PreStage。
- 领域：导入编辑软件前的摄影预筛选。
- 气质：专业、信息密集、实用、以审片为中心。
- 视觉参考：Finder / Lightroom / Capture One 式工作流，而不是营销型应用。

## 4. 当前 macOS 能力

macOS 版本目前支持：

- 源文件夹和目标文件夹选择。
- 相机卡识别和安全弹出。
- 源目录子文件夹浏览，不替换源根目录。
- 可选递归扫描。
- 网格/图标视图、列表视图、画廊视图。
- 可折叠画廊胶片条、自适应胶片条尺寸。
- 右侧检查器，包含元数据和审片控制。
- 0-5 星评分、Pick/Reject/Unmarked、颜色标签。
- 搜索，以及按评分、Pick 状态、颜色、日期范围、相机、镜头筛选。
- 按名称、类型、添加日期、修改日期、创建日期、上次打开日期、大小排序，并支持升降序。
- RAW、JPEG、HEIC、TIFF、PNG、MOV、MP4、M4V 扫描。
- RAW+JPEG 配对和折叠展示。
- XMP sidecar 读取和写入。
- 批量重命名。
- 带规则的复制流程、暂停/继续/取消。
- 复制全部支持文件或仅 RAW。
- 复制冲突策略、数量/大小校验、可选 SHA-256 校验和复制日志。
- 代理 JPEG 生成、画廊预览预热。
- 直方图、波形图、构图辅助线、裁切比例参考遮罩/边框。
- 审片背景、审片留白、多工作区预设。
- 中文和英文本地化。

## 5. 关键体验要求

### 图像边界相关 UI 必须精确

这是 macOS 实现中最重要的经验。

裁切遮罩、辅助线、胶片条边框、对比叠加、过曝图、软打样边界，以及未来任何分析叠加层，都必须与实际渲染出的图像边界一致。不要让叠加层单独计算自己的边界。

Windows 实现应拥有等价于 macOS `PreviewRenderGeometry` 的统一几何服务：

- 输入：预览容器尺寸、预览源像素尺寸、缩放/DPI。
- 输出：渲染图像矩形、裁切矩形、像素对齐后的矩形、遮罩矩形。
- 所有图像绑定叠加层都使用该输出。
- 避免半像素导致的缝隙和抗锯齿亮线。

### 文件夹优先的快速流程

应用不能要求用户先把文件导入目录库才能浏览。它应直接扫描和显示选中文件夹中的文件。

### 元数据兼容性

评分、Pick/Reject 和颜色标签应尽量写入 XMP sidecar。默认不直接修改 RAW 文件。

### 以审片为中心的 UI

画廊应支持深色或中性背景、可选审片留白和快速键盘导航。

## 6. 建议 Windows 架构

推荐分层：

```text
PreStage.Windows
  AppShell
  ViewModels
  Views
  Services
  Models
  Imaging
  Persistence
  Tests
```

核心服务：

- `MediaScannerService`
- `MetadataService`
- `XmpService`
- `ThumbnailService`
- `PreviewRenderGeometry`
- `PreviewImageService`
- `ProxyGenerationService`
- `CopyService`
- `BatchRenameService`
- `WorkspaceService`
- `HistogramService`
- `WaveformService`
- `SimilarityService`（后续）

## 7. 图像策略

Windows 没有完全等价于 macOS QuickLook 的能力。Windows 版本应更多地掌控自己的预览管线。

推荐：

- 使用 WIC 处理标准位图图像。
- 使用 LibRaw 或 Windows Raw Image Extension 解码 RAW。
- 为 RAW 密集工作流生成代理 JPEG。
- 以直接解码得到的位图尺寸作为预览几何来源。
- 积极缓存缩略图和预览位图，同时设置内存上限。

避免：

- 预览图片和叠加层边界由互不相关的服务计算。
- 缩略图内部带 padding，而条目边框仍使用文件元数据。
- 假设 RAW 像素尺寸一定等于嵌入预览尺寸。

## 8. 持久化

应持久化：

- 源路径、目标路径。
- 视图模式、筛选、排序规则。
- 复制设置。
- 语言。
- 审片背景和审片留白。
- 工作区预设。
- 缩略图/元数据缓存。
- 复制和批量重命名日志。

避免让正常浏览依赖中心化目录库数据库。

## 9. 未来方向

功能对齐之后可继续扩展：

- 相似分组。
- 对比视图。
- 过曝/欠曝图。
- 矢量示波器。
- 色相/饱和度直方图。
- 主色调色板。
- GPS 地图。
- 连拍分组。
- AI/Vision 式审片辅助。
- 软打样。

## 10. 成功标准

Windows 移植版在以下场景成立时，可认为初始版本成功：

- 用户可以选择包含 RAW/JPEG 混合文件的文件夹。
- 文件能快速出现在网格、列表和画廊中。
- 画廊预览和胶片条流畅。
- 裁切遮罩和辅助线与图像精确对齐。
- 评分、Pick、颜色标签可用。
- XMP sidecar 可读写。
- 选中文件可以复制，并支持暂停、取消和校验。
- 代理生成能改善 RAW 预览。
- UI 适合长时间审片。
