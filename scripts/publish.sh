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

echo "==> Finding distribution provisioning profile..."
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
PROFILE_PATH=""
for p in "$PROFILE_DIR"/*.mobileprovision; do
  if security cms -D -i "$p" 2>/dev/null | grep -q "Store Provisioning Profile: $BUNDLE_ID"; then
    PROFILE_PATH="$p"
    break
  fi
done

if [ -z "$PROFILE_PATH" ]; then
  echo "ERROR: No App Store provisioning profile found for $BUNDLE_ID"
  echo "Run: xcodebuild -exportArchive -allowProvisioningUpdates ... once to create it"
  exit 1
fi
echo "    Using profile: $(basename "$PROFILE_PATH")"

echo "==> Creating IPA (manual packaging, bypasses Xcode 26 exportArchive bug)..."
WORK_DIR="$PROJECT_DIR/build/ipa_work"
mkdir -p "$WORK_DIR/Payload"
/bin/cp -Rf "$ARCHIVE_APP" "$WORK_DIR/Payload/Niya.app"
/bin/cp -f "$PROFILE_PATH" "$WORK_DIR/Payload/Niya.app/embedded.mobileprovision"

ENTITLEMENTS="$WORK_DIR/entitlements.plist"
cat > "$ENTITLEMENTS" <<EOF
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
</dict>
</plist>
EOF

echo "==> Re-signing with distribution certificate..."
/usr/bin/codesign --force --sign "$DIST_IDENTITY" --entitlements "$ENTITLEMENTS" --timestamp=none "$WORK_DIR/Payload/Niya.app"
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
