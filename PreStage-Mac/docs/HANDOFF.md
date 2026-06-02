# PreStage Handoff / 交接说明

Last updated: 2026-05-26

## Workspace

- Path: `/Users/eason-young/Codex_Authorized/PreStage`
- Branch: `main`
- App name / package / executable: `PreStage`
- Minimum macOS: 15.4
- Old project name: `PhotoCopyTool`; do not reintroduce it.

## First Commands

```bash
git status --short
swift build
CLANG_MODULE_CACHE_PATH=.build/module-cache swift test
./script/build_and_run.sh
```

## Read First

1. `README.md`
2. `docs/project_status.md`
3. `docs/architecture.md`
4. `docs/roadmap.md`
5. `docs/release.md`

For Windows port work, read `WindowsPort/README.md` first.

## Current Product State

PreStage is a native macOS photo preselection app for browsing source folders, reviewing photos before import, marking rating/Pick/color, generating proxies, copying selected assets, and preserving XMP interoperability.

Major implemented areas:

- Source/target folder browsing.
- Camera card detection.
- Grid/list/gallery modes.
- QuickLook preview and direct raster gallery preview.
- Unified image geometry for preview, crop masks, guides, and filmstrip frames.
- RAW+JPEG pairing.
- Proxy JPEG generation and preheat.
- Rating, Pick/Reject, color labels, search, filters, sorting.
- XMP sidecar read/write.
- Copy workflow with pause/resume/cancel, RAW-only mode, verification, logs.
- Batch rename.
- Histogram and waveform scopes.
- Review background, app appearance, and review matte controls.
- Named workspace presets.
- Chinese and English localization.
- Universal macOS build and internal ad-hoc DMG packaging.

## Current Unfinished Work

- Similar grouping.
- Compare view.
- Vision-based review automation.
- Clipping map, vectorscope, hue/saturation histograms, dominant palette.
- App icon pipeline.
- Developer ID signing/notarization.
- Custom shortcut editor.
- Windows x86 implementation.

## Important Engineering Rule

Every new feature must preserve existing behavior by default. Before changing shared models, scan/filter/sort behavior, preview geometry, XMP metadata, copy/rename workflows, workspace persistence, or build/release scripts, identify the affected existing path and add or run the smallest regression check that proves it still works. Do not trade a working workflow for a new roadmap surface without an explicit user decision.

任何新功能都必须默认保护已有功能。修改共享模型、扫描/筛选/排序、预览几何、XMP 元数据、复制/重命名流程、工作区持久化或构建发布脚本前，必须识别受影响的既有路径，并添加或运行最小必要回归验证。未经用户明确决定，不得用已工作的流程去交换新的路线图能力。

Any UI element attached to the rendered image must use the shared geometry path in `PreviewRenderGeometry`. Do not calculate image bounds independently from metadata in a new overlay, because that has caused repeated crop-mask and guide-line drift on panoramic, RAW, proxy, and non-standard-ratio files.

所有依附在图片上的 UI 都必须复用 `PreviewRenderGeometry`。不要在新 overlay 中重新按元数据推算图片边界。

## Regression Hotspots

Use Computer Use for UI changes. Check:

- Panoramic JPEG crop masks and guide lines.
- Vertical RAW/DNG preview and filmstrip.
- RAW with generated proxy.
- RAW without proxy.
- Gallery keyboard navigation.
- Copy pause/cancel.
- XMP read/write.
- Light/dark appearance and review background.
- Sidebar source/target branch behavior.

## Documentation Structure

The old scattered docs were consolidated on 2026-05-26. The active docs are:

- `docs/project_status.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `docs/release.md`
- `docs/HANDOFF.md`

The Windows port handoff package is under `WindowsPort/`.
