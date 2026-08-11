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
val kinflowDefaultSourceCommit = "0".repeat(40)
val kinflowSourceCommit = providers
    .gradleProperty("kinflowSourceCommit")
    .getOrElse(kinflowDefaultSourceCommit)
require(Regex("^[0-9a-f]{40}$").matches(kinflowSourceCommit)) {
    "kinflowSourceCommit must be an exact lowercase 40-hex Git commit."
}
val kinflowSourceState = providers
    .gradleProperty("kinflowSourceState")
    .getOrElse("dirty")
require(kinflowSourceState == "clean" || kinflowSourceState == "dirty") {
    "kinflowSourceState must be clean or dirty."
}

android {
    namespace = "me.newlines.kinflow"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "me.newlines.kinflow"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "kinflow_auth_redirect_host", kinflowAuthRedirectHost)
        manifestPlaceholders["kinflowSourceCommit"] = kinflowSourceCommit
        manifestPlaceholders["kinflowSourceState"] = kinflowSourceState
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
