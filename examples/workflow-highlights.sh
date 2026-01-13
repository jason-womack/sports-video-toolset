#!/usr/bin/env bash
# Example workflow: Extract and combine highlight clips

set -euo pipefail

# Configuration - Update these with your video file and highlight times
INPUT_VIDEO="game-recording.mp4"
OUTPUT_VIDEO="game-highlights.mp4"

# Highlight segments: format is "START DURATION DESCRIPTION"
HIGHLIGHTS=(
    "00:12:30 00:00:15 First-goal"
    "00:38:45 00:00:20 Second-goal"
    "01:15:20 00:00:18 Third-goal"
    "01:42:10 00:00:25 Final-goal"
)

# Get script directory and add bin to PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
export PATH="$BIN_DIR:$PATH"

# Working directory
WORK_DIR="./highlights-work"
mkdir -p "$WORK_DIR"

echo "========================================"
echo "Highlight Extraction Workflow"
echo "========================================"
echo ""

# Check input file
if [[ ! -f "$INPUT_VIDEO" ]]; then
    echo "ERROR: Input file not found: $INPUT_VIDEO"
    echo "Please update INPUT_VIDEO variable with your video file path"
    exit 1
fi

# Extract each highlight
echo "Extracting ${#HIGHLIGHTS[@]} highlight clips..."
CLIP_FILES=()
for i in "${!HIGHLIGHTS[@]}"; do
    IFS=' ' read -r start duration desc <<< "${HIGHLIGHTS[$i]}"
    clip_file="$WORK_DIR/clip-$(printf "%02d" $((i+1)))-${desc}.mp4"
    
    echo "  Clip $((i+1)): $desc (${start} + ${duration})"
    video-trim "$INPUT_VIDEO" "$clip_file" "$start" "$duration" --force
    
    CLIP_FILES+=("$clip_file")
done
echo ""

# Combine all highlights
echo "Combining clips into single highlight reel..."
video-combine "$OUTPUT_VIDEO" "${CLIP_FILES[@]}" --force
echo ""

# Show final info
echo "Final highlight reel:"
video-info "$OUTPUT_VIDEO"
echo ""

# Cleanup
echo "Cleaning up intermediate files..."
rm -rf "$WORK_DIR"
echo ""

echo "========================================"
echo "Highlight extraction complete!"
echo "========================================"
echo "Output: $OUTPUT_VIDEO"
echo ""
