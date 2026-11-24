#!/usr/bin/env bash
# Apply the TSE-SE replacements file to a merged LZA UC tree.
#
# Usage: ./apply.sh <merged-lza-uc-dir> <path-to-upstream-repo>
#
# The second argument points at a checkout of aws/lza-universal-configuration
# (at the matching ref) so we can invoke its scripts/config-replacer.js.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <merged-lza-uc-dir> <path-to-upstream-repo>" >&2
  exit 2
fi

TARGET="$1"
UPSTREAM="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -d "$TARGET" ]]; then
  echo "Target dir does not exist: $TARGET" >&2; exit 1
fi
if [[ ! -f "$UPSTREAM/scripts/config-replacer.js" ]]; then
  echo "Upstream config-replacer.js not found under $UPSTREAM" >&2; exit 1
fi

echo "Applying $HERE/replacements-for-tse-se.yaml to $TARGET"
node "$UPSTREAM/scripts/config-replacer.js" -w "$TARGET" "$HERE/replacements-for-tse-se.yaml"

# Phase B — overlay step (not populated yet).
# if [[ -d "$HERE/overlay" ]]; then
#   echo "Copying overlay files into $TARGET"
#   cp -R "$HERE/overlay/." "$TARGET/"
# fi

echo "Done. Review $HERE/admin-changes.md for admin values to configure."
