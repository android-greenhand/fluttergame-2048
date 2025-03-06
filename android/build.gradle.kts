allprojects {
    repositories {
//        maven { "https://maven.aliyun.com/repository/google" };
//        maven { "https://maven.aliyun.com/repository/public" };
//        maven { "https://maven.aliyun.com/repository/jcenter" };
//        maven { "https://maven.aliyun.com/repository/gradle-plugin" };
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google();
        mavenCentral();
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
