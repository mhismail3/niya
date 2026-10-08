#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREPARE_ONLY=0
case "${1:-}" in
  --prepare-only) PREPARE_ONLY=1 ;;
  "") ;;
  *) echo "Usage: scripts/publish.sh [--prepare-only]" >&2; exit 64 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "Usage: scripts/publish.sh [--prepare-only]" >&2
  exit 64
fi
if [ "$PREPARE_ONLY" = "0" ]; then
  APP_ID="${NIYA_APP_ID:?Set NIYA_APP_ID environment variable}"
  command -v asc >/dev/null || { echo "ERROR: asc CLI is not installed" >&2; exit 1; }
fi

# Keep previous artifacts and device DerivedData; each export has its own directory.
mkdir -p "$PROJECT_DIR/build"
RUN_DIR="$(mktemp -d "$PROJECT_DIR/build/publish-XXXXXX")"
ARCHIVE_PATH="$RUN_DIR/Niya.xcarchive"
EXPORT_PATH="$RUN_DIR/export"
ARCHIVE_LOG="$RUN_DIR/archive.log"
EXPORT_LOG="$RUN_DIR/export.log"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/niya-publish-XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

echo "==> Generating Xcode project..."
"$PROJECT_DIR/scripts/generate-project"

echo "==> Archiving Niya..."
if ! xcodebuild archive \
  -project "$PROJECT_DIR/Niya.xcodeproj" \
  -scheme Niya \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic >"$ARCHIVE_LOG" 2>&1; then
  grep -E "error:|BUILD FAILED|ARCHIVE FAILED" "$ARCHIVE_LOG" | head -20 || true
  echo "ERROR: archive failed; full log: $ARCHIVE_LOG"
  exit 1
fi

# Explicitly export locally. Xcode provisions both targets and signs the package;
# no profile-name assumptions, hand-edited entitlements, or manual re-signing.
python3 - "$SCRATCH/ExportOptions.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "wb") as handle:
    plistlib.dump({
        "method": "app-store-connect",
        "destination": "export",
        "signingStyle": "automatic",
        "signingCertificate": "Apple Distribution",
        "teamID": "MYGKXH6TY4",
        "iCloudContainerEnvironment": "Production",
        "manageAppVersionAndBuildNumber": False,
    }, handle)
PY

echo "==> Exporting App Store Connect IPA locally..."
if ! xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$SCRATCH/ExportOptions.plist" \
  -allowProvisioningUpdates >"$EXPORT_LOG" 2>&1; then
  grep -E "error:|Error|EXPORT FAILED" "$EXPORT_LOG" | head -20 || true
  echo "ERROR: export failed; full log: $EXPORT_LOG"
  echo "For signing failures, sign in to team MYGKXH6TY4 in Xcode Settings > Accounts."
  exit 1
fi

IPA_PATH="$EXPORT_PATH/Niya.ipa"
[ -f "$IPA_PATH" ] || { echo "ERROR: IPA missing: $IPA_PATH"; exit 1; }

# Validate the exported product, not just the archive. Temporary unpacked files
# and decoded profiles stay outside the repository.
unzip -q "$IPA_PATH" -d "$SCRATCH/package"
APP="$SCRATCH/package/Payload/Niya.app"
WIDGET="$APP/PlugIns/NiyaWidgets.appex"
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$WIDGET"
codesign -d --entitlements :- "$APP" >"$SCRATCH/app-entitlements.plist" 2>/dev/null
security cms -D -i "$APP/embedded.mobileprovision" >"$SCRATCH/app-profile.plist"
security cms -D -i "$WIDGET/embedded.mobileprovision" >"$SCRATCH/widget-profile.plist"
python3 - "$SCRATCH" <<'PY'
import datetime, pathlib, plistlib, sys
root = pathlib.Path(sys.argv[1])
def load(name):
    return plistlib.loads((root / name).read_bytes())

def require(condition, message):
    if not condition:
        raise SystemExit("ERROR: " + message)

for filename, bundle in [("app-profile.plist", "com.niya.mobile"),
                         ("widget-profile.plist", "com.niya.mobile.widgets")]:
    profile = load(filename)
    entitlements = profile.get("Entitlements", {})
    require(profile.get("TeamIdentifier") == ["MYGKXH6TY4"], "incorrect distribution team")
    require(entitlements.get("application-identifier") == "MYGKXH6TY4." + bundle,
            "incorrect distribution bundle ID: " + bundle)
    require(not entitlements.get("get-task-allow") and "ProvisionedDevices" not in profile
            and not profile.get("ProvisionsAllDevices"), "not an App Store profile: " + bundle)
    require(profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
            > datetime.datetime.now(datetime.timezone.utc), "expired profile: " + bundle)

entitlements = load("app-entitlements.plist")
require("iCloud.com.niya.mobile" in entitlements.get("com.apple.developer.icloud-container-identifiers", []),
        "exported app lacks iCloud.com.niya.mobile")
require("CloudKit" in entitlements.get("com.apple.developer.icloud-services", []),
        "exported app lacks CloudKit")
require(entitlements.get("com.apple.developer.icloud-container-environment") == "Production",
        "exported app does not use production CloudKit")
require(not entitlements.get("get-task-allow"), "exported app permits debugging")
print("Verified App Store profiles for app/widget and production CloudKit entitlements.")
PY

# Preserve the conventional path for callers, while retaining this run's output.
/bin/cp -f "$IPA_PATH" "$PROJECT_DIR/build/Niya.ipa"
echo "Archive: $ARCHIVE_PATH"
echo "IPA: $IPA_PATH"
echo "Logs: $ARCHIVE_LOG and $EXPORT_LOG"
if [ "$PREPARE_ONLY" = "1" ]; then
  echo "==> Prepared locally (not uploaded)."
  exit 0
fi

echo "==> Uploading to App Store Connect..."
asc builds upload --app "$APP_ID" --ipa "$IPA_PATH"
echo "==> Done! Build uploaded to TestFlight."
echo "==> Check processing status with: asc builds list --app $APP_ID --output table"
