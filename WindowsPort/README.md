# PreStage Windows Port Handoff

Last updated: 2026-05-26

This folder is a dedicated handoff package for building a Windows x86 version of PreStage. The macOS codebase remains the product reference, but the Windows implementation should use Windows-native APIs and controls where practical.

目标：将 PreStage 移植到 Windows x86 平台，尽量保持功能、界面、性能和 macOS 版本一致，同时使用 Windows 原生能力替换 Apple-only API。

## Recommended Reading Order

1. `PROJECT_BRIEF.md`
2. `FEATURE_PARITY_CHECKLIST.md`
3. `ARCHITECTURE_MAPPING.md`
4. `UI_AND_INTERACTION_SPEC.md`
5. `TEST_AND_ACCEPTANCE_PLAN.md`
6. macOS source docs:
   - `../README.md`
   - `../docs/project_status.md`
   - `../docs/architecture.md`
   - `../docs/roadmap.md`

## Porting Principle

Do not clone SwiftUI/AppKit implementation details blindly. Clone the product behavior.

The Windows app should feel like a serious native photo workflow tool:

- Fast folder browsing.
- Stable image-bound overlays.
- Reliable metadata and sidecar workflows.
- Clear source-to-target copy workflow.
- Dark review-friendly UI.
- Predictable keyboard shortcuts.
- Good large-folder performance.

## Suggested Windows Stack

Preferred options:

- C# / .NET 8 or newer.
- WinUI 3 or WPF depending on team experience.
- Windows Imaging Component (WIC) for JPEG/PNG/TIFF/HEIF where available.
- Microsoft Raw Image Extension or LibRaw for RAW support.
- ExifTool, MetadataExtractor, or native metadata APIs for EXIF/XMP.
- SQLite or JSON files only if persistence needs exceed simple settings; avoid a mandatory catalog database for the main workflow.

The exact stack is open, but the UX should remain close to the macOS reference.
