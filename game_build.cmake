# game_build.cmake — extensión por juego, incluida por el CMakeLists generado.
#
# Este repo compila dos revisiones de Tetris desde el mismo extras.c:
#   generated/      -> Tetris (World) V1.0     (tetris.toml)
#   generated-v11/  -> Tetris (JUE)   V1.1     (tetris-v11.toml)
# extras.c necesita saber cuál es para que el launcher acepte la ROM correcta.
get_filename_component(_tetris_out_dir "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
if(_tetris_out_dir STREQUAL "generated-v11")
    target_compile_definitions(${GBRECOMP_GAME_TARGET} PRIVATE TETRIS_V11=1)
    message(STATUS "Tetris: revisión V1.1 (CRC32 0x46DF91AD)")
else()
    message(STATUS "Tetris: revisión V1.0 (CRC32 0x63F9407D)")
endif()
