# PreStage

Language: English | [简体中文](README.zh-CN.md)

PreStage is a cross-platform photo ingest and review tool for photographers who need a fast source-to-target workflow before the final editing stage. It focuses on browsing camera folders, reviewing images, writing XMP sidecars, and copying selected media into an organized destination.

The macOS version is the product reference implementation. The Windows version is an actively developed WPF port that aims to match the same workflow, terminology, and review experience as closely as possible.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `PreStage.App` | Windows WPF desktop application and XAML UI. |
| `PreStage.ViewModels` | Windows MVVM state, commands, workflow orchestration, and persistence glue. |
| `PreStage.Core` | Shared Windows-domain models and services: scanning, metadata, XMP, copy, preview, analysis, workspace persistence. |
| `PreStage.Tests` | xUnit tests for Windows core services and geometry. |
| `PreStage-Mac` | macOS reference implementation, tests, docs, and product behavior baseline. |
| `WindowsPort` | Original Windows port handoff notes and parity checklist. |
| `docs` | Maintainer-facing docs for build, architecture, roadmap, and troubleshooting. |

## Current Status

The Windows app currently supports:

- Folder import and recursive scanning.
- Grid, list, and gallery review modes.
- RAW+JPEG pairing and stack collapse/expand behavior.
- Thumbnail loading, large preview loading, proxy preference for RAW previews.
- Rating, pick/reject, color label, and XMP sidecar round trips.
- Copy/export with organization rules, conflict handling, sidecar copying, and optional verification.
- Histogram, waveform, crop masks, composition guides, and filmstrip review controls.
- Workspace persistence for source, target, view mode, copy settings, and layout preferences.
- Removable camera-card detection with DCIM selection. Safe eject is intentionally not implemented yet.

Known gaps are tracked in [docs/roadmap.md](docs/roadmap.md).

## Quick Start for Windows Developers

Prerequisites:

- Windows 10/11.
- .NET SDK 10.0 or newer.
- Git.

Build and test:

```powershell
dotnet restore .\PreStage.slnx
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

Create a self-contained Windows x64 build:

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained true -o .\releases\PreStage-Win
```

More details: [docs/build-and-release.md](docs/build-and-release.md).

## macOS Reference

The macOS implementation under `PreStage-Mac` is included so contributors can compare behavior directly. When Windows and macOS disagree, treat macOS as the product behavior reference unless there is a clear Windows platform constraint.

Recommended macOS reference files:

- `PreStage-Mac/AGENTS.md` for verification expectations.
- `PreStage-Mac/docs/architecture.md` for product architecture.
- `PreStage-Mac/Sources/PreStage/Views` for established UI structure.
- `PreStage-Mac/Sources/PreStage/Services` for mature workflow logic.

## Documentation

- [Build and release](docs/build-and-release.md)
- [Architecture](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Roadmap and known gaps](docs/roadmap.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Windows port notes](WindowsPort/README.md)

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. The short version:

- Keep Windows behavior aligned with the macOS reference.
- Prefer small, well-tested changes.
- Run the Windows test/build commands before submitting.
- Do not commit build outputs, release zips, local worktrees, or generated binaries.

## License

PreStage is released under the MIT License. See [LICENSE](LICENSE).
