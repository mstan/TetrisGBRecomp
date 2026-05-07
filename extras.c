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

/* Tetris (Japan / World) — single canonical version. */
uint32_t game_get_expected_crc32(void) {
    return 0xE1AA58DBu;
}

/* Single-CRC game; defer to game_get_expected_crc32. */
const uint32_t *game_get_valid_crcs(int *out_count) {
    if (out_count) *out_count = 0;
    return 0;
}
