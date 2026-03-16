#!/usr/bin/env bash
# Build and package daccord game plugins.
#
# Usage:
#   ./build.sh              # Build all games
#   ./build.sh codenames    # Build a specific game

set -euo pipefail
cd "$(dirname "$0")"

build_game() {
    local game_dir="$1"
    local game_name
    game_name=$(basename "$game_dir")
    local bundle_name="${game_name}.daccord-plugin"
    local export_dir="${game_dir}/export"

    if [[ ! -f "${game_dir}/plugin.json" ]]; then
        echo "==> Skipping ${game_name} (no plugin.json)"
        return
    fi

    echo "==> Packaging ${bundle_name}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    cp "${game_dir}/plugin.json" "$tmpdir/"
    mkdir -p "$tmpdir/src"
    cp "${game_dir}"/src/*.lua "$tmpdir/src/"

    if [[ -d "${game_dir}/assets" ]]; then
        cp -r "${game_dir}/assets" "$tmpdir/"
    fi

    mkdir -p "$export_dir"
    (cd "$tmpdir" && zip -r "/tmp/${bundle_name}" plugin.json src/ assets/ 2>/dev/null || \
        zip -r "/tmp/${bundle_name}" plugin.json src/)

    mv "/tmp/${bundle_name}" "${export_dir}/${bundle_name}"
    echo "==> Built: ${export_dir}/${bundle_name}"
}

if [[ $# -gt 0 ]]; then
    game="games/$1"
    if [[ ! -d "$game" ]]; then
        echo "Error: game '$1' not found in games/" >&2
        exit 1
    fi
    build_game "$game"
else
    for game_dir in games/*/; do
        build_game "${game_dir%/}"
    done
fi
