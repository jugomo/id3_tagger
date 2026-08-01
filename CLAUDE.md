# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Two parts that together form one tool:

- `id3_tagger.py` — standalone Python CLI. The actual tagging logic (MusicBrainz/Discogs lookups, filename parsing, ID3 writing). This is the single source of truth for tagging behavior.
- `gui/` — Flutter desktop app (macOS/Windows/Linux) that is a thin GUI wrapper around the CLI. It shells out to `id3_tagger.py` as a subprocess and streams its stdout/stderr; **no tagging logic is duplicated in Dart**. If tagging behavior needs to change, change `id3_tagger.py`, not the GUI.

## Commands

### Python CLI (`id3_tagger.py`)

```bash
# Deps (system python3 has neither by default)
pip3 install --user mutagen requests

# Run
python3 id3_tagger.py --dir /path/to/mp3s --online --discogs-token TOKEN
python3 id3_tagger.py --dir /path/to/mp3s --online --dry-run   # preview only, no writes
python3 id3_tagger.py --dir /path/to/mp3s --datos correcciones.txt
```

No test suite or linter is configured for the Python script.

### Flutter GUI (`gui/`)

```bash
cd gui
flutter pub get
flutter analyze
flutter test
flutter run -d macos          # or -d windows / -d linux
flutter build macos --debug   # compile check without launching
```

## Architecture notes

### `id3_tagger.py`

- Requires `from __future__ import annotations` at the top — the file uses `X | None` (PEP 604) type hints, and the target `python3` on this machine is 3.9.6, which errors on that syntax without the future import. Do not remove it.
- Resolution order per file: parses artist/title from the filename (`NOMBRE_PATRONES` regex list, tried in order), strips mix descriptors like "Extended Mix"/"Rework" only for the *search* query (`limpiar_para_busqueda`) while keeping the original text for anything written to tags, queries MusicBrainz for title/artist/album/year, then Discogs for genre (prefers the `style` field over `genre` — more specific for electronic music). A manual `.txt` corrections file, if given via `--datos`, always overrides both.
- Results are cached per-file in a JSON next to the MP3 directory (`--cache`, default `.id3_cache.json`) so re-runs don't re-query.
- Uses `sys.exit(msg)` (stderr + exit code 1) for the two fatal cases: missing directory, no MP3s found. Everything else is per-file and non-fatal — a failed lookup just leaves that file's data empty rather than aborting the run.
- Rate limits: MusicBrainz and Discogs are both throttled to ~1 request/sec (`MB_RATE_LIMIT_SECONDS`, `DISCOGS_RATE_LIMIT_SECONDS`); don't remove these, MusicBrainz enforces its limit server-side.

### `gui/`

Single-screen `StatefulWidget` app (no state management package — deliberate, given the app's size). Structure:

- `lib/home_page.dart` — the entire UI: form (folder/token/flags) + streaming log console + summary banner.
- `lib/services/tagger_process_service.dart` — runs `id3_tagger.py` via `Process.start(pythonPath, ['-u', scriptPath, ...args], ...)`. The `-u` flag is required: without it Python fully buffers stdout when not attached to a tty, and the log would appear to hang until the process exits. The Discogs token is passed via the `DISCOGS_TOKEN` env var, not argv, so it isn't visible in `ps`/Activity Monitor.
- `lib/services/script_locator_service.dart` — finds `id3_tagger.py` on disk (saved override → `../id3_tagger.py` relative to cwd → manual file picker). The script is deliberately **not** bundled as a Flutter asset: it lives in this repo and the user edits it directly, so embedding a copy would let the GUI silently run a stale version.
- `lib/services/python_env_service.dart` — detects a working `python3`/`pip3` and can install `mutagen`/`requests` on demand (the GUI's "Verificar/instalar dependencias" button).
- `lib/services/settings_service.dart` — persists form state via `shared_preferences` (unencrypted on all platforms — accepted tradeoff for a single-user local tool; don't add `flutter_secure_storage` for this without a reason to revisit that tradeoff).
- macOS App Sandbox is disabled in `gui/macos/Runner/{DebugProfile,Release}.entitlements` (`com.apple.security.app-sandbox = false`) — required for `Process.start` to reach `python3` and for the app to read/write MP3s anywhere on disk. Don't re-enable it without also revisiting how the subprocess and file access work.
