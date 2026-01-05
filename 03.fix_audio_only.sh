#!/usr/bin/env bash
# Audio-fix runner (CSV-driven) pro Plex knihovnu
# - čte seznam souborů z CSV (default: audio_fix_only.csv)
# - pro každý soubor vytvoří výstup vedle originálu jako *.audfix.mkv
# - SKIP pokud výstup existuje a je nenulový
# - čeká na NAS mount (/Volumes/NAS-FILMY)
# - progress [i/N] + log do souboru

# pokud to někdo pustí přes `sh`, přepni se do bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

NAS_MOUNT="/Volumes/NAS-FILMY"
CSV_PATH="${1:-audio_fix_only.csv}"

if [[ ! -f "$CSV_PATH" ]]; then
  echo "[ERROR] CSV nenalezeno: $CSV_PATH" >&2
  echo "Použití: $0 /cesta/k/audio_fix_only.csv" >&2
  exit 1
fi

LOG="fix_audio_only_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "Start: $(date)"
echo "CSV:   $CSV_PATH"
echo "Log:   $LOG"
echo "ffmpeg: $(ffmpeg -version | head -n 1)"
echo "python: $(python3 --version 2>/dev/null || echo 'N/A')"

wait_for_nas() {
  local path="$1"
  if [[ "$path" == "$NAS_MOUNT"* ]]; then
    while [ ! -d "$NAS_MOUNT" ]; do
      echo "[WARN] NAS mount $NAS_MOUNT není dostupný. Čekám 10s..." >&2
      sleep 10
    done
  fi
}

# Vygeneruje NUL-separovaný seznam cest z CSV sloupce `path`.
# Používáme python csv parser (robustní vůči čárkám/uvozovkám v názvech).
paths_nul() {
python3 - "$CSV_PATH" <<'PY'
import csv, sys
from pathlib import Path
csv_path = sys.argv[1]
with open(csv_path, newline='', encoding='utf-8') as f:
    r = csv.DictReader(f)
    for row in r:
        p = (row.get('path') or '').strip()
        if not p:
            continue
        sys.stdout.write(p)
        sys.stdout.write('\0')
PY
}

# Spočítá počet položek v CSV (řádky s vyplněným path)
count_items() {
python3 - "$CSV_PATH" <<'PY'
import csv, sys
n=0
with open(sys.argv[1], newline='', encoding='utf-8') as f:
    r=csv.DictReader(f)
    for row in r:
        if (row.get('path') or '').strip():
            n+=1
print(n)
PY
}

TOTAL=$(count_items)
COUNT=0
OK=0
SKIP=0
FAIL=0

echo "Tasks: $TOTAL"

make_out_path() {
  local in_path="$1"
  local base ext dir name
  dir=$(dirname "$in_path")
  base=$(basename "$in_path")
  ext="${base##*.}"
  name="${base%.*}"
  # zachovat původní příponu (mkv/mp4/...) a jen přidat .audfix
  printf "%s/%s.audfix.%s" "$dir" "$name" "$ext"
}

run_one() {
  local in_path="$1"
  local out_path
  out_path=$(make_out_path "$in_path")

  COUNT=$((COUNT+1))
  printf "\n===== [%d/%d] %s =====\n" "$COUNT" "$TOTAL" "$(date)"
  echo "IN : $in_path"
  echo "OUT: $out_path"

  wait_for_nas "$in_path"
  wait_for_nas "$out_path"

  # SKIP hotové
  if [[ -f "$out_path" && -s "$out_path" ]]; then
    echo "[SKIP] Hotovo (soubor existuje): $out_path"
    SKIP=$((SKIP+1))
    return 0
  fi

  # chybějící input
  if [[ ! -f "$in_path" ]]; then
    echo "[FAIL] Input nenalezen: $in_path"
    FAIL=$((FAIL+1))
    return 1
  fi

  # pokud existuje 0B output, smaž
  if [[ -f "$out_path" && ! -s "$out_path" ]]; then
    echo "[WARN] Nedokončený output (0B), mažu: $out_path"
    rm -f "$out_path" || true
  fi

  # ffmpeg: video/subs kopie, audio -> AC3 640k, zachovat všechny streamy
  local cmd
  cmd=(ffmpeg -hide_banner -nostdin -y -i "$in_path" -map 0 -c:v copy -c:s copy -c:a ac3 -b:a 640k "$out_path")
  echo "CMD: ${cmd[*]}"

  if "${cmd[@]}"; then
    echo "[OK] $out_path"
    OK=$((OK+1))
    return 0
  else
    echo "[FAIL] $in_path"
    FAIL=$((FAIL+1))
    return 1
  fi
}

# Hlavní smyčka
paths_nul | while IFS= read -r -d '' p; do
  # ochrana proti prázdným
  [[ -z "$p" ]] && continue
  # pokud NAS spadne uprostřed, while poběží dál; wait_for_nas to podrží
  run_one "$p" || true

done

echo "\nDONE. OK=$OK SKIP=$SKIP FAIL=$FAIL"
echo "End: $(date)"
