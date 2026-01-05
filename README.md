# Plex Library Check & Format

Nástroj pro standardizaci video souborů v Plex knihovně pro kompatibilní přehrávání na Hisense TV a Plex serveru.

## 📋 Popis

Tento projekt obsahuje sadu skriptů pro analýzu a konverzi video souborů v Plex knihovně. Hlavním cílem je identifikovat a opravit nekompatibilní video soubory, které nejsou správně přehrávány na Hisense TV nebo v Plex aplikacích.

Projekt řeší následující problémy:

- **HEVC 10-bit** video kodek (nekompatibilní s některými přehrávači)
- **Problémové audio kodeky** (DTS, TrueHD) - konverze na AC3
- **Obrázkové titulky** (PGS/DVD) - zachování při konverzi

## ✨ Funkce

- ✅ **Automatické skenování** Plex knihovny a analýza video kodeků
- ✅ **Identifikace problémových souborů** podle kodeků a formátů
- ✅ **Kategorizace problémů** (pouze audio vs. celé video)
- ✅ **Automatická konverze** video souborů do kompatibilního formátu
- ✅ **Resume capability** - přeskočení již zpracovaných souborů
- ✅ **Detailní logování** všech operací

## 📖 Použití

### Základní workflow

1. **Skenování knihovny**: Spusť skript pro analýzu všech video souborů
2. **Analýza výsledků**: Skript automaticky identifikuje problémové soubory
3. **Oprava souborů**: Spusť konverzi podle typu problému (audio nebo celé video)
4. **Ověření**: Zkontroluj logy a výsledné soubory

### Předpoklady

- **macOS** (skripty jsou optimalizované pro macOS s NAS mount)
- **ffmpeg** a **ffprobe** (pro analýzu a konverzi video souborů)
- **Python 3** (pro analýzu CSV)
- **Přístup k NAS** s Plex knihovnou (defaultně `/Volumes/NAS-FILMY`)

#### Instalace ffmpeg

```bash
# macOS (Homebrew)
brew install ffmpeg

# Ověření instalace
ffmpeg -version
ffprobe -version
```

### Krok 1: Skenování Plex knihovny

Spusť skript pro analýzu všech video souborů v knihovně:

```bash
bash ./01.scan_plex_library.sh /Volumes/NAS-FILMY plex_codec_report.csv
```

**Parametry:**

- První parametr: Cesta ke kořenové složce Plex knihovny (default: `.`)
- Druhý parametr: Název výstupního CSV souboru (default: `plex_codec_report.csv`)

**Výstup:**

- `plex_codec_report.csv` - detailní analýza všech video souborů
- `plex_codec_report.csv.progress.log` - log průběhu skenování
- `plex_codec_report.csv.errors.log` - chyby při skenování

**CSV obsahuje:**

- `path` - cesta k souboru
- `container` - kontejner (mkv, mp4, atd.)
- `vcodec` - video kodek (hevc, h264, atd.)
- `vprofile` - video profil
- `pix_fmt` - pixel formát
- `acodec` - audio kodek
- `subtitle_codecs` - titulky
- a další metadata

### Krok 2: Analýza a kategorizace problémů

Spusť Python skript pro analýzu CSV a identifikaci problémových souborů:

```bash
python3 ./02.analyze_plex_csv.py
```

**Výstup:**

- `audio_fix_only.csv` - soubory, které potřebují pouze opravu audio
- `full_video_fix.csv` - soubory, které potřebují kompletní re-encode videa

**Kritéria pro kategorizaci:**

**Audio fix pouze:**

- Audio kodek: DTS, TrueHD
- Video kodek: H.264 nebo HEVC 8-bit (kompatibilní)
- Obrázkové titulky: PGS/DVD

**Full video fix:**

- Video kodek: HEVC 10-bit (nekompatibilní)
- + případně problémové audio nebo obrázkové titulky

### Krok 3: Oprava souborů

#### Oprava pouze audio

Pro soubory, které potřebují pouze opravu audio kodeku:

```bash
bash ./03.fix_audio_only.sh audio_fix_only.csv
```

**Co dělá:**

- Kopíruje video stream beze změny
- Konvertuje audio na AC3 640kbps
- Kopíruje titulky
- Vytvoří `*.fixed.mkv` vedle originálu

#### Oprava celého videa

Pro soubory, které potřebují kompletní re-encode:

```bash
bash ./04.fix_full_video.sh full_video_fix.csv
```

**Co dělá:**

- Re-encode video na H.264 (libx264, CRF 18, High profile)
- Konvertuje audio na AC3 640kbps
- Kopíruje titulky
- Vytvoří `*.fixed.mkv` vedle originálu
- Automaticky přeskočí již zpracované soubory

