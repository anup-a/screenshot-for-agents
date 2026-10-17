#!/bin/zsh
# Makes the README's WebP images from the PNG/MP4 sources, at 2x the width GitHub shows them.
#   Marketing/readme/webp.sh        (needs cwebp, img2webp and ffmpeg: brew install webp ffmpeg)
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=Marketing/readme/assets/web
mkdir -p "$OUT"

still() { # still SRC NAME WIDTH QUALITY
  cwebp -quiet -q "$4" -m 6 -sharp_yuv -resize "$3" 0 "$1" -o "$OUT/$2.webp"
}
for n in charts-tokens charts-legibility charts-speed hero scroll-record; do
  still "Marketing/readme/assets/$n.png" "$n" 1760 82
done
still Marketing/readme/assets/agent-marked.png agent-marked 1280 82
for n in 2-markup 3-private 4-pin 5-on-device; do
  still "Marketing/appstore-v2/$n.png" "appstore-$n" 880 80
done
still Icons/renders/2-scissors.png icon 256 90

# The demo: frames from the MP4 at 15 fps, 880 px wide, packed into one animated WebP.
FRAMES=$(mktemp -d)
ffmpeg -v error -i Marketing/readme/assets/demo.mp4 -vf fps=15,scale=880:-1:flags=lanczos "$FRAMES/f%04d.png"
img2webp -loop 0 -lossy -q 60 -m 4 -mixed -d 67 "$FRAMES"/f*.png -o "$OUT/demo.webp" >/dev/null
rm -rf "$FRAMES"
ls -l "$OUT" | awk 'NR>1 {printf "%8.0f KB  %s\n", $5/1024, $9}'
