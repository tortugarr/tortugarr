package org.moonfin.androidtv

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Tortugarr: opens another installed app (SmartTube) by package, so it runs
 * as its own app with its own updates. Only the packages named in the
 * manifest's <queries> are visible to [installedPackage].
 */
object ExternalAppsChannel {
    private const val CHANNEL = "tortugarr/external_apps"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedPackage" -> {
                    val candidates = call.argument<List<String>>("packages") ?: emptyList()
                    result.success(candidates.firstOrNull { isInstalled(context, it) })
                }
                "launch" -> {
                    val pkg = call.argument<String>("package")
                    val intent = pkg?.let {
                        context.packageManager.getLeanbackLaunchIntentForPackage(it)
                            ?: context.packageManager.getLaunchIntentForPackage(it)
                    }
                    result.success(start(context, intent))
                }
                "view" -> {
                    val pkg = call.argument<String>("package")
                    val url = call.argument<String>("url")
                    val intent = if (pkg == null || url == null) null else
                        Intent(Intent.ACTION_VIEW, Uri.parse(url)).setPackage(pkg)
                    result.success(start(context, intent))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isInstalled(context: Context, pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun start(context: Context, intent: Intent?): Boolean {
        if (intent == null) return false
        return try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
