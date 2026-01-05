#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
OUT="${2:-plex_codec_report.csv}"

# kontrola ffprobe
if ! command -v ffprobe &> /dev/null; then
  echo "[ERROR] ffprobe není nainstalovaný. Nainstalujte ffmpeg." >&2
  exit 1
fi

# spočítat celkový počet souborů pro jednoduchý progress
TOTAL=$(find "$ROOT" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.ts" \) 2>/dev/null | wc -l | tr -d ' ')
COUNT=0
echo "Budu skenovat $TOTAL souborů z: $ROOT" >&2

# hlavička CSV
echo 'path,container,size_bytes,vcodec,vprofile,vlevel,pix_fmt,width,height,avg_fps,bitrate_v,acodec,achannels,alayout,abitrate,subtitle_codecs' > "$OUT"
PROGRESS_LOG="${OUT}.progress.log"
ERROR_LOG="${OUT}.errors.log"
: > "$PROGRESS_LOG"
: > "$ERROR_LOG"

# CSV escape funkce: escape uvozovky a obalit hodnotu do uvozovek pokud obsahuje čárku, uvozovku nebo nový řádek
csv_escape() {
  local val="$1"
  # escape uvozovky
  val=$(printf '%s' "$val" | sed 's/"/""/g')
  # pokud obsahuje čárku, uvozovku nebo nový řádek, obalit do uvozovek
  if [[ "$val" =~ [,] ]] || [[ "$val" == *\"* ]] || [[ "$val" == *$'\n'* ]]; then
    printf '"%s"' "$val"
  else
    printf '%s' "$val"
  fi
}

# video soubory (přidej/uber dle potřeby)
find "$ROOT" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.ts" \) -print0 |
while IFS= read -r -d '' f; do
  echo "$f" >> "$PROGRESS_LOG"
  COUNT=$((COUNT+1))
  if [ "$TOTAL" -gt 0 ]; then
    PCT=$((COUNT*100/TOTAL))
  else
    PCT=0
  fi
  # zobraz progress každých 5 souborů, ať to nezaplaví terminál
  if (( COUNT % 5 == 0 )); then
    printf "\rProgress: %d/%d (%d%%)" "$COUNT" "$TOTAL" "$PCT" >&2
  fi
  # ffprobe JSON-ish do proměnných (vytahujeme jen to důležité)
  container=$(ffprobe -v error -show_entries format=format_name -of default=nk=1:nw=1 "$f" 2>/dev/null | tr ',' ';' || echo "")
  size=$(ffprobe -v error -show_entries format=size -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  vprofile=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" | tr ',' ';' || echo "")
  vlevel=$(ffprobe -v error -select_streams v:0 -show_entries stream=level -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  avg_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")

  acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  achannels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")
  alayout=$(ffprobe -v error -select_streams a:0 -show_entries stream=channel_layout -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" | tr ',' ';' || echo "")
  abitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 "$f" 2>>"$ERROR_LOG" || echo "")

  subs=$(ffprobe -v error -select_streams s -show_entries stream=codec_name -of csv=p=0 "$f" 2>>"$ERROR_LOG" | paste -sd'|' - || true)
  subs=${subs:-""}

  # escape všech hodnot pro CSV
  esc_path=$(csv_escape "$f")
  esc_container=$(csv_escape "$container")
  esc_vprofile=$(csv_escape "$vprofile")
  esc_alayout=$(csv_escape "$alayout")
  esc_subs=$(csv_escape "$subs")

  # zajistit, že prázdné hodnoty jsou prázdné stringy (ne NULL)
  size=${size:-""}
  vcodec=${vcodec:-""}
  vlevel=${vlevel:-""}
  pix_fmt=${pix_fmt:-""}
  width=${width:-""}
  height=${height:-""}
  avg_fps=${avg_fps:-""}
  vbitrate=${vbitrate:-""}
  acodec=${acodec:-""}
  achannels=${achannels:-""}
  abitrate=${abitrate:-""}

  echo "$esc_path,$esc_container,$size,$vcodec,$esc_vprofile,$vlevel,$pix_fmt,$width,$height,$avg_fps,$vbitrate,$acodec,$achannels,$esc_alayout,$abitrate,$esc_subs" >> "$OUT"
done

echo "" >&2
echo "Hotovo: $OUT"
echo "Progress log: $PROGRESS_LOG"
echo "Error log: $ERROR_LOG"
