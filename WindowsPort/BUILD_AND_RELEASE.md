# PreStage Windows Build & Release

## Dev Commands

```powershell
# Build
dotnet build PreStage.App\PreStage.App.csproj

# Test (43 tests)
dotnet test PreStage.Tests\PreStage.Tests.csproj

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
# x64 self-contained single file
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish

# x64 framework-dependent (smaller, requires .NET 10 runtime)
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x64 -p:PublishSingleFile=true -o publish

# x86 self-contained
dotnet publish PreStage.App\PreStage.App.csproj -c Release -r win-x86 --self-contained -p:PublishSingleFile=true -o publish
```

Output: `publish/PreStage.App.exe` (~158MB self-contained)

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
