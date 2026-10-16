plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStorePath = System.getenv("KEYSTORE_PATH")
val releaseStorePassword = System.getenv("KEYSTORE_PASS")

android {
    namespace = "dev.astr.astrbot_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.astr.astrbot_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!releaseStorePath.isNullOrBlank()) {
            create("release") {
                storeFile = file(releaseStorePath)
                storePassword = requireNotNull(releaseStorePassword) {
                    "KEYSTORE_PASS is required when KEYSTORE_PATH is set"
                }
                keyAlias = "astrbot"
                keyPassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            // CI supplies the stable release key; local development can use
            // the debug key when no release keystore is configured.
            signingConfig = signingConfigs.getByName(
                if (releaseStorePath.isNullOrBlank()) "debug" else "release"
            )
        }
    }
}

flutter {
    source = "../.."
}
