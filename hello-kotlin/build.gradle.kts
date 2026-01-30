plugins {
    java
    kotlin("jvm") version "2.2.0"
    kotlin("plugin.serialization") version "2.2.0"
    application
}

group = "org.feuyeux.mmap.audio"
version = "1.0.0"

repositories {
    // 使用阿里云镜像加速
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/central") }
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-jdk8:1.10.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")

    // WebSocket library - Ktor 3.x (latest)
    implementation("io.ktor:ktor-server-core:3.0.3")
    implementation("io.ktor:ktor-server-websockets:3.0.3")
    implementation("io.ktor:ktor-server-cio:3.0.3")
    implementation("io.ktor:ktor-client-core:3.0.3")
    implementation("io.ktor:ktor-client-websockets:3.0.3")
    implementation("io.ktor:ktor-client-cio:3.0.3")

    // Logging
    implementation("ch.qos.logback:logback-classic:1.5.15")
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")

    // Testing
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
    testImplementation("io.ktor:ktor-server-tests:3.0.3")
}

application {
    mainClass.set("MainKt")
}

kotlin {
    jvmToolchain(21)
}

// Task to run server
tasks.register<JavaExec>("runServer") {
    group = "application"
    description = "Run the audio stream server"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("server.MainKt")
}

// Task to run client
tasks.register<JavaExec>("runClient") {
    group = "application"
    description = "Run the audio stream client"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("MainKt")
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "MainKt"
    }
    // 创建 fat JAR，包含所有依赖
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
}
