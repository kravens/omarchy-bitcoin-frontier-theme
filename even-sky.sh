#!/usr/bin/env bash
# Flatten the mottled charcoal in dark sky areas so OLED panels show one even
# tone instead of patches, without touching stars, nebula, moon or coin.
#
# Each image is split into a low-frequency layer (a wide blur: the charcoal
# mottle, the nebula glow) and the high-frequency rest (stars, dust, grain).
# Where the low-frequency luminance is dark (< 10%) it is replaced by flat
# #12141a, blending back to the original above 35%. Bright high-frequency
# detail is kept everywhere; dark speckle only where the image is bright.
#
# Usage: ./even-sky.sh [file ...]   (default: every PNG under backgrounds/)
set -euo pipefail
BASE='#12141a'
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

for f in "${@:-$DIR/backgrounds/*.png $DIR/backgrounds/portrait/*.png}"; do
  for in in $f; do
    echo "== $in"
    size=$(identify -format '%wx%h' "$in")
    magick "$in" -resize 12.5% -blur 0x6 -resize 800% -crop "$size+0+0" +repage "$TMP/L.png"
    magick "$TMP/L.png" -colorspace gray -level 10%,35% -blur 0x4 "$TMP/M.png"
    magick "$TMP/L.png" \( "$TMP/M.png" -alpha off \) -alpha off -compose CopyOpacity -composite \
      \( -size "$size" xc:"$BASE" \) +swap -compose Over -composite -alpha off "$TMP/Lp.png"
    magick "$in" "$TMP/L.png" -compose MinusSrc -composite "$TMP/Hpos.png"
    magick "$TMP/L.png" "$in" -compose MinusSrc -composite "$TMP/Hneg.png"
    magick "$TMP/Lp.png" \( "$TMP/Hpos.png" -evaluate multiply 0.95 \) -compose Plus -composite \
      \( "$TMP/Hneg.png" "$TMP/M.png" -compose Multiply -composite \) -compose MinusSrc -composite \
      -depth 8 -strip "$TMP/out.png"
    mv "$TMP/out.png" "$in"
  done
done
