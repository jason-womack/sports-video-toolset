#!/usr/bin/env bash
set -euox pipefail

# === DEFAULTS ===
SKIP_NORMALIZATION=false
INPUT_DIR="."
PREVIEW=false
PREVIEW_DURATION=10
FILTER_AUDIO=false
DEBUG=false
DRY_RUN=false

# === FLAG PARSING ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-normalization)
      SKIP_NORMALIZATION=true
      shift
      ;;
    --preview)
      PREVIEW=true
      PREVIEW_DURATION="${2:-10}"
      shift 2
      ;;
    --filter-audio)
      FILTER_AUDIO=true
      shift
      ;;
    --debug|-d|--verbose|-v)
      DEBUG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      INPUT_DIR="$1"
      shift
      ;;
  esac
done

log()   { echo "[INFO] $*"; }
debug() { $DEBUG && echo "[DEBUG] $*" >&2; }

# === NORMALIZE FILES INTO PREFIX FOLDERS ===
normalize_files() {
  log "Detecting normalization..."
  base_name=$(basename "$INPUT_DIR")
  normalized_path="$INPUT_DIR/$base_name"

  if [[ "$SKIP_NORMALIZATION" != true && -d "$normalized_path" ]]; then
      debug "Auto-detected normalized folder: $normalized_path"
      input_dir="$normalized_path"
      SKIP_NORMALIZATION=true
  fi

  if [[ "$SKIP_NORMALIZATION" != true ]]; then
    log "Starting normalization..."
    # <<< CHANGED: include MOV files, case-insensitive
    find "$INPUT_DIR" -type f \( -iname 'DJI_*.MP4' -o -iname 'DJI_*.MOV' \) | while read -r f; do
      base=$(basename "$f")
      prefix=$(echo "$base" | cut -d_ -f1-2)
      target="$INPUT_DIR/$prefix"
      mkdir -p "$target"

      if [[ -e "$target/$base" ]]; then
        log "SKIP: $base already exists in $target/"
        continue
      fi

      if $DRY_RUN; then
        log "DRY-RUN: Would move $base → $target/"
      else
        mv "$f" "$target/$base"
        debug "Moved $base → $target/"
      fi
    done
  else
    debug "Skipping normalization (already normalized)"
  fi
}

