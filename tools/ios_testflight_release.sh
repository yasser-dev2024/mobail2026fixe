#!/usr/bin/env bash
set -Eeuo pipefail

readonly expected_bundle_id="com.proshop.mobileShopPro"
readonly runner_temp="${RUNNER_TEMP:-/tmp}"

work_dir=""
keychain_path=""
installed_profile=""

cleanup() {
  set +e

  if [[ -n "$keychain_path" && -f "$keychain_path" ]]; then
    security default-keychain -d user -s "$HOME/Library/Keychains/login.keychain-db"
    security list-keychains -d user -s "$HOME/Library/Keychains/login.keychain-db"
    security delete-keychain "$keychain_path"
  fi

  if [[ -n "$installed_profile" && -f "$installed_profile" ]]; then
    rm -f -- "$installed_profile"
  fi

  if [[ -n "$work_dir" && "$work_dir" == "$runner_temp"/maintenance-assistant-testflight.* ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT

require_secret() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required protected value: %s\n' "$name" >&2
    return 1
  fi
}

decode_base64_secret() {
  local value="$1"
  local destination="$2"

  printf '%s' "$value" |
    tr -d '[:space:]' |
    openssl base64 -d -A -out "$destination"
  test -s "$destination"
}

for secret_name in \
  APPLE_TEAM_ID \
  APP_STORE_CONNECT_KEY_ID \
  APP_STORE_CONNECT_ISSUER_ID \
  APP_STORE_CONNECT_PRIVATE_KEY_BASE64 \
  IOS_DISTRIBUTION_CERTIFICATE_BASE64 \
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD \
  IOS_PROVISIONING_PROFILE_BASE64; do
  require_secret "$secret_name"
done

if [[ "${IOS_BUNDLE_ID:-$expected_bundle_id}" != "$expected_bundle_id" ]]; then
  printf 'Unexpected bundle identifier. Expected %s.\n' "$expected_bundle_id" >&2
  exit 1
fi

if [[ ! "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  printf 'APPLE_TEAM_ID must contain exactly 10 uppercase letters or digits.\n' >&2
  exit 1
fi

if [[ ! "$APP_STORE_CONNECT_KEY_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  printf 'APP_STORE_CONNECT_KEY_ID has an invalid format.\n' >&2
  exit 1
fi

if [[ ! "$APP_STORE_CONNECT_ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  printf 'APP_STORE_CONNECT_ISSUER_ID has an invalid format.\n' >&2
  exit 1
fi

if [[ ! "${BUILD_NUMBER:-}" =~ ^[1-9][0-9]*$ ]]; then
  printf 'BUILD_NUMBER must be a positive integer.\n' >&2
  exit 1
fi

umask 077
work_dir="$(mktemp -d "$runner_temp/maintenance-assistant-testflight.XXXXXX")"
keychain_path="$work_dir/signing.keychain-db"
certificate_path="$work_dir/distribution.p12"
profile_path="$work_dir/distribution.mobileprovision"
profile_plist="$work_dir/profile.plist"
export_options="$work_dir/ExportOptions.plist"
private_keys_dir="$work_dir/private_keys"
inspection_dir="$work_dir/inspection"
keychain_password="$(openssl rand -hex 24)"

decode_base64_secret \
  "$IOS_DISTRIBUTION_CERTIFICATE_BASE64" \
  "$certificate_path"
decode_base64_secret \
  "$IOS_PROVISIONING_PROFILE_BASE64" \
  "$profile_path"

mkdir -p "$private_keys_dir"
api_key_path="$private_keys_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
decode_base64_secret \
  "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" \
  "$api_key_path"

if ! grep -Eq '^-----BEGIN (EC )?PRIVATE KEY-----$' "$api_key_path"; then
  printf 'The App Store Connect API key is not a valid private-key file.\n' >&2
  exit 1
fi

security cms -D -i "$profile_path" >"$profile_plist"
plutil -lint "$profile_plist"

profile_uuid="$(
  /usr/libexec/PlistBuddy -c 'Print :UUID' "$profile_plist"
)"
profile_team="$(
  /usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist"
)"
profile_app_identifier="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :Entitlements:application-identifier' \
    "$profile_plist"
)"
profile_expiration="$(
  /usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$profile_plist"
)"
profile_get_task_allow="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :Entitlements:get-task-allow' \
    "$profile_plist" 2>/dev/null || true
)"
profile_beta_reports="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :Entitlements:beta-reports-active' \
    "$profile_plist" 2>/dev/null || true
)"

if [[ ! "$profile_uuid" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
  printf 'The provisioning profile UUID is invalid.\n' >&2
  exit 1
fi

if [[ "$profile_team" != "$APPLE_TEAM_ID" ]]; then
  printf 'The provisioning profile belongs to a different Apple team.\n' >&2
  exit 1
fi

if [[ "$profile_app_identifier" != "$APPLE_TEAM_ID.$expected_bundle_id" ]]; then
  printf 'The provisioning profile does not match the app bundle identifier.\n' >&2
  exit 1
fi

profile_get_task_allow_normalized="$(
  printf '%s' "$profile_get_task_allow" | tr '[:upper:]' '[:lower:]'
)"
if [[ "$profile_get_task_allow_normalized" != "false" ]]; then
  printf 'A development provisioning profile cannot be uploaded to TestFlight.\n' >&2
  exit 1
fi

profile_beta_reports_normalized="$(
  printf '%s' "$profile_beta_reports" | tr '[:upper:]' '[:lower:]'
)"
if [[ "$profile_beta_reports_normalized" != "true" ]]; then
  printf 'The profile is not an App Store Connect distribution profile.\n' >&2
  exit 1
fi

ruby -rtime -e \
  'exit(Time.parse(ARGV.fetch(0)) > Time.now ? 0 : 1)' \
  "$profile_expiration" || {
  printf 'The provisioning profile has expired.\n' >&2
  exit 1
}

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" \
  -k "$keychain_path" \
  -P "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$keychain_password" \
  "$keychain_path"
security list-keychains \
  -d user \
  -s \
  "$keychain_path" \
  "$HOME/Library/Keychains/login.keychain-db"
security default-keychain -d user -s "$keychain_path"

valid_identities="$(
  security find-identity -v -p codesigning "$keychain_path" |
    awk '/valid identities found/ { print $1 }'
)"
if [[ ! "$valid_identities" =~ ^[1-9][0-9]*$ ]]; then
  printf 'No valid Apple Distribution signing identity was imported.\n' >&2
  exit 1
fi

profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profiles_dir"
installed_profile="$profiles_dir/$profile_uuid.mobileprovision"
cp "$profile_path" "$installed_profile"

cat >>ios/Flutter/Release.xcconfig <<EOF

// Ephemeral TestFlight signing values injected by CI.
DEVELOPMENT_TEAM = $APPLE_TEAM_ID
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = $profile_uuid
EOF

cat >"$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$expected_bundle_id</key>
    <string>$profile_uuid</string>
  </dict>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>$APPLE_TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
plutil -lint "$export_options"

flutter config --no-analytics
flutter pub get
flutter build ipa \
  --release \
  --build-number="$BUILD_NUMBER" \
  --export-options-plist="$export_options"

ipa_path=""
for candidate in build/ios/ipa/*.ipa; do
  if [[ -f "$candidate" ]]; then
    ipa_path="$candidate"
    break
  fi
done
if [[ -z "$ipa_path" || ! -s "$ipa_path" ]]; then
  printf 'Flutter did not produce an IPA file.\n' >&2
  exit 1
fi

mkdir -p "$inspection_dir"
ditto -x -k "$ipa_path" "$inspection_dir"
app_path=""
for candidate in "$inspection_dir"/Payload/*.app; do
  if [[ -d "$candidate" ]]; then
    app_path="$candidate"
    break
  fi
done
if [[ -z "$app_path" ]]; then
  printf 'The IPA does not contain an iOS application bundle.\n' >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app_path"
codesign -d --entitlements :- "$app_path" >"$work_dir/entitlements.plist"
plutil -lint "$work_dir/entitlements.plist"

built_bundle_id="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist"
)"
built_version="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$app_path/Info.plist"
)"
built_number="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Info.plist"
)"
built_get_task_allow="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :get-task-allow' \
    "$work_dir/entitlements.plist" 2>/dev/null || true
)"

if [[ "$built_bundle_id" != "$expected_bundle_id" ]]; then
  printf 'The signed IPA has an unexpected bundle identifier.\n' >&2
  exit 1
fi

if [[ "$built_number" != "$BUILD_NUMBER" ]]; then
  printf 'The signed IPA has an unexpected build number.\n' >&2
  exit 1
fi

built_get_task_allow_normalized="$(
  printf '%s' "$built_get_task_allow" | tr '[:upper:]' '[:lower:]'
)"
if [[ "$built_get_task_allow_normalized" == "true" ]]; then
  printf 'The signed IPA unexpectedly permits debugger attachment.\n' >&2
  exit 1
fi

if /usr/libexec/PlistBuddy \
  -c 'Print :NSAppTransportSecurity:NSAllowsArbitraryLoads' \
  "$app_path/Info.plist" >/dev/null 2>&1; then
  printf 'The signed IPA allows unrestricted insecure network transport.\n' >&2
  exit 1
fi

if find "$inspection_dir" -type f \
  \( -name '*.p12' -o -name '*.p8' -o -name '*.mobileconfig' \) |
  grep -q .; then
  printf 'The IPA contains a forbidden certificate, key, or configuration profile.\n' >&2
  exit 1
fi

ipa_sha256="$(shasum -a 256 "$ipa_path" | awk '{print $1}')"

API_PRIVATE_KEYS_DIR="$private_keys_dir" \
  xcrun altool \
  --validate-app \
  --type ios \
  --file "$ipa_path" \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --output-format json

API_PRIVATE_KEYS_DIR="$private_keys_dir" \
  xcrun altool \
  --upload-app \
  --type ios \
  --file "$ipa_path" \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --output-format json

{
  printf '## TestFlight upload\n\n'
  printf -- '- Bundle: `%s`\n' "$built_bundle_id"
  printf -- '- Version: `%s (%s)`\n' "$built_version" "$built_number"
  printf -- '- IPA SHA-256: `%s`\n' "$ipa_sha256"
  printf -- '- Signing, provisioning, entitlements, and transport checks: passed\n'
  printf -- '- Upload to App Store Connect: completed\n'
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
