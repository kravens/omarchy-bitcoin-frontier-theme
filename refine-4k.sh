#!/usr/bin/env bash
# Rebuild the three main wallpapers at 4K through ppq.ai.
#
# openai/gpt-5.4-image-2 gives by far the best risograph look (real hardware
# detail, stochastic spray-ink grain like the poster) but tops out at
# 2560x1440. google/gemini-3.1-flash-image-preview is the only model that
# honours image_size=4K (5504x3072) and is faithful when asked to reproduce a
# reference exactly. So, per wallpaper:
#   1. base   -- gpt image-to-image at 2K from three references: the v1
#                wallpaper (composition, grainy orange coin), the v2 gemini
#                render (realistic surfaces) and the poster photo (print style).
#   2. 4k     -- gemini reproduces the base at native 4K: no upscale, no tiles.
#   3. finish -- Lanczos to the target size, then the heavy v1-style ink grain
#                is put back on the orange coin, which gemini renders too clean.
#
# Every stage skips when its output exists, so a failed call reruns cheap.
# Outputs land in refined/; copy over backgrounds/ once they look right.
#
# Usage: ./refine-4k.sh [name ...]        (default: all three)
#   ORIENT=port ./refine-4k.sh              9:16 variants from the -port sources
set -euo pipefail

BASE_MODEL=${BASE_MODEL:-openai/gpt-5.4-image-2}
HIRES_MODEL=${HIRES_MODEL:-google/gemini-3.1-flash-image-preview}
ORIENT=${ORIENT:-land}
case $ORIENT in
  land) AR=16:9; SIZE=3840x2160 ;;
  port) AR=9:16; SIZE=2160x3840 ;;
esac
DIR="$(cd "$(dirname "$0")" && pwd)"
V1="$HOME/Pictures/bitcoin-frontier/v1"; V2="$HOME/Pictures/bitcoin-frontier/v2"; POSTER="$HOME/Downloads/navigating_thebitcoin_frontier.jpeg"
OUT="$DIR/refined"; WORK="$OUT/work"
mkdir -p "$WORK"

STYLE='Print style, matching the poster reference exactly: a two-colour risograph screen print -- print-white ink on deep charcoal-blue paper (#12141a) with fine stochastic spray-ink film grain everywhere, visible ink speckle in the midtones and highlights, matte paper texture. The scene is rendered photoreal first (real fabric, metal, foil, antenna struts, regolith, crater shadows, real nebula structure, crisp pinpoint stars) and then printed through that grain. The Bitcoin coin is a perfectly flat disc in bitcoin orange #f7931a printed with the same heavy ink grain and a dark charcoal B glyph -- no shadow, no bevel, no thickness. No halftone dot grid, no smooth digital gradients, no plastic CGI look, no text, no watermark.'

declare -A SCENE=(
  [1-explorer]='Lone astronaut drifting in front of a bright nebula, a single thin tether trailing to the lower left, large orange Bitcoin coin upper right.'
  [2-probe]='Small deep-space probe with a dish antenna crossing a diagonal band of the Milky Way, large orange Bitcoin coin cropped at the lower right.'
  [3-moonrise]='Orange Bitcoin coin rising like a sun behind the limb of the Moon, photoreal lunar surface with sharp-rimmed craters, star field above.'
)

for n in ${@:-1-explorer 2-probe 3-moonrise}; do
  p="$WORK/$n-$ORIENT"
  [ -s "$OUT/$n-$ORIENT.png" ] && { echo "have $n-$ORIENT"; continue; }
  echo "== $n-$ORIENT"

  if [ ! -s "$p-base.png" ]; then
    magick "$V1/$n-$ORIENT.png" -resize 1600x1600 "$p-v1.jpg"
    magick "$V2/$n-$ORIENT.png" -resize 1600x1600 "$p-v2.jpg"
    magick "$POSTER" -resize 1024x1024 "$WORK/poster.jpg"
    PPQ_EXTRA='{"image_config":{"aspect_ratio":"'$AR'","image_size":"2K"}}' \
    ppq-image "Recreate this wallpaper in $AR. Image 1 is the composition to keep exactly: same framing, scale and placement of every element, and its grainy orange coin is the coin treatment to keep. Image 2 shows the same scene with realistic surfaces: take its material realism and detail. Image 3 is the poster whose print style to match. Scene: ${SCENE[$n]} $STYLE" \
      "$p-base.png" "$BASE_MODEL" "$p-v1.jpg" "$p-v2.jpg" "$WORK/poster.jpg"
  fi

  if [ ! -s "$p-4k.jpg" ]; then
    PPQ_EXTRA='{"image_config":{"aspect_ratio":"'$AR'","image_size":"4K"}}' \
    ppq-image "Reproduce this image exactly at 4K resolution: identical composition, identical placement, scale and shape of every element, identical colours and tones. Do not reinterpret, add, remove or move anything. The only change is resolution: render the same fine risograph spray-ink grain, stars, nebula, surfaces and hardware at native 4K sharpness. The orange coin stays a perfectly flat, heavily grainy disc -- no shadow, no bevel." \
      "$p-4k.jpg" "$HIRES_MODEL" "$p-base.png"
  fi

  magick "$p-4k.jpg" -filter Lanczos -resize "$SIZE^" -gravity center -extent "$SIZE" -depth 8 "$p-fit.png"
  # Coin mask: pixels near bitcoin orange AND saturated (cream nebula highlights
  # are warm but washed out); Open drops stray grain, Close fills the B glyph,
  # blur softens the edge so the grain fades in.
  magick "$p-fit.png" \
    \( +clone -fuzz 15% -fill white -opaque '#f7931a' -fill black +opaque white \) \
    \( -clone 0 -colorspace HSL -channel G -separate +channel -threshold 45% \) \
    -delete 0 -compose Multiply -composite \
    -morphology Open Disk:10 -morphology Close Disk:60 -blur 0x6 "$p-coinmask.png"
  # Grain layer is neutral gray outside the mask, so Overlay (identity on gray)
  # cannot touch anything but the coin. Noise is made at half size so the grain
  # clumps like the v1 print instead of single-pixel hiss.
  magick "$p-fit.png" \
    \( -size "$(identify -format '%[fx:w/2]x%[fx:h/2]' "$p-fit.png")" xc:gray50 -seed 7 -attenuate 1.1 +noise Gaussian -resize 200% -clamp \
       \( "$p-coinmask.png" -alpha off \) -compose Multiply -composite \
       \( "$p-coinmask.png" -alpha off -negate -evaluate multiply 0.5 \) -compose Plus -composite \) \
    -compose Overlay -composite -depth 8 "$OUT/$n-$ORIENT.png"
  identify "$OUT/$n-$ORIENT.png"
done
