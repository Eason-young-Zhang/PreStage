# Architecture / 架构说明

Last updated: 2026-05-26

This document is the consolidated technical reference for PreStage. It replaces the older split documents `overview.md`, `modules.md`, `ui_design.md`, and `performance_baselines.md`.

本文是 PreStage 当前统一的技术说明，合并并取代旧的 `overview.md`、`modules.md`、`ui_design.md` 和 `performance_baselines.md`。

## Product Purpose / 产品宗旨

PreStage is a lightweight native macOS app for photo preselection before importing into Lightroom, Capture One, or other heavy catalog/editing software. It focuses on fast folder browsing, quick visual review, basic metadata marking, proxy-assisted RAW preview, and reliable copy/organization.

PreStage 是一个轻量级原生 macOS 选片与复制整理工具，用于在导入 Lightroom、Capture One 等大型软件前快速浏览、筛选、标记和复制摄影素材。

Primary product principles:

- Prefer native platform behavior over custom UI when possible.
- Show files directly from folders; avoid import catalogs and hidden databases.
- Keep source and destination workflows visible and reversible.
- Preserve interoperability through sidecar XMP instead of mutating RAW files.
- Make review overlays exactly match the rendered image, not merely metadata dimensions.

核心产品原则：

- 优先使用系统原生能力。
- 直接浏览文件夹，不要求导入数据库。
- 源文件夹和目标文件夹的复制关系必须清晰。
- 通过 XMP sidecar 保持跨软件兼容。
- 审片叠加层必须贴合实际渲染图像边界，而不是只贴合元数据尺寸。

## Platform / 平台

- Language: Swift 5.9
- Package: Swift Package Manager
- Minimum macOS: 15.4
- App model: SwiftUI app with targeted AppKit / QuickLook interop
- Local bundle identifier: `local.codex.PreStage`
- Source root: `Sources/PreStage`
- Tests: `Tests/PreStageTests`

## Runtime Structure / 运行结构

```text
Sources/PreStage
  App/          App entry point and command/menu registration
  Models/       Media, workspace, filter, sort, copy, scope, and layout models
  Stores/       AppStore orchestration and user workflow state
  Services/     File scanning, metadata, XMP, thumbnails, proxies, copy, rename, diagnostics
  Support/      Shared utilities, localization, geometry, formatters
  Views/        SwiftUI views and AppKit-backed controls
  Resources/    Localized strings and bundle resources
```

## Core Modules / 核心模块

### AppStore

`AppStore` is the central coordinator. It owns current source/target selections, browser state, selected items, filters, sort, copy state, workspace persistence, preview helpers, diagnostics, and status messages.

`AppStore` 是应用级状态协调中心，负责源/目标路径、浏览器状态、选中项、筛选、排序、复制状态、工作区持久化、预览辅助、诊断和状态栏消息。

### MediaScanner

Scans supported media files from the selected source folder. It supports optional recursive source scanning and excludes generated proxy folders.

Supported media includes RAW, JPEG, HEIC, TIFF, PNG, MOV, MP4, and M4V.

### MetadataService

Reads file dates, EXIF camera/lens/exposure fields, pixel dimensions, display dimensions, orientation, color model, and color profile. Metadata loading is split from the fast initial scan and filled later through a cancellable background queue plus disk cache.

### XMPService

Reads and writes rating, color label, and PreStage Pick state. It preserves unknown XML where possible, keeps existing `CreatorTool`, reads English and Simplified Chinese label names, writes language-independent English labels, and treats Lightroom `Rating=-1` as rejected.

### ThumbnailService

Generates thumbnails through `PreviewDecodeService` / ImageIO direct downsampling for supported raster/RAW paths and QuickLookThumbnailing fallback where needed. It uses bounded memory cache plus disk cache keyed by file fingerprint and thumbnail size.

Recent geometry fix: filmstrip layout can update item width from the actual rendered thumbnail `NSImage.size`, not only from metadata aspect ratio.

### Preview Rendering

Gallery preview now has a dedicated geometry path:

- `PreviewDecodeService`: shared preview pipeline for RAW proxy selection, direct-raster capability checks, ImageIO pixel-size reads, downsampled CGImage/NSImage creation, and decode warmup cache.
- `PreviewRasterDecodeProvider`: backend protocol used by `PreviewDecodeService`; current production implementation is `ImageIOPreviewRasterDecodeProvider`.
- `PreviewRenderGeometry`: single source for image rect, crop rect, pixel alignment, and mask rectangles.
- `PreviewSourceGeometry`: compatibility facade used by geometry code; it delegates preview-source dimensions and direct-render checks to `PreviewDecodeService`.
- `RasterMediaPreviewView`: direct ImageIO/CoreGraphics preview renderer for JPEG/HEIC/PNG/TIFF and common RAW formats when ImageIO can decode them.
- `NativeMediaPreviewView`: QuickLook fallback and buffered preview path for sources that cannot be decoded directly.
- `ThumbnailService`, `PreviewPreheatService`, `GalleryPreviewBaselineService`, and `ImageAnalysisService` now share the same decode helper rather than duplicating ImageIO downsampling logic.

This architecture exists to avoid a recurring class of bugs where QuickLook, crop masks, guide lines, and filmstrip frames used different definitions of the image boundary. All image-bound overlays should now derive their rect from `PreviewRenderGeometry`.

Future RAW backends such as LibRaw should be evaluated as `PreviewRasterDecodeProvider` implementations behind `PreviewDecodeService` rather than wired directly into views or analysis services. The current evaluation plan is documented in `docs/libraw_evaluation.md`.

画廊预览现在使用统一几何：

