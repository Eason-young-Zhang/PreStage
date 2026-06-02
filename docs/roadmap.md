# Roadmap and Known Gaps

Language: English | [简体中文](roadmap.zh-CN.md)

This document tracks the Windows port against the macOS reference implementation.

## Near-Term Priorities

### P0: Core Workflow Reliability

- Keep XMP sidecar read/write compatible with common photo tools.
- Preserve sidecars during copy, rename, overwrite, and auto-rename flows.
- Improve preview failure reporting for RAW/video/damaged files.
- Keep large-folder scanning responsive.
- Add tests before changing copy, XMP, metadata, or pairing behavior.

### P1: Cross-Platform UI Parity

- Continue aligning Windows toolbar, sidebar, gallery, inspector, and status feedback with macOS.
- Improve keyboard shortcut parity.
- Persist and restore more layout state, including floating panel positions.
- Add clearer empty/loading/error states for source folders and previews.

### P1: Camera Card Workflow

- Keep DCIM detection and auto-select behavior.
- Implement safe eject through a Windows device API, or keep the current manual fallback.
- Add tests around removable-drive detection logic using injectable drive abstractions.

### P2: Preview and Media Compatibility

- Replace or supplement `System.Drawing` preview paths with a more reliable imaging backend.
- Improve RAW compatibility through WIC, Microsoft Raw Image Extension, LibRaw, or generated proxies.
- Add video preview/proxy handling.
- Add clearer UI labels when a preview is proxy-based or unavailable.

### P2: Packaging

- Add a repeatable release script.
- Add GitHub Actions for Windows build/test.
- Consider installer packaging after the workflow stabilizes.

## Known Current Limitations

- Windows safe eject is not implemented. The UI shows a safe fallback message instead of executing shell commands.
- RAW preview support depends on codecs and proxies; not all RAW formats are guaranteed to render.
- Large directory tree browsing is intentionally shallow to avoid UI freezes.
- Floating histogram/waveform panel positions are not fully persisted yet.
- The Windows UI is close to the macOS workflow but not pixel-identical.
- `System.Drawing.Common` currently emits a package warning and should be revisited.

## What Not to Do

- Do not replace the Windows codebase with the macOS source or another Windows worktree wholesale.
- Do not commit build outputs, release zips, or nested comparison worktrees.
- Do not implement drive eject by interpolating user-controlled paths into PowerShell.
- Do not silently drop sidecar handling when changing copy or rename behavior.
