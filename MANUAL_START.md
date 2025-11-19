# 手动启动指南

如果自动启动脚本有问题，请按照以下步骤手动启动服务：

## 1. 启动 EasyChat 服务 (Java 8)

打开一个新的命令提示符窗口，执行：

```cmd
cd easychat-java
mvn spring-boot:run -Dspring-boot.run.profiles=paperhub
```

等待看到类似这样的输出：
```
Started EasyChatApplication in X.XXX seconds
```

## 2. 启动 PaperHub 后端服务 (Java 17)

打开另一个新的命令提示符窗口，执行：

```cmd
cd Backend\paperhub
mvn spring-boot:run
```

等待看到类似这样的输出：
```
Started PaperhubApplication in X.XXX seconds
```

## 3. 启动 Flutter 前端

打开第三个命令提示符窗口，执行：

```cmd
cd Frontend
flutter run
```

## 4. 验证服务状态

- PaperHub后端: http://localhost:8080
- EasyChat服务: http://localhost:8081
- Flutter前端: http://localhost:3000

## 常见问题

### Java 版本问题
如果你设置了 `JAVA_HOME` 指向 Java 8，但需要运行 Java 17 的服务，可以：

1. 临时设置 Java 17：
```cmd
set JAVA_HOME=C:\path\to\java17
set PATH=%JAVA_HOME%\bin;%PATH%
```

2. 或者在启动 PaperHub 后端时指定 Java 17 的完整路径：
```cmd
cd Backend\paperhub
"D:\java\jdk17\bin\java.exe" -jar target\paperhub-0.0.1-SNAPSHOT.jar
```

### Maven 问题
如果 Maven 命令失败，请确保：
1. Maven 已正确安装
2. Maven 的 `bin` 目录已添加到 PATH 环境变量
3. 或者使用 Maven 的完整路径：
```cmd
"C:\path\to\maven\bin\mvn.cmd" spring-boot:run
```

### 端口占用
如果端口被占用，可以修改配置文件中的端口号：
- EasyChat: 修改 `easychat-java/src/main/resources/application-paperhub.yml` 中的 `server.port`
- PaperHub: 修改 `Backend/paperhub/src/main/resources/application.properties` 中的 `server.port`