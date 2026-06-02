# Architecture Mapping / 架构映射

Language: English | [简体中文](ARCHITECTURE_MAPPING.zh-CN.md)

Last updated: 2026-05-26

This document maps macOS concepts to likely Windows equivalents.

| macOS Concept | Current Role | Windows Equivalent |
| --- | --- | --- |
| SwiftUI views | App layout and high-level state binding | WinUI 3, WPF, Avalonia, or another native desktop UI stack |
| AppKit NSCollectionView | Filmstrip and native list/grid surfaces | ItemsRepeater, ListView/GridView, VirtualizingStackPanel, custom virtualized panel |
| QLPreviewView | Fallback rich preview | Direct image renderer; Shell thumbnail/preview only as fallback |
| QuickLookThumbnailing | Thumbnail generation | WIC, Windows thumbnail provider, LibRaw, ImageSharp/Magick only if acceptable |
| ImageIO | Image metadata and downsampling | WIC, MetadataExtractor, LibRaw, ExifTool |
| NSOpenPanel | Folder picking | Windows FolderBrowserDialog / WinUI folder picker |
| NSWorkspace | Reveal/open/eject where applicable | Windows Shell APIs, Explorer integration |
| UserDefaults | Simple app/workspace persistence | JSON settings in AppData, Windows settings, or lightweight local store |
| XMP sidecar files | Interoperability with Lightroom/Capture One | Same file-based sidecar strategy |
| PreviewRenderGeometry | Unified image boundary | Must be ported nearly directly |

## Must-Port Concepts

### PreviewRenderGeometry

This is mandatory. The Windows app should have an equivalent geometry service from the start.

Input:

- Available preview container size.
- Actual preview bitmap dimensions.
- Display scale/DPI.
- Requested crop ratio.

Output:

- Rendered image rect.
- Pixel-aligned image rect.
- Pixel-aligned crop rect.
- Mask rectangles with outward bleed.

All image-bound UI must depend on this service.

### MediaItem

Windows model should include:

- Stable ID.
- URL/path.
- Filename and extension.
- Media type.
- File size.
- Created/modified/added/last opened dates where available.
- Capture date.
- Camera/lens/exposure fields.
- Pixel dimensions.
- Display dimensions.
- Rating.
- Color label.
- Pick state.
- Copy status.
- XMP status.
- Pairing key.
- Similarity placeholders.

### Workspace

Persist the same user-facing state:

- Layout sizes.
- View mode.
- Filters.
- Sort.
- Copy settings.
- Paths.
- Language.
- Review environment.
- Scope settings.
- Presets.

## Recommended Windows Services

### MediaScannerService

Must support fast initial scan. Expensive metadata should be background-loaded.

### ThumbnailService

Should return thumbnails without internal padding whenever possible. If a Windows shell thumbnail includes padding, track the actual bitmap content rect or generate thumbnails directly.

### PreviewImageService

Should provide decoded bitmap plus actual dimensions. Avoid having UI overlays use a different size source.

### MetadataService

Can combine WIC, ExifTool, MetadataExtractor, and LibRaw depending on chosen stack.

### XmpService

Should be deterministic and conservative. Preserve unknown XML.

### CopyService

Should support cancellation tokens and pause points between files.

### Analysis Services

Histogram/waveform/clipping/vectorscope should share one decoded preview buffer cache.

## Major Risks

- RAW codec availability varies across Windows machines.
- Windows shell thumbnails may contain padding.
- Color management parity with macOS/QuickLook is hard.
- HEIC/HEIF depends on installed codecs.
- File date semantics differ from macOS.
- Eject/safe removal APIs differ.
- DPI scaling can reintroduce half-pixel overlay gaps if geometry is not pixel-aligned.
