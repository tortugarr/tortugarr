#include "lh_audio.h"

#include <stdint.h>

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_ENCODING
#define MA_NO_DECODING
#define MA_NO_GENERATION
#include "vendor/miniaudio.h"

static ma_device g_device;
static int g_active;
static lh_host *g_host;

static void data_callback(ma_device *device, void *output, const void *input,
                          ma_uint32 frame_count) {
  (void)device;
  (void)input;
  if (g_host) {
    lh_read_audio(g_host, (int16_t *)output, (int)frame_count);
  }
}

int lh_audio_start(lh_host *host, double sample_rate) {
  g_host = host;
  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.format = ma_format_s16;
  config.playback.channels = 2;
  config.sampleRate = (ma_uint32)sample_rate;
  config.dataCallback = data_callback;

  if (ma_device_init(NULL, &config, &g_device) != MA_SUCCESS) return -1;
  if (ma_device_start(&g_device) != MA_SUCCESS) {
    ma_device_uninit(&g_device);
    return -2;
  }
  g_active = 1;
  lh_set_audio_paced(host, 1);
  return 0;
}

void lh_audio_stop(void) {
  if (g_active) {
    ma_device_uninit(&g_device);
    g_active = 0;
  }
  g_host = NULL;
}
