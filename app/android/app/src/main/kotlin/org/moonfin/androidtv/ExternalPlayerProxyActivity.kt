package org.moonfin.androidtv

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle

class ExternalPlayerProxyActivity : Activity() {

    companion object {
        private const val REQUEST_EXTERNAL_PLAYER = 8021
        private const val EXTRA_EXTERNAL_PLAYER_LAUNCH_INTENT = "moonfin.external_player.launch_intent"
        private const val EXTRA_EXTERNAL_PLAYER_ERROR_CODE = "moonfin.external_player.error_code"
        private const val EXTRA_EXTERNAL_PLAYER_ERROR_MESSAGE = "moonfin.external_player.error_message"
    }

    private var launchStarted = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            launchExternalPlayer()
        } else if (!launchStarted) {
            launchExternalPlayer()
        }
    }

    private fun launchExternalPlayer() {
        if (launchStarted) return
        launchStarted = true

        val launchIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_EXTERNAL_PLAYER_LAUNCH_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_EXTERNAL_PLAYER_LAUNCH_INTENT)
        }

        if (launchIntent == null) {
            finishWithError(
                code = "BAD_ARGS",
                message = "Missing external player launch intent.",
            )
            return
        }

        try {
            startActivityForResult(launchIntent, REQUEST_EXTERNAL_PLAYER)
        } catch (error: ActivityNotFoundException) {
            finishWithError(
                code = "PLAYER_NOT_FOUND",
                message = error.message ?: "Selected external player is unavailable.",
            )
        } catch (error: Exception) {
            finishWithError(
                code = "LAUNCH_FAILED",
                message = error.message ?: "Failed to launch external player.",
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_EXTERNAL_PLAYER) {
            return
        }

        setResult(resultCode, data)
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        val payload = Intent().apply {
            putExtra(EXTRA_EXTERNAL_PLAYER_ERROR_CODE, code)
            putExtra(EXTRA_EXTERNAL_PLAYER_ERROR_MESSAGE, message)
        }
        setResult(RESULT_CANCELED, payload)
        finish()
    }
}
