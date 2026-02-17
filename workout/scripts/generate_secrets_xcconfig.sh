#!/usr/bin/env bash
set -euo pipefail

output_path="workout/Config/Secrets.xcconfig"
required_vars=(
  "BANNER_AD_UNIT_ID"
  "RECORD_LIST_BANNER_AD_UNIT_ID"
  "GRAPH_BANNER_AD_UNIT_ID"
)

missing=()
for key in "${required_vars[@]}"; do
  if [ -z "${!key:-}" ]; then
    missing+=("$key")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "error: required env vars are missing: ${missing[*]}" >&2
  exit 1
fi

cat > "$output_path" <<EOC
BANNER_AD_UNIT_ID = ${BANNER_AD_UNIT_ID}
RECORD_LIST_BANNER_AD_UNIT_ID = ${RECORD_LIST_BANNER_AD_UNIT_ID}
GRAPH_BANNER_AD_UNIT_ID = ${GRAPH_BANNER_AD_UNIT_ID}
EOC

echo "Generated ${output_path}"
