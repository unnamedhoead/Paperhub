# PaperHub 私聊功能快速启动指南

## 快速开始

### 1. 环境检查
运行环境检查脚本：
```
check-env.bat
```

### 2. 启动服务
使用简化启动脚本：
```
start-services-simple.bat
```

如果仍有问题，请查看 `MANUAL_START.md` 进行手动启动。

## 服务地址

- **PaperHub后端**: http://localhost:8080
- **EasyChat服务**: http://localhost:8081
- **Flutter前端**: 手动运行 `cd Frontend && flutter run`

## 测试私聊功能

1. **注册新用户**
   - 访问前端应用
   - 使用邮箱注册新用户
   - 完成邮箱验证

2. **测试聊天**
   - 登录后进入"消息"页面
   - 点击任意会话进入聊天界面
   - 发送文本消息测试

## 故障排除

### Java版本问题
如果遇到Java版本冲突：

1. **临时切换Java版本**：
```cmd
REM 切换到Java 17
set JAVA_HOME=C:\Program Files\Java\jdk-17
set PATH=%JAVA_HOME%\bin;%PATH%

REM 切换到Java 8
set JAVA_HOME=C:\Program Files\Java\jdk1.8.0_xxx
set PATH=%JAVA_HOME%\bin;%PATH%
```

2. **分别启动**：
   - 先用Java 8启动EasyChat
   - 再用Java 17启动PaperHub

### 端口占用
如果端口被占用，修改配置文件：
- EasyChat: `easychat-java/src/main/resources/application-paperhub.yml`
- PaperHub: `Backend/paperhub/src/main/resources/application.properties`

### 数据库连接
确保MySQL和Redis服务正在运行：
- MySQL: 124.70.87.106:3306
- Redis: 124.70.87.106:6379

## 开发说明

详细的架构说明和API文档请查看 `CHAT_INTEGRATION.md`。