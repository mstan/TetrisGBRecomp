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

    info "2/5  Instalando dependencias con Homebrew (cmake, ninja, sdl2)"
    brew install cmake ninja sdl2
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
info "4/5  Aplicando parche de OpenGL Core para macOS"
if git -C gb-recompiled apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    echo "    El parche ya estaba aplicado."
elif git -C gb-recompiled apply --check "$PATCH" >/dev/null 2>&1; then
    git -C gb-recompiled apply "$PATCH"
    echo "    Parche aplicado."
else
    die "El parche no aplica sobre gb-recompiled@${GBR_PIN:0:7}. ¿Modificaste esa carpeta? Prueba: git -C gb-recompiled checkout -- . && ./macos/setup.sh"
fi

# ---------------------------------------------------------------------------
info "5/5  Compilando el recompilador (gbrecomp)"
cmake -G Ninja -S gb-recompiled -B gb-recompiled/build -DCMAKE_BUILD_TYPE=Release
ninja -C gb-recompiled/build gbrecomp

info "Listo. Siguiente paso:"
echo "    1) Copia tu ROM a:  roms/tetris.gb"
echo "    2) Ejecuta:         ./macos/build.sh"
