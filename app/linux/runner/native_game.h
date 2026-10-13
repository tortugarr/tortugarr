#ifndef RUNNER_NATIVE_GAME_H_
#define RUNNER_NATIVE_GAME_H_

#include <flutter_linux/flutter_linux.h>

// Registers native retro-game playback on the given engine: the control and
// event channels plus the pixel-buffer texture that the shared libretro host
// renders into.
void moonfin_game_register(FlEngine* engine);

#endif  // RUNNER_NATIVE_GAME_H_
