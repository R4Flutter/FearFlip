import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties().apply {
    val propertiesFile = rootProject.file("release.properties")
    if (propertiesFile.exists()) {
        propertiesFile.reader(Charsets.UTF_8).use(::load)
    }
}

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.reader(Charsets.UTF_8).use(::load)
    }
}

fun configuredValue(propertyName: String, envName: String): String? {
    val gradleValue = providers.gradleProperty(propertyName).orNull
    if (!gradleValue.isNullOrBlank()) {
        return gradleValue
    }

    val releaseValue = releaseProperties.getProperty(propertyName)
    if (!releaseValue.isNullOrBlank()) {
        return releaseValue
    }

    val envValue = System.getenv(envName)
    if (!envValue.isNullOrBlank()) {
        return envValue
    }

    return null
}

val appName = configuredValue("fearflip.appName", "FEARFLIP_APP_NAME") ?: "FearFlip"
val namespaceValue =
    configuredValue("fearflip.namespace", "FEARFLIP_NAMESPACE") ?: "dev.fearflip.game"
val toolingFallbackApplicationId = "com.example.fearflipgame"
val applicationIdValue =
    configuredValue("fearflip.applicationId", "FEARFLIP_APPLICATION_ID")
        ?: toolingFallbackApplicationId
val releaseAdmobAppId = configuredValue(
    "fearflip.admob.appId",
    "FEARFLIP_ADMOB_APP_ID",
)
val releaseTasksRequested = gradle.startParameter.taskNames.any { taskName ->
    val normalized = taskName.lowercase()
    normalized.contains("release") ||
        normalized.contains("bundle") ||
        normalized.contains("publish")
}

    val defaultReleaseAdmobAppId = "ca-app-pub-1234567890123456~1234567890"

val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val releaseStorePassword = keystoreProperties.getProperty("storePassword")
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

android {
    namespace = namespaceValue
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        // Keep this literal assignment so Flutter tooling can statically resolve the package id.
        applicationId = "com.example.fearflipgame"
        if (applicationIdValue != toolingFallbackApplicationId) {
            applicationId = applicationIdValue
        }
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = appName
    }

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            manifestPlaceholders["admobAppId"] =
                releaseAdmobAppId?.takeIf { it.isNotBlank() } ?: defaultReleaseAdmobAppId
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

if (releaseTasksRequested) {
    if (applicationIdValue == toolingFallbackApplicationId) {
        logger.warn(
            "Release is using fallback applicationId '$toolingFallbackApplicationId'. " +
                "Set fearflip.applicationId in android/release.properties for production.",
        )
    }

    if (releaseAdmobAppId.isNullOrBlank()) {
        logger.warn(
            "Release fearflip.admob.appId is not configured; using fallback app id. " +
                "Set fearflip.admob.appId in android/release.properties for production.",
        )
    }

    if (!hasReleaseSigning) {
        logger.warn(
            "Release signing not configured in android/key.properties; using debug signing for this build.",
        )
    }
}

flutter {
    source = "../.."
}
