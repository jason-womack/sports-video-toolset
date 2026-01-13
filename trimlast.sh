#!/bin/bash

# Usage: trimlast inputfile seconds_to_trim
# Example: trimlast "video.mp4" 80

if [ $# -ne 2 ]; then
  echo "Usage: $0 <inputfile> <seconds-to-trim>"
  exit 1
fi

INPUT="$1"
TRIM="$2"

if [ ! -f "$INPUT" ]; then
  echo "Error: Input file '$INPUT' not found."
  exit 1
fi

# Get total duration in seconds (as a float)
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")

if [ -z "$DURATION" ]; then
  echo "Error: Could not determine duration of '$INPUT'."
  exit 1
fi

# Compute new duration (keep = total - trim)
KEEP_SECONDS=$(awk -v d="$DURATION" -v t="$TRIM" 'BEGIN { print d - t }')

# Guard against negative or zero
if awk -v k="$KEEP_SECONDS" 'BEGIN { exit (k > 0 ? 0 : 1) }'; then
  :
else
  echo "Error: Trim value ($TRIM) is greater than or equal to file duration ($DURATION seconds)."
  exit 1
fi

# Convert KEEP_SECONDS (float) to HH:MM:SS.mmm
KEEP_TS=$(awk -v k="$KEEP_SECONDS" '
BEGIN {
  h = int(k / 3600);
  m = int((k % 3600) / 60);
  s = k - h * 3600 - m * 60;
  # Print as HH:MM:SS.mmm
  printf("%02d:%02d:%06.3f", h, m, s);
}')

BASENAME="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTPUT="${BASENAME}_trimmed.${EXT}"

echo "Input duration: $DURATION seconds"
echo "Trimming last $TRIM seconds"
echo "Keeping up to: $KEEP_TS"
echo "Output file: $OUTPUT"

ffmpeg -i "$INPUT" -to "$KEEP_TS" -c copy "$OUTPUT"

