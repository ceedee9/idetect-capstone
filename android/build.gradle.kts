allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Register afterEvaluate BEFORE evaluationDependsOn triggers evaluations
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let { ext ->
            // Only raise compileSdk to minimum 34 (fixes lStar attr error in google_mlkit_commons)
            // Never lower it — sqflite_android needs 36+ for BAKLAVA constant
            if ((ext.compileSdk ?: 0) < 34) {
                ext.compileSdk = 34
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
