# 项目执行说明

简明说明如何在 Windows 环境下配置并运行本 Spring Boot 后端项目。

## 一、前置条件

- JDK 1.8
- Maven 3.x
- MySQL已经与远程数据库连接
- Git、IntelliJ IDEA

## 二、JDK 1.8 配置（Windows） 目前没办法在jdk17中找到安全的能运行的版本，现在要解决这个问题

1. 安装 JDK 1.8（例如安装到 `C:\Program Files\Java\jdk1.8.0_xx`）。
2. 配置环境变量：
   - 新建/修改 `JAVA_HOME` 指向 `C:\Program Files\Java\jdk1.8.0_xx`
   - 在 `Path` 中添加 `%JAVA_HOME%\bin`
3. 验证：
   - 打开 CMD，运行 `java -version`，应显示 1.8.x

## 三、Maven 配置 3.5及以上都可以

1. 安装 Maven（解压到例如 `C:\apache-maven-3.x`）。
2. 配置环境变量：
   - 新建/修改 `MAVEN_HOME` 指向 Maven 安装目录
   - 在 `Path` 中添加 `%MAVEN_HOME%\bin`
3. 可选：配置 `C:\Users\<你的用户>\.m2\settings.xml`（私服/镜像）。
4. 验证：`mvn -v`

## 四、其余配置

1. redis配置
spring.redis.database=0
spring.redis.host=127.0.0.1
spring.redis.port=6379
2. 文件存放目录配置
project.folder=c:/easychat/
3. 配置超级管理员
admin.emails=<test@qq.com>

## 五、运行

1. 终端运行 mvn clean install -U 编译包
2. 开始运行项目
