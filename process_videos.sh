#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# === DEFAULTS ===
INPUT_DIR="."
FILTER_AUDIO=false
DEBUG=false

log()   { echo "[INFO] $*"; }
debug() { [ "$DEBUG" = true ] && echo "[DEBUG] $*" >&2; }

# === FLAG PARSING ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter-audio) FILTER_AUDIO=true; shift ;;
    --debug|-d) DEBUG=true; shift ;;
    *) INPUT_DIR="$1"; shift ;;
  esac
done

# Enable full shell tracing when -d is used
if [[ "$DEBUG" = true ]]; then
  set -x
fi

# === NORMALIZATION ===
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

  if (( ${#RAW_FILES[@]} == 0 )); then
    debug "No DJI/VID files found for normalization"
    return
  fi

  prefixes=()
  for f in "${RAW_FILES[@]}"; do
    base=$(basename "$f")
    if [[ "$base" == DJI_* ]]; then
      p=$(echo "$base" | cut -d_ -f1-2)
    else
      p=$(echo "$base" | cut -d_ -f1-3)
    fi
    prefixes+=("$p")
  done

  unique=($(printf "%s\n" "${prefixes[@]}" | sort -u))
  if (( ${#unique[@]} == 1 )); then
    log "All files share prefix '${unique[0]}'. Treating current directory as normalized."
    return
  fi

  log "Normalizing raw files..."
  for f in "${RAW_FILES[@]}"; do
    base=$(basename "$f")
    if [[ "$base" == DJI_* ]]; then
      prefix=$(echo "$base" | cut -d_ -f1-2)
    else
      prefix=$(echo "$base" | cut -d_ -f1-3)
    fi
    mkdir -p "$INPUT_DIR/$prefix"
    mv "$f" "$INPUT_DIR/$prefix/$base"
  done
}

# === PROCESS FOLDER ===
process_folder() {
  folder="$1"
  log "process_folder called for: $folder"
  cd "$folder"

  prefix=$(basename "$(pwd)")
  combined="${prefix}_combined.mp4"
  preview="${prefix}_preview.mp4"
  final="${prefix}_final.mp4"
  cfg="${prefix}.cfg"

  # Create cfg if missing
  if [[ ! -f "$cfg" ]]; then
    cat > "$cfg" <<EOF
left-crop=0.0
right-crop=0.0
bottom-crop=0.0
start-trim=0.0
end-trim=0.0
preview=true
preview-length=10
EOF
    log "Created default config: $cfg"
  fi

  echo
  echo "[INFO] Edit config: $cfg"
  ${EDITOR:-nano} "$cfg"
  read -r -p "Press ENTER to continue..." _

  # Parse cfg
  declare -A CFG
  while IFS='=' read -r key value; do
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')
    CFG["$key"]="$value"
  done < "$cfg"

  left="${CFG[left-crop]:-0}"
  right="${CFG[right-crop]:-0}"
  bottom="${CFG[bottom-crop]:-0}"
  start="${CFG[start-trim]:-0}"
  end="${CFG[end-trim]:-0}"
  do_preview="${CFG[preview]:-true}"
  preview_len="${CFG[preview-length]:-10}"

  debug "Config: left=$left right=$right bottom=$bottom start=$start end=$end preview=$do_preview preview_len=$preview_len"

  # Determine if cropping is needed
  no_crop=true
  if (( $(echo "$left > 0" | bc -l) )) || \
     (( $(echo "$right > 0" | bc -l) )) || \
     (( $(echo "$bottom > 0" | bc -l) )); then
    no_crop=false
  fi
  debug "no_crop=$no_crop"

  # Detect source clips
  printf "%s\n" DJI_*.[Mm][Pp]4 DJI_*.[Mm][Oo][Vv] VID_*.[Mm][Pp]4 VID_*.[Mm][Oo][Vv] \
    | grep -v '\*' | sort > input.txt

  has_sources=false
  [[ -s input.txt ]] && has_sources=true

  # === FAST PATH (no crop, has sources, no combined) ===
  if [[ "$no_crop" == true && "$has_sources" == true && ! -f "$combined" ]]; then
    log "Fast path: no crop → generating final directly without combined"

    > concat.txt
    total_duration=0

    while read -r f; do
      echo "file '$PWD/$f'" >> concat.txt

      # Get duration of each file individually
      d=$(ffprobe -v error -select_streams v:0 \
          -show_entries format=duration \
          -of csv=p=0 "$f")

      # If ffprobe fails, treat as zero instead of N/A
      [[ "$d" == "N/A" || -z "$d" ]] && d=0

      total_duration=$(awk "BEGIN {print $total_duration + $d}")
    done < input.txt

    trim_duration=$(awk "BEGIN {print $total_duration - $start - $end}")
    (( $(echo "$trim_duration < 0" | bc -l) )) && trim_duration=0

    # Generate final
    ffmpeg -y -ss "$start" -f concat -safe 0 -i concat.txt \
      -t "$trim_duration" -c copy -movflags +faststart "$final"

    # Generate preview from final
    if [[ "${do_preview,,}" == "true" ]]; then
      log "Generating preview from final → $preview"
      ffmpeg -y -ss 0 -i "$final" \
        -t "$preview_len" \
        -c:v h264_videotoolbox -b:v 60000000 \
        "$preview"
    fi

    cd - >/dev/null
    return
  fi


  # === COMBINED EXISTS ===
  if [[ -f "$combined" ]]; then
    log "Using existing combined file: $combined"
  else
    # === NEED TO CREATE COMBINED ===
    if [[ "$has_sources" == false ]]; then
      log "No combined file and no source clips. Nothing to do."
      cd - >/dev/null
      return
    fi

    log "Combining source clips → $combined"

    > concat.txt
    while read -r f; do
      echo "file '$PWD/$f'" >> concat.txt
    done < input.txt

    if [[ "$no_crop" == true ]]; then
      ffmpeg -y -f concat -safe 0 -i concat.txt -c copy "$combined"
    else
      cmd=(ffmpeg -y -f concat -safe 0 -i concat.txt -map 0:v:0 -map 0:a:0 \
            -c:v h264_videotoolbox -b:v 60000000)
      $FILTER_AUDIO && cmd+=(-af "highpass=f=200,lowpass=f=3000")
      cmd+=("$combined")
      "${cmd[@]}"
    fi
  fi

  # Get video info
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$combined")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$combined")
  duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$combined")

  debug "Video: ${width}x${height}, duration=$duration"

  # Crop math
  crop_left_px=$(awk "BEGIN {print int($width * $left / 2)}")
  crop_right_px=$(awk "BEGIN {print int($width * $right / 2)}")
  crop_bottom_px=$(awk "BEGIN {print int($height * $bottom / 2)}")

  remaining_width=$((width - crop_left_px - crop_right_px))
  ideal_height=$(awk "BEGIN {print int($remaining_width / 1.77777777778)}")
  crop_top_px=$((height - crop_bottom_px - ideal_height))
  (( crop_top_px < 0 )) && crop_top_px=0

  crop_w=$((width - crop_left_px - crop_right_px))
  crop_h=$((height - crop_top_px - crop_bottom_px))

  debug "Crop px: left=$crop_left_px right=$crop_right_px top=$crop_top_px bottom=$crop_bottom_px w=$crop_w h=$crop_h"

  # Preview or final
  if [[ "${do_preview,,}" == "true" ]]; then
    log "Generating preview → $preview"
    ffmpeg -y -ss "$start" -i "$combined" \
      -vf "crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px" \
      -t "$preview_len" -c:v h264_videotoolbox -b:v 60000000 "$preview"
  else
    trim_duration=$(awk "BEGIN {print $duration - $start - $end}")
    log "Generating final → $final (trim_duration=$trim_duration)"

    if [[ "$no_crop" == true ]]; then
      ffmpeg -y -ss "$start" -i "$combined" \
        -t "$trim_duration" -c copy -movflags +faststart "$final"
      rm -f "$combined"
    else
      ffmpeg -y -ss "$start" -i "$combined" \
        -vf "crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px,
             scale=3840:2160:flags=lanczos,
             unsharp=luma_msize_x=5:luma_msize_y=5:luma_amount=0.5,
             hqdn3d=10" \
        -t "$trim_duration" \
        -c:v h264_videotoolbox -b:v 60000000 \
        -movflags +faststart \
        -c:a aac -b:a 384k -ar 48000 \
        "$final"
    fi
  fi

  cd - >/dev/null
}

# === MAIN ===
normalize_files
process_folder "$INPUT_DIR"
echo "[INFO] All rendering jobs completed."
