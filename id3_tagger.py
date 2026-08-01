#!/usr/bin/env python3
"""
Escribe tags ID3 en MP3s obteniendo los datos automáticamente de internet
a partir del nombre de cada fichero:

    - MusicBrainz  -> título, artista, álbum, año
    - Discogs      -> género/subgénero (campo "style", mucho más preciso
                       para electrónica: Progressive House, Melodic House
                       & Techno, Afro House, Tech House, Latin, etc.)

Opcionalmente admite un TXT con correcciones manuales que tienen prioridad
sobre todo lo anterior.

PATRONES DE NOMBRE DE FICHERO reconocidos (se prueban en este orden):
    "Artista - Título.mp3"
    "01 - Artista - Título.mp3"
    "01. Artista - Título.mp3"
    "Título.mp3"                         (sin artista; búsqueda menos fiable)

Los resultados se cachean en un .json junto al directorio de MP3 para no
repetir peticiones si ejecutas el script varias veces.

DISCOGS TOKEN (necesario para el género):
    1. Crea una cuenta gratuita en discogs.com si no tienes una
    2. Ve a https://www.discogs.com/settings/developers
    3. Pulsa "Generate new token" y copia el token
    4. Pásalo con --discogs-token TU_TOKEN o expórtalo como variable de
       entorno: export DISCOGS_TOKEN=tu_token

TXT de correcciones manuales (opcional):
    archivo: cancion.mp3
    titulo: Título correcto
    artista: Artista correcto
    album: Álbum
    anio: 2026
    genero: Progressive House
    pista: 3

Uso:
    python id3_writer_online.py --dir /ruta/mp3s --online --discogs-token TOKEN
    python id3_writer_online.py --dir /ruta/mp3s --online --datos correcciones.txt
    python id3_writer_online.py --dir /ruta/mp3s --online --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

try:
    from mutagen.id3 import ID3, TIT2, TPE1, TALB, TDRC, TCON, TRCK, ID3NoHeaderError
except ImportError:
    sys.exit("Falta mutagen. Instálalo con: pip install mutagen --break-system-packages")

try:
    import requests
except ImportError:
    sys.exit("Falta requests. Instálalo con: pip install requests --break-system-packages")


MB_URL = "https://musicbrainz.org/ws/2/recording/"
MB_HEADERS = {"User-Agent": "id3-writer-script/1.0 (uso personal, sin contacto publico)"}
MB_RATE_LIMIT_SECONDS = 1.1  # MusicBrainz exige max 1 req/seg

DISCOGS_URL = "https://api.discogs.com/database/search"
DISCOGS_HEADERS = {"User-Agent": "id3-writer-script/1.0 +uso personal"}
DISCOGS_RATE_LIMIT_SECONDS = 1.1  # con token autenticado el límite es generoso, pero vamos finos

FIELD_MAP = {
    "titulo": "TIT2",
    "artista": "TPE1",
    "album": "TALB",
    "anio": "TDRC",
    "genero": "TCON",
    "pista": "TRCK",
}
FRAME_CLASSES = {
    "TIT2": TIT2, "TPE1": TPE1, "TALB": TALB,
    "TDRC": TDRC, "TCON": TCON, "TRCK": TRCK,
}

NOMBRE_PATRONES = [
    re.compile(r"^\d+[\.\-\s]+(?P<artista>.+?)\s*-\s*(?P<titulo>.+)$"),
    re.compile(r"^(?P<artista>.+?)\s*-\s*(?P<titulo>.+)$"),
    re.compile(r"^\d+[\.\-\s]+(?P<titulo>.+)$"),
    re.compile(r"^(?P<titulo>.+)$"),
]

# Palabras que indican que un paréntesis/corchete es un descriptor de mezcla
# (no parte real del título) y por tanto estorba en la búsqueda online.
# P.ej. "No More (I Can't Stand It) [Rework]" -> se quita "[Rework]" para
# buscar, pero "(I Can't Stand It)" se conserva porque no coincide con
# ninguna palabra clave.
MODIFICADORES_MEZCLA = re.compile(
    r"\s*[\(\[](?:[^()\[\]]*\b(?:original mix|extended mix|extended|radio edit|"
    r"radio|club mix|vip|vip mix|dub mix|dub|instrumental|acapella|a capella|"
    r"bootleg|rework|remix|edit|mashup|live|version|clean|explicit|"
    r"free download|unreleased)\b[^()\[\]]*)[\)\]]",
    re.IGNORECASE,
)


def limpiar_para_busqueda(texto: str) -> str:
    """Quita descriptores de mezcla (Rework, Extended Mix, VIP...) para que
    las búsquedas online encuentren el release/track original."""
    if not texto:
        return texto
    limpio = MODIFICADORES_MEZCLA.sub("", texto).strip()
    return limpio or texto


def parsear_nombre(nombre_sin_ext: str) -> dict:
    """Extrae artista/título del nombre de fichero probando varios patrones."""
    for patron in NOMBRE_PATRONES:
        m = patron.match(nombre_sin_ext.strip())
        if m:
            datos = m.groupdict()
            return {k: v.strip() for k, v in datos.items() if v}
    return {"titulo": nombre_sin_ext.strip()}


def cargar_cache(cache_path: Path) -> dict:
    if cache_path.is_file():
        try:
            return json.loads(cache_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def guardar_cache(cache_path: Path, cache: dict) -> None:
    cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def buscar_musicbrainz(artista: str, titulo: str, debug: bool = False) -> dict | None:
    """Consulta la API de búsqueda de grabaciones de MusicBrainz (título/artista/álbum/año)."""
    partes = []
    if titulo:
        partes.append(f'recording:"{titulo}"')
    if artista:
        partes.append(f'artist:"{artista}"')
    if not partes:
        return None

    params = {"query": " AND ".join(partes), "fmt": "json", "limit": 5}
    if debug:
        print(f"    [MB] query: {params['query']}")
    try:
        resp = requests.get(MB_URL, params=params, headers=MB_HEADERS, timeout=10)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  ! Error consultando MusicBrainz: {e}")
        return None

    grabaciones = resp.json().get("recordings", [])
    if debug:
        print(f"    [MB] resultados: {len(grabaciones)}")
    if not grabaciones:
        return None

    mejor = max(grabaciones, key=lambda r: r.get("score", 0))

    resultado = {
        "titulo": mejor.get("title"),
        "artista": ", ".join(
            ac.get("name", "") for ac in mejor.get("artist-credit", []) if ac.get("name")
        ) or None,
    }

    releases = mejor.get("releases") or []
    if releases:
        release = releases[0]
        resultado["album"] = release.get("title")
        fecha = release.get("date", "")
        if fecha:
            resultado["anio"] = fecha.split("-")[0]

    return {k: v for k, v in resultado.items() if v}


def buscar_discogs_genero(artista: str, titulo: str, token: str | None, debug: bool = False) -> str | None:
    """Consulta Discogs y devuelve el 'style' (subgénero) del primer resultado.

    El campo 'style' de Discogs es mucho más específico que 'genre' para
    música electrónica (p.ej. 'Progressive House', 'Melodic House & Techno',
    'Afro House', 'Tech House', 'Latin'...), así que se prioriza sobre 'genre'.
    """
    if not token:
        return None

    q = " ".join(p for p in [artista, titulo] if p)
    if not q:
        return None

    params = {"q": q, "type": "release", "token": token}
    if debug:
        print(f"    [Discogs] query: {q}")
    try:
        resp = requests.get(DISCOGS_URL, params=params, headers=DISCOGS_HEADERS, timeout=10)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  ! Error consultando Discogs: {e}")
        return None

    resultados = resp.json().get("results", [])
    if debug:
        print(f"    [Discogs] resultados: {len(resultados)}")
        if resultados:
            print(f"    [Discogs] primer resultado: {resultados[0].get('title')!r} "
                  f"genre={resultados[0].get('genre')} style={resultados[0].get('style')}")
    if not resultados:
        return None

    primero = resultados[0]
    estilos = primero.get("style") or []
    generos = primero.get("genre") or []
    etiquetas = estilos or generos
    if not etiquetas:
        return None

    return "; ".join(etiquetas[:2])


def obtener_datos_online(mp3_path: Path, cache: dict, discogs_token: str | None,
                          genero_por_defecto: str | None = None, debug: bool = False) -> dict:
    clave = mp3_path.name
    if clave in cache:
        return cache[clave]

    pistas = parsear_nombre(mp3_path.stem)
    artista = pistas.get("artista", "")
    titulo = pistas.get("titulo", "")

    # Para buscar usamos versiones "limpias" (sin Rework/Extended Mix/VIP...),
    # pero lo que se escribe en el tag mantiene lo que haya encontrado MusicBrainz
    # o, en su defecto, el nombre de fichero original.
    artista_busq = limpiar_para_busqueda(artista)
    titulo_busq = limpiar_para_busqueda(titulo)

    if debug:
        print(f"  [debug] fichero: {mp3_path.name}")
        print(f"  [debug] parseado -> artista={artista!r} titulo={titulo!r}")
        if (artista_busq, titulo_busq) != (artista, titulo):
            print(f"  [debug] limpio para buscar -> artista={artista_busq!r} titulo={titulo_busq!r}")

    resultado = buscar_musicbrainz(artista_busq, titulo_busq, debug=debug) or dict(pistas)
    time.sleep(MB_RATE_LIMIT_SECONDS)

    genero = buscar_discogs_genero(
        artista_busq or resultado.get("artista", ""),
        titulo_busq or resultado.get("titulo", ""),
        discogs_token,
        debug=debug,
    )
    if discogs_token:
        time.sleep(DISCOGS_RATE_LIMIT_SECONDS)

    if genero:
        resultado["genero"] = genero
    elif genero_por_defecto:
        resultado["genero"] = genero_por_defecto
        if debug:
            print(f"  [debug] sin género encontrado, aplicando por defecto: {genero_por_defecto!r}")

    cache[clave] = resultado
    return resultado


def parsear_txt_manual(path: Path) -> dict:
    tracks, bloque = {}, {}

    def cerrar():
        archivo = bloque.pop("archivo", None)
        if archivo:
            tracks[archivo] = dict(bloque)
        bloque.clear()

    with open(path, encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if not linea:
                if bloque:
                    cerrar()
                continue
            if ":" not in linea:
                continue
            clave, valor = linea.split(":", 1)
            bloque[clave.strip().lower()] = valor.strip()
    if bloque:
        cerrar()
    return tracks


def escribir_tags(mp3_path: Path, datos: dict, dry_run: bool) -> None:
    try:
        audio = ID3(mp3_path)
    except ID3NoHeaderError:
        audio = ID3()

    cambios = []
    for campo, valor in datos.items():
        frame_id = FIELD_MAP.get(campo)
        if not frame_id or not valor:
            continue
        frame_cls = FRAME_CLASSES[frame_id]
        audio.setall(frame_id, [frame_cls(encoding=3, text=str(valor))])
        cambios.append(f"{campo}={valor}")

    print(f"{mp3_path.name}: {', '.join(cambios) if cambios else 'sin datos'}")

    if not dry_run and cambios:
        audio.save(mp3_path, v2_version=3)


def main():
    parser = argparse.ArgumentParser(description="Escribe tags ID3 en MP3s (manual y/o buscando online)")
    parser.add_argument("--dir", required=True, help="Directorio con los MP3")
    parser.add_argument("--datos", help="Fichero .txt con correcciones manuales (opcional, tiene prioridad)")
    parser.add_argument("--online", action="store_true", help="Busca metadatos en MusicBrainz + Discogs por nombre de fichero")
    parser.add_argument("--discogs-token", default=os.environ.get("DISCOGS_TOKEN"),
                         help="Token personal de Discogs (o usa la variable de entorno DISCOGS_TOKEN). Necesario para el género.")
    parser.add_argument("--cache", default=".id3_cache.json", help="Fichero de caché para no repetir búsquedas")
    parser.add_argument("--genero-por-defecto", dest="genero_por_defecto",
                         help="Género a aplicar cuando no se encuentra ninguno online (útil para sets de un estilo concreto)")
    parser.add_argument("--debug", action="store_true", help="Muestra las queries y respuestas de las APIs para diagnosticar fallos")
    parser.add_argument("--dry-run", action="store_true", help="Solo muestra qué haría, sin escribir nada")
    args = parser.parse_args()

    directorio = Path(args.dir)
    if not directorio.is_dir():
        sys.exit(f"El directorio no existe: {directorio}")

    if args.online and not args.discogs_token:
        print("Aviso: sin --discogs-token no se podrá obtener el género/subgénero.")
        print("Genera uno gratis en https://www.discogs.com/settings/developers\n")

    manual = parsear_txt_manual(Path(args.datos)) if args.datos else {}

    mp3s = sorted(directorio.glob("*.mp3"))
    if not mp3s:
        sys.exit("No se han encontrado MP3 en el directorio")

    cache_path = directorio / args.cache
    cache = cargar_cache(cache_path) if args.online else {}

    for mp3_path in mp3s:
        datos = {}
        if args.online:
            datos.update(obtener_datos_online(
                mp3_path, cache, args.discogs_token,
                genero_por_defecto=args.genero_por_defecto,
                debug=args.debug,
            ))
        if mp3_path.name in manual:
            datos.update(manual[mp3_path.name])  # el txt manual sobrescribe lo online

        if not datos:
            print(f"{mp3_path.name}: sin datos (ni online ni manual), se omite")
            continue

        escribir_tags(mp3_path, datos, args.dry_run)

    if args.online:
        guardar_cache(cache_path, cache)

    print("\nListo" + (" (dry-run, no se ha escrito nada)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
