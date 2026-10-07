import java.util.Properties

fun loadAndroidTvVersionCode(rootDir: File, fallback: Int): Int {
    val pubspec = rootDir.resolve("../pubspec.yaml")
    if (!pubspec.exists()) return fallback

    val line = pubspec.readLines().firstOrNull {
        it.trimStart().startsWith("android_tv_build_number:")
    } ?: return fallback

    val rawValue = line.substringAfter(":", "").trim()
    return rawValue.toIntOrNull() ?: fallback
}

fun loadAndroidTvVersionName(rootDir: File, fallback: String): String {
    val pubspec = rootDir.resolve("../pubspec.yaml")
    if (!pubspec.exists()) return fallback

    val line = pubspec.readLines().firstOrNull {
        it.trimStart().startsWith("android_tv_version:")
    } ?: return fallback

    val rawValue = line.substringAfter(":", "").trim()
    return rawValue.ifEmpty { fallback }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val keystoreStoreType = keystoreProperties
    .getProperty("storeType")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }

val hasReleaseKeystore = rootProject.file("app/release.keystore").exists() &&
    (keystoreProperties.getProperty("keyAlias")?.isNotBlank() == true)

android {
    namespace = "org.moonfin.androidtv"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    val androidTvVersionCode = loadAndroidTvVersionCode(rootDir, flutter.versionCode)
    val androidTvVersionName = loadAndroidTvVersionName(rootDir, flutter.versionName)

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Fallback so the main manifest's ${enableImpeller} always resolves;
        // TV flavors override this to "false".
        manifestPlaceholders["enableImpeller"] = "true"
    }

    flavorDimensions += "device"
    productFlavors {
        // Own id (Tortugarr), separate from upstream Moonfin. The namespace below stays as-is.
        val baseAppId = "io.github.tortugarr"
        val baseAppName = "Tortugarr"
        val mobileAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        val tvAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        create("mobile") {
            dimension = "device"
            applicationId = baseAppId
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk { abiFilters += mobileAbis }
            manifestPlaceholders["appName"] = baseAppName
        }
        create("mobile-beta") {
            dimension = "device"
            applicationId = "$baseAppId.beta"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk { abiFilters += mobileAbis }
            manifestPlaceholders["appName"] = "$baseAppName Beta"
        }
        create("androidTv") {
            dimension = "device"
            applicationId = baseAppId
            versionCode = androidTvVersionCode
            versionName = androidTvVersionName
            ndk { abiFilters += tvAbis }
            manifestPlaceholders["appName"] = baseAppName
            // Impeller off on TV: the GLES fallback stutters on TV-box GPUs.
            manifestPlaceholders["enableImpeller"] = "false"
        }
        create("androidTv-beta") {
            dimension = "device"
            applicationId = "$baseAppId.beta"
            versionCode = androidTvVersionCode
            versionName = androidTvVersionName
            ndk { abiFilters += tvAbis }
            manifestPlaceholders["appName"] = "$baseAppName Beta"
            manifestPlaceholders["enableImpeller"] = "false"
        }
        // Public build (build-android-tv-public.sh): no server keys, no Firebase.
        // Own id so it never replaces the private build on a device.
        create("androidTv-public") {
            dimension = "device"
            applicationId = "$baseAppId.public"
            versionCode = androidTvVersionCode
            versionName = androidTvVersionName
            ndk { abiFilters += tvAbis }
            manifestPlaceholders["appName"] = baseAppName
            manifestPlaceholders["enableImpeller"] = "false"
        }
        // Public phone/tablet build (build-android-tv-public.sh --mobile).
        create("mobile-public") {
            dimension = "device"
            applicationId = "$baseAppId.public"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk { abiFilters += mobileAbis }
            manifestPlaceholders["appName"] = baseAppName
        }
    }

    // The public builds use the same manifests as the private ones.
    sourceSets {
        getByName("androidTv-public") {
            manifest.srcFile("src/androidTv/AndroidManifest.xml")
        }
        getByName("mobile-public") {
            manifest.srcFile("src/mobile/AndroidManifest.xml")
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file("release.keystore")
                storeType = keystoreStoreType
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += setOf("**/libc++_shared.so")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-cast-framework:22.0.0")
    implementation("eu.simonbinder:sqlite3-native-library:3.52.0")
    implementation("androidx.tvprovider:tvprovider:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.10.1")
}

val flutterApkOutputDir = layout.buildDirectory.dir("app/outputs/flutter-apk")

tasks.register<Copy>("copyAndroidTvDebugApkForFlutter") {
    from(flutterApkOutputDir.map { it.file("app-androidtv-debug.apk") })
    into(flutterApkOutputDir)
    rename { "app-debug.apk" }
}

tasks.matching { it.name == "assembleDebug" }.configureEach {
    finalizedBy("copyAndroidTvDebugApkForFlutter")
}

// The bundled google-services.json is upstream Moonfin's Firebase project; the
// public build carries none of it (push is off in Tortugarr anyway).
tasks.configureEach {
    if (name.contains("GoogleServices") && name.contains("public", ignoreCase = true)) enabled = false
}
