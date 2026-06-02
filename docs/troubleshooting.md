# Troubleshooting

## MSBuild Access Denied Under `obj/`

Symptoms:

- `MSB3491`
- `Access to the path is denied`
- Failures writing `*.FileListAbsolute.txt`, assembly reference caches, or temporary MSBuild files.

Try:

```powershell
Get-Process dotnet,MSBuild,VBCSCompiler -ErrorAction SilentlyContinue | Stop-Process -Force
dotnet build-server shutdown
```

Then remove generated outputs:

```powershell
Remove-Item .\PreStage.App\bin,.\PreStage.App\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.Core\bin,.\PreStage.Core\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.ViewModels\bin,.\PreStage.ViewModels\obj -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\PreStage.Tests\bin,.\PreStage.Tests\obj -Recurse -Force -ErrorAction SilentlyContinue
```

If the workspace was copied from another machine, check ACLs:

```powershell
icacls .
```

The current user should have write access. If the ACL contains unknown SIDs and MSBuild cannot write, grant the current user full control on the workspace with care:

```powershell
$root = (Resolve-Path .).Path
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls $root /grant "$user`:(OI)(CI)F" /T /C
```

## `gh` Is Missing

GitHub CLI is useful but not required for ordinary `git push`.

Install `gh` if you need pull-request creation from the command line:

```powershell
winget install GitHub.cli
gh auth login
```

## RAW Files Do Not Preview

The current Windows preview path is not a complete RAW decoder.

Options:

- Install Microsoft Raw Image Extension.
- Generate JPEG proxies.
- Place newer proxies under a sibling `Proxies` folder with matching filenames.

Example:

```text
Source/
  IMG_0001.CR3
  Proxies/
    IMG_0001.jpg
```

If `Proxies/IMG_0001.jpg` is newer than `IMG_0001.CR3`, PreStage uses the proxy for preview.

## XMP Review State Does Not Appear

Check that the sidecar is next to the media file and uses the same base filename:

```text
IMG_0001.CR3
IMG_0001.xmp
```

PreStage writes:

- `xap:Rating`
- `xap:Label`
- `photoshop:Urgency`
- `prestage:PickState`

Lightroom rejected files may use `Rating=-1`; PreStage normalizes that as rejected with rating `0`.

## Copy Results Look Unexpected

Copy behavior depends on:

- Organization rule: capture date, preserve structure, camera model, rating.
- Conflict policy: auto rename, skip, overwrite.
- Content mode: all supported or RAW only.
- Verification: size or SHA-256.

Sidecars are treated as part of the copied asset. If a destination sidecar exists, it participates in conflict detection.

## Workspace State Seems Stale

Delete local workspace data:

```powershell
Remove-Item "$env:LOCALAPPDATA\PreStage" -Recurse -Force
```

Then restart the app.

## Unicode or Space-Containing Paths

The project is expected to support paths with spaces and non-ASCII characters. If a failure appears path-related, capture:

- Full source path.
- Full target path.
- File extension.
- Whether the file is local, removable, network, or cloud-backed.
- Whether Windows reports permission or lock errors.
