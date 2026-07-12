#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS with Xcode installed."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

flutter pub get
flutter build ios --release --no-codesign

echo ""
echo "iPadOS build prepared."
echo "Next step:"
echo "  open ios/Runner.xcworkspace"
echo ""
echo "Then use Xcode to sign and run/archive the app."
