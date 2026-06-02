# Architecture Overview

Language: English | [简体中文](architecture.zh-CN.md)

PreStage is organized around a simple photo workflow:

1. Select a source folder or camera-card DCIM folder.
2. Scan media and pair related assets, such as RAW+JPEG.
3. Review items in grid, list, or gallery mode.
4. Apply rating, pick/reject, color labels, overlays, and preview tools.
5. Copy selected or visible media into a target folder with predictable organization and conflict handling.

## Platform Reference

The macOS implementation in `PreStage-Mac` is the product behavior reference. The Windows implementation should stay aligned with macOS unless a Windows platform constraint requires a difference.

When adding or changing a feature:

- Read the related macOS service/view first when practical.
- Keep Windows terminology, command placement, and feedback close to macOS.
- Document unavoidable platform differences.

## Windows Projects

### `PreStage.App`

WPF UI project.

Responsibilities:

- Main window layout.
- Gallery, inspector, copy log, and custom controls.
- XAML resources, styles, converters, and code-behind for UI-only behavior.

Avoid putting file-system, metadata, or copy logic here.

### `PreStage.ViewModels`

MVVM orchestration layer.

Responsibilities:

- UI state and commands.
- Connecting app actions to core services.
- Workspace preset restore/save.
- Filtering, sorting, selection, preview loading, copy workflow, and review commands.

This layer may coordinate services, but should avoid low-level platform APIs when possible.

### `PreStage.Core`

Domain models and services.

Important areas:

- `Models`: media state, filter/sort/copy models, panel layout, workspace presets.
- `Services/MediaScannerService.cs`: folder scan and metadata enrichment entry points.
- `Services/MetadataService.cs`: EXIF/XMP enrichment and sidecar merge.
- `Services/XmpService.cs`: sidecar read/write and Lightroom-style rejected rating handling.
- `Services/CopyService.cs`: copy workflow, conflict handling, sidecar preservation, verification.
- `Services/PreviewImageService.cs`: preview loading and RAW proxy preference.
- `Services/HistogramService.cs`, `WaveformService.cs`, `ImageAnalysisService.cs`: review analysis tools.
- `Services/CameraCardService.cs`: removable-drive/DCIM detection with safe eject left as a TODO.

Core should remain mostly UI-agnostic. If a service needs UI-thread dispatching, put that in the ViewModel instead.

### `PreStage.Tests`

xUnit tests for core behavior and geometry.

Current high-value coverage:

- XMP read/write round trips.
- Lightroom rejected rating compatibility.
- Metadata sidecar enrichment.
- Copy sidecar preservation and conflict handling.
- Preserve-structure copy paths.
- Preview render geometry.
- Histogram/waveform/image analysis services.

## Persistence

Workspace state is stored by `WorkspaceService` under:

```text
%LocalAppData%\PreStage\
```

Saved state includes source/target paths, view mode, filters, copy settings, camera-card action, and layout preferences.

## XMP Sidecar Behavior

PreStage writes review state to XMP sidecars:

- Rating: `xap:Rating`
- Color label: `xap:Label`
- Photoshop urgency mapping for labels
- Pick state: `prestage:PickState`

Lightroom-style `Rating=-1` is treated as `PickState.Rejected` with normalized rating `0`.

When copying files, matching sidecars are treated as part of the media asset:

- Existing sidecars participate in conflict detection.
- Auto-renamed media receives a matching auto-renamed sidecar.
- Overwrite removes stale destination sidecars before copying new sidecars.

## Preview and RAW Strategy

Direct preview support depends on Windows imaging capabilities and `System.Drawing` compatibility. RAW files may not decode directly on every machine. For RAW media, `PreviewImageService` first looks for a fresher JPEG proxy under a sibling `Proxies` folder.

Future work should consider replacing or supplementing the current imaging path with Windows Imaging Component, LibRaw, or another predictable decoder.

## Camera Card Strategy

`CameraCardService` detects removable drives and DCIM folders. It intentionally does not shell out to eject drives. Safe eject should be implemented through a Windows device API or kept as a clear manual fallback.
