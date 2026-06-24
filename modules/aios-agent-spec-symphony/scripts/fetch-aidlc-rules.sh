#!/usr/bin/env bash
# Download awslabs/aidlc-workflows release rules into OUTPUT_DIR.
# Layout: aws-aidlc-rules/, aws-aidlc-rule-details/, LICENSE, VERSION.
set -euo pipefail

VERSION="${1:?version e.g. 1.0.0 or v1.0.0}"
OUTPUT_DIR="${2:?output_dir}"

raw="${VERSION#v}"
tag="v${raw}"
zip_name="ai-dlc-rules-${tag}.zip"
zip_url="https://github.com/awslabs/aidlc-workflows/releases/download/${tag}/${zip_name}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fsSL -o "${tmpdir}/${zip_name}" "${zip_url}"
unzip -q -o "${tmpdir}/${zip_name}" -d "${tmpdir}/extract"

rm -rf "${OUTPUT_DIR}"
mkdir -p "$(dirname "${OUTPUT_DIR}")"
mv "${tmpdir}/extract/aidlc-rules" "${OUTPUT_DIR}"

curl -fsSL -o "${OUTPUT_DIR}/LICENSE" "https://raw.githubusercontent.com/awslabs/aidlc-workflows/${tag}/LICENSE" 2>/dev/null || true
{
  echo "${tag}"
  echo "source: https://github.com/awslabs/aidlc-workflows/releases/tag/${tag}"
  echo "fetched_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"${OUTPUT_DIR}/VERSION"

echo "aidlc_rules_fetched=${tag}"
echo "aidlc_rules_dir=${OUTPUT_DIR}"
