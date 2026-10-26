import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store upload key. android/key.properties (git-ignored) points at the keystore, which lives
// outside the repo. Without it - e.g. on a co-developer's machine - release builds fall back to
// the debug key: fine for testing, but Play rejects them, so store builds must come from a machine
// that has the upload key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKey = keystorePropertiesFile.exists()
if (hasUploadKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.focalsoft.fsvalet.fs_valetfusion"
    // Google Play requires new apps and updates to target a recent API level; 36 = Android 16.
    compileSdk = 36
    // flutter.ndkVersion (26.3.11579264) resolves to a broken/incomplete NDK install on this
    // machine (empty toolchain/llvm/prebuilt bin dir - CMAKE_C_COMPILER not set). Pinned to
    // 26.1.10909125, which is fully present, until the SDK manager's 26.3 download is repaired.
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications uses java.time APIs that need desugaring below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Permanent once published on Play (and registered in Firebase) - never change it.
        applicationId = "com.focalsoft.fsvalet.fs_valetfusion"
        // 23 (Android 6): required by firebase_messaging.
        minSdk = 23
        targetSdk = 36
        // From pubspec.yaml "version: x.y.z+N" - bump N for every Play upload.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    // Two flavours of the same app: "production" (Play Store id, talks to valetfusion.focalsoft.ae)
    // and "staging" (own id so it installs next to production, own Firebase app, talks to
    // stvf.focalsoft.ae). The Dart side reads VF_ENV (lib/config/environment.dart).
    //   flutter build apk --flavor production --dart-define=VF_ENV=production
    //   flutter build apk --flavor staging    --dart-define=VF_ENV=staging
    flavorDimensions += "env"
    productFlavors {
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "Valet Fusion")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Valet Fusion STG")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Push notifications (FCM) switch on only once the Firebase project's google-services.json is
// dropped into android/app/. Without it the app still builds and runs; FirebaseBootstrap just
// skips push and the in-app/local reminders keep working.
// Each flavour needs the google-services.json of ITS OWN Firebase app:
//   production -> android/app/google-services.json          (production project)
//   staging    -> android/app/src/staging/google-services.json (staging project)
// The plugins are applied only when the file for the flavour being built exists, so a staging
// build without a staging Firebase project still compiles (push simply stays off).
val requestedFlavor = gradle.startParameter.taskNames.joinToString(" ").let {
    if (it.contains("Staging", ignoreCase = true)) "staging" else "production"
}
val googleServicesFile = if (requestedFlavor == "staging") file("src/staging/google-services.json") else file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    // Crash reports from testers' / customers' phones (Firebase console > Crashlytics).
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.warn("Firebase: ${googleServicesFile.path} not found - building '$requestedFlavor' without push/crash reporting")
}
