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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

gradle.projectsEvaluated {
    subprojects {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                val javaTarget = project.tasks.withType<JavaCompile>()
                    .firstOrNull()?.targetCompatibility
                if (javaTarget != null) {
                    jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
                    )
                }
            }
        }
    }
}
