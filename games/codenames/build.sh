#!/usr/bin/env bash
# Build and package the Codenames plugin.
#
# Usage:
#   ./build.sh           # Package plugin (downloads ELF from godot-sandbox releases if needed)
#   ./build.sh compile   # Compile GDScript→ELF then package (requires godot-sandbox toolchain)

set -euo pipefail
cd "$(dirname "$0")"

EXPORT_DIR="export"
BUNDLE_NAME="codenames.daccord-plugin"
GODOT_SANDBOX_REPO="krazyjakee/godot-sandbox"
GODOT_SANDBOX_TAG="v0.49"

if [[ "${1:-}" == "compile" ]]; then
    echo "==> Compiling GDScript to RISC-V ELF via godot-sandbox..."
    echo "    (This step requires the godot-sandbox editor toolchain.)"
    echo "    Compile src/main.gd in the Godot editor, then copy the"
    echo "    output ELF to ${EXPORT_DIR}/bin/plugin.elf"
    echo ""
    echo "    Alternatively, if the cmake/zig toolchain is set up:"
    echo "    godot --headless --script addons/godot_sandbox/compile.gd src/main.gd"
    exit 1
fi

if [[ ! -f "${EXPORT_DIR}/bin/plugin.elf" ]]; then
    echo "==> ELF not found, downloading from ${GODOT_SANDBOX_REPO} ${GODOT_SANDBOX_TAG}..."
    mkdir -p "${EXPORT_DIR}/bin"
    gh release download "${GODOT_SANDBOX_TAG}" \
        --repo "${GODOT_SANDBOX_REPO}" \
        --pattern "gdscript.elf" \
        --output "${EXPORT_DIR}/bin/plugin.elf"
    echo "==> Downloaded ${EXPORT_DIR}/bin/plugin.elf"
fi

echo "==> Packaging ${BUNDLE_NAME}..."

# Create a temp dir for bundle contents
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp plugin.json "$TMPDIR/"
mkdir -p "$TMPDIR/bin"
cp "${EXPORT_DIR}/bin/plugin.elf" "$TMPDIR/bin/"

if [[ -d assets ]]; then
    cp -r assets "$TMPDIR/"
fi

# Create the bundle (ZIP with .daccord-plugin extension)
cd "$TMPDIR"
zip -r "/tmp/${BUNDLE_NAME}" plugin.json bin/ assets/ 2>/dev/null || \
    zip -r "/tmp/${BUNDLE_NAME}" plugin.json bin/
cd - > /dev/null

mv "/tmp/${BUNDLE_NAME}" "${EXPORT_DIR}/${BUNDLE_NAME}"
echo "==> Built: ${EXPORT_DIR}/${BUNDLE_NAME}"
echo "   Upload this file to a daccord server via the plugin admin UI."
