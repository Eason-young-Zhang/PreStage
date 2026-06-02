# 排障指南

语言：[English](troubleshooting.md) | 简体中文

## MSBuild 在 `obj/` 下 Access Denied

症状：

- `MSB3491`
- `Access to the path is denied`
- 写入 `*.FileListAbsolute.txt`、程序集引用缓存或 MSBuild 临时文件失败。

先尝试：

```powershell
Get-Process dotnet,MSBuild,VBCSCompiler -ErrorAction SilentlyContinue | Stop-Process -Force
dotnet build-server shutdown
```

然后删除生成产物：

```powershell
Remove-Item .\PreStage.App\bin,.\PreStage.App\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.Core\bin,.\PreStage.Core\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.ViewModels\bin,.\PreStage.ViewModels\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.Tests\bin,.\PreStage.Tests\obj -Recurse -Force -ErrorAction SilentlyContinue
```

如果工作区是从其它机器复制过来的，请检查 ACL：

```powershell
icacls .
```

当前用户应具有写权限。如果 ACL 中存在未知 SID，且 MSBuild 无法写入，可以谨慎地为当前用户授予工作区完全控制：

```powershell
$root = (Resolve-Path .).Path
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls $root /grant "$user`:(OI)(CI)F" /T /C
```

## 缺少 `gh`

GitHub CLI 对命令行创建 PR 很有用，但普通 `git push` 不一定需要它。

如果需要从命令行创建 PR，可以安装：

```powershell
winget install GitHub.cli
gh auth login
```

## RAW 文件无法预览

当前 Windows 预览路径不是完整 RAW 解码器。

可选方案：

- 安装 Microsoft Raw Image Extension。
- 生成 JPEG 代理图。
- 将更新的代理图放到同级 `Proxies` 文件夹，并保持同名。

示例：

```text
Source/
  IMG_0001.CR3
  Proxies/
    IMG_0001.jpg
```

如果 `Proxies/IMG_0001.jpg` 比 `IMG_0001.CR3` 更新，PreStage 会使用代理图预览。

## XMP 审片状态未出现

确认 sidecar 与媒体文件位于同一目录，且基础文件名一致：

```text
IMG_0001.CR3
IMG_0001.xmp
```

PreStage 写入：

- `xap:Rating`
- `xap:Label`
- `photoshop:Urgency`
- `prestage:PickState`

Lightroom rejected 文件可能使用 `Rating=-1`；PreStage 会将其归一为 rejected 且 rating 为 `0`。

## 复制结果不符合预期

复制行为取决于：

- 组织规则：拍摄日期、保留结构、相机型号、星级。
- 冲突策略：自动重命名、跳过、覆盖。
- 内容模式：所有支持文件或 RAW only。
- 校验模式：大小或 SHA-256。

Sidecar 会被视为媒体资产的一部分。如果目标 sidecar 已存在，它会参与冲突检测。

## 工作区状态陈旧

删除本地工作区数据：

```powershell
Remove-Item "$env:LOCALAPPDATA\PreStage" -Recurse -Force
```

然后重启应用。

## Unicode 或包含空格的路径

项目预期支持包含空格和非 ASCII 字符的路径。如果失败看起来与路径有关，请记录：

- 完整源路径。
- 完整目标路径。
- 文件扩展名。
- 文件位于本地、可移动设备、网络盘还是云同步目录。
- Windows 是否报告权限或文件锁错误。
