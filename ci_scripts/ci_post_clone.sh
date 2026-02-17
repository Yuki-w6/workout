#!/bin/bash
set -euo pipefail

# Resolve paths from this script location to avoid CI_WORKSPACE differences.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/workout"

cd "$PROJECT_ROOT"
bash scripts/generate_secrets_xcconfig.sh

# Fail fast if generation did not produce the expected file.
test -f workout/Config/Secrets.xcconfig
