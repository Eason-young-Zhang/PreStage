# 架构说明

语言：[English](architecture.md) | 简体中文

PreStage 围绕一个简单的摄影素材工作流组织：

1. 选择源目录或相机卡 DCIM 目录。
2. 扫描媒体文件，并对 RAW+JPEG 等关联素材进行配对。
3. 通过网格、列表或画廊模式审片。
4. 应用星级、Pick/Reject、颜色标签、构图叠加和预览工具。
5. 将选中或可见素材按可预测规则复制到目标目录。

## 平台参考

`PreStage-Mac` 是产品行为参考实现。Windows 版本应尽量与 macOS 保持一致，除非存在明确 Windows 平台限制。

新增或修改功能时：

- 可行时先阅读相关 macOS service/view。
- 保持 Windows 术语、命令位置和反馈方式接近 macOS。
- 对不可避免的平台差异进行文档说明。

## Windows 项目

### `PreStage.App`

WPF UI 项目。

职责：

- 主窗口布局。
- 画廊、检查器、复制日志和自定义控件。
- XAML 资源、样式、转换器，以及仅限 UI 行为的 code-behind。

不要把文件系统、元数据或复制业务逻辑放在这里。

### `PreStage.ViewModels`

MVVM 编排层。

职责：

- UI 状态和命令。
- 将应用动作连接到 Core 服务。
- 工作区 preset 的恢复与保存。
- 过滤、排序、选择、预览加载、复制流程和审片命令。

这一层可以编排服务，但应尽量避免直接处理低层平台 API。

### `PreStage.Core`

领域模型和服务。

重要模块：

- `Models`：媒体状态、过滤/排序/复制模型、面板布局、工作区 preset。
- `Services/MediaScannerService.cs`：文件夹扫描和元数据增强入口。
- `Services/MetadataService.cs`：EXIF/XMP 增强与 sidecar 合并。
- `Services/XmpService.cs`：sidecar 读写，以及 Lightroom rejected rating 兼容。
- `Services/CopyService.cs`：复制流程、冲突处理、sidecar 保留、校验。
- `Services/PreviewImageService.cs`：预览加载和 RAW 代理优先逻辑。
- `Services/HistogramService.cs`、`WaveformService.cs`、`ImageAnalysisService.cs`：审片分析工具。
- `Services/CameraCardService.cs`：可移动盘/DCIM 检测，安全弹出仍为 TODO。

Core 应尽量保持 UI 无关。如果服务需要 UI 线程调度，应放到 ViewModel 中完成。

### `PreStage.Tests`

xUnit 测试，覆盖核心行为和几何逻辑。

当前高价值覆盖包括：

- XMP 读写往返。
- Lightroom rejected rating 兼容。
- Metadata sidecar 增强。
- Copy sidecar 保留和冲突处理。
- Preserve-structure 复制路径。
- 预览渲染几何。
- 直方图、波形图和图像分析服务。

## 持久化

工作区状态由 `WorkspaceService` 存储在：

```text
%LocalAppData%\PreStage\
```

保存内容包括源/目标路径、视图模式、过滤器、复制设置、相机卡动作和布局偏好。

## XMP Sidecar 行为

PreStage 将审片状态写入 XMP sidecar：

- 星级：`xap:Rating`
- 颜色标签：`xap:Label`
- Photoshop urgency 标签映射
- Pick 状态：`prestage:PickState`

Lightroom 风格的 `Rating=-1` 会被视为 `PickState.Rejected`，并将 rating 归一为 `0`。

复制文件时，匹配 sidecar 会被视为媒体资产的一部分：

- 目标 sidecar 已存在时参与冲突检测。
- 自动重命名媒体时，sidecar 同步自动重命名。
- 覆盖时会先删除陈旧目标 sidecar，再复制新 sidecar。

## 预览和 RAW 策略

直接预览能力依赖 Windows 图像能力和当前 `System.Drawing` 路径。RAW 文件不一定能在所有机器上直接解码。对于 RAW 媒体，`PreviewImageService` 会先查找同级 `Proxies` 文件夹中更新的 JPEG 代理。

后续可考虑用 Windows Imaging Component、LibRaw 或其它稳定解码器替换/补充当前路径。

## 相机卡策略

`CameraCardService` 检测可移动盘和 DCIM 文件夹。它刻意不通过 shell 命令弹出设备。安全弹出应通过可靠 Windows 设备 API 实现，或继续保留明确的手动安全移除降级方案。
