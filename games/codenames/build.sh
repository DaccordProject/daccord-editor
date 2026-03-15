#!/usr/bin/env bash
# Build and package the Codenames plugin.
#
# Usage:
#   ./build.sh           # Package plugin (bundles .sgd source + plugin.json)
#
# Plugins use the .sgd (SafeGDScript) format. The daccord runtime loads
# gdscript.elf from addons/godot_sandbox/ and passes the .sgd source to
# it — no separate compilation step required.

set -euo pipefail
cd "$(dirname "$0")"

EXPORT_DIR="export"
BUNDLE_NAME="codenames.daccord-plugin"

echo "==> Packaging ${BUNDLE_NAME}..."

# Create a temp dir for bundle contents
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp plugin.json "$TMPDIR/"
mkdir -p "$TMPDIR/src"
cp src/main.sgd "$TMPDIR/src/"

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
