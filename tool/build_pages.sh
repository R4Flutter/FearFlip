#!/usr/bin/env bash
# Builds the GitHub Pages site into build/pages/.
#
#   bash tool/build_pages.sh
#
# The same build as the CrazyGames upload, without the CrazyGames SDK script:
# outside CrazyGames the game runs on its own (saves stay in the browser's
# localStorage, no ads, rewards are given straight away).
# .github/workflows/pages.yml runs this on every push to main.
set -euo pipefail
cd "$(dirname "$0")/.."

bash tool/build_crazygames.sh

OUT=build/pages
rm -rf "$OUT"
cp -r build/crazygames "$OUT"

sed -i '/sdk\.crazygames\.com/d' "$OUT/index.html"
if grep -q 'sdk\.crazygames\.com' "$OUT/index.html"; then
  echo "build_pages: the CrazyGames SDK is still in index.html" >&2
  exit 1
fi

# Serve every file as is (no Jekyll processing on GitHub Pages).
touch "$OUT/.nojekyll"

echo "Pages site:    $OUT ($(du -sh "$OUT" | cut -f1))"
