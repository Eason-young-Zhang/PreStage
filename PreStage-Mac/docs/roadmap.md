# Roadmap / 路线图

Last updated: 2026-05-26

This file consolidates the older `implementation_plan.md`, `next_phase_plan.md`, and `review_scopes_and_analysis_tools_plan.md`.

本文合并旧的 `implementation_plan.md`、`next_phase_plan.md` 和 `review_scopes_and_analysis_tools_plan.md`。

## Phase Status / 阶段状态

| Phase | Status | Notes |
| --- | --- | --- |
| v0.1 Basic usable version | Mostly complete | Folder selection, card detection, grid/list/gallery, rating, tags, copy progress/log, pause/cancel, verification, layout persistence, safe eject. Needs real removable-card regression. |
| v0.2 Filtering and metadata | Mostly complete | XMP, filters, RAW+JPEG pairing, multiple copy rules, RAW-only copy, SHA-256 option, batch rename, logs. Needs Lightroom/Capture One real sidecar regression and large-card workflow testing. |
| v0.3 Similar grouping | Not implemented | Placeholder models exist. Needs similarity service, UI, thresholds, persistence, and performance design. |
| v0.4 Advanced review | Partially started | QuickLook, gallery preview, proxy fallback, histogram, waveform, guides, crop masks, review environment started. Compare view and Vision analysis are not implemented. |

## Priority Queue / 优先级队列

### A. Review Stability And Trust

- Gallery preview boundary correctness: recently rebuilt around unified preview geometry, direct raster preview, pixel-aligned masks, and rendered-thumbnail aspect ratios.
- Decode pipeline consolidation: `PreviewDecodeService` now centralizes preview-source selection, backend-based raster decoding, ImageIO downsampling, direct-raster checks, pixel-size reads, and preview warmup; see `docs/libraw_evaluation.md` before adding new RAW backends.
- Gallery switching smoothness: dual QuickLook buffering exists for fallback path; direct raster preview still needs performance tuning for very large RAW.
- Histogram and waveform: implemented but need real-folder UI/performance regression.
- Proxy generation and preheat: implemented with status bar progress; command-line real-folder baselines exist, but UI-level large-folder regression is still needed.

### B. Internal Beta Quality

- Real RAW-only large-directory performance baselines: initial command-line baseline recorded in `docs/baselines/`; continue with UI scrolling/switching checks.
- Lightroom and Capture One XMP round-trip sample suite.
- App icon and `.icns` pipeline.
- More robust release checks before every DMG.
- Real removable-card regression with DCIM variants.

### C. Workflow Enhancements

- Batch rename real-world regression and optional copy-flow integration.
- Detailed hash verification report UI.
- User-configurable keyboard shortcuts with conflict detection.
- Workspace preset import/export.

### D. Advanced Review And Automation

- Similar image grouping.
- 2-4 image compare view.
- Vision FeaturePrint clustering.
- Face, closed-eye, blur, and sharpness detection.
- Burst grouping and automatic review assistance.

### E. Planned-But-Unwired Surfaces

- App icon and `.icns` release asset pipeline.
- Developer ID signing and notarization.
- Windows x86 implementation from the handoff package.

## Review Scopes And Analysis Tools / 审片示波器与分析工具

Implemented:

- Histogram floating and inspector modes.
- Waveform floating and inspector modes.
- Luma/RGB/channel waveform data service.
- Shared image analysis buffer.
- Composition guide overlays.
- Crop aspect reference with mask/frame modes.
- Review background and review matte controls.

Planned:

- LibRaw evaluation as an optional RAW analysis backend, not a default gallery renderer.
- RGB clipping map; RAW-aware clipping map later.
- Vectorscope with skin-tone and hue reference lines.
- Hue histogram.
- Saturation histogram.
- Dominant palette extraction with 5-12 colors, percentages, average luminance/saturation, and harmony relationship labels.
- EXIF statistics by user-selected fields.
- GPS/map panel.
- Burst grouping, eventually shared with similarity grouping.

## Planned Feature Implementation Sketch / 未实现功能推进草案

These items already appear in models, docs, or menus as planned surfaces, but they are not product-complete yet. Treat this as the next-pass implementation map rather than a detailed design spec.

Implementation rule: roadmap features must be incremental and non-regressive. Each step should reuse existing services and UI contracts where possible, avoid changing proven workflows unless explicitly requested, and include focused regression verification for any shared path it touches.

实施原则：路线图功能必须渐进且不破坏既有能力。每一步都应优先复用现有服务和 UI 契约，除非明确要求，否则不得改变已经验证过的工作流；凡触及共享路径，都要包含有针对性的回归验证。

### Similar Grouping And Vision Review / 相似分组与智能审片

1. Add a `SimilarityService` that computes a lightweight perceptual hash first, then optionally upgrades to Vision `VNFeaturePrintObservation` where available.
2. Store only stable derived metadata in `MediaItem.perceptualHash` and `similarityGroupID`; keep expensive vectors in a cache keyed by file fingerprint rather than in workspace presets.
3. Add a thresholded grouping model around `SimilarityGroup`, with explicit states for pending, ready, and failed analysis.
4. Start with a sidebar or gallery filter that shows groups and near-duplicates; defer automatic delete/reject suggestions until grouping accuracy is validated.
5. Share the grouping substrate with future burst grouping, blur/sharpness checks, face/closed-eye detection, and other Vision review aids.

