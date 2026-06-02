# Windows Port Project Brief / Windows 移植项目总说明

Language: English | [简体中文](PROJECT_BRIEF.zh-CN.md)

Last updated: 2026-05-26

## 1. Product Mission / 产品使命

PreStage is a lightweight photo preselection and copy workflow tool. It is designed for photographers who need to quickly inspect files from memory cards or local folders before importing them into Lightroom, Capture One, or another heavy editing/catalog application.

PreStage 是一个轻量级摄影素材预筛选和复制整理工具。它服务于摄影师在导入 Lightroom、Capture One 等大型软件前的快速选片、标记、筛选、代理预览和复制整理流程。

The Windows port should preserve the same mission:

- Start quickly.
- Browse folders directly.
- Avoid a mandatory import/catalog step.
- Provide fast visual review.
- Write interoperable sidecar metadata.
- Copy selected assets safely into organized destination folders.

## 2. Target Platform / 目标平台

- Primary target: Windows x86/x64 desktop.
- Architecture target requested by user: Windows X86 platform.
- Recommended OS baseline: Windows 10 22H2 or Windows 11.
- Form factor: desktop/laptop, mouse/keyboard first.
- Performance priority: large photo folders and removable cards.

## 3. Product Identity / 产品身份

- Name: PreStage
- Domain: photo preselection before editing/import.
- Tone: professional, dense, utilitarian, review-focused.
- Visual reference: Finder / Lightroom / Capture One style workflow, not a marketing app.

## 4. Current macOS Feature Set / 当前 macOS 能力

The macOS version currently supports:

- Source folder selection.
- Target folder selection.
- Camera card detection and safe eject.
- Source folder child selection without replacing root.
- Optional recursive source scanning.
- Grid/icon view.
- List view.
- Gallery view.
- Collapsible gallery filmstrip.
- Adaptive filmstrip item sizes.
- Right inspector with metadata and review controls.
- Rating 0-5.
- Pick / Reject / Unmarked.
- Color labels.
- Search.
- Filters by rating, Pick state, color, date range, camera, lens.
- Sorting by name, kind, added date, modified date, created date, last opened date, size.
- Sort ascending/descending toggle.
- RAW, JPEG, HEIC, TIFF, PNG, MOV, MP4, M4V scanning.
- RAW+JPEG pairing and collapsed display.
- XMP sidecar read/write.
- Batch rename.
- Copy workflow with rules.
- Copy pause/resume/cancel.
- Copy all supported files or RAW only.
- Copy conflict policies.
- Count/size verification.
- Optional SHA-256 verification.
- Copy logs.
- Proxy JPEG generation.
- Gallery preview preheat.
- Histogram.
- Waveform scope.
- Composition guides.
- Crop aspect reference with mask/frame.
- Review background and review matte.
- Multiple workspace presets.
- Chinese and English localization.

## 5. Critical UX Requirements / 关键体验要求

### Image-Bound UI Must Be Exact

This is the most important lesson from the macOS implementation.

Crop masks, guide lines, filmstrip frames, compare overlays, clipping maps, soft-proof boundaries, and any future analysis overlay must match the actual rendered image boundary. Do not calculate overlay bounds separately from the preview renderer.

Windows implementation should create a single geometry service equivalent to macOS `PreviewRenderGeometry`:

- Input: container size, preview source pixel size, scale/DPI.
- Output: rendered image rect, crop rect, pixel-aligned rects, mask rectangles.
- All overlays use this output.
- Avoid half-pixel gaps and antialias bright lines.

### Fast Folder-First Workflow

The app must not require users to import files into a catalog before browsing. It should scan and show files directly from the selected folder.

### Metadata Compatibility

Ratings, Pick/Reject, and color labels should be written to XMP sidecars where safe. RAW files should not be modified directly by default.

### Review-Oriented UI

The gallery should support dark or neutral backgrounds, optional review padding, and fast keyboard navigation.

## 6. Suggested Windows Architecture / 建议 Windows 架构

Recommended layers:

```text
PreStage.Windows
  AppShell
  ViewModels
  Views
  Services
  Models
  Imaging
  Persistence
  Tests
```

Services:

- `MediaScannerService`
- `MetadataService`
- `XmpService`
- `ThumbnailService`
- `PreviewRenderGeometry`
- `PreviewImageService`
- `ProxyGenerationService`
- `CopyService`
- `BatchRenameService`
- `WorkspaceService`
- `HistogramService`
- `WaveformService`
- `SimilarityService` later

## 7. Imaging Strategy / 图像策略

Windows has no QuickLook equivalent that perfectly matches macOS. The Windows port should own more of the preview pipeline directly.

Recommended:

- Use WIC for standard raster images.
- Use LibRaw or Windows Raw Image Extension for RAW decoding.
- Generate proxy JPEGs for RAW-heavy workflows.
- Use direct decoded bitmap dimensions as the source of preview geometry.
- Cache thumbnails and preview bitmaps aggressively but with memory limits.

Avoid:

- One service for preview image and another unrelated service for overlay bounds.
- Letting thumbnails include internal padding while item frames use file metadata.
- Assuming RAW pixel dimensions equal embedded preview dimensions.

## 8. Persistence / 持久化

Persist:

- Source path.
- Target path.
- View mode.
- Filters.
- Sort rule.
- Copy settings.
- Language.
- Review background.
- Review matte.
- Workspace presets.
- Thumbnail/metadata caches.
- Copy and batch rename logs.

Avoid making the app dependent on a central catalog database for normal browsing.

## 9. Future Product Direction / 未来方向

After parity:

- Similar grouping.
- Compare view.
- Clipping map.
- Vectorscope.
- Hue/saturation histograms.
- Dominant palette.
- GPS map.
- Burst grouping.
- AI/Vision-style review assistance.
- Soft proofing.

## 10. Success Criteria / 成功标准

The Windows port can be considered initially successful when:

- A user can choose a folder with mixed RAW/JPEG files.
- Files appear quickly in grid/list/gallery.
- Gallery preview and filmstrip are smooth.
- Crop masks and guides exactly match the image.
- Ratings/Pick/color labels work.
- XMP sidecars are read/written.
- Selected files can be copied with pause/cancel and verification.
- Proxy generation improves RAW preview.
- UI feels suitable for long review sessions.
