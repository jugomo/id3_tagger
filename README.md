# id3_tagger

[Español](README.es.md) · **English**

Tags MP3s with ID3 metadata (title, artist, album, year, genre) fetched automatically from the internet based on each file's name.

- **MusicBrainz** → title, artist, album, year
- **Discogs** → genre/subgenre (the `style` field, much more precise than `genre` for electronic music: Progressive House, Melodic House & Techno, Afro House, Tech House, Latin, etc.)

Optionally accepts a TXT file with manual corrections that take priority over everything above, and caches results in a `.json` file so it doesn't repeat requests between runs.

The repository has two parts:

- **`id3_tagger.py`** — CLI script with all the tagging logic.
- **`gui/`** — Flutter desktop app (macOS/Windows/Linux) that wraps the script above in a graphical interface, without duplicating its logic.

## Requirements

- Python 3.9+ with the `mutagen` and `requests` packages:
  ```bash
  pip3 install --user mutagen requests
  ```
- A (free) Discogs token if you want the genre to be filled in:
  1. Create an account at [discogs.com](https://www.discogs.com) if you don't have one.
  2. Go to [discogs.com/settings/developers](https://www.discogs.com/settings/developers).
  3. Click "Generate new token" and copy the token.
  4. Pass it with `--discogs-token YOUR_TOKEN` or export it as the `DISCOGS_TOKEN` environment variable.

## Command-line usage

```bash
python3 id3_tagger.py --dir /path/to/mp3s --online --discogs-token TOKEN
python3 id3_tagger.py --dir /path/to/mp3s --online --datos corrections.txt
python3 id3_tagger.py --dir /path/to/mp3s --online --dry-run
```

### Recognized filename patterns (in this order)

```
Artist - Title.mp3
01 - Artist - Title.mp3
01. Artist - Title.mp3
Title.mp3                (no artist; less reliable search)
```

### Manual corrections file (optional)

```
archivo: song.mp3
titulo: Correct title
artista: Correct artist
album: Album
anio: 2026
genero: Progressive House
pista: 3
```

### Main options

| Flag | Description |
|---|---|
| `--dir` | Directory with the MP3s (required) |
| `--online` | Enables the MusicBrainz + Discogs lookup |
| `--discogs-token` | Discogs token (or the `DISCOGS_TOKEN` environment variable) |
| `--datos` | `.txt` file with manual corrections, takes priority over everything |
| `--genero-por-defecto` | Genre to apply when none is found online |
| `--cache` | Cache file (default `.id3_cache.json`, next to `--dir`) |
| `--debug` | Shows the API queries and responses |
| `--dry-run` | Only shows what it would do, without writing anything |

## Desktop app (GUI)

A graphical alternative to the CLI: pick a folder, configure options, and watch the progress live, without using the terminal.

```bash
cd gui
flutter pub get
flutter run -d macos   # or -d windows / -d linux
```

The app automatically detects `python3` and locates `id3_tagger.py` in the repo; it includes a button to check and install `mutagen`/`requests` if they're missing. See [`gui/README.md`](gui/README.md) for details of the Flutter project.
