package org.moonfin.nativevideo

import androidx.media3.common.AudioAttributes

class AudioAttributeState {
    private var audioAttributes: AudioAttributes? = null

    fun updateAudioAttributes(
        builder: AudioAttributes.Builder.() -> Unit,
        onChange: (audioAttributes: AudioAttributes) -> Unit,
    ) {
        val nextAudioAttributes = AudioAttributes.Builder().apply(builder).build()
        if (audioAttributes != nextAudioAttributes) {
            onChange(nextAudioAttributes)
            audioAttributes = nextAudioAttributes
        }
    }
}