**Výstup:**

- `fix_full_video_YYYYMMDD_HHMMSS.log` - detailní log konverze
- `*.fixed.mkv` - opravené soubory vedle originálů

**Poznámky:**

- Skript automaticky čeká na NAS mount, pokud není dostupný
- Zobrazuje progress pro každý soubor `[X/N]`
- Může trvat velmi dlouho (hodiny až dny) pro velké knihovny
- Lze bezpečně přerušit a znovu spustit - přeskočí hotové soubory

### Ověření výsledků

Zkontroluj log soubory pro detaily:

```bash
# Zobraz poslední řádky logu
tail -20 fix_full_video_*.log

# Zkontroluj počet úspěšných konverzí
grep "^\[OK\]" fix_full_video_*.log | wc -l

# Zkontroluj chyby
grep "^\[FAIL\]" fix_full_video_*.log
```

## 🔧 Technická dokumentace

### 🏗️ Architektura

Projekt je navržen jako sada nezávislých skriptů, které lze spouštět postupně:

1. **Skenování** - bash skript s ffprobe pro analýzu metadat
2. **Analýza** - Python skript pro kategorizaci problémů
3. **Konverze** - bash skripty s ffmpeg pro opravu souborů

**Charakteristiky:**

- **Idempotentní** - opakované spuštění je bezpečné
- **Resume capability** - automatické přeskočení hotových souborů
- **Detailní logování** - všechny operace jsou logovány
- **CSV-driven** - práce se seznamy souborů z CSV

### Technický stack

**Nástroje:**

- **ffmpeg / ffprobe** - analýza a konverze video souborů
- **Python 3** - analýza CSV a kategorizace
- **Bash** - orchestrace skriptů

**Video konverze:**

- Video: H.264 (libx264), CRF 18, High profile, Level 4.1
- Audio: AC3, 640kbps, 5.1 surround
- Titulky: Copy (zachování originálu)

### 📁 Struktura projektu

```
plex-library-check-format/
├── 01.scan_plex_library.sh      # Skenování Plex knihovny
├── 02.analyze_plex_csv.py       # Analýza a kategorizace problémů
├── 03.fix_audio_only.sh         # Oprava pouze audio
├── 04.fix_full_video.sh         # Oprava celého videa
├── plex_codec_report.csv        # Výstup skenování (generováno)
├── audio_fix_only.csv           # Seznam pro audio fix (generováno)
├── full_video_fix.csv           # Seznam pro full fix (generováno)
├── fix_full_video_*.log         # Logy konverze (generováno)
└── README.md                    # Tato dokumentace
```

### 🔧 Detaily konverze

#### Video konverze (full fix)

```bash
ffmpeg -i input.mkv \
  -map 0 \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -profile:v high \
  -level 4.1 \
  -crf 18 \
  -c:a ac3 \
  -b:a 640k \
  -c:s copy \
  output.fixed.mkv
```

**Parametry:**

- `-map 0` - zkopíruje všechny streamy z inputu
- `-c:v libx264` - H.264 video kodek
- `-pix_fmt yuv420p` - 8-bit pixel formát (kompatibilní)
- `-profile:v high` - High profile pro lepší kompatibilitu
- `-crf 18` - vysoká kvalita (nižší = lepší kvalita)
- `-c:a ac3` - AC3 audio kodek
- `-b:a 640k` - audio bitrate
- `-c:s copy` - kopírování titulků beze změny

#### Audio konverze (audio fix)

```bash
ffmpeg -i input.mkv \
  -map 0 \
  -c:v copy \
  -c:a ac3 \
  -b:a 640k \
  -c:s copy \
  output.fixed.mkv
```

**Parametry:**

- `-c:v copy` - video beze změny
- `-c:a ac3` - pouze audio konverze

### 🐛 Známé problémy

- **Dlouhá doba konverze**: Full video re-encode může trvat hodiny až dny pro velké soubory
- **TrueHD audio**: Některé TrueHD streamy mohou způsobit chyby při dekódování (skript pokračuje)
- **Velikost výstupních souborů**: H.264 soubory mohou být větší než originální HEVC 10-bit

### 📚 Další zdroje

- [ffmpeg dokumentace](https://ffmpeg.org/documentation.html)
- [Plex podporované formáty](https://support.plex.tv/articles/200250387-plex-media-server-requirements/)
- [Hisense TV podporované formáty](https://www.hisense.com/support)

## 📄 Licence

Tento projekt je vytvořen pro osobní použití.

---

## 🤝 Contributing

Tento projekt je určen pro osobní použití. Pokud máte návrhy na vylepšení, můžete vytvořit issue nebo pull request.
