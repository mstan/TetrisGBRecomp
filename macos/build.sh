#!/usr/bin/env bash
# =============================================================================
#  macos/build.sh — genera el código C desde la ROM y compila Tetris nativo
#
#  Soporta dos revisiones, cada una en su propia carpeta:
#    v10  Tetris (World) V1.0   roms/tetris.gb      -> generated/build/Tetris
#    v11  Tetris (JUE)   V1.1   roms/tetris-v11.gb  -> generated-v11/build/Tetris
#         (en la V1.1 la música A-TYPE es Korobeiniki)
#
#  Uso (desde la raíz del repo):
#    ./macos/build.sh          compila todas las versiones cuya ROM esté en roms/
#    ./macos/build.sh v10      solo la V1.0
#    ./macos/build.sh v11      solo la V1.1
#
#  Las ROMs se reconocen por su SHA-1, no por el nombre: puedes dejarlas en
#  roms/ con cualquier nombre y el script las copia al nombre que corresponde.
#
#  Variables opcionales:
#    CLEAN=1               borra la carpeta generada antes de compilar
#    SKIP_ROM_CHECK=1      no verifica el SHA-1 (solo con GAME_TOML)
#    GAME_TOML=otro.toml   compila una configuración arbitraria (modo experto)
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GBRECOMP="$ROOT/gb-recompiled/build/bin/gbrecomp"
V10_SHA1="${V10_SHA1:-3f2a6407c9900ad5817ee1cfb3609c5ee17400fc}"   # Tetris (World) V1.0
V11_SHA1="${V11_SHA1:-74591cc9501af93873f9a5d3eb12da12c0723bbc}"   # Tetris (JUE) V1.1
V10_ROM="roms/tetris.gb"
V11_ROM="roms/tetris-v11.gb"

info() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

sha1_of() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 1 "$1" | awk '{print $1}'
    else sha1sum "$1" | awk '{print $1}'; fi
}

# Configura y compila un proyecto generado (carpeta $1).
compile_generated() {
    local out="$1"
    info "Configurando $out (OpenGL Core, Release)"
    cmake -G Ninja -S "$out" -B "$out/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DGBRECOMP_GENERATED_OPT_LEVEL=2 \
        -DGBRT_GL_CORE=ON \
        -DRECOMP_UI_ROOT="$ROOT/recomp-ui"
    info "Compilando $out"
    ninja -C "$out/build"
}

[ -x "$GBRECOMP" ] || die "No existe $GBRECOMP. Ejecuta primero ./macos/setup.sh"

# --- Modo experto: una configuración arbitraria ------------------------------
if [ -n "${GAME_TOML:-}" ]; then
    [ -f "$GAME_TOML" ] || die "No existe $GAME_TOML"
    OUT="$(awk -F'"' '/^output_dir/{print $2; exit}' "$GAME_TOML")"
    OUT="${OUT:-generated}"
    [ "${CLEAN:-0}" = "1" ] && rm -rf "$OUT"
    info "Recompilando la ROM a C (gbrecomp --config $GAME_TOML)"
    "$GBRECOMP" --config "$GAME_TOML"
    compile_generated "$OUT"
    info "Listo: $OUT/build"
    exit 0
fi

# --- 1. Reconocer las ROMs de roms/ por su SHA-1 -----------------------------
info "1/3  Buscando ROMs de Tetris en roms/"
mkdir -p roms
HAVE_V10=0; HAVE_V11=0
for f in roms/*; do
    [ -f "$f" ] || continue
    case "$f" in *.gb|*.GB|*.Gb|*.gB) ;; *) continue ;; esac
    s="$(sha1_of "$f")"
    if [ "$s" = "$V10_SHA1" ]; then
        [ "$f" = "$V10_ROM" ] || { cp "$f" "$V10_ROM"; echo "    $f -> $V10_ROM"; }
        HAVE_V10=1
    elif [ "$s" = "$V11_SHA1" ]; then
        [ "$f" = "$V11_ROM" ] || { cp "$f" "$V11_ROM"; echo "    $f -> $V11_ROM"; }
        HAVE_V11=1
    else
        echo "    (ignorada: $f — SHA-1 $s no es V1.0 ni V1.1)"
    fi
done
[ "$HAVE_V10" = 1 ] && echo "    V1.0 encontrada: $V10_ROM"
[ "$HAVE_V11" = 1 ] && echo "    V1.1 encontrada: $V11_ROM"

WANT="${1:-all}"
case "$WANT" in
    all)
        TARGETS=""
        [ "$HAVE_V10" = 1 ] && TARGETS="$TARGETS v10"
        [ "$HAVE_V11" = 1 ] && TARGETS="$TARGETS v11"
        [ -n "$TARGETS" ] || die "No hay ninguna ROM reconocida en roms/.
       V1.0: SHA-1 $V10_SHA1
       V1.1: SHA-1 $V11_SHA1"
        ;;
    v10) [ "$HAVE_V10" = 1 ] || die "Falta la ROM V1.0 (SHA-1 $V10_SHA1) en roms/."; TARGETS="v10" ;;
    v11) [ "$HAVE_V11" = 1 ] || die "Falta la ROM V1.1 (SHA-1 $V11_SHA1) en roms/."; TARGETS="v11" ;;
    *)   die "Versión desconocida: '$WANT'. Usa v10, v11 o nada (todas)." ;;
esac

for V in $TARGETS; do
    if [ "$V" = v10 ]; then
        TOML="tetris.toml"; OUT="generated"; NAME="V1.0"
    else
        TOML="tetris-v11.toml"; OUT="generated-v11"; NAME="V1.1"
        [ -f "$TOML" ] || die "Falta $TOML en el repo (git pull)."
    fi

    [ "${CLEAN:-0}" = "1" ] && rm -rf "$OUT"

    info "2/3  [$NAME] Recompilando la ROM a C (gbrecomp --config $TOML)"
    "$GBRECOMP" --config "$TOML"

    info "3/3  [$NAME] Compilación nativa"
    compile_generated "$OUT"
    # El launcher lee la ROM de rom.cfg (junto al ejecutable): dejarla apuntada
    # para que aparezca verificada desde el primer arranque.
    if [ ! -s "$OUT/build/rom.cfg" ]; then
        if [ "$V" = v10 ]; then echo "$ROOT/$V10_ROM" > "$OUT/build/rom.cfg"
        else echo "$ROOT/$V11_ROM" > "$OUT/build/rom.cfg"; fi
    fi
    info "Listo [$NAME]: $OUT/build/Tetris   ->   ./macos/run.sh $V"
done
