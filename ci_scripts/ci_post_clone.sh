#!/bin/bash
set -euo pipefail

# Xcode Cloud executes this from the repository root.
cd "$CI_WORKSPACE/workout"
bash scripts/generate_secrets_xcconfig.sh
