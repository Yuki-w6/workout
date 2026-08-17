#!/usr/bin/env bash
set -euo pipefail

output_path="workout/GoogleService-Info.plist"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "error: required env var is missing: GOOGLE_SERVICE_INFO_PLIST_BASE64" >&2
  exit 1
fi

echo "${GOOGLE_SERVICE_INFO_PLIST_BASE64}" | base64 --decode > "$output_path"

echo "Generated ${output_path}"
