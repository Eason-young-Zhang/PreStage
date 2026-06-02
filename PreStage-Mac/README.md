# PreStage

PreStage is a native macOS photo preselection and copy workflow app built with Swift, SwiftUI, and AppKit interop where native macOS controls are the best fit.

The project was previously named `PhotoCopyTool`. The current app, Swift package, executable target, bundle name, and source module are all named `PreStage`.

## 中文说明

PreStage 是一款原生 macOS 摄影素材预筛选与复制工作流应用，使用 Swift、SwiftUI 和必要的 AppKit 桥接实现。它面向将照片导入 Lightroom、Capture One 等大型软件之前的快速浏览、标记、筛选、代理文件生成和复制整理场景。

项目曾用名为 `PhotoCopyTool`。当前应用名、Swift package、可执行 target、bundle 名称和源码模块均已统一为 `PreStage`。

## Requirements

- macOS 15.4 or later
- Swift Package Manager / Xcode command line tools

## 当前状态

- 当前可用能力已经覆盖原始 v0.1 的大部分目标，以及 v0.2 的大部分核心工作流；另有若干 v0.4 审片效率能力已经提前实现。
- 近期重点改动包括统一画廊预览几何、直接栅格预览、遮幅/辅助线像素对齐、胶片条实际缩略图比例、直方图/波形图、代理 JPEG 预览、复制暂停/继续/取消、仅复制 RAW 文件、页面级快捷键和悬停快捷键提示。
- 最新状态、阶段目标核对和未实现清单见 `docs/project_status.md`。
- 架构、模块、UI 和性能说明见 `docs/architecture.md`。
- 下一阶段路线图见 `docs/roadmap.md`。
- 新会话交接信息见 `docs/HANDOFF.md`。
- 内测 DMG 分发说明见 `docs/release.md`。
- Windows x86 移植交接包见 `WindowsPort/`。

## Project Identity

- Swift package: `PreStage`
- Executable target: `PreStage`
- Source root: `Sources/PreStage`
- Bundle identifier used by the local run script: `local.codex.PreStage`
- Workspace defaults key: `PreStage.workspace.default`

## Structure

- `Package.swift`: SwiftPM package definition and deployment target.
- `Sources/PreStage/App`: app entry point and commands.
- `Sources/PreStage/Models`: workspace, media, and UI state models.
- `Sources/PreStage/Stores`: app-level state coordination.
- `Sources/PreStage/Services`: file scanning, metadata, thumbnails, copy, orientation, XMP, and device services.
- `Sources/PreStage/Views`: SwiftUI/AppKit-backed interface components.
- `Sources/PreStage/Resources`: localized strings and bundled resources.
- `docs`: active project status, architecture, roadmap, release, and handoff documents.
- `WindowsPort`: Windows x86 port project brief and handoff package.
- `script/build_and_run.sh`: local build, bundle, and launch helper.

## 中文构建与运行

构建：

```bash
swift build
```

本地运行：

```bash
./script/build_and_run.sh
```

构建并验证 app bundle 能够启动：

```bash
./script/build_and_run.sh --verify
```

生成同时支持 Apple Silicon 和 Intel Mac 的 universal app：

```bash
./script/build_and_run.sh --universal
```

生成便于发给朋友试用的内测 DMG：

```bash
./script/package_release.sh --adhoc --verify
```

该 DMG 使用 ad-hoc 签名，未经过 Apple 公证。对方第一次打开时可能需要右键选择“打开”，或在“系统设置 > 隐私与安全性”中允许打开。

## Build

```bash
swift build
```

## Test

```bash
swift test
```

If SwiftPM tries to write Clang module cache files outside the workspace in a sandboxed environment, run:

```bash
CLANG_MODULE_CACHE_PATH=.build/module-cache swift test
```

## Run Locally

```bash
./script/build_and_run.sh
```

To verify that the generated app bundle launches:

```bash
./script/build_and_run.sh --verify
```

The script creates `dist/PreStage.app` from the SwiftPM debug executable and bundled resources.

## Build A Universal App

To create a release app bundle that can run on both Apple Silicon and Intel Macs:

```bash
./script/build_and_run.sh --universal
```

The universal build compiles `arm64` and `x86_64`, merges them with `lipo`, ad-hoc signs the app bundle, and writes `dist/PreStage.app`.

Verify the executable architectures with:

```bash
lipo -info dist/PreStage.app/Contents/MacOS/PreStage
```

The expected output includes both `x86_64` and `arm64`.

## Build An Internal Testing DMG

To create a DMG for trusted internal testing:

```bash
./script/package_release.sh --adhoc --verify
```

The script builds the universal app bundle, creates `dist/PreStage-Internal-macOS15.4.dmg`, verifies the app signature, verifies the DMG, and confirms the app binary contains both `x86_64` and `arm64`.

This package is ad-hoc signed and not notarized. See `docs/release.md` before sending it to testers.

## Renaming The Outer Folder

The outer project folder name can be changed safely. Git, SwiftPM, and the run script all use project-relative paths, so the app should continue to build after moving or renaming the folder as long as the entire repository moves together.

After renaming the outer folder, update any external tools or editor sessions that still point at the old absolute path. For Codex work, reopen or refresh the workspace and provide the new absolute path so commands run in the correct directory.

## Notes For Future Development

- Prefer Apple-native APIs and controls before adding custom replacements.
- Keep the primary compatibility target at macOS 15.4 unless the deployment plan changes.
- Keep feature work aligned with the active documents in `docs`, especially `docs/project_status.md`, `docs/architecture.md`, and `docs/roadmap.md`.
- Do not reintroduce the old `PhotoCopyTool` name in package, target, bundle, workspace, or source paths.
