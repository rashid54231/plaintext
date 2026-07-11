allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all subprojects to use Java 17 to suppress Java 8 obsolete warnings
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.AppExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureProject = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            val methods = android.javaClass.methods
            for (method in methods) {
                if (method.name == "compileSdk" || method.name == "setCompileSdk") {
                    if (method.parameterTypes.size == 1 && (method.parameterTypes[0] == java.lang.Integer::class.java || method.parameterTypes[0] == Integer.TYPE)) {
                        method.invoke(android, 36)
                        break
                    }
                }
            }
            for (method in methods) {
                if (method.name == "compileSdkVersion" || method.name == "setCompileSdkVersion") {
                    if (method.parameterTypes.size == 1 && (method.parameterTypes[0] == java.lang.Integer::class.java || method.parameterTypes[0] == Integer.TYPE)) {
                        method.invoke(android, 36)
                        break
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }
}
