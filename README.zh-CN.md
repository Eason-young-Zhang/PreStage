# PreStage

语言：[English](README.md) | 简体中文

PreStage 是一款跨平台摄影素材导入前筛选与复制整理工具，面向需要在 Lightroom、Capture One 等大型编辑/目录软件之前快速浏览、筛选、标记和整理素材的摄影师。它强调文件夹优先、快速审片、XMP sidecar 互通，以及可靠的源目录到目标目录复制流程。

macOS 版本是产品参考实现。Windows 版本是正在积极开发的 WPF 移植版，目标是在工作流、术语、UI 结构和审片体验上尽可能接近 macOS 版本。

## 仓库结构

| 路径 | 说明 |
| --- | --- |
| `PreStage.App` | Windows WPF 桌面应用和 XAML UI。 |
| `PreStage.ViewModels` | Windows MVVM 状态、命令、工作流编排和持久化连接层。 |
| `PreStage.Core` | Windows 领域模型和服务：扫描、元数据、XMP、复制、预览、分析、工作区持久化。 |
| `PreStage.Tests` | Windows 核心服务和几何逻辑的 xUnit 测试。 |
| `PreStage-Mac` | macOS 参考实现、测试、文档和产品行为基准。 |
| `WindowsPort` | 早期 Windows 移植交接说明和功能对齐清单。 |
| `docs` | 面向维护者的构建、架构、路线图和排障文档。 |

## 当前状态

Windows 版本目前支持：

- 文件夹导入和递归扫描。
- 网格、列表、画廊三种浏览/审片模式。
- RAW+JPEG 配对和折叠/展开显示。
- 缩略图加载、大图预览，以及 RAW 代理 JPEG 优先预览。
- 星级、Pick/Reject、颜色标签，以及 XMP sidecar 往返读写。
- 按规则复制/导出、冲突处理、sidecar 同步复制和可选校验。
- 直方图、波形图、裁切遮罩、构图线和底部胶片条审片控件。
- 源目录、目标目录、视图模式、复制设置和布局偏好的工作区持久化。
- 可移动相机卡检测和 DCIM 目录选择。安全弹出尚未实现，当前提供手动安全移除提示。

已知缺口见 [docs/roadmap.zh-CN.md](docs/roadmap.zh-CN.md)。

## Windows 开发快速开始

前置条件：

- Windows 10/11。
- .NET SDK 10.0 或更高版本。
- Git。

构建和测试：

```powershell
dotnet restore .\PreStage.slnx
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

创建 Windows x64 自包含构建：

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained true -o .\releases\PreStage-Win
```

更多说明见 [docs/build-and-release.zh-CN.md](docs/build-and-release.zh-CN.md)。

## macOS 参考实现

仓库中的 `PreStage-Mac` 用于让贡献者直接对照成熟产品行为。当 Windows 与 macOS 表现不一致时，除非存在明确 Windows 平台限制，否则应以 macOS 行为为准。

推荐阅读：

- `PreStage-Mac/AGENTS.md`：验证规程。
- `PreStage-Mac/docs/architecture.md`：macOS 产品架构。
- `PreStage-Mac/Sources/PreStage/Views`：既定 UI 结构。
- `PreStage-Mac/Sources/PreStage/Services`：较成熟的工作流逻辑。

## 文档

- [构建与发布](docs/build-and-release.zh-CN.md)
- [架构说明](docs/architecture.zh-CN.md)
- [贡献指南](CONTRIBUTING.zh-CN.md)
- [路线图与已知缺口](docs/roadmap.zh-CN.md)
- [排障指南](docs/troubleshooting.zh-CN.md)
- [Windows 移植说明](WindowsPort/README.zh-CN.md)

## 参与贡献

欢迎贡献。提交 PR 前请阅读 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。简要原则：

- Windows 行为尽量与 macOS 参考实现保持一致。
- 优先提交小而可测试的改动。
- 提交前运行 Windows 测试和构建命令。
- 不要提交构建产物、发布 zip、本地对照工作区或生成二进制。

## 许可证

PreStage 使用 MIT License 发布。见 [LICENSE](LICENSE)。
