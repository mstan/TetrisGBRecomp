# TetrisGBRecomp

Static recompilation of Tetris (Game Boy) for native PC.
Built with the [gb-recompiled](https://github.com/mstan/gbrecompiled) engine and the
shared [recomp-ui](https://github.com/mstan/recomp-ui) launcher.

> **Status: Believed to be 100% playable.** All game modes tested. Zero interpreter
> fallbacks with the Tier-0 seed manifest applied. If you find a bug, please open an issue.

## What Works

- All game modes (A-Type, B-Type)
- Title screen, menus, demo/attract mode
- Music and sound effects
- recomp-ui launcher: ROM picker with CRC gate, settings/video/input overlay (F1)

## ROM identity

The ROM is **not** embedded. On first run the launcher asks for one and gates it
against `game_get_expected_crc32()` in `extras.c`:

| Field | Value |
| --- | --- |
| CRC32 | `0x63F9407D` |
| SHA-1 | `3f2a6407c9900ad5817ee1cfb3609c5ee17400fc` |
| Size | 32,768 bytes |
| Header title / version | `TETRIS`, mask-ROM version `0x00` (V1.0) |

Common dump names: **Tetris (World)** / `Tetris (W) (V1.0) [!].gb`. The V1.1 revision
(`Tetris (JUE) (V1.1) [!]`, CRC32 `0x46DF91AD`) is a different program image and is
**not** supported — the recompiled code comes from V1.0.

The accepted path is cached in `rom.cfg` next to the executable; delete it to re-pick.

## Build & run

### Dependencies

- **Engine:** [`gb-recompiled`](https://github.com/mstan/gbrecompiled), cloned as a
  sibling directory (`runtime_dir` in the TOML points at `../gb-recompiled/runtime`).
- **Launcher:** [`recomp-ui`](https://github.com/mstan/recomp-ui), also a sibling
  checkout. CMake auto-discovers it; override with `-DRECOMP_UI_ROOT=<path>`.
- **Toolchain (Windows / msys2 mingw64):** GCC, CMake, Ninja, SDL2. The build conflicts
  with devkitPro on `PATH`; export a clean PATH first.
- **ROM:** your own dump at `roms/tetris.gb` (see [ROM identity](#rom-identity)).

### Commands

```bash
export CLEAN_PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:/c/Windows/system32:/c/Windows"

# 0. Build the engine once (in the gb-recompiled checkout).
PATH="$CLEAN_PATH" ninja -C ../gb-recompiled/build gbrecomp

# 1. Generate C from the ROM, driven by the TOML (+ harvested Tier-0 seeds).
PATH="$CLEAN_PATH" ../gb-recompiled/build/bin/gbrecomp.exe --config tetris.toml

# 2. Configure + build the generated project.
PATH="$CLEAN_PATH" cmake -G Ninja -S generated -B generated/build \
  -DCMAKE_C_COMPILER=/c/msys64/mingw64/bin/gcc.exe \
  -DCMAKE_CXX_COMPILER=/c/msys64/mingw64/bin/g++.exe \
  -DCMAKE_MAKE_PROGRAM=/c/msys64/mingw64/bin/ninja.exe \
  -DCMAKE_BUILD_TYPE=Release -DGBRECOMP_GENERATED_OPT_LEVEL=2
PATH="$CLEAN_PATH" ninja -C generated/build      # -> generated/build/Tetris.exe

# 3. Run it (SDL window; TCP debug server on 127.0.0.1:4370).
PATH="$CLEAN_PATH" ./generated/build/Tetris.exe

# 4. Harvest the run's interpreter fallbacks into the manifest, then GOTO 1.
PATH="$CLEAN_PATH" ../gb-recompiled/build/bin/gbrecomp.exe \
  --harvest generated/build/interp_fallbacks.log --manifest dispatch_misses.toml
```

### Packaging a release

Ship the executable **with `assets/`** (the launcher needs its fonts/images) and the
mingw-w64 runtime DLLs: `SDL2.dll`, `libEGL.dll`, `libGLESv2.dll`, `zlib1.dll`,
`libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`. `libEGL.dll` is loaded
dynamically by SDL/ANGLE, so `ldd` does not list it — omitting it fails at startup with
*"Could not load EGL library"* on machines without msys2.

Always verify the packaged tree from a clean `PATH` before publishing, and confirm the
CRC baked into the binary matches the ROM the release was generated from:

```bash
python -c "d=open('Tetris.exe','rb').read(); print(hex(d.find((0x63F9407D).to_bytes(4,'little'))))"
```

## Controls

| GB Button | Keyboard |
|-----------|----------|
| D-Pad     | Arrow keys |
| A         | Z |
| B         | X |
| Start     | Enter |
| Select    | Right Shift |

| Hotkey | Action |
|--------|--------|
| F1 | recomp-ui overlay (settings, video, input, mods) |
| TAB (hold) | Turbo (fast-forward) |

Rebind in the overlay or edit `keybinds.ini` next to the executable.

## Architecture

This is a **static recompiler**, not an emulator. The original SM83 (Game Boy CPU)
machine code is translated to C at build time, then compiled to native x64. The Game Boy
PPU, APU, and memory mapper are simulated by the runtime library.

## What's in this repo

| Path | Purpose |
|---|---|
| `tetris.toml` | Recompiler config: ROM path/CRC, output, entry points, HRAM overlay |
| `dispatch_misses.toml` | Tier-0 manifest: harvested zero-FP function-entry seeds (auto-ingested) |
| `extras.c` | Game hooks: expected CRC32, launcher name, `gb` (DMG) platform |
| `recomp/launcher/boxart.tga` | Launcher card art |
| `README.md` | This file |

**Not tracked (regenerable or external):** `generated/` (recompiler output + build tree),
`roms/` (the ROM), `logs/`, `interp_fallbacks.log`, and the `gb-recompiled` / `recomp-ui`
checkouts (pinned as submodules, junctions locally).

## Hard rules (inherited from the engine project)

- **Zero false positives in code discovery.** Decoding data as code is a failure.
  Trace-harvested seeds are safe because they provably executed.
- **Never edit generated code** (`generated/*.c`). It's a build artifact — fix the engine
  and regenerate.
- **Ghidra before guessing** runtime/crash behavior (engine RULE 0).

---

<p align="center">
  <sub><b>R.A.I.D. — Retro AI Development</b> · a Discord for AI-assisted retro reverse-engineering, decomp &amp; recomp</sub>
</p>

<p align="center">
  <a href="https://discord.gg/Ad9BwSzctP"><img src=".github/raid-discord.png" alt="Join the Retro AI Development (R.A.I.D.) Discord" width="200"></a>
</p>
