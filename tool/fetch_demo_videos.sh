#!/usr/bin/env bash
# One-off: download the demo videos of the submissions that have one into
# finalist_brief_server/.cache/videos/<slug>.mp4 (git-ignored).
# Requires yt-dlp. YouTube sometimes 403s the default client; the android
# client fallback is what worked on 2026-09-21 (360p for two of the three).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/finalist_brief_server/.cache/videos"
mkdir -p "$OUT"

python3 - "$ROOT/finalist_brief_server/assets/humor_genome/submissions.json" <<'PY' | while read -r slug url; do
import json, sys
for s in json.load(open(sys.argv[1])):
    if s["hasDemoVideo"]:
        print(s["slug"], s["demoUrl"])
PY
  if [ -f "$OUT/$slug.mp4" ]; then echo "have  $slug"; continue; fi
  for client in default android ios; do
    extra=(); [ "$client" != default ] && extra=(--extractor-args "youtube:player_client=$client")
    if yt-dlp -q --no-warnings "${extra[@]}" \
         -f "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/b[height<=720]/b" \
         --merge-output-format mp4 -o "$OUT/$slug.%(ext)s" "$url" 2>/dev/null && [ -f "$OUT/$slug.mp4" ]; then
      echo "got   $slug (client=$client)"; break
    fi
  done
  [ -f "$OUT/$slug.mp4" ] || echo "FAIL  $slug" >&2
done
