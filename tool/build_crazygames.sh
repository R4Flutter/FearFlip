#!/usr/bin/env bash
# Builds the CrazyGames upload: build/crazygames/ and build/fearflip_crazygames.zip
#
#   bash tool/build_crazygames.sh
#
# Everything is served from the zip itself (no CDN, no service worker); the
# only outside request is the CrazyGames SDK script in web/index.html.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web \
  --release \
  --no-web-resources-cdn \
  --pwa-strategy=none \
  --no-source-maps

OUT=build/crazygames
rm -rf "$OUT"
cp -r build/web "$OUT"

# Not needed at runtime: the WebAssembly (skwasm) renderer this build doesn't
# use, debug symbols and build bookkeeping.
rm -f "$OUT"/canvaskit/skwasm* "$OUT"/canvaskit/*.symbols "$OUT"/canvaskit/chromium/*.symbols
rm -f "$OUT"/.last_build_id "$OUT"/flutter_service_worker.js
# Source art kept in the repo for tooling, never loaded by the game.
rm -rf "$OUT"/assets/assets/new_assets

ZIP=build/fearflip_crazygames.zip
rm -f "$ZIP"
(cd "$OUT" && zip -qr -9 "../$(basename "$ZIP")" .)

echo
echo "Upload folder: $OUT"
echo "Upload zip:    $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "Files:         $(find "$OUT" -type f | wc -l)"
echo "Unpacked size: $(du -sh "$OUT" | cut -f1)"
