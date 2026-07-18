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

/* Tetris — CRC32 of roms/tetris.gb, the exact ROM this project is recompiled
 * from (the launcher gates the loaded ROM against this). */
uint32_t game_get_expected_crc32(void) {
    return 0x63F9407Du;
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
const char *game_get_name(void) { return "Tetris"; }
