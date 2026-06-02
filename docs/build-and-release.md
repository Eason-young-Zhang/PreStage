# Build and Release Guide

This guide covers the Windows WPF port. The macOS reference implementation has its own scripts under `PreStage-Mac/script`.

## Prerequisites

- Windows 10/11.
- .NET SDK 10.0 or newer.
- Git.

Optional:

- Visual Studio 2026 or later with .NET desktop development workloads.
- Microsoft Raw Image Extension for broader RAW preview support through Windows codecs.

## Restore, Test, Build

From the repository root:

```powershell
dotnet restore .\PreStage.slnx
dotnet test .\PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false
dotnet build .\PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false
```

The current Windows test suite should report 54 passing tests.

## Run Locally

```powershell
dotnet run --project .\PreStage.App\PreStage.App.csproj
```

Local app data is stored under:

```text
%LocalAppData%\PreStage\
```

Delete that folder to reset workspace presets and local state.

## Publish

Self-contained x64 build:

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:Version=0.1.0 `
  -p:AssemblyVersion=0.1.0.0 `
  -p:FileVersion=0.1.0.0 `
  -o .\releases\PreStage-Win-V0.1.0
```

Framework-dependent x64 build:

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x64 `
  --self-contained false `
  -o .\releases\PreStage-Win-framework-dependent
```

x86 build:

```powershell
dotnet publish .\PreStage.App\PreStage.App.csproj `
  -c Release `
  -r win-x86 `
  --self-contained true `
  -o .\releases\PreStage-Win-x86
```

`releases/` is ignored by git and should not be committed.

## Release Smoke Checklist

- [ ] Published app launches without an immediate crash.
- [ ] Source folder selection works with paths containing spaces and non-ASCII characters.
- [ ] Grid, list, and gallery modes render.
- [ ] Gallery preview, filmstrip, histogram, waveform, crop mask, and guides work.
- [ ] Rating, pick/reject, and color labels write XMP sidecars.
- [ ] Reopening the app reloads workspace settings.
- [ ] Copy workflow handles existing files according to selected conflict policy.
- [ ] XMP sidecars are copied or auto-renamed together with media files.
- [ ] Empty folders, inaccessible folders, and damaged files fail gracefully.

## Common Build Notes

- `System.Drawing.Common` currently produces a package warning. It is used by the current preview/analysis path and can be revisited when that path is replaced by WIC or another imaging backend.
- If MSBuild reports access denied under `obj/`, check workspace ACLs and stop stale `dotnet`, `MSBuild`, or `VBCSCompiler` processes.
- Use `-m:1 -nr:false` when diagnosing file-lock issues.
