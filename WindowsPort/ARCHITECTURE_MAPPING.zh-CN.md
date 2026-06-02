# 架构映射

Language: [English](ARCHITECTURE_MAPPING.md) | 简体中文

最后更新：2026-05-26

本文档用于把 macOS 版本中的核心概念映射到 Windows 版本中可采用的等价实现。

| macOS 概念 | 当前作用 | Windows 等价实现 |
| --- | --- | --- |
| SwiftUI views | 应用布局和高层状态绑定 | WPF、WinUI 3、Avalonia 或其他原生桌面 UI 栈 |
| AppKit NSCollectionView | 胶片条、列表/网格原生表面 | ItemsRepeater、ListView/GridView、VirtualizingStackPanel、自定义虚拟化面板 |
| QLPreviewView | 富预览兜底 | 直接图像渲染；Shell 缩略图/预览仅作为兜底 |
| QuickLookThumbnailing | 缩略图生成 | WIC、Windows thumbnail provider、LibRaw、ImageSharp/Magick（如可接受） |
| ImageIO | 图像元数据和下采样 | WIC、MetadataExtractor、LibRaw、ExifTool |
| NSOpenPanel | 文件夹选择 | Windows FolderBrowserDialog / WinUI folder picker |
| NSWorkspace | 打开、在文件管理器中显示、弹出设备等 | Windows Shell API、Explorer 集成 |
| UserDefaults | 简单应用/工作区持久化 | AppData 下 JSON 设置、Windows settings 或轻量本地存储 |
| XMP sidecar files | 与 Lightroom/Capture One 互操作 | 相同的文件型 sidecar 策略 |
| PreviewRenderGeometry | 统一图像边界 | 必须近似直接移植 |

## 必须移植的概念

### PreviewRenderGeometry

这是强制要求。Windows 应用应从一开始就拥有等价的几何服务。

输入：

- 可用预览容器尺寸。
- 实际预览位图尺寸。
- 显示缩放/DPI。
- 请求的裁切比例。

输出：

- 渲染后的图像矩形。
- 像素对齐后的图像矩形。
- 像素对齐后的裁切矩形。
- 带外扩 bleed 的遮罩矩形。

所有绑定在图像上的 UI 都必须依赖这个服务。

### MediaItem

Windows 模型应包含：

- 稳定 ID。
- URL/路径。
- 文件名和扩展名。
- 媒体类型。
- 文件大小。
- 可用时的创建、修改、添加、上次打开日期。
- 拍摄日期。
- 相机、镜头、曝光字段。
- 像素尺寸。
- 展示尺寸。
- 评分。
- 颜色标签。
- Pick 状态。
- 复制状态。
- XMP 状态。
- 配对键。
- 相似性相关占位字段。

### Workspace

应持久化同样的用户可见状态：

- 布局尺寸。
- 视图模式。
- 筛选。
- 排序。
- 复制设置。
- 路径。
- 语言。
- 审片环境。
- 分析 scope 设置。
- 预设。

## 推荐 Windows 服务

### MediaScannerService

必须支持快速初始扫描。昂贵的元数据读取应在后台加载。

### ThumbnailService

应尽量返回没有内部 padding 的缩略图。如果 Windows shell 缩略图包含 padding，需要追踪实际位图内容矩形，或改为直接生成缩略图。

### PreviewImageService

应提供解码位图和真实尺寸。避免 UI 叠加层使用另一个尺寸来源。

### MetadataService

可根据技术栈组合 WIC、ExifTool、MetadataExtractor 和 LibRaw。

### XmpService

实现应确定、保守，并保留未知 XML。

### CopyService

应支持 cancellation token，并在文件之间设置暂停点。

### Analysis Services

直方图、波形、过曝图、矢量示波器等分析功能应共享同一个解码预览缓冲缓存。

## 主要风险

- Windows 机器上的 RAW codec 可用性不一致。
- Windows shell 缩略图可能包含 padding。
- 与 macOS/QuickLook 保持色彩管理一致较难。
- HEIC/HEIF 依赖已安装 codec。
- Windows 文件日期语义与 macOS 不同。
- 弹出/安全移除设备的 API 不同。
- DPI 缩放如果没有像素对齐，可能重新引入半像素叠加缝隙。
