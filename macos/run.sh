#!/usr/bin/env bash
# =============================================================================
#  macos/run.sh — ejecuta el Tetris compilado
#
#  Uso:
#    ./macos/run.sh          la V1.1 si está compilada; si no, la V1.0
#    ./macos/run.sh v11      Tetris V1.1 (música A-TYPE = Korobeiniki)
#    ./macos/run.sh v10      Tetris V1.0
#  Cualquier argumento extra se pasa al juego (p. ej. --dump-frames 60,300).
#
#  Se ejecuta desde la carpeta build/ porque el launcher busca su carpeta
#  assets/ y guarda rom.cfg / runtime_prefs.ini junto al ejecutable.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE_NAME="${EXE_NAME:-Tetris}"

V="${1:-}"
case "$V" in
    v10|v11) shift ;;
    *) V="" ;;
esac
if [ -z "$V" ]; then
    if [ -x "$ROOT/generated-v11/build/$EXE_NAME" ]; then V=v11
    else V=v10; fi
fi
if [ "$V" = v11 ]; then BUILD="$ROOT/generated-v11/build"; else BUILD="$ROOT/generated/build"; fi

if [ ! -x "$BUILD/$EXE_NAME" ]; then
    echo "No existe $BUILD/$EXE_NAME. Ejecuta primero ./macos/build.sh $V" >&2
    exit 1
fi

echo "Iniciando Tetris $V  (otra versión: ./macos/run.sh v10 | v11)"
cd "$BUILD"
exec "./$EXE_NAME" "$@"
