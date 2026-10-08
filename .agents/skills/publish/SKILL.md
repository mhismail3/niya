---
name: publish
description: Build, upload, and manage Niya on TestFlight and App Store Connect using the asc CLI
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Grep, Glob
argument-hint: [build|status|testers|bump|submit]
---

# /publish — TestFlight Lifecycle Management

Manage the full TestFlight lifecycle for Niya: build, upload, version management, tester distribution, and submission.

## Project Constants

- **Bundle ID**: `com.niya.mobile`
- **Team ID**: `MYGKXH6TY4`
- **Scheme**: `Niya`
- **Project**: `Niya.xcodeproj`
- **Build output**: `build/` (gitignored)
- **Project spec**: `project.yml` (the `.xcodeproj` is generated)

## Getting the App ID

The numeric App Store Connect app ID is required for most `asc` commands. Retrieve it with:

```bash
asc apps list --output json | jq -r '.[] | select(.bundleId == "com.niya.mobile") | .id'
```

Store in `NIYA_APP_ID` env var for the session.

## Subcommands

### `/publish build` — Archive, Export, Upload

To prepare a distribution archive and IPA locally **without uploading**, run
`bash scripts/publish.sh --prepare-only`. This does not require `NIYA_APP_ID`
or the `asc` CLI, but still requires distribution signing and App Store
provisioning profiles. Never install this Release build on a device.

1. Get the app ID (see above) and export as `NIYA_APP_ID`
2. Run the publish script:
   ```bash
   NIYA_APP_ID=<id> bash scripts/publish.sh
   ```
3. The script will:
   - Clean the `build/` directory
   - Archive the Niya scheme for iOS (Release config)
   - Package the IPA manually to `build/Niya.ipa` (bypasses an Xcode 26 `exportArchive` bug)
   - Upload the IPA via `asc builds upload`
   - List recent builds to confirm

**If archiving fails** with a signing error:
- Verify the team ID and automatic signing in Xcode
- Ensure the Apple Developer account has a valid iOS Distribution certificate
- Try opening the project in Xcode first to let it resolve signing

**If upload fails**:
- Check `asc auth login` is configured (see Phase 2 in the plan)
- Verify the IPA exists at `build/Niya.ipa`
- Try `asc builds upload` manually with `--verbose`

### `/publish status` — Check Build Processing

```bash
APP_ID=$(asc apps list --output json | jq -r '.[] | select(.bundleId == "com.niya.mobile") | .id')
asc testflight builds list --app "$APP_ID" --limit 5 --output table
```

Build states: `PROCESSING` → `VALID` (ready) or `INVALID` (error).

### `/publish testers` — Manage Beta Groups & Testers

**List existing groups:**
```bash
asc testflight groups list --app "$APP_ID" --output table
```

**Create a beta group:**
```bash
asc testflight groups create --app "$APP_ID" --name "Beta Testers"
```

**Add a tester by email:**
```bash
asc testflight testers add --app "$APP_ID" --email "user@example.com" --first-name "First" --last-name "Last" --group "Beta Testers"
```

**List testers:**
```bash
asc testflight testers list --app "$APP_ID" --output table
```

Ask the user for tester email addresses if not provided.

### `/publish bump` — Increment Version Numbers

Versions live only in `project.yml` (`settings.base`), inherited by every target:

```bash
grep -E 'CURRENT_PROJECT_VERSION|MARKETING_VERSION' project.yml
```

- **Build number** (before each upload): increment `CURRENT_PROJECT_VERSION`.
- **Marketing version** (e.g. 1.0 → 1.1): ask the user, then set `MARKETING_VERSION`.

`scripts/publish.sh` regenerates the project, so no other file needs editing.

### `/publish submit` — Submit for External Testing or App Store Review

**Submit a build for external beta review:**
```bash
asc testflight submissions create --app "$APP_ID" --build "<build_number>"
```

The first external TestFlight build triggers an automatic Apple review (~24-48 hours). Subsequent builds to the same beta group typically don't require re-review.

**For App Store submission** (when ready):
```bash
asc appstore submissions create --app "$APP_ID"
```

## First-Time Setup Checklist

Before `/publish build` will work, ensure:

1. `asc` is installed: `brew install asc`
2. API key is configured: `asc auth login --name "Niya" --key-id <KEY_ID> --issuer-id <ISSUER_ID> --private-key ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
3. App is registered in App Store Connect with bundle ID `com.niya.mobile`
4. Privacy policy URL is set in App Store Connect (required for external testers)
5. Verify with: `asc apps list --output table`
