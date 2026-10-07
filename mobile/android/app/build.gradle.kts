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
            // Required: without these, R8 strips the generic signatures that
            // flutter_local_notifications' Gson deserialisation depends on,
            // and the boot receiver crashes the process on every app update.
            // See proguard-rules.pro.
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
