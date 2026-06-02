# 构建与发布指南

语言：[English](build-and-release.md) | 简体中文

本文覆盖 Windows WPF 移植版。macOS 参考实现有独立脚本，位于 `PreStage-Mac/script`。

## 前置条件

- Windows 10/11。
- .NET SDK 10.0 或更高版本。
- Git。

可选：

- Visual Studio 2026 或更高版本，并安装 .NET 桌面开发工作负载。
- Microsoft Raw Image Extension，用于通过 Windows codec 增强 RAW 预览支持。

## Restore、测试、构建

从仓库根目录运行：

```powershell
dotnet restore .\PreStage.slnx
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
```

当前 Windows 测试套件应显示 54 个测试通过。

## 本地运行

```powershell
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

本地应用数据存储在：

```text
%LocalAppData%\PreStage\
```

删除该文件夹可以重置工作区 preset 和本地状态。

## 发布

x64 自包含构建：

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:Version=0.1.0 `
  -p:AssemblyVersion=0.1.0.0 `
  -p:FileVersion=0.1.0.0 `
  -o .\releases\PreStage-Win-V0.1.0
```

x64 framework-dependent 构建：

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x64 `
  --self-contained false `
  -o .\releases\PreStage-Win-framework-dependent
```

x86 构建：

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x86 `
  --self-contained true `
  -o .\releases\PreStage-Win-x86
```

`releases/` 已被 git 忽略，不应提交。

## 发布 Smoke Checklist

- [ ] 发布版应用启动后不立即崩溃。
- [ ] 源目录选择支持包含空格和非 ASCII 字符的路径。
- [ ] 网格、列表、画廊模式都能渲染。
- [ ] 画廊预览、胶片条、直方图、波形图、裁切遮罩和构图线可用。
- [ ] 星级、Pick/Reject 和颜色标签能写入 XMP sidecar。
- [ ] 重新打开应用后能加载工作区设置。
- [ ] 复制流程按所选冲突策略处理已存在文件。
- [ ] XMP sidecar 会随媒体文件一起复制或自动重命名。
- [ ] 空目录、无权限目录和损坏文件能优雅失败。

## 常见构建说明

- `System.Drawing.Common` 目前会产生包警告。它仍被当前预览/分析路径使用，后续可在替换为 WIC 或其它图像后端时重新评估。
- 如果 MSBuild 在 `obj/` 下报告 access denied，请检查工作区 ACL，并停止残留 `dotnet`、`MSBuild` 或 `VBCSCompiler` 进程。
- 排查文件锁问题时建议使用 `-m:1 -nr:false`。
