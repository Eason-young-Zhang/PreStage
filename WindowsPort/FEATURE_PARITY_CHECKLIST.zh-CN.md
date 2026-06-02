# 功能对齐清单

Language: [English](FEATURE_PARITY_CHECKLIST.md) | 简体中文

最后更新：2026-05-26

本清单用于跟踪 Windows 实现与 macOS 参考版本的功能对齐情况。

状态说明：✅ = 已完成，⬜ = 未完成，➖ = 延后到 v1 之后

## A. 核心浏览

- [x] 源文件夹选择器。（✅ MainViewModel 中通过 FolderBrowserDialog）
- [x] 目标文件夹选择器。（✅ MainViewModel 中通过 FolderBrowserDialog）
- [x] 浏览源目录子文件夹且不替换源根目录。（✅ 侧边栏文件夹选择）
- [x] 可选包含子文件夹。（✅ 侧边栏 CheckBox）
- [x] 扫描 RAW/JPEG/HEIC/TIFF/PNG/MOV/MP4/M4V。（✅ MediaScannerService.QuickScan）
- [x] 昂贵元数据之前的快速初始扫描。（✅ QuickScan + 后台 EnrichMetadata）
- [x] 网格视图。（✅ MainWindow 中 WrapPanel + ListBox）
- [x] 列表视图。（✅ 带 GridView 列的 ListView）
- [x] 画廊视图。（✅ GalleryView 预览 + 胶片条）
- [x] 可折叠胶片条。（✅ ToggleFilmstripCommand）
- [x] 检查器/详情面板。（✅ 右侧完整 EXIF + 审片控制）
- [x] 搜索。（✅ FilterState.SearchText 实时筛选）
- [x] 按名称、类型、添加、修改、创建、上次打开、大小排序。（✅ SortRule + ComboBox）
- [x] 升序/降序切换。（✅ ToggleSortDirectionCommand）

## B. 预览与几何

- [x] 统一预览几何服务。（✅ PreviewRenderGeometry：ImageRect/CropRect/MaskRects/PixelAlign）
- [x] 直接位图图像渲染。（✅ PreviewImageService -> WPF Image control via BitmapSource）
- [x] RAW 预览路径。（✅ System.Drawing Bitmap decode 支持常见 RAW）
- [x] 代理 JPEG 预览路径。（✅ 画廊预览可优先检查 proxy 目录）
- [x] 像素对齐的图像矩形。（✅ PreviewRenderGeometry.PixelAlign）
- [x] 像素对齐的裁切矩形。（✅ PreviewRenderGeometry.CropRect）
- [x] 四片式裁切遮罩并外扩，防止 1px 缝隙。（✅ CropMaskOverlay + MaskRects）
- [x] 构图辅助线。（✅ CompositionGuideOverlay：三分线/中心/对角线/黄金比例）
- [x] 裁切比例。（✅ 画廊工具条：隐藏/1:1/4:3/3:2/16:9/5:4/9:16）
- [x] 胶片条条目宽度跟随真实缩略图比例。（✅ 已修复固定 72px 宽度问题）
- [x] 全景图回归测试。（✅ PreviewRenderGeometryTests.ImageRect_Panoramic10k）
- [x] 垂直 RAW/DNG 回归测试。（✅ PreviewRenderGeometryTests.ImageRect_VerticalRaw）
- [x] 非标准比例回归测试。（✅ PreviewRenderGeometryTests 覆盖全部比例）

## C. 元数据与 XMP

- [x] EXIF 拍摄日期。（✅ MetadataExtractor.TagDateTimeOriginal）
- [x] 相机品牌/型号。（✅ ExifIfd0Directory -> CameraMake/CameraModel）
- [x] 镜头。（✅ TagLensModel）
- [x] 焦距。（✅ TagFocalLength）
- [x] 光圈。（✅ TagFNumber）
- [x] 快门。（✅ TagExposureTime）
- [x] ISO。（✅ TagIsoEquivalent）
- [x] 尺寸。（✅ TagImageWidth/Height + orientation 处理）
- [x] 色彩空间/配置文件。（✅ MetadataExtractor 可读取 ICC tag，已接入）
- [x] 评分。（✅ 0-5 星 + XMP 持久化）
- [x] Pick/Reject/Unmarked。（✅ PickState enum + XMP 持久化）
- [x] 颜色标签。（✅ Red/Yellow/Green/Blue/Purple + XMP 持久化）
- [x] XMP sidecar 读取。（✅ XmpService.Read via XDocument）
- [x] XMP sidecar 写入。（✅ XmpService.Write 保留未知 XML）
- [x] 保留未知 XMP。（✅ RawDocument 存储并在写入时合并）
- [x] Lightroom `Rating=-1` 拒绝行为。（✅ XmpServiceTests.LightroomRejectedRating）
- [x] Capture One 样例兼容。（✅ 测试存在，已做真实 sidecar 样例测试）

## D. RAW+JPEG 配对

- [x] 同文件夹同 basename 配对。（✅ MediaPairingService.PairRawAndJpeg）
- [x] 网格/画廊折叠显示。（✅ 配对项显示为单项，partner 通过 PairedAssetKey 隐藏）
- [x] 配对元数据变更。（✅ WriteXmpSidecar 同时写入配对素材）
- [x] 配对复制行为。（✅ CopyService 分别复制两个文件）
- [x] 可选展开 stack。（✅ UI toggle 已实现）

## E. 复制工作流

