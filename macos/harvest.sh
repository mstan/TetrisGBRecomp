#!/usr/bin/env bash
# =============================================================================
#  macos/harvest.sh — incorpora al recompilado las funciones que faltaron
#
#  Mientras juegas, si el juego entra en código que el recompilador no encontró,
#  lo ejecuta el intérprete de respaldo (funciona, pero no es código nativo) y
#  lo anota en <carpeta>/build/interp_fallbacks.log. Este script añade esas
#  direcciones al manifiesto de semillas y recompila.
#
#  Uso:  juega un rato con ./macos/run.sh v11, cierra el juego y luego:
#          ./macos/harvest.sh v11        (o v10)
#  Repite hasta que el script diga que no hay nada nuevo.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GBRECOMP="$ROOT/gb-recompiled/build/bin/gbrecomp"

V="${1:-v11}"
case "$V" in
    v10) OUT="generated";     MANIFEST="dispatch_misses.toml" ;;
    v11) OUT="generated-v11"; MANIFEST="dispatch_misses-v11.toml" ;;
    *)   echo "Uso: ./macos/harvest.sh v10|v11" >&2; exit 1 ;;
esac
LOG="$OUT/build/interp_fallbacks.log"

[ -x "$GBRECOMP" ] || { echo "Ejecuta primero ./macos/setup.sh" >&2; exit 1; }
if [ ! -s "$LOG" ]; then
    echo "No hay $LOG (o está vacío): no se registró ninguna función nueva. ¡Nada que hacer!"
    exit 0
fi

BEFORE="$(grep -c '^\[\[miss\]\]' "$MANIFEST" 2>/dev/null || true)"; BEFORE="${BEFORE:-0}"
"$GBRECOMP" --harvest "$LOG" --manifest "$MANIFEST"
AFTER="$(grep -c '^\[\[miss\]\]' "$MANIFEST" 2>/dev/null || true)"; AFTER="${AFTER:-0}"
echo "Semillas en $MANIFEST: $BEFORE -> $AFTER"

if [ "$AFTER" = "$BEFORE" ]; then
    echo "No había direcciones nuevas. ¡El recompilado ya cubre todo lo jugado!"
    exit 0
fi
# Archivar el log para no volver a cosechar lo mismo.
mv "$LOG" "$LOG.$(date +%Y%m%d-%H%M%S)"
echo "Recompilando con las semillas nuevas..."
exec "$ROOT/macos/build.sh" "$V"
