#!/usr/bin/env bash
# Build and package the Battleships plugin.
#
# Usage:
#   ./build.sh           # Package plugin (bundles .lua source + plugin.json)

set -euo pipefail
cd "$(dirname "$0")"

EXPORT_DIR="export"
BUNDLE_NAME="battleships.daccord-plugin"

echo "==> Packaging ${BUNDLE_NAME}..."

# Create a temp dir for bundle contents
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp plugin.json "$TMPDIR/"
mkdir -p "$TMPDIR/src"
cp src/*.lua "$TMPDIR/src/"

if [[ -d assets ]]; then
    cp -r assets "$TMPDIR/"
fi

# Create the bundle (ZIP with .daccord-plugin extension)
mkdir -p "${EXPORT_DIR}"
cd "$TMPDIR"
zip -r "/tmp/${BUNDLE_NAME}" plugin.json src/ assets/ 2>/dev/null || \
    zip -r "/tmp/${BUNDLE_NAME}" plugin.json src/
cd - > /dev/null

mv "/tmp/${BUNDLE_NAME}" "${EXPORT_DIR}/${BUNDLE_NAME}"
echo "==> Built: ${EXPORT_DIR}/${BUNDLE_NAME}"
echo "   Upload this file to a daccord server via the plugin admin UI."
