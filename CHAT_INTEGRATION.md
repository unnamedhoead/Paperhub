# PaperHub 私聊功能集成指南

## 架构概述

本项目实现了PaperHub学术社交平台的私聊功能，采用以下架构：

- **Frontend**: Flutter应用，负责用户界面和交互
- **Backend**: Spring Boot 3.5.7 (Java 17)，主业务逻辑和用户认证
- **EasyChat**: Spring Boot 2.6.1 (Java 8)，独立的聊天服务

## 技术方案

### 1. 版本冲突解决
- 保持两个后端独立运行，避免Java版本冲突
- PaperHub后端使用Java 17，EasyChat使用Java 8
- 通过PaperHub后端作为代理统一处理前端请求

### 2. 用户认证集成
- PaperHub负责用户注册、登录、邮箱验证
- 用户验证成功后自动同步到EasyChat系统
- 前端使用PaperHub的JWT令牌进行认证

### 3. 聊天功能实现
- 支持文本消息发送
- 支持图片/文件上传
- 支持表情发送
- 支持消息撤回和删除
- 支持会话列表管理

## 部署步骤

### 1. 环境要求
- Java 17 (PaperHub后端)
- Java 8 (EasyChat)
- MySQL 5.7+
- Redis
- Flutter 3.9.2+

### 2. 数据库准备

#### PaperHub数据库
使用现有的paperHub数据库

#### EasyChat数据库
执行 `easychat-java/easychat.sql` 创建表结构

### 3. 配置修改

#### PaperHub后端配置
检查 `Backend/paperhub/src/main/resources/application.properties`

#### EasyChat配置
使用 `easychat-java/src/main/resources/application-paperhub.yml`

### 4. 启动服务

#### 方式一：使用启动脚本
```bash
# Windows
start-services.bat

# Linux/Mac (需要创建对应的shell脚本)
./start-services.sh
```

#### 方式二：手动启动

1. 启动EasyChat服务：
```bash
cd easychat-java
mvn spring-boot:run -Dspring-boot.run.profiles=paperhub
```

2. 启动PaperHub后端：
```bash
cd Backend/paperhub
mvn spring-boot:run
```

3. 启动Flutter前端：
```bash
cd Frontend
flutter run
```

## API接口

### 聊天相关接口

#### 发送消息
- **URL**: `POST /api/chat/sendMessage`
- **认证**: Bearer Token
- **参数**:
  ```json
  {
    "contactId": "string",
    "messageContent": "string",
    "messageType": 0,
    "fileSize": null,
    "fileName": null,
    "fileType": null
  }
  ```

#### 获取会话列表
- **URL**: `GET /api/chat/conversations`
- **认证**: Bearer Token

#### 获取消息历史
- **URL**: `GET /api/chat/messages/{contactId}`
- **认证**: Bearer Token

## 功能特性

### 已实现功能
- ✅ 用户注册和认证
- ✅ 邮箱验证
- ✅ 用户同步到聊天系统
- ✅ 文本消息发送
- ✅ 会话列表
- ✅ 消息历史
- ✅ 消息状态管理（发送中/已发送/失败）

### 待实现功能
- ⏳ 图片/文件上传
- ⏳ 语音消息
- ⏳ 表情发送
- ⏳ 消息撤回
- ⏳ 消息删除
- ⏳ 实时消息推送

## 故障排除

### 常见问题

1. **EasyChat启动失败**
   - 检查Java 8是否正确安装
   - 检查MySQL和Redis连接配置

2. **用户同步失败**
   - 检查EasyChat服务是否正常运行
   - 查看后端日志中的错误信息

3. **消息发送失败**
   - 检查网络连接
   - 验证JWT令牌是否有效
   - 检查EasyChat服务状态

### 日志查看

- PaperHub后端日志：控制台输出
- EasyChat日志：控制台输出
- Flutter前端日志：开发工具控制台

## 开发说明

### 代码结构

```
Backend/paperhub/src/main/java/com/example/paperhub/chat/
├── ChatProxyController.java    # 聊天代理控制器
└── UserSyncService.java        # 用户同步服务

Frontend/lib/services/
└── chat_service.dart           # 聊天服务
```

### 扩展开发

要添加新的聊天功能：

1. 在EasyChat中添加对应的API接口
2. 在PaperHub的ChatProxyController中添加代理方法
3. 在前端的ChatService中添加对应的方法
4. 更新前端UI组件

## 联系方式

如有问题，请联系开发团队。