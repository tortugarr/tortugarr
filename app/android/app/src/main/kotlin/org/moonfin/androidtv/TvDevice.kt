package org.moonfin.androidtv

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

/**
 * Whether this device is a TV, or null when the platform could not answer.
 *
 * Both signals are calls into system_server, which is contended enough right
 * after a boot or a wake to throw. Callers need to tell that apart from a real
 * "no", because answering "no" puts the phone UI on a TV for the whole session.
 */
fun isTelevisionOrNull(context: Context): Boolean? {
    // The leanback feature is a static property of the device, so it is the
    // signal to trust when both answer.
    val hasLeanback = runCatching {
        val pm = context.packageManager
        pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature("amazon.hardware.fire_tv")
    }.getOrNull()
    if (hasLeanback == true) return true

    val uiModeType = runCatching {
        (context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)?.currentModeType
    }.getOrNull()
    if (uiModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true

    return if (hasLeanback == false && uiModeType != null) false else null
}

fun isTelevision(context: Context): Boolean = isTelevisionOrNull(context) == true
