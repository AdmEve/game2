#!/usr/bin/env bash
# Builds a web copy of the app (same lib/, same fonts) for headless UI checks.
# The repo stays Android-only: web scaffolding is generated in a temp copy.
#   tool/ui_e2e/build_web.sh <out-dir>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?usage: build_web.sh <out-dir>}"
WORK="$(mktemp -d)"
cp -r "$ROOT/lib" "$ROOT/assets" "$ROOT/pubspec.yaml" "$ROOT/analysis_options.yaml" "$WORK/"
cd "$WORK"
flutter create --project-name naqashi --org ir.naqashi --platforms=web . >/dev/null
# CanvasKit bundled locally (no gstatic CDN); semantics tree on so the page can be driven by text.
flutter build web --release --no-web-resources-cdn --dart-define=E2E_SEMANTICS=true >/dev/null
rm -rf "$OUT" && cp -r build/web "$OUT"
echo "web build in $OUT"
