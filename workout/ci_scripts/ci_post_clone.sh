#!/bin/bash
set -euo pipefail

# Resolve paths from this script location to avoid CI_WORKSPACE differences.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
bash scripts/generate_secrets_xcconfig.sh
bash scripts/generate_google_service_info.sh

# Fail fast if generation did not produce the expected files.
test -f workout/Config/Secrets.xcconfig
test -f workout/GoogleService-Info.plist
