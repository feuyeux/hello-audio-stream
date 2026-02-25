plugins {
    java
    kotlin("jvm") version "2.3.10"
    kotlin("plugin.serialization") version "2.3.10"
    application
}

group = "org.feuyeux.mmap.audio"
version = "1.0.0"

repositories {
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/central") }
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    mavenCentral()
}

val ktorVersion = "3.0.3"

dependencies {
    add("implementation", "org.jetbrains.kotlin:kotlin-stdlib")
    add("implementation", "org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
    add("implementation", "org.jetbrains.kotlinx:kotlinx-coroutines-jdk8:1.10.1")
    add("implementation", "org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")

    add("implementation", "io.ktor:ktor-server-core:$ktorVersion")
    add("implementation", "io.ktor:ktor-server-websockets:$ktorVersion")
    add("implementation", "io.ktor:ktor-server-cio:$ktorVersion")
    add("implementation", "io.ktor:ktor-client-core:$ktorVersion")
    add("implementation", "io.ktor:ktor-client-websockets:$ktorVersion")
    add("implementation", "io.ktor:ktor-client-cio:$ktorVersion")

    add("implementation", "ch.qos.logback:logback-classic:1.5.15")
    add("implementation", "io.github.microutils:kotlin-logging-jvm:3.0.5")

    add("testImplementation", "org.jetbrains.kotlin:kotlin-test")
    add("testImplementation", "org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
    add("testImplementation", "io.ktor:ktor-server-tests:$ktorVersion")
}

the<JavaApplication>().mainClass.set("MainKt")

extensions.configure<JavaPluginExtension> {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

tasks.named<JavaExec>("run") {
    mainClass.set("MainKt")
    args = listOf("--input", "../audio/input/hello.opus", "--server", "ws://localhost:8080")
}

tasks.register<JavaExec>("runServer") {
    group = "application"
    description = "Run the audio stream server"
    classpath = project.the<SourceSetContainer>()["main"].runtimeClasspath
    mainClass.set("server.ServerKt")
}

tasks.register<JavaExec>("runClient") {
    group = "application"
    description = "Run the audio stream client"
    classpath = project.the<SourceSetContainer>()["main"].runtimeClasspath
    mainClass.set("MainKt")
}

tasks.named<Jar>("jar") {
    manifest {
        attributes["Main-Class"] = "MainKt"
    }
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(configurations.named("runtimeClasspath").get().map { if (it.isDirectory) it else zipTree(it) })
}
