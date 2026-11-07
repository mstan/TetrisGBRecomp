#!/usr/bin/env bash
# =============================================================================
#  macos/build.sh — genera el código C desde la ROM y compila Tetris nativo
#
#  Requisitos: haber ejecutado ./macos/setup.sh y tener roms/tetris.gb
#  Uso (desde la raíz del repo):   ./macos/build.sh
#  Resultado:                      generated/build/Tetris
#
#  Variables opcionales:
#    GAME_TOML=otro.toml   usa otra configuración (por defecto tetris.toml)
#    SKIP_ROM_CHECK=1      no verifica el SHA-1 de la ROM
#    CLEAN=1               borra generated/ antes de compilar
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GAME_TOML="${GAME_TOML:-tetris.toml}"
ROM="${ROM:-roms/tetris.gb}"
EXPECTED_SHA1="3f2a6407c9900ad5817ee1cfb3609c5ee17400fc"   # Tetris (World) V1.0
GBRECOMP="$ROOT/gb-recompiled/build/bin/gbrecomp"

info() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

[ -x "$GBRECOMP" ] || die "No existe $GBRECOMP. Ejecuta primero ./macos/setup.sh"
[ -f "$GAME_TOML" ] || die "No existe $GAME_TOML"

if [ "$GAME_TOML" = "tetris.toml" ] && [ "${SKIP_ROM_CHECK:-0}" != "1" ]; then
    info "1/4  Verificando la ROM ($ROM)"
    [ -f "$ROM" ] || die "No encuentro $ROM. Copia tu volcado de Tetris (World) V1.0 ahí con ese nombre exacto."
    if command -v shasum >/dev/null 2>&1; then
        SHA1="$(shasum -a 1 "$ROM" | awk '{print $1}')"
    else
        SHA1="$(sha1sum "$ROM" | awk '{print $1}')"
    fi
    if [ "$SHA1" != "$EXPECTED_SHA1" ]; then
        die "La ROM no es Tetris (World) V1.0.
       SHA-1 obtenido:  $SHA1
       SHA-1 esperado:  $EXPECTED_SHA1
       (La revisión V1.1 no está soportada.)"
    fi
    echo "    ROM correcta (SHA-1 $SHA1)"
else
    info "1/4  Verificación de ROM omitida"
fi

if [ "${CLEAN:-0}" = "1" ]; then
    rm -rf generated
fi

info "2/4  Recompilando la ROM a C (gbrecomp --config $GAME_TOML)"
"$GBRECOMP" --config "$GAME_TOML"

info "3/4  Configurando el proyecto generado (OpenGL Core, Release)"
cmake -G Ninja -S generated -B generated/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGBRECOMP_GENERATED_OPT_LEVEL=2 \
    -DGBRT_GL_CORE=ON \
    -DRECOMP_UI_ROOT="$ROOT/recomp-ui"

info "4/4  Compilando"
ninja -C generated/build

EXE="$(find generated/build -maxdepth 1 -type f -perm -u+x ! -name '*.so' ! -name '*.dylib' | head -n 1)"
info "Listo: ${EXE:-generated/build/<juego>}"
echo "    Ejecuta:  ./macos/run.sh"
