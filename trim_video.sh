#!/bin/bash

# -------------------------------
# FFmpeg Video Trimmer Script
# -------------------------------
# Trims seconds from the start and/or end of a video.
# Optionally generates preview clips.
# Uses stream copy mode (no re-encoding).
#
# Usage:
#   ./trim_video.sh input.mp4 [-s START] [-e END] [-p] [-P]
#
# Options:
#   -s | --start     Seconds to trim from start (default: 0)
#   -e | --end       Seconds to trim from end (default: 0)
#   -p               Generate preview of first 10 seconds after start trim
#   -P               Generate preview of last 10 seconds before end trim
#   -h | --help      Show help message
#
# Output:
#   Main file:       input_final.mp4
#   Preview start:   input_preview.mp4 (if -p)
#   Preview end:     input_preview_end.mp4 (if -P)

# -------------------------------
# Default values
# -------------------------------
start_trim=0
end_trim=0
preview_start=false
preview_end=false
input=""
output=""

# -------------------------------
# Normalize combined short flags (e.g., -pP → -p -P)
# -------------------------------
normalized_args=()
for arg in "$@"; do
  if [[ "$arg" =~ ^-[^-] && "$arg" != "--"* && "${#arg}" -gt 2 ]]; then
    chars="${arg:1}"
    for (( i=0; i<${#chars}; i++ )); do
      normalized_args+=("-${chars:$i:1}")
    done
  else
    normalized_args+=("$arg")
  fi
done
set -- "${normalized_args[@]}"

# -------------------------------
# Help message
# -------------------------------
show_help() {
  echo "Usage: $0 input.mp4 [-s START] [-e END] [-p] [-P]"
  echo ""
  echo "Options:"
  echo "  -s, --start     Seconds to trim from start (default: 0)"
  echo "  -e, --end       Seconds to trim from end (default: 0)"
  echo "  -p              Generate preview of first 10 seconds after start trim"
  echo "  -P              Generate preview of last 10 seconds before end trim"
  echo "  -h, --help      Show this help message"
  echo ""
  echo "Output:"
  echo "  Main file:       input_final.mp4"
  echo "  Preview start:   input_preview.mp4 (if -p)"
  echo "  Preview end:     input_preview_end.mp4 (if -P)"
  exit 0
}

# -------------------------------
# Parse arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--start) start_trim="$2"; shift 2 ;;
    -e|--end) end_trim="$2"; shift 2 ;;
    -p) preview_start=true; shift ;;
    -P) preview_end=true; shift ;;
    -h|--help) show_help ;;
    -*)
      echo "Unknown option: $1"
      show_help
      ;;
    *)
      if [[ -z "$input" ]]; then
        input="$1"
        shift
      else
        echo "Unexpected argument: $1"
        show_help
      fi
      ;;
  esac
done

# -------------------------------
# Validate input
# -------------------------------
if [[ -z "$input" ]]; then
  echo "Error: Input file is required."
  show_help
fi

if [[ ! -f "$input" ]]; then
  echo "Error: File '$input' not found."
  exit 1
fi

# -------------------------------
# Derive output filenames
# -------------------------------
base="${input%.*}"
output="${base}_final.mp4"
preview="${base}_preview.mp4"
preview_end="${base}_preview_end.mp4"

# -------------------------------
# Get video duration
# -------------------------------
duration=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$input")

# -------------------------------
# Calculate trimmed duration
# -------------------------------
trimmed_duration=$(echo "$duration - $start_trim - $end_trim" | bc)

# -------------------------------
# Sanity check
# -------------------------------
if (( $(echo "$trimmed_duration <= 0" | bc -l) )); then
  echo "Error: Trimmed duration is zero or negative. Check your start/end values."
  exit 1
fi

# -------------------------------
# Debug logging
# -------------------------------
echo "Input file:        $input"
echo "Start trim:        $start_trim seconds"
echo "End trim:          $end_trim seconds"
echo "Original duration: $duration seconds"
echo "Trimmed duration:  $trimmed_duration seconds"
echo "Output file:       $output"
if $preview_start; then echo "Preview start:     $preview"; fi
if $preview_end; then echo "Preview end:       $preview_end"; fi

# -------------------------------
# Run FFmpeg main trim
# -------------------------------
ffmpeg -ss "$start_trim" -i "$input" -t "$trimmed_duration" -c copy "$output"

# -------------------------------
# Generate preview start
# -------------------------------
if $preview_start; then
  ffmpeg -ss "$start_trim" -i "$input" -t 10 -c copy "$preview"
fi

# -------------------------------
# Generate preview end
# -------------------------------
if $preview_end; then
  end_point=$(echo "$duration - $end_trim - 10" | bc)
  if (( $(echo "$end_point < 0" | bc -l) )); then
    echo "Warning: Not enough duration for end preview. Skipping."
  else
    ffmpeg -ss "$end_point" -i "$input" -t 10 -c copy "$preview_end"
  fi
fi

