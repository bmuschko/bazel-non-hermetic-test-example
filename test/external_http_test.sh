#!/usr/bin/env bash
# Verifies that an external HTTP endpoint is reachable and returns the expected content.
set -euo pipefail

url="https://example.com"
body="$(curl --fail --silent --show-error --max-time 30 "$url")"

if [[ "$body" != *"Example Domain"* ]]; then
  echo "Unexpected response from $url" >&2
  exit 1
fi

echo "Successfully reached $url"
