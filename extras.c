/*
 * extras.c — TetrisGBRecomp game-specific hooks.
 *
 * The runtime library (gbrt) provides weak defaults for every game_*
 * hook in runtime/src/game_extras_default.c. We override only the ROM
 * identity hook here; everything else stays default.
 *
 * Modeled after FaxanaduRecomp/extras.c in the NES recomp project.
 */
#include <stdint.h>
#include "game_extras.h"

/* Two revisions are supported, each recompiled into its own output dir
 * (game_build.cmake defines TETRIS_V11 for generated-v11/). The launcher gates
 * the loaded ROM against the CRC32 of the exact image this binary came from:
 *   V1.0  Tetris (World)      roms/tetris.gb      CRC32 0x63F9407D
 *   V1.1  Tetris (JUE) V1.1   roms/tetris-v11.gb  CRC32 0x46DF91AD
 *         (A-TYPE music = Korobeiniki) */
#if defined(TETRIS_V11)
#  define TETRIS_ROM_CRC32 0x46DF91ADu
#  define TETRIS_TITLE     "Tetris (V1.1)"
#else
#  define TETRIS_ROM_CRC32 0x63F9407Du
#  define TETRIS_TITLE     "Tetris (V1.0)"
#endif

uint32_t game_get_expected_crc32(void) {
    return TETRIS_ROM_CRC32;
}

/* Single-CRC game; defer to game_get_expected_crc32. */
const uint32_t *game_get_valid_crcs(int *out_count) {
    if (out_count) *out_count = 0;
    return 0;
}

/* Tetris is a DMG (original Game Boy) title — override the "gbc" default so the
 * launcher shows the Game Boy profile/branding rather than Game Boy Color. */
const char *game_get_platform(void) { return "gb"; }

/* Launcher title (defaults to "GB Recompiled" otherwise). */
const char *game_get_name(void) { return TETRIS_TITLE; }
