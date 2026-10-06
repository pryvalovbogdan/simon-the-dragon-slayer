#!/bin/bash
# Gate before any App Store / TestFlight upload. Builds the Release configuration and fails if the
# bundle is missing something Apple requires.
set -uo pipefail
cd "$(dirname "$0")/.."
FAILED=0
fail() { echo "✘ $1"; FAILED=1; }
pass() { echo "✔ $1"; }

xcodegen generate >/dev/null
xcodebuild -project SimonTheDragonSlayer.xcodeproj -scheme SimonTheDragonSlayer -configuration Release \
  -destination "generic/platform=iOS Simulator" -derivedDataPath .build/xcode-release build >/dev/null 2>&1
APP=.build/xcode-release/Build/Products/Release-iphonesimulator/SimonTheDragonSlayer.app
if [ ! -d "$APP" ]; then echo "✘ Release build failed (run xcodebuild by hand to see why)"; exit 1; fi
pass "Release configuration builds"

PLIST="$APP/Info.plist"
value() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null; }
case "$(value CFBundleIdentifier)" in
  com.example.*|"") fail "bundle id is still a placeholder: $(value CFBundleIdentifier)" ;;
  *) pass "bundle id $(value CFBundleIdentifier)" ;;
esac
[ -n "$(value CFBundleShortVersionString)" ] && pass "version $(value CFBundleShortVersionString) ($(value CFBundleVersion))" || fail "no version"
[ -n "$(value CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" ] && pass "app icon present" || fail "app icon missing"
[ -e App/Resources/PrivacyInfo.xcprivacy ] && pass "privacy manifest present" || fail "PrivacyInfo.xcprivacy missing (required: the app reads UserDefaults)"
strings "$APP/SimonTheDragonSlayer" | grep -q -- "-autoplay" && fail "debug autoplay flag is compiled into the Release binary" || pass "no debug launch flags in Release"

[ $FAILED = 0 ] && echo "Ready to archive." || echo "Not ready."
exit $FAILED
