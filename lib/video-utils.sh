#!/usr/bin/env bash
# video-utils.sh - Core utility functions for video processing
# Provides reusable functions for lossless video operations

set -euo pipefail

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Check if ffmpeg is available
check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_error "ffmpeg is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Check if ffprobe is available
check_ffprobe() {
    if ! command -v ffprobe >/dev/null 2>&1; then
        log_error "ffprobe is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Validate input file exists and is readable
validate_input_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "Input file does not exist: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Input file is not readable: $file"
        return 1
    fi
    
    return 0
}

# Get video duration in seconds
get_duration() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$file"
}

# Get video codec
get_video_codec() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$file"
}

# Get audio codec
get_audio_codec() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$file"
}

# Get video resolution
get_resolution() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=s=x:p=0 "$file"
}

# Get video framerate
get_framerate() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -select_streams v:0 \
        -show_entries stream=r_frame_rate \
        -of default=noprint_wrappers=1:nokey=1 "$file"
}

# Parse time format (supports HH:MM:SS, MM:SS, or seconds)
parse_time() {
    local time_str="$1"
    echo "$time_str"
}

# Create output directory if it doesn't exist
ensure_output_dir() {
    local output_file="$1"
    local output_dir
    output_dir="$(dirname "$output_file")"
    
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir"
        log_info "Created output directory: $output_dir"
    fi
}

# Generate output filename with timestamp if file exists
generate_unique_filename() {
    local base_file="$1"
    
    if [[ ! -e "$base_file" ]]; then
        echo "$base_file"
        return 0
    fi
    
    local dir
    local base
    local ext
    dir="$(dirname "$base_file")"
    base="$(basename "$base_file")"
    
    if [[ "$base" =~ \. ]]; then
        ext="${base##*.}"
        base="${base%.*}"
    else
        ext=""
    fi
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    
    if [[ -n "$ext" ]]; then
        echo "${dir}/${base}_${timestamp}.${ext}"
    else
        echo "${dir}/${base}_${timestamp}"
    fi
}

# Display video information
show_video_info() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    log_info "Video information for: $file"
    echo "----------------------------------------"
    echo "Duration:    $(get_duration "$file") seconds"
    echo "Resolution:  $(get_resolution "$file")"
    echo "Framerate:   $(get_framerate "$file")"
    echo "Video codec: $(get_video_codec "$file")"
    echo "Audio codec: $(get_audio_codec "$file")"
    echo "----------------------------------------"
}

# Verify output file was created successfully
verify_output() {
    local output_file="$1"
    
    if [[ ! -f "$output_file" ]]; then
        log_error "Output file was not created: $output_file"
        return 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
    
    if [[ "$file_size" -eq 0 ]]; then
        log_error "Output file is empty: $output_file"
        return 1
    fi
    
    log_success "Output file created: $output_file ($(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size} bytes"))"
    return 0
}
