#!/usr/bin/env bash
# =============================================================================
#  macos/setup.sh — prepara TetrisGBRecomp para macOS (se ejecuta UNA vez)
#
#  1. Comprueba Xcode Command Line Tools y Homebrew.
#  2. Instala cmake, ninja y SDL2 con Homebrew.
#  3. Descarga gb-recompiled y recomp-ui en los commits fijados por este repo.
#  4. Aplica el parche de OpenGL Core (macOS no tiene OpenGL ES).
#  5. Compila el recompilador (gbrecomp).
#
#  Uso (desde la raíz del repo):   ./macos/setup.sh
#  Compatible con el bash 3.2 que trae macOS.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Commits con los que se validó Tetris (los mismos que fijan los submódulos).
GBR_URL="https://github.com/mstan/gbrecompiled.git"
RUI_URL="https://github.com/mstan/recomp-ui.git"
GBR_PIN_DEFAULT="1ee166873993c16db6b2a64f9fc67a35f98573d1"
RUI_PIN_DEFAULT="44f549c0f159df343cba9d8c3842dbc7e592eb08"
PATCH="$ROOT/macos/patches/gb-recompiled-opengl-core.patch"

info() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

# Lee el commit fijado del gitlink del submódulo; si no existe, usa el default.
pin_for() {
    local path="$1" fallback="$2" sha=""
    if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        sha="$(git -C "$ROOT" ls-tree HEAD "$path" 2>/dev/null | awk '$2=="commit"{print $3}')"
    fi
    if [ -n "$sha" ]; then echo "$sha"; else echo "$fallback"; fi
}

# Clona URL en DIR exactamente en el commit SHA (clon superficial).
fetch_at() {
    local dir="$1" url="$2" sha="$3"
    if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
        local cur
        cur="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"
        if [ "$cur" = "$sha" ]; then
            echo "    $dir ya está en ${sha:0:7}"
            return
        fi
        echo "    $dir existe en ${cur:0:7}; cambiando a ${sha:0:7}"
        git -C "$dir" fetch --depth 1 origin "$sha"
        git -C "$dir" checkout -q --force FETCH_HEAD
        return
    fi
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        die "$dir existe pero no es un repositorio git. Bórralo o renómbralo y vuelve a ejecutar."
    fi
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "$url"
    git -C "$dir" fetch --depth 1 origin "$sha"
    git -C "$dir" checkout -q FETCH_HEAD
}

# ---------------------------------------------------------------------------
info "1/5  Comprobando herramientas del sistema"
if [ "$(uname -s)" = "Darwin" ]; then
    if ! xcode-select -p >/dev/null 2>&1; then
        warn "Faltan las Xcode Command Line Tools. Se abrirá el instalador;"
        warn "cuando termine, vuelve a ejecutar ./macos/setup.sh"
        xcode-select --install || true
        exit 1
    fi
    echo "    Xcode Command Line Tools: OK ($(xcode-select -p))"
    if ! command -v brew >/dev/null 2>&1; then
        die "No se encontró Homebrew. Instálalo desde https://brew.sh y vuelve a ejecutar."
    fi
    echo "    Homebrew: OK ($(brew --prefix))"

    info "2/5  Instalando dependencias con Homebrew (solo las que falten)"
    # En Mac Intel, Homebrew puede compilar desde código fuente (sin "bottles"):
    # CMake tarda 10-30 min. Saltamos lo que ya esté instalado (de Homebrew,
    # del instalador oficial de CMake, etc.) para no repetir ese trabajo.
    MISSING=""
    command -v cmake >/dev/null 2>&1 || MISSING="$MISSING cmake"
    command -v ninja >/dev/null 2>&1 || MISSING="$MISSING ninja"
    if ! brew list --versions sdl2 >/dev/null 2>&1 && ! command -v sdl2-config >/dev/null 2>&1; then
        MISSING="$MISSING sdl2"
    fi
    if [ -n "$MISSING" ]; then
        echo "    Por instalar:$MISSING"
        echo "    (si Homebrew compila desde código fuente puede tardar; no cierres la Terminal)"
        # shellcheck disable=SC2086
        brew install $MISSING
    else
        echo "    cmake, ninja y SDL2 ya están instalados: nada que hacer."
    fi
    echo "    cmake: $(command -v cmake)   ninja: $(command -v ninja)"
else
    warn "No estás en macOS ($(uname -s)): se omite Homebrew."
    warn "Asegúrate de tener cmake, ninja, git, un compilador C/C++ y SDL2 (dev)."
    info "2/5  (omitido fuera de macOS)"
fi
for tool in git cmake ninja; do
    command -v "$tool" >/dev/null 2>&1 || die "Falta '$tool' en el PATH."
done

# ---------------------------------------------------------------------------
info "3/5  Descargando gb-recompiled y recomp-ui (versiones fijadas)"
GBR_PIN="$(pin_for gb-recompiled "$GBR_PIN_DEFAULT")"
RUI_PIN="$(pin_for recomp-ui "$RUI_PIN_DEFAULT")"
fetch_at "$ROOT/gb-recompiled" "$GBR_URL" "$GBR_PIN"
fetch_at "$ROOT/recomp-ui"     "$RUI_URL" "$RUI_PIN"

# ---------------------------------------------------------------------------
info "4/5  Aplicando parches (OpenGL Core + controles en gb-recompiled; launcher DMG en recomp-ui)"
# apply_patch <repo> <patch> [archivo nuevo que crea el parche...]
# Idempotente: si ya está aplicado no hace nada; si hay una versión anterior
# (o cambios locales) vuelve al commit fijado limpio y aplica la actual.
# Las carpetas ignoradas por git (build/) se conservan.
apply_patch() {
    local repo="$1" patch="$2"; shift 2
    if git -C "$repo" apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "    $(basename "$patch"): ya aplicado (versión actual)."
        return
    fi
    local dirty=0 f
    [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ] && dirty=1
    for f in "$@"; do [ -f "$repo/$f" ] && dirty=1; done
    if [ "$dirty" = 1 ]; then
        echo "    $(basename "$patch"): actualizando una versión anterior..."
        git -C "$repo" checkout -q -- .
        for f in "$@"; do rm -f "$repo/$f"; done
    fi
    git -C "$repo" apply --check "$patch" >/dev/null 2>&1 \
        || die "$(basename "$patch") no aplica sobre $repo."
    git -C "$repo" apply "$patch"
    echo "    $(basename "$patch"): aplicado."
}
apply_patch gb-recompiled "$PATCH" runtime/include/gbrt_gl.h
apply_patch recomp-ui "$ROOT/macos/patches/recomp-ui-dmg-launcher.patch"

# ---------------------------------------------------------------------------
info "5/5  Compilando el recompilador (gbrecomp)"
cmake -G Ninja -S gb-recompiled -B gb-recompiled/build -DCMAKE_BUILD_TYPE=Release
ninja -C gb-recompiled/build gbrecomp

info "Listo. Siguiente paso:"
echo "    1) Copia tu ROM (V1.1 y/o V1.0, con cualquier nombre) a la carpeta roms/"
echo "    2) Ejecuta:         ./macos/build.sh"
