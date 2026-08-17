#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure Secrets.xcconfig and GoogleService-Info.plist exist before xcodebuild.
if [ ! -f "workout/Config/Secrets.xcconfig" ]; then
  bash scripts/generate_secrets_xcconfig.sh
fi
if [ ! -f "workout/GoogleService-Info.plist" ]; then
  bash scripts/generate_google_service_info.sh
fi

test -f workout/Config/Secrets.xcconfig
test -f workout/GoogleService-Info.plist