- [x] 复制选中项目。（✅ StartCopyCommand 复制 MediaItems collection）
- [x] 复制全部支持文件。（✅ CopyContentMode.AllSupported）
- [x] 仅复制 RAW。（✅ CopyContentMode.RawOnly）
- [x] 日期文件夹规则。（✅ BuildDatePath：yyyy-MM-dd 子文件夹）
- [x] 保留目录结构规则。（✅ BuildPreservePath：源目录相对路径）
- [x] 相机文件夹规则。（✅ BuildCameraPath：CameraModel/date 子文件夹）
- [x] 评分文件夹规则。（✅ BuildRatingPath：X_stars 子文件夹）
- [x] 冲突自动重命名。（✅ GetUniquePath：file_1.ext）
- [x] 冲突跳过。（✅ CopyConflictPolicy.SkipExisting）
- [x] 冲突覆盖。（✅ CopyConflictPolicy.Overwrite）
- [x] 暂停。（✅ CopyService.Pause via Monitor.Wait）
- [x] 继续。（✅ CopyService.Resume via Monitor.Pulse）
- [x] 取消。（✅ CopyService.Cancel via CancellationTokenSource）
- [x] 进度。（✅ CopyProgress with Fraction + UI ProgressBar）
- [x] 复制日志。（✅ CopyLogRecord + CopyLogView）
- [x] 数量/大小校验。（✅ CopyVerificationMode.SizeOnly）
- [x] SHA-256 校验。（✅ CopyVerificationMode.Sha256）

## F. 代理与性能

- [x] 生成代理 JPEG。（✅ ProxyGenerationService）
- [x] 代理新鲜度检查。（✅ 检查文件存在和时间戳）
- [x] 扫描时排除 proxy 文件夹。（✅ MediaScannerService.IsInProxyFolder）
- [x] 附近预览预热。（✅ PreviewPreheatService 已实现）
- [x] 缩略图内存缓存。（✅ ConcurrentDictionary LRU eviction）
- [x] 缩略图磁盘缓存。（✅ `%LocalAppData%\PreStage\Thumbnails` 中 JPEG 文件）
- [x] 元数据磁盘缓存。（✅ MetadataDiskCache 已实现）
- [x] 大 RAW-only 文件夹基线。（✅ PerformanceBaselineService + tests）

## G. 分析工具

- [x] 直方图。（✅ HistogramService + HistogramView 浮动面板）
- [x] X 方向波形。（✅ WaveformService.ComputeX）
- [x] Y 方向波形。（✅ WaveformService.ComputeY）
- [x] RGB overlay。（✅ HistogramView 渲染全部 3 个通道）
- [x] RGB parade 或通道模式。（✅ HistogramDisplayMode toggle 已接入 UI）
- [x] 浮动面板。（✅ Histogram/Waveform 作为 GalleryView 中浮动 Border overlay）
- [x] 检查器内放置。（✅ 已嵌入 Inspector）
- [ ] 过曝/欠曝图。（➖ 按 roadmap 延后）
- [ ] 矢量示波器。（➖ 按 roadmap 延后）
- [ ] 色相直方图。（➖ 按 roadmap 延后）
- [ ] 饱和度直方图。（➖ 按 roadmap 延后）
- [ ] 主色调色板。（➖ 按 roadmap 延后）

## H. 工作区与 UI

- [x] 工作区持久化。（✅ WorkspaceService -> `%LocalAppData%` 下 JSON）
- [x] 命名工作区预设。（✅ WorkspacePreset model + ApplyPreset）
- [x] 语言偏好。（✅ L10n.Tr 支持中文/英文）
- [x] 浅色/深色/系统外观。（✅ 侧边栏 AppAppearanceMode ComboBox）
- [x] 预览背景选择。（✅ PreviewBackgroundTone ComboBox）
- [x] 审片留白。（✅ ReviewMatteSize ComboBox：None/Small/Medium/Large）
- [x] 键盘快捷键。（✅ MainWindow PreviewKeyDown：0-5/P/X/U/Left/Right/Esc）
- [x] 快捷键提示和命令可发现性。（✅ 所有按钮带 tooltip）

## I. 打包

- [x] Windows 调试运行命令。（✅ 已记录在 BUILD_AND_RELEASE.md）
- [x] Windows 测试命令。（✅ `dotnet test PreStage.Tests`）
- [x] 安装/打包策略。（✅ `dotnet publish -c Release -r win-x64 --self-contained`）
- [x] x86/x64 架构决策。（✅ 当前目标 win-x64，可增加 win-x86）
- [x] 发布验证清单。（✅ 已记录在 BUILD_AND_RELEASE.md）

## 汇总

| 分区 | 已完成 | 待完成 | 延后 |
|------|--------|--------|------|
| A. 核心浏览 | 14/14 | 0 | 0 |
| B. 预览与几何 | 13/13 | 0 | 0 |
| C. 元数据与 XMP | 17/17 | 0 | 0 |
| D. RAW+JPEG 配对 | 5/5 | 0 | 0 |
| E. 复制工作流 | 17/17 | 0 | 0 |
| F. 代理与性能 | 8/8 | 0 | 0 |
| G. 分析工具 | 7/12 | 0 | 5 |
| H. 工作区与 UI | 8/8 | 0 | 0 |
| I. 打包 | 5/5 | 0 | 0 |
| **总计** | **94/99** | **0** | **5** |

核心功能对齐度：**94.9%**（排除延后项：94/94 = 100%）
