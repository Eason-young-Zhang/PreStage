# PreStage Windows 移植交接说明

Language: [English](README.md) | 简体中文

最后更新：2026-05-26

本目录是 PreStage Windows x86/x64 版本的移植与交接资料包。macOS 版本仍然是产品行为参考实现，但 Windows 版本应在保持体验一致的前提下，尽量使用 Windows 原生 API、控件和文件系统能力。

目标：将 PreStage 移植到 Windows 平台，使功能、界面、性能和 macOS 版本尽可能一致，同时用 Windows 原生能力替代 Apple-only API。

## 推荐阅读顺序

0. 根目录项目文档：
   - `../README.zh-CN.md`
   - `../docs/build-and-release.zh-CN.md`
   - `../docs/architecture.zh-CN.md`
   - `../docs/roadmap.zh-CN.md`
1. `PROJECT_BRIEF.zh-CN.md`
2. `FEATURE_PARITY_CHECKLIST.zh-CN.md`
3. `ARCHITECTURE_MAPPING.zh-CN.md`
4. `UI_AND_INTERACTION_SPEC.zh-CN.md`
5. `TEST_AND_ACCEPTANCE_PLAN.zh-CN.md`
6. macOS 参考源码文档：
   - `../PreStage-Mac/README.md`
   - `../PreStage-Mac/docs/project_status.md`
   - `../PreStage-Mac/docs/architecture.md`
   - `../PreStage-Mac/docs/roadmap.md`

## 移植原则

不要机械复制 SwiftUI 或 AppKit 的实现细节。要复制的是产品行为。

Windows 应用应像一个严肃的原生摄影工作流工具：

- 快速浏览文件夹。
- 稳定的图像边界叠加层。
- 可靠的元数据与 XMP sidecar 工作流。
- 清晰的源目录到目标目录复制流程。
- 适合长时间审片的深色界面。
- 可预测的键盘快捷键。
- 良好的大文件夹性能。

## 建议 Windows 技术栈

当前实现推荐：

- C# / .NET 10 或更新版本。
- WPF 作为当前 Windows 版本 UI。
- Windows Imaging Component（WIC）用于 JPEG/PNG/TIFF/HEIF 等可用格式。
- Microsoft Raw Image Extension 或 LibRaw 用于 RAW 支持。
- ExifTool、MetadataExtractor 或原生元数据 API 用于 EXIF/XMP。
- 持久化优先使用 `%LocalAppData%` 下的 JSON；只有当需求超过简单设置时才引入 SQLite，避免让主流程依赖强制目录库。

技术栈可以继续调整，但用户体验应始终贴近 macOS 参考版本。
