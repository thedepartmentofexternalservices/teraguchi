#!/usr/bin/env bash
# Create synthetic decode input only; never capture a desktop or modify a display.
set -euo pipefail
output=${1:?usage: make-hevc-identity-fixture.sh NEW_PRIVATE_OUTPUT_DIRECTORY}
umask 077
mkdir "$output"
ffmpeg=${FFMPEG:-ffmpeg}
"$ffmpeg" -version > "$output/encoder-version.txt"
# 120 distinct ten-bit RGB ramp frames, then repeat the complete closed sequence
# 15 times. This gives 1,800 frames; it is not 1,800 distinct source frames.
"$ffmpeg" -hide_banner -nostdin -n -loglevel warning -filter_threads 2 \
    -f lavfi -i "nullsrc=s=3840x2160:r=60,format=gbrp10le,geq=r='mod(X+7*N,1024)':g='mod(Y+3*N,1024)':b='mod(X+Y+11*N,1024)'" \
    -frames:v 120 -an -c:v libx265 -preset ultrafast -crf 12 \
    -pix_fmt gbrp10le -colorspace rgb -color_range pc \
    -color_primaries bt709 -color_trc iec61966-2-1 \
    -x265-params 'pools=4:frame-threads=2:keyint=60:min-keyint=60:scenecut=0:open-gop=0:repeat-headers=1' \
    -f hevc "$output/cycle.hevc" 2> "$output/encode.log"
python3 - "$output" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]); cycle=(p/'cycle.hevc').read_bytes()
with (p/'identity-4k-1800.hevc').open('xb') as out:
    for _ in range(15): out.write(cycle)
manifest={'kind':'synthetic moving ten-bit RGB ramps','width':3840,'height':2160,
          'frames':1800,'unique_frames':120,'repetitions':15,'fps':60,
          'profile':'hevc-rext10-444-identity',
          'sha256':hashlib.sha256((p/'identity-4k-1800.hevc').read_bytes()).hexdigest(),
          'scope':'decode format and throughput; not capture, color fidelity, or presentation qualification'}
(p/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('synthetic_identity_fixture=created frames=1800 unique_frames=120 repetitions=15')
PY