# === PROCESS EACH PREFIX FOLDER ===
process_folder() {
  folder="$1"
  cd "$folder"
  log "Processing folder: $folder"

  # <<< CHANGED: include MOV files in input list
  shopt -s nullglob
  ls DJI_*.MP4 DJI_*.MOV 2>/dev/null | sort > input.txt
  shopt -u nullglob
  [[ -s input.txt ]] || { log "No input files in $folder, skipping."; cd - >/dev/null; return; }

  # === CONCATENATE FILES ===
  > concat.txt
  while read -r f; do
    echo "file '$PWD/$f'" >> concat.txt
  done < input.txt

  prefix=$(basename "$(pwd)")
  out="${prefix}_combined.mp4"
  preview_out="${prefix}_preview.mp4"
  final_out="${prefix}_final.mp4"
  cfg="${prefix}.cfg"

  # === CREATE DEFAULT CONFIG IF MISSING ===
  if [[ ! -f "$cfg" ]]; then
    cat > "$cfg" <<EOF
left-crop=0.0
bottom-crop=0.0
right-crop=0.0
start-trim=0.0
end-trim=0.0
preview=true
EOF
    log "Created default config: $cfg"
  fi

  # === PARSE CONFIG ===
  declare -A CFG
  while IFS='=' read -r key value; do
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')
    CFG["$key"]="$value"
  done < "$cfg"

  left_crop="${CFG[left-crop]:-0.0}"
  bottom_crop="${CFG[bottom-crop]:-0.0}"
  right_crop="${CFG[right-crop]:-0.0}"
  start_trim="${CFG[start-trim]:-0.0}"
  end_trim="${CFG[end-trim]:-0.0}"
  cfg_preview="${CFG[preview]:-false}"

  # === COMBINE FILES ===
  cmd=(ffmpeg -y -f concat -safe 0 -analyzeduration 100000000 -probesize 100000000 -i concat.txt -map 0:v:0 -map 0:a:0 -c:v h264_videotoolbox -b:v 60000000)
  $FILTER_AUDIO && cmd+=(-af "highpass=f=200,lowpass=f=3000")
  cmd+=("$out")

  if [[ -f "$out" ]]; then
    log "SKIP: Combined file $out already exists. Skipping combine step."
  else
    log "Combining files into $out..."
    if $DRY_RUN; then
      log "DRY-RUN: ${cmd[*]}"
    else
      "${cmd[@]}"
    fi
  fi

  # === GET VIDEO DIMENSIONS ===
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$out")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$out")
  duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")

  log "Video Info: $width x $height - $duration"

  crop_left_px=$(awk "BEGIN {print int($width * $left_crop / 2)}")
  crop_right_px=$(awk "BEGIN {print int($width * $right_crop / 2)}")
  crop_bottom_px=$(awk "BEGIN {print int($height * $bottom_crop / 2)}")

  remaining_width=$((width - crop_left_px - crop_right_px))
  remaining_height=$((height - crop_bottom_px))
  ideal_height=$(awk "BEGIN {print int($remaining_width / 1.77777777778)}")
  crop_top_px=$((height - crop_bottom_px - ideal_height))
  (( crop_top_px < 0 )) && crop_top_px=0

  crop_w=$((width - crop_left_px - crop_right_px))
  crop_h=$((height - crop_top_px - crop_bottom_px))

  debug "Crop: left=$crop_left_px, right=$crop_right_px, top=$crop_top_px, bottom=$crop_bottom_px"
  debug "Trim: start=$start_trim, end=$end_trim"
  debug "Preview mode: $cfg_preview"
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

  # === PREVIEW OR FINAL RENDER ===
  if [[ "${cfg_preview,,}" == "true" ]]; then
    log "Generating preview ($PREVIEW_DURATION sec) → $preview_out"
    cmd=(ffmpeg -y -ss "$start_trim" -i "$out" \
         -vf "crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px" \
         -t "$PREVIEW_DURATION" -c:v h264_videotoolbox -b:v 60000000 -threads 12 "$preview_out")
    $DRY_RUN && log "DRY-RUN: ${cmd[*]}" || "${cmd[@]}"
  else
    trim_duration=$(awk "BEGIN {print $duration - $end_trim}")
    log "Rendering final output → $final_out"

    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    meta_comment="Zoomed crop from 4K source, rendered at 4K with sharpening and denoise. Timestamp: $timestamp"

    cmd=(ffmpeg -y -ss "$start_trim" -i "$out" \
         -vf "crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px,
              scale=3840:2160:flags=lanczos,
              unsharp=luma_msize_x=5:luma_msize_y=5:luma_amount=0.5,
              hqdn3d=10" \
         -to "$trim_duration" \
         -c:v h264_videotoolbox -b:v 60000000 \
         -movflags +faststart \
         -metadata comment="$meta_comment" \
         -c:a aac -b:a 384k -ar 48000 \
         -threads 12
         "$final_out")

    $DRY_RUN && log "DRY-RUN: ${cmd[*]}" || "${cmd[@]}"
  fi

  # === MANIFEST ===
  jq -n \
    --arg folder "$folder" \
    --arg output "$out" \
    --arg final_output "$final_out" \
    --arg preview "$cfg_preview" \
    --argjson preview_duration "$PREVIEW_DURATION" \
    --argjson left_crop "$left_crop" \
    --argjson right_crop "$right_crop" \
    --argjson bottom_crop "$bottom_crop" \
    --argjson start_trim "$start_trim" \
    --argjson end_trim "$end_trim" \
    --arg timestamp "$timestamp" \
    '{
      folder: $folder,
      output: $output,
      final_output: $final_output,
      preview: ($preview == "true"),
      preview_duration: $preview_duration,
      crop: {
        left: $left_crop,
        right: $right_crop,
        bottom: $bottom_crop
      },
      trim: {
        start: $start_trim,
        end: $end_trim
      },
      metadata: {
        comment: "Zoomed crop from 4K source, rendered at 4K with sharpening and denoise.",
        timestamp: $timestamp
      }
    }' > manifest.json

  cd - >/dev/null
}

# === MAIN ===
if [[ "$DRY_RUN" == true ]]; then
    debug "Dry-run: normalization would be skipped: $SKIP_NORMALIZATION"
fi

normalize_files

$DRY_RUN && { log "Dry-run complete. No files were moved or processed."; exit 0; }

log "Processing folders..."
shopt -s nullglob
# <<< CHANGED: include MOV files in detection
DJI_FILES=("$INPUT_DIR"/DJI_*.MP4 "$INPUT_DIR"/DJI_*.MOV)
shopt -u nullglob

if (( ${#DJI_FILES[@]} > 0 )); then
  # Normalized folder: contains DJI_*.MP4 or DJI_*.MOV files directly
  echo "[INFO] Single normalized folder detected: $INPUT_DIR"
  process_folder "$INPUT_DIR"
else
  echo "[INFO] Batch mode: process all DJI_* subfolders"
  for dir in "$INPUT_DIR"/DJI_*; do
    [[ -d "$dir" ]] || continue
    process_folder "$dir" &
  done
fi

wait
echo "All rendering jobs completed."