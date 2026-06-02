#!/usr/bin/env bash
# Remove PII redaction placeholders that must not appear in committed markdown/YAML.
# Guild may redact note() values for the UI; strip before writing git artifacts.
set -euo pipefail

strip_pii_redaction_tokens_stream() {
  sed -E 's/\[HIDDEN:[0-9a-f]+\]//g' \
    | sed -E 's/[[:space:]]{2,}/ /g' \
    | sed -E 's/[[:space:]]+\|/ |/g' \
    | sed -E 's/\|[[:space:]]+/| /g'
}

strip_pii_redaction_tokens_file() {
  local path="${1:?FILE}"
  local tmp
  tmp="$(mktemp)"
  strip_pii_redaction_tokens_stream <"$path" >"$tmp"
  mv "$tmp" "$path"
}

case "${1:-}" in
  file) shift; strip_pii_redaction_tokens_file "$@" ;;
  "") strip_pii_redaction_tokens_stream ;;
  *)
    echo "usage: text-sanitize.sh [file PATH]" >&2
    exit 1
    ;;
esac
