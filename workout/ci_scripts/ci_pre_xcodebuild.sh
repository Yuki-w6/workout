#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure Secrets.xcconfig exists before xcodebuild.
if [ ! -f "workout/Config/Secrets.xcconfig" ]; then
  bash scripts/generate_secrets_xcconfig.sh
fi

test -f workout/Config/Secrets.xcconfig
