#!/usr/bin/env bash
# =============================================================================
#  macos/run.sh — ejecuta el Tetris compilado
#
#  Se ejecuta desde generated/build/ porque el launcher busca su carpeta
#  assets/ y guarda rom.cfg / keybinds.ini junto al ejecutable.
#  Cualquier argumento extra se pasa al juego (p. ej. --dump-frames 60,300).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE_NAME="${EXE_NAME:-Tetris}"
BUILD="$ROOT/generated/build"

if [ ! -x "$BUILD/$EXE_NAME" ]; then
    echo "No existe $BUILD/$EXE_NAME. Ejecuta primero ./macos/build.sh" >&2
    exit 1
fi

cd "$BUILD"
exec "./$EXE_NAME" "$@"
