# Test And Acceptance Plan / 测试与验收计划

Language: English | [简体中文](TEST_AND_ACCEPTANCE_PLAN.zh-CN.md)

Last updated: 2026-05-26

## Build Verification

- Clean build succeeds.
- Unit tests pass.
- App launches from development command.
- App launches after packaging.

## Required Sample Folders

Create or collect:

- JPEG-only folder.
- RAW-only folder.
- RAW+JPEG same-basename folder.
- DNG vertical images.
- Panoramic `12000x6000` or similar images.
- Non-standard aspect ratio images.
- Folder with generated proxies.
- Folder with missing/stale proxies.
- Lightroom XMP samples.
- Capture One XMP samples.
- Large folder: 200+ RAW.
- Larger folder: 500-1000 RAW if possible.

## Geometry Acceptance

For every sample:

- Main preview image boundary matches actual visible image.
- Crop mask fully covers outside crop area.
- No 1px bright sliver on right, left, top, or bottom.
- Guide lines do not extend beyond image unless intentionally attached to crop rect.
- Filmstrip frame fits actual thumbnail content.
- Panoramic images do not get oversized frames.
- Vertical RAW does not inherit landscape metadata frame.
- DPI scaling at 100%, 125%, 150%, 200% does not reintroduce gaps.

## Performance Acceptance

Measure:

- Initial scan time.
- Time to first thumbnails.
- Time to first gallery preview.
- Direction-key navigation latency.
- Memory after scanning 200/500/1000 RAW.
- Proxy generation throughput.
- Copy throughput.
- Hash verification cost.

Targets should be refined after first Windows prototype.

## Metadata/XMP Acceptance

- Read rating.
- Read Pick/Reject.
- Read color label.
- Write rating.
- Write Pick/Reject.
- Write color label.
- Preserve unknown XML.
- Do not corrupt malformed sidecars.
- Lightroom round-trip.
- Capture One round-trip.

## Copy Acceptance

- Copy selected JPEG.
- Copy selected RAW.
- Copy RAW+JPEG pair.
- Copy RAW only.
- Date folder rule.
- Preserve structure rule.
- Camera folder rule.
- Rating folder rule.
- Auto rename conflict.
- Skip conflict.
- Overwrite conflict.
- Pause between files.
- Resume after pause.
- Cancel without corrupting completed files.
- Count/size verification.
- SHA-256 verification.

## UI Acceptance

- Left sidebar remains usable at minimum width.
- Source and target folder branch behavior is clear.
- Filters are discoverable and resettable.
- Toolbar copy and copy settings are near each other.
- Gallery filmstrip can be collapsed.
- Inspector scrolls when metadata is long.
- Light and dark modes are readable.
- Keyboard shortcuts work regardless of focus where appropriate.

## Release Acceptance

- Installer installs app.
- App launches without development environment.
- Settings persist.
- Cache folders are in the correct Windows user data location.
- App can be uninstalled cleanly.
