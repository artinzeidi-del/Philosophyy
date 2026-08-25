import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing material for a store build, when there is any.
//
// `android/key.properties` is not in the repository and is not meant to be:
// a key that ships with the source is a key anyone can sign with. When the
// file is absent — which is the case for every build that is not a store
// upload — the release build falls back to the keystore below, which is
// checked in on purpose. See the comment on `signingConfigs`.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.philosophia.philosophyy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.philosophia.philosophyy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs,
        // 1000 * ABI_VERSION is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // A keystore that is in the repository, with the password Android uses
        // for every debug key.
        //
        // The reason it is here rather than generated: Android decides whether
        // an APK is an update to an installed app by comparing signatures, and
        // a keystore generated on a fresh CI runner is a different key every
        // build. That produces a download that will not install over the copy
        // already on the phone — the reader has to uninstall first, and the
        // library they have marked up goes with it. A fixed key makes every
        // build an update to the last one.
        //
        // It protects nothing, and is not meant to: the password is public and
        // so is the file. That is exactly the same guarantee a debug key has
        // always given, and it is why this build is not one a store will take.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // The real one, created only when key.properties says where it is —
        // an empty signing config is a build failure waiting for the one
        // machine that has the file.
        keyProperties.getProperty("storeFile")?.let { store ->
            create("release") {
                storeFile = rootProject.file(store)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
