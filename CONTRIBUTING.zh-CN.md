# PreStage 贡献指南

语言：[English](CONTRIBUTING.md) | 简体中文

感谢你帮助改进 PreStage。本仓库包含两个实现：

- `PreStage-Mac` 是 macOS 参考实现。
- `PreStage.App`、`PreStage.Core`、`PreStage.ViewModels` 和 `PreStage.Tests` 是 Windows WPF 移植版。

项目目标不是做两个“功能类似但体验不同”的产品，而是尽量让两个平台在行为、术语和工作流上保持一致。

## 开发原则

1. 将 macOS 作为行为基准。
   如果 Windows 版本与 macOS 不一致，请先确认差异是否有意为之，或者是否由平台限制导致。

2. 分离 UI 与业务逻辑。
   工作流逻辑优先放在 `PreStage.ViewModels`，平台/文件相关逻辑优先放在 `PreStage.Core.Services`。

3. 避免静默功能回退。
   如果某个 macOS 功能暂时无法在 Windows 实现，请添加明确 TODO、已知限制或安全降级方案。

4. 优先采用安全的 Windows 行为。
   不要把用户可控路径拼接进 shell 命令。例如相机卡安全弹出当前是安全 no-op，等待后续通过可靠 Windows 设备 API 实现。

5. 不提交生成产物。
   `bin/`、`obj/`、`releases/`、`publish/`、`PreStage-Win-Trae/` 和 macOS 打包二进制都应保持忽略。

## 本地验证

大多数 Windows 改动请运行：

```powershell
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
```

如果改动影响用户可见 UI，还需要启动应用并手动检查相关流程：

```powershell
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

建议手动检查：

- 选择源目录，确认网格/列表/画廊模式正常。
- 选择目标目录，执行一次小规模复制。
- 设置星级、Pick/Reject 和颜色标签，确认 XMP sidecar 输出。
- 在浮动和检查器位置之间切换直方图/波形图。
- 重启应用后确认状态恢复。

## Pull Request 检查清单

- [ ] 改动范围清晰，便于 review。
- [ ] Windows 测试通过。
- [ ] Windows App 构建通过。
- [ ] UI 改动已经手动 smoke test。
- [ ] 相关行为已与 macOS 参考实现对照。
- [ ] 新边界情况已通过测试覆盖，或作为已知限制记录。

## 编码说明

- 保持 C# nullable 注解有意义。
- 扫描、元数据、缩略图、预览和复制等耗时工作优先异步处理。
- Windows 路径处理需要支持空格、中文/Unicode、较长文件名和权限失败。
- 复制、重命名和冲突处理时必须保留 XMP sidecar。
- 代码注释保持少量，仅解释不明显的行为。
