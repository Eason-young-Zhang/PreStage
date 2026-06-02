# PreStage Windows Build & Release

## Dev Commands

```powershell
# Restore
dotnet restore PreStage.slnx

# Test (currently 54 tests)
dotnet test PreStage.Tests\PreStage.Tests.csproj -v minimal -m:1 -nr:false

# Build
dotnet build PreStage.App\PreStage.App.csproj -v minimal -m:1 -nr:false

# Run (development)
dotnet run --project PreStage.App\PreStage.App.csproj
```

## Debug Run

```powershell
# Debug run (with hot reload in IDE)
dotnet run --project PreStage.App\PreStage.App.csproj

# Debug run with specific culture
dotnet run --project PreStage.App\PreStage.App.csproj -- --lang zh
```

## Release Publish

```powershell
# x64 self-contained
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained true -o releases\PreStage-Win

# x64 framework-dependent (smaller, requires .NET 10 runtime)
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained false -o releases\PreStage-Win-framework-dependent

# x86 self-contained
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x86 --self-contained true -o releases\PreStage-Win-x86
```

Output: `releases/<build-name>/PreStage.App.exe`. The `releases/` folder is ignored by git.

## Release Verification Checklist

1. [ ] App launches without errors from published exe
2. [ ] Source folder selection opens folder browser and loads items
3. [ ] Grid view, list view, and gallery view all render correctly
4. [ ] Gallery preview displays selected image without distortion
5. [ ] Crop mask overlays align precisely with image bounds (no 1px gaps)
6. [ ] Rating, Pick state, and Color Label values persist correctly via XMP sidecar
7. [ ] XMP persistence survives round-trip: write metadata, close app, reopen, verify values retained
8. [ ] Copy workflow completes with file verification (size or SHA-256)
9. [ ] Settings persist across app restarts (workspace.json in %LocalAppData%)
10. [ ] App restart restores previous layout, source folder, and view mode
11. [ ] Clean uninstall: delete publish folder and %LocalAppData%\PreStage\ leaves no residual files

## Notes

- The macOS version under `PreStage-Mac` is the product behavior reference.
- Do not commit `bin/`, `obj/`, `releases/`, `publish/`, or comparison worktrees.
- Camera-card eject currently uses a safe manual fallback. Do not replace it with shell commands that interpolate user-controlled paths.
- See `../docs/build-and-release.md` for the current maintainer guide.