### Compare View / 多图对比视图

1. Reuse `PreviewDecodeService` and `PreviewRenderGeometry` so each compared image uses the same preview-source and overlay math as gallery mode.
2. Add a compare selection state for 2-4 items, seeded from the current selected/focused browser items.
3. Build a split-pane compare view with synchronized rating, Pick, color label, zoom/pan, and optional metadata rows.
4. Keep compare overlays limited at first: crop reference, guides, histogram/waveform per active pane; avoid adding new geometry paths.
5. Add targeted regression with panoramic JPEG, vertical RAW/DNG, RAW proxy, and mixed RAW+JPEG selections.

### Review Scopes And Metadata Panels / 示波器与元数据面板

1. Extend `ImageAnalysisService` with reusable analysis products: clipping mask, hue histogram, saturation histogram, dominant palette, and vectorscope data.
2. Use the existing RGB preview buffer for first implementation; evaluate LibRaw only for RAW-aware clipping and sensor-level scope accuracy after ImageIO behavior is measured.
3. Add explicit unavailable/error states to scope panels so videos or unsupported images do not show an endless progress indicator.
4. Add a GPS/EXIF statistics panel behind inspector placement first, then consider floating panels only if the workflow demands it.
5. Add fixture tests for histogram/scope math and UI regression with known clipped, saturated, and GPS-tagged samples.

### Shortcut Editor And Workspace Exchange / 快捷键与工作区交换

1. Introduce a shortcut registry that maps command identifiers to default key equivalents and current user overrides.
2. Add conflict detection before persisting overrides, including conflicts with app commands and workflow shortcuts handled by local event monitors.
3. Route AppCommands, Quick Look shortcuts, filmstrip shortcuts, and browser shortcuts through the registry instead of hard-coded key checks.
4. Add workspace preset import/export as JSON once preset schema stability and migration behavior are covered by tests.

### Release Assets And Distribution / 发布资产与分发

1. Add a source app icon asset and repeatable `.icns` generation script.
2. Teach `script/build_and_run.sh` to include the icon in `Info.plist` and bundle resources.
3. Add release-readiness checks for icon presence, localization, universal architecture, code signature, and DMG integrity.
4. Add Developer ID signing and notarization as explicit release-only paths; keep ad-hoc DMG for internal testing.

### Windows x86 Port / Windows x86 移植

1. Keep `WindowsPort/` as the behavior reference and build a separate implementation rather than mixing Windows code into the macOS Swift target.
2. Start with read-only parity: scanner, grid/list/gallery, sorting/filtering, thumbnail cache, and unified preview geometry.
3. Add metadata/XMP, copy workflow, proxy generation, and scopes only after the browser shell is performant on RAW-heavy folders.
4. Use the macOS tests and real-folder baseline reports as acceptance references, translating them into the Windows stack over time.

## RAW Decode Backend Roadmap / RAW 解码后端路线

The current production backend remains ImageIO/QuickLook through `PreviewDecodeService`.

当前生产后端仍然是通过 `PreviewDecodeService` 调用 ImageIO/QuickLook。

Future LibRaw work is fixed as a roadmap item, not a default-preview replacement:

1. Keep `PreviewRasterDecodeProvider` as the backend boundary.
2. Build a standalone LibRaw probe before production integration.
3. Compare LibRaw against ImageIO/QuickLook on real RAW folders and Windows-port samples.
4. Use LibRaw first for RAW-aware clipping maps and analysis scopes.
5. Expose LibRaw as an optional preview backend only after performance, memory, color, packaging, and licensing checks pass.

未来 LibRaw 工作固定为路线图项目，而不是默认预览替换：

1. 保持 `PreviewRasterDecodeProvider` 作为后端边界。
2. 正式接入前先构建独立 LibRaw 探针。
3. 使用真实 RAW 文件夹和 Windows 移植样本对比 ImageIO/QuickLook。
4. 优先用于 RAW-aware clipping map 和分析示波器。
5. 只有在性能、内存、色彩、打包和授权检查通过后，才作为可选预览后端开放。

## Review Environment And Soft Proofing / 审阅环境与软打样

Implemented:

- Follow system / light / dark appearance preference.
- Preview background tone presets.
- Review matte padding presets.
- Inspector scrolling for long metadata.

Planned:

- ICC/ICM profile picker.
- Favorite proof profiles.
- Soft proof preview path based on ColorSync/Core Image rather than QuickLook.
- Explicit option to write profile information only when safe and user-approved.

## Windows Port Milestone / Windows 移植里程碑

The macOS app remains the source of truth for product behavior. A Windows x86 port should target functional and visual parity, while replacing Apple-only APIs with Windows-native equivalents.

Recommended Windows port stages:

1. Read-only browser shell: source/target folder panes, media scan, grid/list/gallery, sorting/filtering.
2. Preview parity: thumbnails, gallery preview, filmstrip, unified image geometry, crop masks, guides.
3. Metadata/XMP: EXIF display, rating/Pick/color labels, sidecar compatibility.
4. Copy workflow: rules, pause/resume/cancel, verification, logs.
5. Proxy generation and preheat.
6. Histogram/waveform and review overlays.
7. Batch rename and workspace presets.
8. Performance tuning for RAW-heavy folders.
9. Installer/package for Windows x86.

Detailed Windows handoff documents live in `WindowsPort/`.
