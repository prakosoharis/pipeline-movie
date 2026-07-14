#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$PIPELINE_DIR/.." && pwd)"
ASSEMBLY_DIR="$PROJECT_ROOT/07-final/.assembly-audio"
CONCAT_LIST="$ASSEMBLY_DIR/concat.txt"
OUTPUT="$PROJECT_ROOT/07-final/film-final.mp4"
TEMP_OUTPUT="$PROJECT_ROOT/07-final/.film-final.assembling.tmp.mp4"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required" >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe is required" >&2; exit 1; }

mkdir -p "$ASSEMBLY_DIR"
: > "$CONCAT_LIST"
rm -f "$TEMP_OUTPUT"
trap 'rm -f "$TEMP_OUTPUT"' EXIT

for number in $(seq -w 1 22); do
  shot_id="shot-$number"
  input="$PROJECT_ROOT/05-generated-video/$shot_id/$shot_id-final.mp4"
  [[ -s "$input" ]] || { echo "Missing final shot: $input" >&2; exit 1; }

  properties="$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$input")"
  [[ "$properties" == "1440,608,24/1" ]] || {
    echo "$shot_id has unexpected video properties: $properties" >&2
    exit 1
  }
  audio_count="$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=index -of csv=p=0 "$input" | awk 'NF {count++} END {print count + 0}')"
  [[ "$audio_count" -eq 1 ]] || { echo "$shot_id has no audio stream" >&2; exit 1; }
  printf "file '%s'\n" "$input" >> "$CONCAT_LIST"
done

[[ "$(wc -l < "$CONCAT_LIST" | tr -d ' ')" -eq 22 ]] || {
  echo "Concat list does not contain 22 shots" >&2
  exit 1
}

ffmpeg -nostdin -y -fflags +genpts -f concat -safe 0 -i "$CONCAT_LIST" \
  -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart "$TEMP_OUTPUT"
[[ -s "$TEMP_OUTPUT" ]] || { echo "Final assembly failed: $TEMP_OUTPUT" >&2; exit 1; }

final_properties="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$TEMP_OUTPUT")"
[[ "$final_properties" == "1440,608,24/1" ]] || {
  echo "Final film has unexpected video properties: $final_properties" >&2
  exit 1
}
final_audio_count="$(ffprobe -v error -select_streams a:0 \
  -show_entries stream=index -of csv=p=0 "$TEMP_OUTPUT" | awk 'NF {count++} END {print count + 0}')"
[[ "$final_audio_count" -eq 1 ]] || { echo "Final film has no audio stream" >&2; exit 1; }

mv "$TEMP_OUTPUT" "$OUTPUT"
trap - EXIT

duration="$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$OUTPUT")"
echo "Final film with audio: $OUTPUT"
echo "Shots: 22"
echo "Duration: ${duration}s"
