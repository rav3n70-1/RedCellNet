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

android {
    namespace = "com.example.red_cell_net" // Check/Update
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Keep this

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Keep desugaring enabled
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    sourceSets { getByName("main").java.srcDirs("src/main/kotlin") }

    defaultConfig {
        applicationId = "com.example.red_cell_net" // Check/Update
        minSdk = 23 // Keep this
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode ?: flutterVersionCode.toInt()
        versionName = flutter.versionName ?: flutterVersionName
        multiDexEnabled = true
    }

     signingConfigs { getByName("debug") { /* Standard debug */ } }

    buildTypes {
        getByName("debug"){ signingConfig = signingConfigs.getByName("debug") }
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug") // Change for release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation("androidx.multidex:multidex:2.0.1")

    // FIX: Update desugaring library version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Use required version

    // TODO: MERGE any other dependencies
}