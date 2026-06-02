#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PreStage"
BUNDLE_ID="local.codex.PreStage"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
MIN_MACOS_VERSION="15.4"
MODE="debug"
VERIFY=false

export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"

for arg in "$@"; do
  case "$arg" in
    --verify)
      VERIFY=true
      ;;
    --universal|--release-universal)
      MODE="universal"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--verify] [--universal|--release-universal]" >&2
      exit 64
      ;;
  esac
done

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

write_info_plist() {
  cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleAllowMixedLocalizations</key>
  <true/>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

prepare_bundle() {
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
}

copy_resources() {
  local resource_bundle="$1"
  if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$APP_BUNDLE/Contents/Resources/"
  fi
}

copy_main_localizations() {
  local resources_dir="Sources/$APP_NAME/Resources"
  for language in en zh-Hans; do
    local source_dir="$resources_dir/$language.lproj"
    local target_dir="$APP_BUNDLE/Contents/Resources/$language.lproj"
    if [[ -f "$source_dir/InfoPlist.strings" ]]; then
      mkdir -p "$target_dir"
      cp "$source_dir/InfoPlist.strings" "$target_dir/InfoPlist.strings"
    fi
  done
}

adhoc_sign() {
  if command -v codesign >/dev/null 2>&1; then
    /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
  fi
}

launch_and_verify() {
  /usr/bin/open -n "$APP_BUNDLE"
  if [[ "$VERIFY" == true ]]; then
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched"
  fi
}

build_debug_bundle() {
  local executable=".build/debug/$APP_NAME"
  local resource_bundle=".build/debug/${APP_NAME}_${APP_NAME}.bundle"

  swift build
  prepare_bundle
  cp "$executable" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  copy_resources "$resource_bundle"
  copy_main_localizations
  write_info_plist
  launch_and_verify
}

build_universal_bundle() {
  local arm_triple="arm64-apple-macosx${MIN_MACOS_VERSION}"
  local x86_triple="x86_64-apple-macosx${MIN_MACOS_VERSION}"
  local arm_bin_path
  local x86_bin_path
  arm_bin_path="$(swift build -c release --triple "$arm_triple" --show-bin-path)"
  x86_bin_path="$(swift build -c release --triple "$x86_triple" --show-bin-path)"

  swift build -c release --triple "$arm_triple"
  swift build -c release --triple "$x86_triple"

  prepare_bundle
  lipo -create \
    "$arm_bin_path/$APP_NAME" \
    "$x86_bin_path/$APP_NAME" \
    -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  copy_resources "$arm_bin_path/${APP_NAME}_${APP_NAME}.bundle"
  copy_main_localizations
  write_info_plist
  adhoc_sign

  lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  echo "Created universal app at $APP_BUNDLE"

  if [[ "$VERIFY" == true ]]; then
    launch_and_verify
  fi
}

if [[ "$MODE" == "universal" ]]; then
  build_universal_bundle
else
  build_debug_bundle
fi
