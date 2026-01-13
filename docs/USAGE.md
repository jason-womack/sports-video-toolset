# Sports Video Toolset - Usage Guide

A comprehensive collection of shell scripts for efficient, lossless video processing workflows.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Scripts Overview](#scripts-overview)
- [Detailed Usage](#detailed-usage)
- [Common Workflows](#common-workflows)
- [Tips and Best Practices](#tips-and-best-practices)

## Installation

### Prerequisites

- **ffmpeg** (4.0 or later recommended)
- **ffprobe** (included with ffmpeg)
- **bash** (4.0 or later)

Install on various systems:

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# macOS with Homebrew
brew install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/jason-womack/sports-video-toolset.git
cd sports-video-toolset
```

2. Add `bin/` to your PATH (optional):
```bash
export PATH="$PATH:$(pwd)/bin"
```

Or create symlinks to a directory in your PATH:
```bash
sudo ln -s $(pwd)/bin/* /usr/local/bin/
```

## Quick Start

```bash
# Get video information
./bin/video-info game.mp4

# Trim a highlight (lossless)
./bin/video-trim game.mp4 highlight.mp4 00:15:30 00:02:00

# Combine multiple segments
./bin/video-combine full-game.mp4 quarter1.mp4 quarter2.mp4 quarter3.mp4 quarter4.mp4

# Normalize for web publishing
./bin/video-normalize raw.mp4 web-ready.mp4 --preset youtube-1080p

# Prepare with metadata
./bin/video-prepare final.mp4 published.mp4 -t "Championship Game" --faststart
```

## Scripts Overview

| Script | Purpose | Lossless |
|--------|---------|----------|
| `video-info` | Display video file information | N/A |
| `video-trim` | Extract segments by time range | ✓ |
| `video-combine` | Concatenate multiple videos | ✓ |
| `video-crop` | Crop to specific dimensions | ✗ |
| `video-normalize` | Standardize codec/format | ✗ |
| `video-prepare` | Add metadata, optimize for web | ✓ |

## Detailed Usage

### video-info

Display comprehensive information about video files.

```bash
# Basic info
video-info game.mp4

# Multiple files
video-info video1.mp4 video2.mp4 video3.mp4

# Verbose output
video-info --verbose game.mp4

# JSON format
video-info --json game.mp4 > info.json
```

**Output includes:**
- File size
- Duration
- Video codec, resolution, framerate, bitrate
- Audio codec, sample rate, channels

### video-trim

Losslessly extract video segments using stream copy.

```bash
# Extract 2 minutes starting at 15:30
video-trim game.mp4 highlight.mp4 00:15:30 00:02:00

# Extract from specific time to end
video-trim game.mp4 second-half.mp4 00:45:00

# Time can be in seconds
video-trim game.mp4 clip.mp4 930 120

# Show input info first
video-trim --info game.mp4

# Force overwrite
video-trim --force game.mp4 highlight.mp4 00:15:30 00:02:00
```

**Important notes:**
- Uses stream copy for instant, lossless extraction
- Output may start slightly before requested time (keyframe boundary)
- For frame-accurate cuts, re-encoding is required

### video-combine

Losslessly concatenate multiple video files.

```bash
# Combine multiple files
video-combine full-game.mp4 q1.mp4 q2.mp4 q3.mp4 q4.mp4

# Use file list
video-combine full-game.mp4 --list segments.txt

# Combine with wildcards (files in alphabetical order)
video-combine full-game.mp4 part*.mp4
```

**File list format** (`segments.txt`):
```
/path/to/video1.mp4
/path/to/video2.mp4
/path/to/video3.mp4
```

**Requirements:**
- All input files must have identical codecs, resolution, and framerate
- Files are joined in the order specified
- For incompatible files, normalize all files first

### video-crop

Crop video to specific dimensions (requires re-encoding).

```bash
# Manual crop with coordinates
video-crop game.mp4 cropped.mp4 1280 720 320 180

# Use preset for common crops
video-crop game.mp4 square.mp4 --preset center-1:1
video-crop game.mp4 main-camera.mp4 --preset left-half

# Show available presets
video-crop --help
```

**Presets:**
- `center-16:9` - Crop center to 16:9 aspect ratio
- `center-4:3` - Crop center to 4:3 aspect ratio
- `center-1:1` - Crop center to square
- `left-half` - Crop left half of video
- `right-half` - Crop right half of video

**Notes:**
- Cropping requires re-encoding (not lossless)
- Uses H.264 with high quality (CRF 18)
- Audio is copied without re-encoding

### video-normalize

Normalize video for consistent playback across platforms.

```bash
# Basic normalization (H.264/AAC)
video-normalize raw.mp4 normalized.mp4

# Specific resolution
video-normalize raw.mp4 720p.mp4 -r 1280x720

# With audio normalization
video-normalize raw.mp4 normalized.mp4 -a

# Set framerate
video-normalize raw.mp4 30fps.mp4 --framerate 30

# Use preset
video-normalize raw.mp4 youtube.mp4 --preset youtube-1080p

# Custom quality
video-normalize raw.mp4 high-quality.mp4 --crf 18 --preset slow
```

**Presets:**
- `youtube-1080p` - 1920x1080, 30fps, CRF 21
- `youtube-720p` - 1280x720, 30fps, CRF 23
- `web-friendly` - 1280x720, 30fps, fast encode

**Quality settings:**
- CRF (Constant Rate Factor): 18-28 (lower = better quality)
- Preset: fast, medium, slow (slower = better compression)

### video-prepare

Prepare video for publishing with metadata and optimization.

```bash
# Add metadata
video-prepare game.mp4 published.mp4 \
  -t "Championship Game" \
  -a "Sports Team" \
  -d "2026-01-13"

# Enable fast start for web streaming
video-prepare game.mp4 web.mp4 --faststart

# Extract thumbnail
video-prepare game.mp4 final.mp4 --thumbnail 00:05:30

# Strip all metadata
video-prepare raw.mp4 clean.mp4 --strip-metadata

# Combine options
video-prepare game.mp4 published.mp4 \
  -t "Big Game" \
  --faststart \
  --thumbnail 00:10:00
```

**Features:**
- Lossless metadata updates (stream copy)
- Fast start optimization for web streaming
- Thumbnail extraction at specified time
- Metadata stripping for privacy

## Common Workflows

### 1. Process Raw Sports Footage

Full workflow from raw footage to published video:

```bash
# Step 1: Inspect the raw footage
video-info raw-footage.mp4

# Step 2: Trim to relevant segments
video-trim raw-footage.mp4 half1.mp4 00:00:00 00:45:00
video-trim raw-footage.mp4 half2.mp4 00:45:00 00:45:00

# Step 3: Combine segments
video-combine game-full.mp4 half1.mp4 half2.mp4

# Step 4: Normalize for publishing
video-normalize game-full.mp4 game-normalized.mp4 --preset youtube-1080p

# Step 5: Add metadata and prepare
video-prepare game-normalized.mp4 game-final.mp4 \
  -t "Championship Game 2026" \
  -a "Sports Team" \
  -d "2026-01-13" \
  --faststart \
  --thumbnail 00:05:00

# Clean up intermediate files
rm half1.mp4 half2.mp4 game-full.mp4 game-normalized.mp4
```

### 2. Extract and Publish Highlights

```bash
# Extract multiple highlights
video-trim game.mp4 goal1.mp4 00:12:30 00:00:15
video-trim game.mp4 goal2.mp4 00:38:45 00:00:20
video-trim game.mp4 goal3.mp4 01:15:20 00:00:18

# Combine highlights
video-combine highlights.mp4 goal1.mp4 goal2.mp4 goal3.mp4

# Prepare for social media (square crop)
video-crop highlights.mp4 highlights-square.mp4 --preset center-1:1

# Add metadata
video-prepare highlights-square.mp4 highlights-final.mp4 \
  -t "Game Highlights" \
  --faststart
```

### 3. Multi-Camera Processing

```bash
# Extract same time range from multiple cameras
video-trim camera1-raw.mp4 camera1-game.mp4 00:10:00 02:00:00
video-trim camera2-raw.mp4 camera2-game.mp4 00:10:00 02:00:00

# Crop each camera's view
video-crop camera1-game.mp4 camera1-main.mp4 --preset left-half
video-crop camera2-game.mp4 camera2-wide.mp4 --preset center-16:9

# Normalize both to same specs
video-normalize camera1-main.mp4 camera1-final.mp4 --preset youtube-1080p
video-normalize camera2-wide.mp4 camera2-final.mp4 --preset youtube-1080p
```

### 4. Batch Processing

```bash
# Process all MP4 files in a directory
for file in *.mp4; do
  video-normalize "$file" "normalized/${file}"
done

# Extract same segment from multiple files
for file in game*.mp4; do
  video-trim "$file" "highlights/${file}" 00:15:30 00:05:00
done

# Add metadata to multiple files
for file in video*.mp4; do
  video-prepare "$file" "final/${file}" \
    -t "Game Recording" \
    -d "2026-01-13" \
    --faststart
done
```

## Tips and Best Practices

### Performance

1. **Use lossless operations when possible**: `video-trim`, `video-combine`, and `video-prepare` (without filters) use stream copy for instant processing.

2. **Trim before normalizing**: Extract segments first, then normalize only what you need.

3. **Normalize once**: Normalize after all lossless operations (trim, combine) are complete.

4. **Batch similar operations**: Process multiple files with the same settings in parallel.

### Quality

1. **Preserve originals**: Always keep original footage; work with copies.

2. **Minimize re-encoding**: Each re-encode loses quality. Plan your workflow to re-encode once.

3. **Use appropriate CRF**: 
   - CRF 18-21: Near-lossless, large files
   - CRF 23: Good quality, standard
   - CRF 28: Lower quality, smaller files

4. **Match source resolution**: Don't upscale; normalize to source resolution or lower.

### Organization

1. **Use descriptive filenames**: Include date, event, camera, and version.
   ```
   2026-01-13_championship_camera1_raw.mp4
   2026-01-13_championship_camera1_normalized.mp4
   2026-01-13_championship_highlights.mp4
   ```

2. **Create directory structure**:
   ```
   project/
   ├── raw/          # Original footage
   ├── trimmed/      # Extracted segments
   ├── combined/     # Concatenated files
   ├── normalized/   # Processed files
   └── final/        # Published files
   ```

3. **Document processing**: Keep notes on settings used.

### Compatibility

1. **Check codecs before combining**: Use `video-info` to verify files have matching codecs.

2. **Normalize incompatible files**: Use same preset to ensure compatibility.

3. **Test on target platform**: Verify output works on intended playback platform.

### Troubleshooting

**Problem**: "Output file starts before requested time"
- **Solution**: This is normal with stream copy (keyframe limitation). For frame-accurate cuts, re-encode.

**Problem**: "Cannot combine files - different codecs"
- **Solution**: Normalize all files with the same preset first.

**Problem**: "Audio out of sync"
- **Solution**: Ensure all source files have same framerate. Check with `video-info`.

**Problem**: "File size too large"
- **Solution**: Increase CRF value (lower quality), or use faster preset.

## Advanced Examples

### Custom Encoding Settings

```bash
# High-quality archive
video-normalize raw.mp4 archive.mp4 --crf 18 --preset slow

# Fast preview
video-normalize raw.mp4 preview.mp4 --crf 28 --preset ultrafast

# Web-optimized with custom resolution
video-normalize raw.mp4 web.mp4 -r 1280x720 --framerate 30 --crf 23
```

### Using with File Lists

Create `process-list.txt`:
```
/games/2026-01-13/camera1.mp4
/games/2026-01-13/camera2.mp4
/games/2026-01-14/camera1.mp4
```

Process:
```bash
while IFS= read -r file; do
  basename=$(basename "$file" .mp4)
  video-normalize "$file" "output/${basename}-normalized.mp4"
done < process-list.txt
```

### Pipeline with Verification

```bash
#!/bin/bash
set -euo pipefail

INPUT="raw-game.mp4"
OUTPUT="published-game.mp4"

# Verify input exists
if [[ ! -f "$INPUT" ]]; then
  echo "Error: Input file not found"
  exit 1
fi

# Show input info
echo "Processing: $INPUT"
video-info "$INPUT"

# Process
video-trim "$INPUT" "trimmed.mp4" 00:05:00 01:30:00
video-normalize "trimmed.mp4" "normalized.mp4" --preset youtube-1080p
video-prepare "normalized.mp4" "$OUTPUT" \
  -t "Game Recording" \
  --faststart

# Verify output
if [[ -f "$OUTPUT" ]]; then
  echo "Success! Output file:"
  video-info "$OUTPUT"
else
  echo "Error: Output file not created"
  exit 1
fi

# Cleanup
rm trimmed.mp4 normalized.mp4
```

## Additional Resources

- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [FFmpeg Wiki](https://trac.ffmpeg.org/wiki)
- [H.264 Encoding Guide](https://trac.ffmpeg.org/wiki/Encode/H.264)

## Support

For issues or questions:
- Check script help: `<script> --help`
- View video info: `video-info --verbose <file>`
- Review FFmpeg logs for detailed error messages

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.
