# TetrisGBRecomp

Static recompilation of Tetris (Game Boy) for native PC.
Built with the [gb-recompiled](https://github.com/mstan/gbrecompiled) framework.

> **Status: Believed to be 100% playable.** All game modes tested. Zero interpreter fallbacks. If you find a bug, please open an issue.

## What Works

- All game modes (A-Type, B-Type)
- Title screen, menus, demo/attract mode
- Music and sound effects
- Saving high scores

## Quick Start

1. Clone with submodules: `git clone --recursive https://github.com/mstan/TetrisGBRecomp`
2. Place your `tetris.gb` ROM in `roms/`
3. Build and run (requires MSYS2 MinGW64, CMake, Ninja, SDL2):

```bash
# From the generated/build directory:
cmake .. -G Ninja
ninja
./Tetris.exe
```

## Controls

| GB Button | Keyboard |
|-----------|----------|
| D-Pad     | Arrow keys |
| A         | Z |
| B         | X |
| Start     | Enter |
| Select    | Tab |

| Hotkey | Action |
|--------|--------|
| TAB (hold) | Turbo (fast-forward) |

## Architecture

This is a **static recompiler**, not an emulator. The original SM83 (Game Boy CPU) machine code is translated to C at build time, then compiled to native x64. The Game Boy PPU, APU, and memory mapper are simulated by the runtime library.

- `tetris.toml` — recompiler configuration (entry points, HRAM overlays)
- `generated/` — auto-generated C code (not committed)
- `gb-recompiled/` — framework submodule (recompiler + runtime)
