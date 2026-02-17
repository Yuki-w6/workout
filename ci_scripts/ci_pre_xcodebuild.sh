#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/workout"

cd "$PROJECT_ROOT"

# Ensure Secrets.xcconfig exists before xcodebuild.
if [ ! -f "workout/Config/Secrets.xcconfig" ]; then
  bash scripts/generate_secrets_xcconfig.sh
fi

test -f workout/Config/Secrets.xcconfig
