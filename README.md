# id3_tagger

Etiqueta MP3s con metadatos ID3 (título, artista, álbum, año, género) obtenidos automáticamente de internet a partir del nombre de cada fichero.

- **MusicBrainz** → título, artista, álbum, año
- **Discogs** → género/subgénero (campo `style`, mucho más preciso que `genre` para música electrónica: Progressive House, Melodic House & Techno, Afro House, Tech House, Latin, etc.)

Admite opcionalmente un TXT con correcciones manuales que tienen prioridad sobre todo lo anterior, y cachea los resultados en un `.json` para no repetir peticiones entre ejecuciones.

El repositorio tiene dos partes:

- **`id3_tagger.py`** — script CLI con toda la lógica de etiquetado.
- **`gui/`** — app de escritorio en Flutter (macOS/Windows/Linux) que envuelve el script anterior en una interfaz gráfica, sin duplicar su lógica.

## Requisitos

- Python 3.9+ con los paquetes `mutagen` y `requests`:
  ```bash
  pip3 install --user mutagen requests
  ```
- Un token de Discogs (gratuito) si quieres que se rellene el género:
  1. Crea una cuenta en [discogs.com](https://www.discogs.com) si no tienes una.
  2. Ve a [discogs.com/settings/developers](https://www.discogs.com/settings/developers).
  3. Pulsa "Generate new token" y copia el token.
  4. Pásalo con `--discogs-token TU_TOKEN` o expórtalo como variable de entorno `DISCOGS_TOKEN`.

## Uso por línea de comandos

```bash
python3 id3_tagger.py --dir /ruta/mp3s --online --discogs-token TOKEN
python3 id3_tagger.py --dir /ruta/mp3s --online --datos correcciones.txt
python3 id3_tagger.py --dir /ruta/mp3s --online --dry-run
```

### Patrones de nombre de fichero reconocidos (en este orden)

```
Artista - Título.mp3
01 - Artista - Título.mp3
01. Artista - Título.mp3
Título.mp3                (sin artista; búsqueda menos fiable)
```

### Fichero de correcciones manuales (opcional)

```
archivo: cancion.mp3
titulo: Título correcto
artista: Artista correcto
album: Álbum
anio: 2026
genero: Progressive House
pista: 3
```

### Opciones principales

| Flag | Descripción |
|---|---|
| `--dir` | Directorio con los MP3 (obligatorio) |
| `--online` | Activa la búsqueda en MusicBrainz + Discogs |
| `--discogs-token` | Token de Discogs (o variable de entorno `DISCOGS_TOKEN`) |
| `--datos` | Fichero `.txt` con correcciones manuales, tiene prioridad sobre todo |
| `--genero-por-defecto` | Género a aplicar cuando no se encuentra ninguno online |
| `--cache` | Fichero de caché (por defecto `.id3_cache.json`, junto a `--dir`) |
| `--debug` | Muestra las queries y respuestas de las APIs |
| `--dry-run` | Solo muestra qué haría, sin escribir nada |

## App de escritorio (GUI)

Alternativa gráfica al CLI: seleccionar carpeta, configurar opciones y ver el progreso en vivo, sin usar la terminal.

```bash
cd gui
flutter pub get
flutter run -d macos   # o -d windows / -d linux
```

La app detecta automáticamente `python3` y localiza `id3_tagger.py` en el repo; incluye un botón para verificar e instalar `mutagen`/`requests` si faltan. Ver [`gui/README.md`](gui/README.md) para detalles del proyecto Flutter.
