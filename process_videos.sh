#!/usr/bin/env bash
set -euox pipefail
shopt -s nullglob

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

  RAW_FILES=()
  for pattern in \
      "$INPUT_DIR"/DJI_*.[Mm][Pp]4 \
      "$INPUT_DIR"/DJI_*.[Mm][Oo][Vv] \
      "$INPUT_DIR"/VID_*.[Mm][Pp]4 \
      "$INPUT_DIR"/VID_*.[Mm][Oo][Vv]; do

    for f in $pattern; do
      [[ -f "$f" ]] && RAW_FILES+=("$f")
    done
  done

  NORMALIZED_FOLDERS=()
  for pattern in "$INPUT_DIR"/DJI_* "$INPUT_DIR"/VID_*; do
    for d in $pattern; do
      [[ -d "$d" ]] && NORMALIZED_FOLDERS+=("$d")
    done
  done

  HAS_RAW=false
  HAS_FOLDERS=false
  (( ${#RAW_FILES[@]} > 0 )) && HAS_RAW=true
  (( ${#NORMALIZED_FOLDERS[@]} > 0 )) && HAS_FOLDERS=true

  # === NEW RULE: If all RAW files share the same prefix → treat current folder as normalized
  if [[ "$HAS_RAW" == true ]]; then
    prefixes=()

    for f in "${RAW_FILES[@]}"; do
      base=$(basename "$f")

      if [[ "$base" == DJI_* ]]; then
        p=$(echo "$base" | cut -d_ -f1-2)
      elif [[ "$base" == VID_* ]]; then
        p=$(echo "$base" | cut -d_ -f1-3)
      else
        p=$(echo "$base" | cut -d_ -f1-2)
      fi

      prefixes+=("$p")
    done

    unique_prefixes=($(printf "%s\n" "${prefixes[@]}" | sort -u))

    if (( ${#unique_prefixes[@]} == 1 )); then
      log "All files share prefix '${unique_prefixes[0]}'. Treating current directory as normalized."
      return
    fi
  fi

  # === CASE 1: Raw files exist → normalize
  if [[ "$HAS_RAW" == true ]]; then
    log "Raw DJI/VID files detected. Normalizing..."

    for f in "${RAW_FILES[@]}"; do
      base=$(basename "$f")

      if [[ "$base" == DJI_* ]]; then
        prefix=$(echo "$base" | cut -d_ -f1-2)
      elif [[ "$base" == VID_* ]]; then
        prefix=$(echo "$base" | cut -d_ -f1-3)
      else
        prefix=$(echo "$base" | cut -d_ -f1-2)
      fi

      target="$INPUT_DIR/$prefix"
      mkdir -p "$target"

      mv "$f" "$target/$base"
      debug "Moved $base → $target/"
    done

    return
  fi

  # === CASE 2: Already normalized
  if [[ "$HAS_FOLDERS" == true ]]; then
    debug "Skipping normalization (already normalized)"
    return
  fi

  debug "No DJI/VID files found for normalization"
}

# === PROCESS EACH PREFIX FOLDER ===
process_folder() {
  folder="$1"
  cd "$folder"
  log "Processing folder: $folder"

  ls DJI_*.[Mm][Pp]4 DJI_*.[Mm][Oo][Vv] VID_*.[Mm][Pp]4 VID_*.[Mm][Oo][Vv] 2>/dev/null | sort > input.txt
  [[ -s input.txt ]] || { log "No input files in $folder, skipping."; cd - >/dev/null; return; }

  prefix=$(basename "$(pwd)")
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

  # === ALWAYS PAUSE HERE ===
  echo
  echo "[INFO] Config ready for $folder: $cfg"
  echo "[INFO] Edit start-trim and end-trim values now."
  ${EDITOR:-nano} "$cfg"
  read -r -p "Press ENTER when ready to render..." _

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

  # === DETERMINE ZERO-REENCODE PATH ===
  no_crop=false
  if [[ "$left_crop" == 0* && "$right_crop" == 0* && "$bottom_crop" == 0* ]]; then
      no_crop=true
  fi

  # === GET PER-FILE DURATIONS ===
  mapfile -t FILES < input.txt
  declare -A DUR
  for f in "${FILES[@]}"; do
    DUR["$f"]=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  done

  # === BUILD concat_trimmed.txt WHEN no_crop=true ===
  if [[ "$no_crop" == true ]]; then
    log "Building concat_trimmed.txt for zero-reencode concat+trim..."

    total=0
    remaining_start="$start_trim"
    remaining_end="$end_trim"

    > concat_trimmed.txt

    # Pass 1: handle start_trim
    for f in "${FILES[@]}"; do
      dur=${DUR["$f"]}

      if (( $(echo "$remaining_start >= $dur" | bc -l) )); then
        remaining_start=$(echo "$remaining_start - $dur" | bc -l)
        continue
      fi

      echo "file '$PWD/$f'" >> concat_trimmed.txt
      echo "inpoint $remaining_start" >> concat_trimmed.txt
      break
    done

    # Pass 2: middle files
    start_found=false
    for f in "${FILES[@]}"; do
      if [[ "$start_found" == false ]]; then
        [[ "$f" == "${FILES[0]}" ]] && start_found=true
        continue
      fi
      echo "file '$PWD/$f'" >> concat_trimmed.txt
    done

    # Pass 3: apply end_trim to last file
    last="${FILES[-1]}"
    last_dur=${DUR["$last"]}
    outpoint=$(echo "$last_dur - $end_trim" | bc -l)
    echo "outpoint $outpoint" >> concat_trimmed.txt

    # === SINGLE-PASS CONCAT+TRIM ===
    log "Running zero-reencode concat+trim → $final_out"
    ffmpeg -y -f concat -safe 0 -i concat_trimmed.txt -c copy "$final_out"
    cd - >/dev/null
    return
  fi

  # === NON-ZERO-CROP PATH (existing behavior) ===
  # Combine first
  out="${prefix}_combined.mp4"
  if [[ ! -f "$out" ]]; then
    log "Combining files (reencode) → $out"
    cmd=(ffmpeg -y -f concat -safe 0 -analyzeduration 100000000 -probesize 100000000 \
          -i <(sed "s|^|file '$PWD/|" input.txt | sed "s|$|'|") \
          -map 0:v:0 -map 0:a:0 -c:v h264_videotoolbox -b:v 60000000)
    $FILTER_AUDIO && cmd+=(-af "highpass=f=200,lowpass=f=3000")
    cmd+=("$out")
    "${cmd[@]}"
  fi

  # Get dimensions
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$out")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$out")
  duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")

  crop_left_px=$(awk "BEGIN {print int($width * $left_crop / 2)}")
  crop_right_px=$(awk "BEGIN {print int($width * $right_crop / 2)}")
  crop_bottom_px=$(awk "BEGIN {print int($height * $bottom_crop / 2)}")

  remaining_width=$((width - crop_left_px - crop_right_px))
  ideal_height=$(awk "BEGIN {print int($remaining_width / 1.77777777778)}")
  crop_top_px=$((height - crop_bottom_px - ideal_height))
  (( crop_top_px < 0 )) && crop_top_px=0

  crop_w=$((width - crop_left_px - crop_right_px))
  crop_h=$((height - crop_top_px - crop_bottom_px))

  trim_duration=$(awk "BEGIN {print $duration - $start_trim - $end_trim}")

  log "Final render path (crop/zoom) → $final_out"
  ffmpeg -y -ss "$start_trim" -i "$out" \
    -vf "crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px,
         scale=3840:2160:flags=lanczos,
         unsharp=luma_msize_x=5:luma_msize_y=5:luma_amount=0.5,
         hqdn3d=10" \
    -t "$trim_duration" \
    -c:v h264_videotoolbox -b:v 60000000 \
    -movflags +faststart \
    -c:a aac -b:a 384k -ar 48000 \
    "$final_out"

  cd - >/dev/null
}

# === MAIN ===
normalize_files

log "Processing folders..."
FILES=("$INPUT_DIR"/DJI_*.[Mm][Pp]4 "$INPUT_DIR"/DJI_*.[Mm][Oo][Vv] "$INPUT_DIR"/VID_*.[Mm][Pp]4 "$INPUT_DIR"/VID_*.[Mm][Oo][Vv])

if (( ${#FILES[@]} > 0 )); then
  echo "[INFO] Single normalized folder detected: $INPUT_DIR"
  process_folder "$INPUT_DIR"
else
  echo "[INFO] Batch mode: processing all DJI_/VID_ subfolders"
  for dir in "$INPUT_DIR"/DJI_* "$INPUT_DIR"/VID_*; do
    [[ -d "$dir" ]] || continue
    process_folder "$dir" &
  done
fi

wait
echo "All rendering jobs completed."
