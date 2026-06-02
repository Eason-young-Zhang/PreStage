# Contributing to PreStage

Language: English | [简体中文](CONTRIBUTING.zh-CN.md)

Thanks for helping improve PreStage. This project has two implementations in one repository:

- `PreStage-Mac` is the macOS reference implementation.
- `PreStage.App`, `PreStage.Core`, `PreStage.ViewModels`, and `PreStage.Tests` are the Windows WPF port.

The goal is not to create two similar-but-different products. The goal is to keep behavior, terminology, and workflow as aligned as possible across platforms.

## Development Principles

1. Treat macOS as the behavior reference.
   If the Windows version differs from macOS, first check whether the difference is intentional or platform-required.

2. Keep UI and business logic separated.
   Prefer putting workflow logic in `PreStage.ViewModels` and platform/file logic in `PreStage.Core.Services`.

3. Avoid silent feature regressions.
   If a macOS feature cannot be implemented on Windows yet, add an explicit TODO or known limitation with a safe fallback.

4. Prefer safe Windows behavior.
   Avoid shelling out with interpolated user-controlled paths. For example, camera-card eject is currently a safe no-op until a proper Windows device-eject implementation is added.

5. Do not commit generated outputs.
   `bin/`, `obj/`, `releases/`, `publish/`, `PreStage-Win-Trae/`, and packaged macOS binaries are intentionally ignored.

## Local Verification

For most Windows changes, run:

```powershell
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
```

For user-visible UI changes, also launch the app and check the affected workflow manually:

```powershell
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

Suggested manual checks:

- Select a source folder and verify grid/list/gallery modes.
- Select a target folder and run a small copy.
- Set rating, pick/reject, and color label, then verify XMP sidecar output.
- Switch histogram/waveform between floating and inspector placement.
- Confirm the app starts cleanly after restart.

## Pull Request Checklist

- [ ] The change is scoped and easy to review.
- [ ] Windows tests pass.
- [ ] Windows app builds.
- [ ] UI changes were manually smoke-tested.
- [ ] Behavior was compared with the macOS reference when relevant.
- [ ] New edge cases are covered by tests or documented as known limitations.

## Coding Notes

- Keep C# nullable annotations meaningful.
- Prefer async work for scanning, metadata, thumbnails, previews, and copy operations.
- Keep path handling Windows-safe: support spaces, Unicode, long-ish names, and permission failures.
- Preserve XMP sidecars when copying, renaming, or resolving conflicts.
- Keep comments rare and focused on non-obvious behavior.
