# Release And Distribution / 发布与分发

Last updated: 2026-05-26

This document replaces `docs/distribution.md`.

## Current macOS Internal Build / 当前 macOS 内测构建

PreStage currently supports internal ad-hoc DMG packaging:

```bash
./script/package_release.sh --adhoc --verify
```

Output:

```text
dist/PreStage-Internal-macOS15.4.dmg
```

The app bundle can be built as universal for Apple Silicon and Intel Macs:

```bash
./script/build_and_run.sh --universal
lipo -info dist/PreStage.app/Contents/MacOS/PreStage
```

Expected architectures include `x86_64` and `arm64`.

## Recipient Install Steps / 收件人安装步骤

1. Open the DMG.
2. Drag `PreStage.app` to Applications.
3. First launch: Control-click or right-click the app and choose Open.
4. If blocked, use System Settings > Privacy & Security to allow this app.

内测包为 ad-hoc 签名，未公证。不要要求测试者全局关闭 Gatekeeper。

## Verification / 验证

```bash
hdiutil verify dist/PreStage-Internal-macOS15.4.dmg
lipo -info dist/PreStage.app/Contents/MacOS/PreStage
codesign --verify --deep --strict --verbose=2 dist/PreStage.app
```

## Future Developer ID Release / 后续 Developer ID 发布

Required for smoother public distribution outside the Mac App Store:

- Apple Developer Program membership.
- Developer ID Application certificate.
- Hardened Runtime.
- Notarization with `xcrun notarytool`.
- Stapling with `xcrun stapler`.
- Gatekeeper validation with `spctl`.

Future script target:

```bash
./script/package_release.sh --developer-id --verify
```

## Windows Distribution Placeholder / Windows 分发占位

Windows packaging is not implemented in this repository. The Windows port should define its own installer strategy, likely MSIX or NSIS/Inno Setup depending on the chosen UI/runtime stack. See `WindowsPort/`.
