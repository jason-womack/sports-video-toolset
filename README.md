# sports-video-toolset

A collection of modular, reliable video‑processing scripts designed for high‑volume sports footage. Includes tools for trimming, combining, cropping, normalizing, and preparing game recordings for publishing. Built for speed, zero‑reencode workflows, predictable output, and repeatable processing across multiple camera formats.

## Features

- **Lossless Operations**: Trim and combine videos using stream copy for instant, zero-quality-loss processing
- **Modular Design**: Individual scripts for specific tasks that can be chained together
- **Portable Shell Scripts**: POSIX-compatible bash scripts that work across Linux and macOS
- **Comprehensive Documentation**: Clear usage examples and workflow guides
- **Safe Defaults**: Prevents accidental overwrites and validates inputs
- **Predictable Output**: Consistent results with standard codecs and containers

## Quick Start

```bash
# Clone the repository
git clone https://github.com/jason-womack/sports-video-toolset.git
cd sports-video-toolset

# Make scripts executable (if needed)
chmod +x bin/*

# Get video information
./bin/video-info game.mp4

# Trim a highlight clip (lossless)
./bin/video-trim game.mp4 highlight.mp4 00:15:30 00:02:00

# Combine multiple segments
./bin/video-combine full-game.mp4 quarter1.mp4 quarter2.mp4 quarter3.mp4

# Normalize for publishing
./bin/video-normalize raw.mp4 web-ready.mp4 --preset youtube-1080p

# Prepare with metadata
./bin/video-prepare final.mp4 published.mp4 -t "Championship Game" --faststart
```

## Tools

| Tool | Purpose | Speed |
|------|---------|-------|
| **video-info** | Display video file information | Instant |
| **video-trim** | Extract segments by time range | Instant (lossless) |
| **video-combine** | Concatenate multiple videos | Instant (lossless) |
| **video-crop** | Crop video to specific dimensions | Re-encode required |
| **video-normalize** | Standardize codec/format for platforms | Re-encode required |
| **video-prepare** | Add metadata, optimize for web | Instant (lossless) |

## Prerequisites

- **ffmpeg** (4.0 or later)
- **bash** (4.0 or later)

Install on your system:

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# macOS with Homebrew
brew install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg
```

## Documentation

- **[Usage Guide](docs/USAGE.md)**: Comprehensive documentation with examples
- **[Contributing Guide](docs/CONTRIBUTING.md)**: Guidelines for contributors
- **[Example Workflows](examples/)**: Ready-to-use workflow scripts

## Example Workflows

### Complete Publishing Workflow

```bash
# 1. Inspect raw footage
video-info raw-footage.mp4

# 2. Trim to relevant content (lossless, instant)
video-trim raw-footage.mp4 game.mp4 00:05:00 02:00:00

# 3. Normalize for YouTube
video-normalize game.mp4 game-normalized.mp4 --preset youtube-1080p

# 4. Add metadata and optimize
video-prepare game-normalized.mp4 published.mp4 \
  -t "Championship Game 2026" \
  --faststart \
  --thumbnail 00:10:00
```

### Extract Highlight Clips

```bash
# Extract multiple highlights
video-trim game.mp4 goal1.mp4 00:12:30 00:00:15
video-trim game.mp4 goal2.mp4 00:38:45 00:00:20
video-trim game.mp4 goal3.mp4 01:15:20 00:00:18

# Combine into highlight reel
video-combine highlights.mp4 goal1.mp4 goal2.mp4 goal3.mp4

# Prepare for social media
video-prepare highlights.mp4 highlights-final.mp4 -t "Game Highlights" --faststart
```

See [examples/](examples/) for complete workflow scripts.

## Project Structure

```
sports-video-toolset/
├── bin/                    # Executable scripts
│   ├── video-trim          # Losslessly trim video segments
│   ├── video-combine       # Concatenate multiple videos
│   ├── video-crop          # Crop video dimensions
│   ├── video-normalize     # Normalize video for platforms
│   ├── video-prepare       # Add metadata, optimize for web
│   └── video-info          # Display video information
├── lib/                    # Shared library functions
│   └── video-utils.sh      # Core utility functions
├── docs/                   # Documentation
│   ├── USAGE.md           # Comprehensive usage guide
│   └── CONTRIBUTING.md    # Contributing guidelines
├── examples/              # Example workflows
│   ├── workflow-youtube.sh       # Complete YouTube workflow
│   ├── workflow-highlights.sh    # Highlight extraction
│   └── segments-list.txt         # Example file list
└── README.md              # This file
```

## Design Principles

1. **Speed First**: Use lossless stream copy operations whenever possible
2. **Modular**: Each script does one thing well and can be combined
3. **Safe Defaults**: Prevent accidental overwrites, validate all inputs
4. **Clear Output**: Informative messages with color-coded logging
5. **Portable**: Works across Linux and macOS with standard tools
6. **Maintainable**: Clear code structure, comprehensive documentation

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

## License

This project is available for use in processing sports video footage.

## Support

- Check the [Usage Guide](docs/USAGE.md) for detailed documentation
- Use `<script> --help` for script-specific help
- Use `video-info --verbose <file>` to diagnose file issues

## Acknowledgments

Built with [FFmpeg](https://ffmpeg.org/), the industry-standard multimedia framework.
