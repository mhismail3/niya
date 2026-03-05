#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Niya"
PROJECT="$PROJECT_DIR/Niya.xcodeproj"
ARCHIVE_PATH="$PROJECT_DIR/build/Niya.xcarchive"
IPA_PATH="$PROJECT_DIR/build/Niya.ipa"
APP_ID="${NIYA_APP_ID:?Set NIYA_APP_ID environment variable}"

TEAM_ID="MYGKXH6TY4"
DIST_IDENTITY="Apple Distribution: MOHSIN H ISMAIL ($TEAM_ID)"
BUNDLE_ID="com.niya.mobile"
WIDGET_BUNDLE_ID="com.niya.mobile.widgets"

echo "==> Cleaning build directory..."
rm -rf "$PROJECT_DIR/build"

echo "==> Archiving $SCHEME..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  | tail -1

ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/Niya.app"
if [ ! -d "$ARCHIVE_APP" ]; then
  echo "ERROR: Archive app not found at $ARCHIVE_APP"
  exit 1
fi

# --- Find provisioning profiles ---
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

find_store_profile() {
  local bid="$1"
  for p in "$PROFILE_DIR"/*.mobileprovision; do
    if security cms -D -i "$p" 2>/dev/null | grep -q "Store Provisioning Profile: $bid"; then
      echo "$p"
      return
    fi
  done
}

echo "==> Finding distribution provisioning profiles..."
APP_PROFILE="$(find_store_profile "$BUNDLE_ID")"
WIDGET_PROFILE="$(find_store_profile "$WIDGET_BUNDLE_ID")"

if [ -z "$APP_PROFILE" ]; then
  echo "ERROR: No App Store provisioning profile found for $BUNDLE_ID"
  exit 1
fi
echo "    App profile: $(basename "$APP_PROFILE")"

if [ -z "$WIDGET_PROFILE" ]; then
  echo "ERROR: No App Store provisioning profile found for $WIDGET_BUNDLE_ID"
  echo "    Open the project in Xcode and archive once to generate it."
  exit 1
fi
echo "    Widget profile: $(basename "$WIDGET_PROFILE")"

echo "==> Creating IPA (manual packaging, bypasses Xcode 26 exportArchive bug)..."
WORK_DIR="$PROJECT_DIR/build/ipa_work"
mkdir -p "$WORK_DIR/Payload"
/bin/cp -Rf "$ARCHIVE_APP" "$WORK_DIR/Payload/Niya.app"

# Embed provisioning profiles
/bin/cp -f "$APP_PROFILE" "$WORK_DIR/Payload/Niya.app/embedded.mobileprovision"

APPEX_DIR="$WORK_DIR/Payload/Niya.app/PlugIns/NiyaWidgets.appex"
if [ -d "$APPEX_DIR" ]; then
  /bin/cp -f "$WIDGET_PROFILE" "$APPEX_DIR/embedded.mobileprovision"
fi

# --- Entitlements ---
APP_ENTITLEMENTS="$WORK_DIR/app_entitlements.plist"
cat > "$APP_ENTITLEMENTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>beta-reports-active</key>
    <true/>
    <key>aps-environment</key>
    <string>production</string>
    <key>get-task-allow</key>
    <false/>
    <key>keychain-access-groups</key>
    <array>
        <string>${TEAM_ID}.*</string>
        <string>com.apple.token</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.niya.mobile</string>
    </array>
</dict>
</plist>
EOF

WIDGET_ENTITLEMENTS="$WORK_DIR/widget_entitlements.plist"
cat > "$WIDGET_ENTITLEMENTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${WIDGET_BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>get-task-allow</key>
    <false/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.niya.mobile</string>
    </array>
</dict>
</plist>
EOF

# --- Re-sign (extensions first, then main app) ---
echo "==> Re-signing widget extension..."
if [ -d "$APPEX_DIR" ]; then
  /usr/bin/codesign --force --sign "$DIST_IDENTITY" --entitlements "$WIDGET_ENTITLEMENTS" --timestamp=none "$APPEX_DIR"
fi

echo "==> Re-signing main app..."
/usr/bin/codesign --force --sign "$DIST_IDENTITY" --entitlements "$APP_ENTITLEMENTS" --timestamp=none "$WORK_DIR/Payload/Niya.app"
/usr/bin/codesign -vvv "$WORK_DIR/Payload/Niya.app" 2>&1 | tail -2

echo "==> Zipping IPA..."
(cd "$WORK_DIR" && zip -qr "$IPA_PATH" Payload/)

if [ ! -f "$IPA_PATH" ]; then
  echo "ERROR: IPA not found at $IPA_PATH"
  exit 1
fi
echo "    IPA: $IPA_PATH ($(du -h "$IPA_PATH" | cut -f1))"

echo "==> Uploading to App Store Connect..."
asc builds upload --app "$APP_ID" --ipa "$IPA_PATH"

echo "==> Done! Build uploaded to TestFlight."
echo "==> Check processing status with: asc builds list --app $APP_ID --output table"
