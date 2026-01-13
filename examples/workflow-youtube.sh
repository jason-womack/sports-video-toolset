#!/usr/bin/env bash
# Example workflow: Process raw game footage for YouTube publishing
# This script demonstrates a complete workflow from raw footage to published video

set -euo pipefail

# Configuration
RAW_INPUT="raw-game-footage.mp4"
FINAL_OUTPUT="published-game.mp4"
TRIM_START="00:05:00"       # Skip first 5 minutes (pregame)
TRIM_DURATION="02:00:00"    # Process 2 hours of gameplay
TITLE="Championship Game 2026"
AUTHOR="Sports Team Name"
DATE="2026-01-13"
THUMBNAIL_TIME="00:10:00"   # Extract thumbnail at 10 minutes

# Get script directory and add bin to PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
export PATH="$BIN_DIR:$PATH"

# Working directory for intermediate files
WORK_DIR="./work"
mkdir -p "$WORK_DIR"

echo "========================================"
echo "Sports Video Processing Workflow"
echo "========================================"
echo ""

# Step 1: Check input file
echo "Step 1: Checking input file..."
if [[ ! -f "$RAW_INPUT" ]]; then
    echo "ERROR: Input file not found: $RAW_INPUT"
    echo "Please update RAW_INPUT variable with your video file path"
    exit 1
fi

video-info "$RAW_INPUT"
echo ""

# Step 2: Trim raw footage to game time
echo "Step 2: Trimming raw footage..."
TRIMMED="$WORK_DIR/trimmed.mp4"
video-trim "$RAW_INPUT" "$TRIMMED" "$TRIM_START" "$TRIM_DURATION" --force
echo ""

# Step 3: Normalize for YouTube
echo "Step 3: Normalizing for YouTube (1080p)..."
NORMALIZED="$WORK_DIR/normalized.mp4"
video-normalize "$TRIMMED" "$NORMALIZED" --preset youtube-1080p --force
echo ""

# Step 4: Add metadata and prepare for publishing
echo "Step 4: Adding metadata and preparing for web..."
video-prepare "$NORMALIZED" "$FINAL_OUTPUT" \
    -t "$TITLE" \
    -a "$AUTHOR" \
    -d "$DATE" \
    --thumbnail "$THUMBNAIL_TIME" \
    --faststart \
    --force
echo ""

# Step 5: Display final video info
echo "Step 5: Final video information..."
video-info "$FINAL_OUTPUT"
echo ""

# Cleanup
echo "Cleaning up intermediate files..."
rm -rf "$WORK_DIR"
echo ""

echo "========================================"
echo "Processing complete!"
echo "========================================"
echo "Output file: $FINAL_OUTPUT"
echo "Thumbnail:   ${FINAL_OUTPUT%.*}.jpg"
echo ""
echo "Your video is ready for publishing!"
