// A desktop audio sink for the libretro host, backed by miniaudio. Windows and
// Linux share it since neither runner has its own audio path. It opens a
// playback device that pulls the host ring, so the host paces on audio.

#ifndef LH_AUDIO_H
#define LH_AUDIO_H

#include "libretro_host.h"

#ifdef __cplusplus
extern "C" {
#endif

// Starts playback at [sample_rate] and switches the host to audio pacing.
// Returns 0 on success.
int lh_audio_start(lh_host *host, double sample_rate);

// Stops and releases the device.
void lh_audio_stop(void);

#ifdef __cplusplus
}
#endif

#endif  // LH_AUDIO_H
