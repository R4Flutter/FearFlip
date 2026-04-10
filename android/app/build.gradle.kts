import java.util.Properties
import org.gradle.api.GradleException

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
            manifestPlaceholders["admobAppId"] = releaseAdmobAppId ?: ""
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

if (releaseTasksRequested) {
    if (applicationIdValue == toolingFallbackApplicationId) {
        throw GradleException(
            "Release builds require a final Android applicationId. " +
                "Set fearflip.applicationId in android/release.properties " +
                "and regenerate Firebase/FlutterFire config to match.",
        )
    }

    if (releaseAdmobAppId.isNullOrBlank()) {
        throw GradleException(
            "Release builds require fearflip.admob.appId. " +
                "Set it in android/release.properties or FEARFLIP_ADMOB_APP_ID.",
        )
    }

    if (!hasReleaseSigning) {
        throw GradleException(
            "Release builds require android/key.properties with storeFile, " +
                "storePassword, keyAlias, and keyPassword.",
        )
    }
}

flutter {
    source = "../.."
}
