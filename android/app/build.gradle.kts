plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.havbits"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val releaseKeystore = file("../release.keystore")

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = "atobits"
            keyPassword = "atobits2024!"
            storeFile = releaseKeystore
            storePassword = "atobits2024!"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.havbits"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            signingConfig = if (releaseKeystore.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// Workaround: AGP can crash during :app:packageRelease if
// dex-metadata-map.properties becomes corrupted (e.g., contains NUL bytes).
// In that case, PackageApplication.baselineProfileDataForJson() blindly splits
// every line on '=' and indexes [1]. Sanitizing the file prevents the crash.
tasks.matching { it.name.startsWith("packageRelease") }.configureEach {
    doFirst {
        val candidates = listOf(
            file(
                "$buildDir/intermediates/dex_metadata_directory/release/compileReleaseArtProfile/dex-metadata-map.properties",
            ),
            file(
                "$buildDir/intermediates/dex_metadata_directory/release/compileReleaseArtProfile/out/dex-metadata-map.properties",
            ),
        )

        for (dexMetadataProps in candidates) {
            if (!dexMetadataProps.exists()) continue

            val bytes = dexMetadataProps.readBytes()
            val hasNul = bytes.any { it == 0.toByte() }
            val text = runCatching { String(bytes, Charsets.UTF_8) }.getOrElse { "" }
            val hasBadLine = text.lineSequence().any { line ->
                val trimmed = line.trim()
                trimmed.isNotEmpty() && !trimmed.contains("=")
            }

            if (hasNul || hasBadLine) {
                logger.warn("Sanitizing corrupted dex metadata map: ${dexMetadataProps.absolutePath}")
                dexMetadataProps.writeText("")
            }
        }
    }
}
