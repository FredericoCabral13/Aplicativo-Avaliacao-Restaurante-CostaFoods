plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_restaurante"
    compileSdk = flutter.compileSdkVersion.toInt()
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.app_restaurante"
        minSdk = flutter.minSdkVersion.toInt()  // ✅ .toInt()
        targetSdk = flutter.targetSdkVersion.toInt()  // ✅ .toInt()
        versionCode = flutter.versionCode?.toInt() ?: 1  // ✅ Tratamento seguro
        versionName = flutter.versionName ?: "1.0.0"  // ✅ Tratamento seguro
    }

    buildTypes {
        release {
            // ✅ Mantenha debug para teste, mas recomendo criar signing config
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true  // ✅ Otimização
            isShrinkResources = true  // ✅ Reduz tamanho
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}