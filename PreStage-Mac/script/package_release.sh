#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PreStage"
MIN_MACOS_VERSION="15.4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DEFAULT_DMG="$DIST_DIR/$APP_NAME-Internal-macOS${MIN_MACOS_VERSION}.dmg"
DMG_PATH="$DEFAULT_DMG"
VOLUME_NAME="$APP_NAME"
MODE="adhoc"
VERIFY=false
SKIP_BUILD=false

usage() {
  cat >&2 <<USAGE
Usage: $0 [--adhoc] [--verify] [--skip-build] [--output PATH] [--volume-name NAME]

Creates an internal testing DMG from the universal PreStage app bundle.

Options:
  --adhoc            Build an ad-hoc signed internal testing DMG. This is the default.
  --verify           Verify the generated app bundle and DMG.
  --skip-build       Reuse an existing dist/PreStage.app bundle.
  --output PATH      Write the DMG to PATH. Default: $DEFAULT_DMG
  --volume-name NAME Use NAME as the mounted DMG volume name. Default: $APP_NAME
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adhoc)
      MODE="adhoc"
      shift
      ;;
    --verify)
      VERIFY=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      DMG_PATH="$2"
      shift 2
      ;;
    --volume-name)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      VOLUME_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 64
      ;;
  esac
done

if [[ "$MODE" != "adhoc" ]]; then
  echo "Only --adhoc packaging is currently supported." >&2
  exit 64
fi

cd "$PROJECT_ROOT"

if [[ "$SKIP_BUILD" != true ]]; then
  ./script/build_and_run.sh --universal
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle: $APP_BUNDLE" >&2
  echo "Run ./script/build_and_run.sh --universal first, or omit --skip-build." >&2
  exit 66
fi

mkdir -p "$DIST_DIR" "$(dirname "$DMG_PATH")"

DMG_ROOT="$DIST_DIR/dmg-root"
TMP_DMG="$DIST_DIR/$APP_NAME.tmp.dmg"

rm -rf "$DMG_ROOT"
rm -f "$TMP_DMG" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$TMP_DMG" >/dev/null

mv "$TMP_DMG" "$DMG_PATH"
rm -rf "$DMG_ROOT"

if [[ "$VERIFY" == true ]]; then
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  /usr/bin/hdiutil verify "$DMG_PATH"
  /usr/bin/lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi

echo "Created internal testing DMG at $DMG_PATH"
echo "This DMG is ad-hoc signed and not notarized. First launch on another Mac may require Control-click > Open or approval in Privacy & Security."
