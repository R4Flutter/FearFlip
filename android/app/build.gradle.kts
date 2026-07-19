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
val toolingFallbackApplicationId = "dev.fearflip.game"
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

val defaultReleaseAdmobAppId = "ca-app-pub-3940256099942544~3347511713"

val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val releaseStorePassword = keystoreProperties.getProperty("storePassword")
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

if (releaseTasksRequested) {
    val errors = mutableListOf<String>()
    val googleServicesFile = project.file("google-services.json")
    val googleServicesText = if (googleServicesFile.exists()) {
        googleServicesFile.readText(Charsets.UTF_8)
    } else {
        ""
    }

    if (applicationIdValue == toolingFallbackApplicationId) {
        errors += "Set fearflip.applicationId in android/release.properties; fallback '$toolingFallbackApplicationId' cannot be uploaded to Play."
    }

    if (namespaceValue == toolingFallbackApplicationId) {
        errors += "Set fearflip.namespace to the final package namespace."
    }

    if (releaseAdmobAppId.isNullOrBlank() ||
        releaseAdmobAppId == defaultReleaseAdmobAppId ||
        !releaseAdmobAppId.startsWith("ca-app-pub-") ||
        !releaseAdmobAppId.contains("~")
    ) {
        errors += "Set fearflip.admob.appId to the real AdMob Android app id in android/release.properties."
    }

    if (!hasReleaseSigning) {
        errors += "Configure release signing in untracked android/key.properties before building a release bundle."
    }

    if (!googleServicesFile.exists()) {
        errors += "android/app/google-services.json is missing."
    } else if (!Regex("\"package_name\"\\s*:\\s*\"${Regex.escape(applicationIdValue)}\"").containsMatchIn(googleServicesText)) {
        errors += "google-services.json does not contain the release applicationId '$applicationIdValue'. Download a fresh Firebase config for the final package."
    }

    if (errors.isNotEmpty()) {
        throw GradleException(
            "FearFlip release configuration is incomplete:\n- " + errors.joinToString("\n- "),
        )
    }
}

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
                storeFile = rootProject.file(releaseStoreFilePath!!)
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
        maybeCreate("profile").apply {
            initWith(getByName("debug"))
            matchingFallbacks += listOf("debug")
            manifestPlaceholders["admobAppId"] =
                releaseAdmobAppId?.takeIf { it.isNotBlank() }
                    ?: defaultReleaseAdmobAppId
        }
        release {
            manifestPlaceholders["admobAppId"] =
                releaseAdmobAppId?.takeIf { it.isNotBlank() } ?: defaultReleaseAdmobAppId
            // R8 + resource shrinking. Keep rules for ads/firebase/billing/unity
            // already live in proguard-rules.pro, so shrinking is safe.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
