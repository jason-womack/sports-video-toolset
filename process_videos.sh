#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# === DEFAULTS ===
INPUT_DIR="."
DEBUG=false

log()   { echo "[INFO] $*"; }
debug() { [ "$DEBUG" = true ] && echo "[DEBUG] $*" >&2; }

# === FLAG PARSING ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug|-d) DEBUG=true; shift ;;
    *) INPUT_DIR="$1"; shift ;;
  esac
done

[[ "$DEBUG" = true ]] && set -x

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
  log "Processing folder: $folder"
  cd "$folder"

  prefix=$(basename "$(pwd)")
  combined="${prefix}_combined.mp4"
  preview="${prefix}_preview.mp4"
  final="${prefix}_final.mp4"
  cfg="${prefix}.cfg"

  # === CREATE CFG IF MISSING ===
  if [[ ! -f "$cfg" ]]; then
    cat > "$cfg" <<EOF
# === FILTER SLOTS ===
left-crop=0.0
right-crop=0.0
bottom-crop=0.0
start-trim=0.0
end-trim=0.0

preview=true
preview-length=10

default-scale=scale=in_range=tv:out_range=tv,scale=3840:2160:flags=lanczos
default-denoise=
default-sharpen=

additional-params=
EOF
    log "Created default config: $cfg"
  fi

  echo "[INFO] Edit config: $cfg"
  ${EDITOR:-nano} "$cfg"
  read -r -p "Press ENTER to continue..." _

  # === PARSE CFG ===
  declare -A CFG
  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^# ]] && continue
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

  default_scale="${CFG[default-scale]}"
  default_denoise="${CFG[default-denoise]}"
  default_sharpen="${CFG[default-sharpen]}"
  additional_params="${CFG[additional-params]:-}"

  # === DETECT SOURCE CLIPS ===
  printf "%s\n" DJI_*.[Mm][Pp]4 DJI_*.[Mm][Oo][Vv] VID_*.[Mm][Pp]4 VID_*.[Mm][Oo][Vv] \
    | grep -v '\*' | sort > input.txt

  has_sources=false
  [[ -s input.txt ]] && has_sources=true

  # === COMBINE STEP (C1) ===
  if [[ -f "$combined" ]]; then
    log "Combined file exists → skipping combine (C1)"
  else
    if [[ "$has_sources" == false ]]; then
      log "No source clips found."
      cd - >/dev/null
      return
    fi

    log "FAST COMBINE: HEVC/H.264 copy → $combined"

    > concat.txt
    while read -r f; do
      echo "file '$PWD/$f'" >> concat.txt
    done < input.txt

    ffmpeg -y -f concat -safe 0 -i concat.txt \
      -map 0:v -map "0:a?" \
      -c copy \
      "$combined"
  fi

  # === DETECT SOURCE CODEC ===
  codec=$(ffprobe -v error -select_streams v:0 \
          -show_entries stream=codec_name \
          -of csv=p=0 "$combined")

  log "Detected source codec: $codec"

  # === SELECT ENCODER BASED ON SOURCE ===
  case "$codec" in
    hevc)
      ENCODER="libx265"
      ENC_OPTS="-preset fast -crf 20 -tag:v hvc1 -x265-params bframes=0:colorprim=bt709:transfer=bt709:colormatrix=bt709:range=limited"
      HEVC_DOWNSCALE=true
      ;;
    h264)
      ENCODER="libx264"
      ENC_OPTS="-preset veryfast -crf 18 -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:range=limited"
      HEVC_DOWNSCALE=false
      ;;
    *)
      log "Unknown codec '$codec', falling back to libx264"
      ENCODER="libx264"
      ENC_OPTS="-preset veryfast -crf 18 -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:range=limited"
      HEVC_DOWNSCALE=false
      ;;
  esac

  log "Using encoder: $ENCODER $ENC_OPTS"

  # === VIDEO INFO ===
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$combined")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$combined")
  duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$combined")

  # === CROP MATH ===
  crop_left_px=$(awk "BEGIN {print int($width * $left / 2)}")
  crop_right_px=$(awk "BEGIN {print int($width * $right / 2)}")
  crop_bottom_px=$(awk "BEGIN {print int($height * $bottom / 2)}")

  remaining_width=$((width - crop_left_px - crop_right_px))
  ideal_height=$(awk "BEGIN {print int($remaining_width / 1.77777777778)}")
  crop_top_px=$((height - crop_bottom_px - ideal_height))
  (( crop_top_px < 0 )) && crop_top_px=0

  crop_w=$((width - crop_left_px - crop_right_px))
  crop_h=$((height - crop_top_px - crop_bottom_px))

  # === FILTER SLOTS ===
  slot_crop="crop=w=$crop_w:h=$crop_h:x=$crop_left_px:y=$crop_top_px"
  slot_scale="$default_scale"
  slot_denoise="$default_denoise"
  slot_texture=""
  slot_sharpen="$default_sharpen"
  slot_color=""
  slot_look=""

  IFS=',' read -ra USER_FILTERS <<< "$additional_params"
  for f in "${USER_FILTERS[@]}"; do
    [[ -z "$f" ]] && continue
    case "$f" in
      crop=*)      slot_crop="$f" ;;
      scale=*)     slot_scale="$f" ;;
      hqdn3d=*|nlmeans=*|vaguedenoiser=*) slot_denoise="$f" ;;
      unsharp=*|sharpen=*) slot_sharpen="$f" ;;
      eq=*|curves=*|colorbalance=*|hue=*|gamma=*) slot_color="$f" ;;
      lut=*|vignette=*|lenscorrection=*) slot_look="$f" ;;
      smartblur=*|guided=*|bilateral=*|*) slot_texture="$slot_texture,$f" ;;
    esac
  done

  slot_texture="${slot_texture#,}"

  # === BUILD VF CHAIN ===
  if [[ "$HEVC_DOWNSCALE" == true ]]; then
    # H.265 path: downscale → force 8-bit → filter → upscale → force 8-bit
    vf_chain="$slot_crop,scale=1920:1080,format=yuv420p,$slot_denoise"
    [[ -n "$slot_texture" ]] && vf_chain="$vf_chain,$slot_texture"
    [[ -n "$slot_sharpen" ]] && vf_chain="$vf_chain,$slot_sharpen"
    [[ -n "$slot_color" ]] && vf_chain="$vf_chain,$slot_color"
    [[ -n "$slot_look" ]] && vf_chain="$vf_chain,$slot_look"
    vf_chain="$vf_chain,scale=in_range=tv:out_range=tv,scale=3840:2160:flags=lanczos,format=yuv420p"
  else
    # H.264 path: full-res filter chain → force 8-bit
    vf_chain="$slot_crop,$slot_scale,format=yuv420p,$slot_denoise"
    [[ -n "$slot_texture" ]] && vf_chain="$vf_chain,$slot_texture"
    [[ -n "$slot_sharpen" ]] && vf_chain="$vf_chain,$slot_sharpen"
    [[ -n "$slot_color" ]] && vf_chain="$vf_chain,$slot_color"
    [[ -n "$slot_look" ]] && vf_chain="$vf_chain,$slot_look"
    vf_chain="$vf_chain,format=yuv420p"
  fi

  # === PREVIEW (PR2) ===
  if [[ "${do_preview,,}" == "true" ]]; then
    log "Rendering preview (PR2, full filter chain)"
    ffmpeg -y -ss "$start" -i "$combined" \
      -vf "$vf_chain" \
      -t "$preview_len" \
      -c:v $ENCODER $ENC_OPTS \
      "$preview"
    cd - >/dev/null
    return
  fi

  # === FINAL RENDER (F3) ===
  if [[ -f "$final" ]]; then
    read -r -p "Final file exists. Overwrite? (y/n) " ans
    [[ "$ans" != "y" ]] && { cd - >/dev/null; return; }
  fi

  log "Rendering FINAL output"
  trim_duration=$(awk "BEGIN {print $duration - $start - $end}")

  ffmpeg -y -ss "$start" -i "$combined" \
    -vf "$vf_chain" \
    -t "$trim_duration" \
    -c:v $ENCODER $ENC_OPTS \
    -movflags +faststart \
    -c:a aac -b:a 384k -ar 48000 \
    "$final"

  cd - >/dev/null
}

# === MAIN ===
normalize_files
process_folder "$INPUT_DIR"
echo "[INFO] All rendering jobs completed."
