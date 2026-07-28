plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val kinflowDefaultAuthRedirectHost = "auth.example.invalid"
val kinflowAuthRedirectHostPattern = Regex(
    "^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]{2,63}$",
)
val kinflowAuthRedirectHost = providers
    .gradleProperty("kinflowAuthRedirectHost")
    .getOrElse(kinflowDefaultAuthRedirectHost)
require(kinflowAuthRedirectHostPattern.matches(kinflowAuthRedirectHost)) {
    "kinflowAuthRedirectHost must be a DNS host without scheme, port, path, wildcard, or whitespace."
}

android {
    namespace = "me.newlines.kinflow"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "me.newlines.kinflow"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["kinflowAuthRedirectHost"] = kinflowAuthRedirectHost
            resValue("string", "app_name", "KinFlow Dev")
        }
        create("prod") {
            dimension = "environment"
            manifestPlaceholders["kinflowAuthRedirectHost"] = kinflowAuthRedirectHost
            resValue("string", "app_name", "KinFlow")
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
