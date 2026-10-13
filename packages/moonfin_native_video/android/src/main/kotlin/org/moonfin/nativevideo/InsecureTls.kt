package org.moonfin.nativevideo

import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * media3 streams through HttpURLConnection, which checks the system trust
 * store that the Dart client is told to skip, so a self signed server browses
 * fine and then fails every playback. Turning this on lets the player reach the
 * same server the rest of the app already talks to.
 *
 * The defaults it replaces are put back as soon as the setting goes off, so
 * nothing here outlives the choice the user made.
 */
object InsecureTls {
    private var allowed = false
    private var originalSocketFactory: SSLSocketFactory? = null
    private var originalHostnameVerifier: HostnameVerifier? = null

    @Synchronized
    fun setAllowed(allow: Boolean) {
        if (allow == allowed) return
        allowed = allow
        if (allow) apply() else restore()
    }

    private fun apply() {
        originalSocketFactory = HttpsURLConnection.getDefaultSSLSocketFactory()
        originalHostnameVerifier = HttpsURLConnection.getDefaultHostnameVerifier()

        val context = SSLContext.getInstance("TLS")
        context.init(null, arrayOf<TrustManager>(AcceptEveryCertificate), SecureRandom())
        HttpsURLConnection.setDefaultSSLSocketFactory(context.socketFactory)
        HttpsURLConnection.setDefaultHostnameVerifier { _, _ -> true }
    }

    private fun restore() {
        originalSocketFactory?.let { HttpsURLConnection.setDefaultSSLSocketFactory(it) }
        originalHostnameVerifier?.let { HttpsURLConnection.setDefaultHostnameVerifier(it) }
        originalSocketFactory = null
        originalHostnameVerifier = null
    }

    private object AcceptEveryCertificate : X509TrustManager {
        override fun checkClientTrusted(chain: Array<X509Certificate>?, authType: String?) = Unit

        override fun checkServerTrusted(chain: Array<X509Certificate>?, authType: String?) = Unit

        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }
}
