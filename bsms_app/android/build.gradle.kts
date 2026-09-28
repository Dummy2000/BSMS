import com.android.build.gradle.AppExtension
import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val androidCompileSdk = 36

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Registered before the subproject applies AGP, so this runs after the
    // plugin's own build.gradle (which may pin an older compileSdk, e.g.
    // reactive_ble_mobile uses 33) but before AGP finalizes the DSL.
    afterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.apply {
            val current = compileSdkVersion?.removePrefix("android-")?.toIntOrNull()
            if (current != null && current < androidCompileSdk) {
                compileSdkVersion(androidCompileSdk)
            }
        }
        if (project.plugins.hasPlugin("com.android.application")) {
            project.extensions.configure<AppExtension>("android") {
                compileSdkVersion(androidCompileSdk)
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
