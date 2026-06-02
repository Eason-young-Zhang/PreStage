# PreStage Windows 构建与发布

Language: [English](BUILD_AND_RELEASE.md) | 简体中文

## 开发命令

```powershell
# 还原依赖
dotnet restore PreStage.slnx

# 测试（当前 54 个测试）
dotnet test PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false

# 构建
dotnet build PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false

# 开发运行
dotnet run --project PreStage.App\PreStage.App.csproj
```

## 调试运行

```powershell
# 调试运行（IDE 中可配合热重载）
dotnet run --project PreStage.App\PreStage.App.csproj

# 使用指定语言运行
dotnet run --project PreStage.App\PreStage.App.csproj -- --lang zh
```

## Release 发布

```powershell
# x64 自包含版本
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained true -o releases\PreStage-Win

# x64 框架依赖版本（体积更小，需要 .NET 10 Runtime）
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained false -o releases\PreStage-Win-framework-dependent

# x86 自包含版本
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x86 --self-contained true -o releases\PreStage-Win-x86
```

输出文件：`releases/<build-name>/PreStage.App.exe`。`releases/` 目录已被 git 忽略。

## 发布验证清单

1. [ ] 从发布后的 exe 启动应用无错误
2. [ ] 源文件夹选择器可以打开，并能加载素材
3. [ ] 网格、列表、画廊三种视图均能正确渲染
4. [ ] 画廊预览能显示选中图片且不变形
5. [ ] 裁切遮罩与图像边界精确对齐，无 1px 缝隙
6. [ ] 评分、Pick 状态、颜色标签可通过 XMP sidecar 正确持久化
7. [ ] XMP 回读正常：写入元数据、关闭应用、重新打开后值仍保留
8. [ ] 复制流程完成后可通过文件大小或 SHA-256 校验
9. [ ] 设置可跨重启持久化（`%LocalAppData%\PreStage\workspace.json`）
10. [ ] 应用重启后能恢复上次布局、源目录和视图模式
11. [ ] 干净卸载：删除发布目录和 `%LocalAppData%\PreStage\` 后没有残留依赖

## 注意事项

- `PreStage-Mac` 下的 macOS 版本是产品行为参考。
- 不要提交 `bin/`、`obj/`、`releases/`、`publish/` 或对比用工作树。
- 相机卡弹出当前采用安全的手动降级方案。不要用拼接用户路径的 shell 命令替代它。
- 当前维护者构建说明见 `../docs/build-and-release.zh-CN.md`。
