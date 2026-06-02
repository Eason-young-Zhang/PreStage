# Project Status / 项目状态

Last updated: 2026-05-26
Branch: `main`

## Snapshot / 当前概况

PreStage is a native macOS photo preselection and copy workflow app. It is now beyond the original v0.1 scope, covers most v0.2 goals, and includes several advanced review tools requested during development.

PreStage 是一个原生 macOS 摄影素材预筛选与复制整理应用。当前实现已超过原始 v0.1 范围，覆盖大部分 v0.2 目标，并提前实现了一批高级审片工具。

Latest important baseline:

- Unified gallery preview geometry.
- Shared `PreviewDecodeService` for RAW proxy selection, backend-based raster decoding, ImageIO downsampling, preview warmup, thumbnails, and analysis buffers.
- Direct raster preview path for JPEG/HEIC/PNG/TIFF and common RAW when ImageIO can decode them.
- Pixel-aligned crop masks with outward bleed to prevent 1px bright slivers.
- Filmstrip item width can follow actual rendered thumbnail aspect ratio.
- Histogram and waveform scopes are available in floating and inspector placements.
- Review environment controls exist for app appearance, preview background, and review matte.
- Repeatable real-world baseline tests now cover mixed DNG/RW2/JPEG and RAW-only RW2 folders.

## Implemented / 已实现能力

- SwiftPM native macOS app using SwiftUI plus AppKit/QuickLook interop.
- Source and target folder selection.
- Camera card detection, mount/unmount monitoring, configurable insert behavior, and safe eject.
- Source folder branch picker with stable root and child-folder content browsing.
- Optional recursive source scanning.
- Icon, list, and gallery browsing modes.
- Adaptive gallery filmstrip, collapsible filmstrip, adjustable filmstrip height, adjustable inspector width.
- Unified gallery preview geometry for preview, crop mask, guide overlay, and filmstrip sizing.
- Direct raster preview renderer plus QuickLook fallback.
- Quick Look preview from grid/list with arrow-key selection sync and workflow shortcuts.
- RAW, JPEG, HEIC, TIFF, PNG, MOV, MP4, M4V scanning.
- Thumbnail generation with ImageIO, QuickLook fallback, bounded memory cache, and disk cache.
- Shared preview decode pipeline for gallery, thumbnail, preheat, baseline, and analysis services.
- Background metadata loading with disk cache.
- EXIF/date/size/camera/lens/exposure/dimension/color profile display.
- Rating, Pick/Reject, color labels, search, and filters.
- Rich sorting by name, kind, added, modified, created, last opened, and size.
- XMP sidecar read/write for rating, color label, and PreStage Pick state.
- RAW+JPEG pairing and paired metadata/copy behavior.
- Batch rename with preview, tokens, cleanup, sidecar handling, RAW+JPEG grouping, conflict detection, undo, and logs.
- Copy rules by date, preserved structure, camera model, and rating.
- Copy pause/resume/cancel.
- Copy all supported files or RAW only.
- Copy conflict policies and verification by size/count or optional SHA-256.
- Proxy JPEG generation with progress and scanner exclusion.
- Gallery preview preheat for nearby items and RAW proxy preparation.
- Histogram and waveform scopes.
- Composition guides and crop aspect masks/frames.
- Review appearance, preview background, and review matte controls.
- Workspace persistence and named workspace presets.
- Chinese and English localization, including bundle localization for system panels.
- Universal macOS app build path for Apple Silicon and Intel.
- Internal ad-hoc DMG packaging.
- Automated tests currently cover 58 cases across core services, preview geometry, preview decoding, and optional real-world baselines.

## Current Gaps / 当前缺口

- v0.3 similarity grouping is still not implemented.
- 2-4 image compare view is not implemented.
- Vision FeaturePrint / face / closed-eye / blur / sharpness analysis is not implemented.
- Clipping map, vectorscope, hue histogram, saturation histogram, dominant palette, GPS panel, and EXIF statistics are planned but not implemented.
- User-configurable shortcut editor is not implemented.
- App icon and `.icns` asset pipeline are not implemented.
- Developer ID signing and notarization are not implemented.
- Lightroom / Capture One XMP compatibility needs real sidecar sample regression.
- RAW-only large-folder command-line baseline has started; UI-level scrolling/switching regression is still needed.
- Real removable camera-card regression is still needed.
- Windows x86 port has documentation only; no implementation exists yet.
- Rough next-step implementation sketches for planned-but-unwired features are maintained in `docs/roadmap.md`.

## Recent High-Risk Fix / 最近高风险修复

The project previously had repeated issues where crop masks, guide lines, gallery preview, and filmstrip frames disagreed about the image boundary, especially for panoramic images, non-standard aspect ratios, RAW embedded previews, and proxy images.

The fix introduced:

- `PreviewRenderGeometry` as the single geometry source.
- Direct ImageIO/CoreGraphics raster preview where possible.
- QuickLook only as fallback for sources that cannot be decoded directly.
- Pixel-aligned preview and crop rects.
- Four independent crop mask rectangles instead of one even-odd fill path.
- Outward mask bleed to avoid 1px bright edge artifacts.
- Filmstrip rendered-thumbnail aspect tracking.

Future overlay, soft proof, compare, and analysis tools must reuse this geometry path.

## Recommended Next Work / 建议下一步

1. Continue UI-level real-world regression on panoramic JPEG, vertical RAW/DNG, RAW-only folders, RAW+JPEG folders, and generated proxies.
2. Prepare Lightroom and Capture One XMP sidecar fixtures.
3. Build app icon and release asset pipeline.
4. Decide whether v0.3 similarity grouping or Windows x86 port is the next major implementation track.
5. Use `WindowsPort/` documents as the handoff package for Windows development.

## Documentation Map / 文档地图

- `README.md`: project entrance and common commands.
- `docs/architecture.md`: current architecture, modules, UI structure, performance notes.
- `docs/roadmap.md`: phase status and future feature plan.
- `docs/release.md`: macOS packaging and distribution.
- `docs/HANDOFF.md`: concise continuation notes for future coding sessions.
- `docs/baselines/`: repeatable real-world baseline reports and commands.
- `WindowsPort/`: Windows x86 port handoff package.
