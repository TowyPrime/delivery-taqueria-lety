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
subprojects {
    project.evaluationDependsOn(":app")
}

// stripe_android depende de play-services-tapandpay, que no está en ningún
// repositorio público: el lint "vital" del release no puede resolverlo y rompe
// el build. Se desactiva solo ese análisis en los módulos de plugins.
subprojects {
    if (project.name != "app") {
        tasks.configureEach {
            if (name.startsWith("lintVital")) {
                enabled = false
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
