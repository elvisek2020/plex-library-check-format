#!/usr/bin/env python3
import csv

SRC = "plex_codec_report.csv"

OUT_AUDIO_CSV = "audio_fix_only.csv"
OUT_FULL_CSV  = "full_video_fix.csv"

# --- helpers ---
def low(x) -> str:
    return (x or "").strip().lower()

def is_hevc_10bit(vcodec, pix_fmt, vprofile) -> bool:
    v = low(vcodec)
    pf = low(pix_fmt)
    vp = low(vprofile)
    if v not in ("hevc", "h265"):
        return False
    return ("p010" in pf) or ("yuv420p10" in pf) or ("main 10" in vp)

def audio_problem(acodec) -> bool:
    return low(acodec) in ("dts", "dca", "truehd")

def has_image_subs(subs) -> bool:
    subs = low(subs)
    return ("hdmv_pgs_subtitle" in subs) or ("dvd_subtitle" in subs)

def reason(row):
    r = []
    if is_hevc_10bit(row["vcodec"], row["pix_fmt"], row["vprofile"]):
        r.append("hevc_10bit")
    if audio_problem(row["acodec"]):
        r.append(f"audio_{low(row['acodec'])}")
    if has_image_subs(row["subtitle_codecs"]):
        r.append("subs_pgs/dvd")
    return "|".join(r)

# --- load ---
with open(SRC, newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = [row for row in reader]

# --- classify ---
audio_only = []
full_fix = []

for row in rows:
    hevc10 = is_hevc_10bit(row["vcodec"], row["pix_fmt"], row["vprofile"])
    audp = audio_problem(row["acodec"])
    img = has_image_subs(row["subtitle_codecs"])

    # FULL FIX = HEVC 10bit + (PGS/DVD subs OR problem audio)
    # (videa nepřevádíme zbytečně; jen když je 10bit HEVC "kombinační průšvih")
    if hevc10 and (img or audp):
        full_fix.append(row)
    # AUDIO FIX = DTS/TrueHD/DCA, pokud to není full fix
    elif audp:
        audio_only.append(row)

# --- write CSV lists ---
def write_list(path, items):
    fields = ["path","container","size_bytes","vcodec","vprofile","pix_fmt","acodec","subtitle_codecs","reason"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in items:
            out = {k: r.get(k,"") for k in fields if k != "reason"}
            out["reason"] = reason(r)
            w.writerow(out)

write_list(OUT_AUDIO_CSV, audio_only)
write_list(OUT_FULL_CSV, full_fix)

print(f"Hotovo:")
print(f"  {OUT_AUDIO_CSV}  (audio-only: {len(audio_only)})")
print(f"  {OUT_FULL_CSV}   (full-fix:   {len(full_fix)})")