- `PreviewDecodeService`：共享预览管线，负责 RAW 代理选择、直接栅格支持判断、ImageIO 像素尺寸读取、CGImage/NSImage 下采样和预热缓存。
- `PreviewRasterDecodeProvider`：`PreviewDecodeService` 使用的解码后端协议；当前生产实现是 `ImageIOPreviewRasterDecodeProvider`。
- `PreviewRenderGeometry`：唯一的图片 rect、裁切 rect、像素对齐和遮幅矩形来源。
- `PreviewSourceGeometry`：几何代码使用的兼容门面，实际尺寸读取和直接渲染判断委托给 `PreviewDecodeService`。
- `RasterMediaPreviewView`：对 JPEG/HEIC/PNG/TIFF 和常见 RAW 优先走 ImageIO/CoreGraphics 直接渲染。
- `NativeMediaPreviewView`：作为无法直接解码时的 QuickLook fallback。
- `ThumbnailService`、`PreviewPreheatService`、`GalleryPreviewBaselineService` 和 `ImageAnalysisService` 共享同一套解码辅助能力，避免重复维护 ImageIO 下采样逻辑。

这套结构用于彻底避免“预览图、遮幅、辅助线、胶片条外框各自计算边界”的问题。

未来如果接入 LibRaw 等 RAW 后端，应作为 `PreviewRasterDecodeProvider` 实现挂在 `PreviewDecodeService` 之后评估，而不是直接写入具体视图或分析服务。当前评估方案见 `docs/libraw_evaluation.md`。

### ProxyGenerationService

Generates lower-resolution JPEG proxy files inside source folders for faster RAW preview. Proxy folders are excluded from scanning. Gallery preview prefers valid proxies when available.

### PreviewPreheatService

Runs low-priority preheat work around the current gallery selection. It can prepare nearby RAW proxies and warm preview resources, with progress shown in the status bar.

### Histogram, Waveform, And Analysis

`ImageAnalysisService` creates reusable RGBA buffers from the current gallery preview source. Histogram and waveform services use this shared data path. Current scope tooling includes histogram and waveform with floating and inspector placement.

### CopyService

Supports date, preserved-structure, camera, and rating organization rules; copy all files or RAW only; auto rename, skip, or overwrite conflicts; pause/resume/cancel; count/size verification; optional SHA-256 verification; and persistent copy logs.

### BatchRenameService

Supports selected-file batch rename with preview, tokens, cleanup options, sidecar rename, RAW+JPEG grouping, conflict detection, recent in-memory undo, and persistent logs.

### WorkspaceService

Persists layout, view mode, filters, sort, copy settings, language, source/target paths, transforms, logs, subfolder preference, card behavior, review environment, scope settings, and named workspace presets.

## UI Architecture / 界面结构

Main layout:

- Left sidebar: card status, source folder, target folder, filters.
- Browser header: folder title, view mode, sort direction, sort field.
- Main browser: icon, list, or gallery mode.
- Gallery inspector: rating, Pick state, color labels, scopes, metadata.
- Bottom gallery strip: collapsible filmstrip and review tool controls.
- Toolbar: copy, copy settings, share, more menu, search.

Design guidance:

- Keep UI dense and work-focused.
- Use icon buttons for tools and native hover help for shortcut hints.
- Avoid decorative card-heavy layouts.
- In gallery mode, preserve the image as the center of attention.
- Do not allow overlays to drift from rendered image bounds.
- New feature work must be non-regressive by default: preserve existing scan, preview, metadata, copy, workspace, and release behavior unless the user explicitly approves a behavior change, and cover shared-path changes with focused regression tests.

## Current Important State Models / 关键模型

- `MediaItem`: file identity, type, dates, metadata, display dimensions, rating, label, Pick state, copy/XMP status, pairing, similarity placeholders.
- `PanelLayout`: layout sizes, view options, crop/guide/scope settings, appearance/background/review matte controls.
- `FilterState`: rating, Pick state, color, camera/lens, search, date range.
- `SortRule`: field and direction for name, kind, date added, modified, created, last opened, size.
- `WorkspacePreset`: named workspace state.
- `SimilarityGroup`: placeholder for future grouping.

## Performance Notes / 性能说明

Current performance strategy:

- Fast initial scan first; expensive metadata later.
- Disk-backed thumbnail cache and metadata cache.
- Proxy JPEGs for faster RAW gallery preview.
- Cancellable preview preheat around current selection.
- Image analysis services cache by file fingerprint and preview URL.
- Window live-resize state reduces expensive gallery invalidation.
- Direct ImageIO rendering is preferred for gallery raster previews to avoid QuickLook internal padding and geometry mismatch.

Known profiling needs:

- RAW-only folders with 200/500/1000+ files.
- Long direction-key gallery navigation.
- Proxy generation across entire folders.
- Memory peak during analysis scopes.
- Large copy with pause/cancel/hash verification.

## Testing / 测试

Primary commands:

```bash
swift build
CLANG_MODULE_CACHE_PATH=.build/module-cache swift test
./script/build_and_run.sh
```

Current automated coverage includes pairing, filtering, sorting, copy, cancellation, RAW-only copy, proxy paths, scanner proxy exclusion, workspace migration, thumbnail cache, XMP, histogram, waveform, image analysis, batch rename, and preview/filmstrip geometry.

UI changes should be verified with Computer Use, especially:

- Gallery image boundaries, crop masks, guide lines, and filmstrip frames.
- Icon/list QuickLook and keyboard navigation.
- Source/target folder branch behavior.
- Copy settings popover and copy pause/cancel.
- Light/dark appearance and review background.
