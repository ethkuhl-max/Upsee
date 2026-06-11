#!/bin/sh
# Xcode Cloud post-clone hook — runs after the source is checked out, before
# Xcode resolves the project. We use it to regenerate Upsee.xcodeproj from
# project.yml so the build sees the canonical project layout, not whatever
# state happened to be committed locally.
#
# This script lives at the repo root: ci_scripts/ci_post_clone.sh
# Xcode Cloud auto-detects and runs it — no extra wiring needed.

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

# XcodeGen is vendored at .tooling/xcodegen/bin/xcodegen — no Homebrew needed.
if [ ! -x ".tooling/xcodegen/bin/xcodegen" ]; then
    echo "ERROR: Vendored XcodeGen binary missing at .tooling/xcodegen/bin/xcodegen"
    exit 1
fi

echo "Regenerating Upsee.xcodeproj from project.yml..."
.tooling/xcodegen/bin/xcodegen generate

echo "Done."
