plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.familyfinance.family_finance"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.familyfinance.family_finance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Google's enhanced sideloading protection refuses to install an APK that
    // declares BIND_NOTIFICATION_LISTENER_SERVICE when it comes from a browser
    // or file manager, with "App blocked to protect your device". It is a
    // blanket policy, not a malware verdict, so there is no way to allow it.
    //
    // The listener therefore lives only in the `detect` flavour. `standard`
    // carries no trace of it and sideloads normally; `detect` keeps automatic
    // payment detection and has to be installed over adb or from the Play
    // Store, which are exempt.
    flavorDimensions += "detection"

    productFlavors {
        create("standard") {
            dimension = "detection"
        }
        create("detect") {
            dimension = "detection"
            versionNameSuffix = "-detect"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = "familyfinance"
            keyPassword = "familyfinance123"
            storeFile = file("key.jks")
            storePassword = "familyfinance123"
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Needed since the ML Kit text recognition plugin references
            // optional script modules that are never packaged; see
            // proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

// google_mlkit_text_recognition depends on `com.google.mlkit:text-recognition`,
// which bundles the Latin OCR model into the APK. Swapping it for the
// Play-Services artifact keeps the model out of the build entirely: Google Play
// Services delivers it on demand instead. Same `com.google.mlkit.vision.text`
// API, so no plugin source changes are needed.
//
// The trade-off is that the first scan on a device that has not downloaded the
// model yet fails; BillScan treats that as "model not ready" and falls back to
// manual entry rather than surfacing an error.
configurations.all {
    resolutionStrategy.dependencySubstitution {
        substitute(module("com.google.mlkit:text-recognition"))
            .using(module("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1"))
            .because("Keeps the ~4MB bundled OCR model out of a sideloaded APK")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
