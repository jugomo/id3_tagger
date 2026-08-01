# id3_tagger_gui

Cliente de escritorio en Flutter (macOS/Windows/Linux) para [`id3_tagger.py`](../id3_tagger.py). Es una interfaz gráfica sobre el script: selecciona una carpeta de MP3s, configura las opciones y lanza el etiquetado viendo el progreso en vivo, sin usar la terminal.

La app no reimplementa la lógica de etiquetado: invoca `id3_tagger.py` como subproceso y muestra su salida en streaming. Toda la lógica de búsqueda/etiquetado vive en el script Python raíz del repo.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos   # o -d windows / -d linux
```

## Funcionalidad

- Selector de carpeta con MP3s y de fichero de correcciones manuales (`.txt`, opcional).
- Checkboxes para búsqueda online (MusicBrainz + Discogs), dry-run y debug.
- Campo para el token de Discogs (prellenado desde la variable de entorno `DISCOGS_TOKEN` si está definida) y para un género por defecto.
- Botón "Verificar/instalar dependencias": comprueba si `python3` tiene `mutagen`/`requests` instalados y ofrece instalarlos.
- Consola con streaming de stdout/stderr coloreado y resumen final (procesados/omitidos/errores).
- Localiza `id3_tagger.py` automáticamente (relativo al repo); si no lo encuentra, permite seleccionarlo a mano y recuerda la ruta.

Ver [`../CLAUDE.md`](../CLAUDE.md) para el detalle de la arquitectura interna (estructura de `lib/`, por qué el script no se empaqueta como asset, etc.).
