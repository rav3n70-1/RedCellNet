// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // id("com.google.gms.google-services") // Add if using Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (!localPropertiesFile.exists()) {
    val localPropertiesFileAlt = project.file("../local.properties")
    if (localPropertiesFileAlt.exists()) { localPropertiesFileAlt.inputStream().use { reader -> localProperties.load(reader) } }
} else { localPropertiesFile.inputStream().use { reader -> localProperties.load(reader) } }
val flutterVersionCode: String = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName: String = localProperties.getProperty("flutter.versionName") ?: "1.0"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { reader -> keystoreProperties.load(reader) }
}

android {
    namespace = "com.example.red_cell_net"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Keep desugaring enabled
        isCoreLibraryDesugaringEnabled = true
    }

    sourceSets { getByName("main").java.srcDirs("src/main/kotlin") }

    defaultConfig {
        applicationId = "com.example.red_cell_net"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode ?: flutterVersionCode.toInt()
        versionName = flutter.versionName ?: flutterVersionName
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") { /* Standard debug */ }
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("debug") { signingConfig = signingConfigs.getByName("debug") }
        getByName("release") {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.biometric:biometric:1.1.0")

    // FIX: Update desugaring library version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Use required version
}
