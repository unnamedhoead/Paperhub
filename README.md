# PaperHub

PaperHub 是一个服务高校师生与研究人员的学术社区。用户可以在平台上发布灵感笔记、浏览学科分区内容、关注学者、收藏/评论/点赞笔记，并通过即时通讯与通知系统保持交流。项目采用 **Flutter** 打造跨平台前端，后端基于 **Spring Boot + MySQL**，并实现 Access/Refresh Token 的安全认证与自动刷新机制。

---

## 核心特性

- 🧱 **瀑布流发现页**：两列 Masonry 卡片展示最新/热门帖子，支持懒加载和分页。
- 👥 **关注信息流**：仅显示已关注作者的动态，未读帖子以红点标识。
- 🏷️ **学科分区**：按主学科标签获取帖子，支持标签过滤，切换即刷新。
- 💬 **互动体验**：点赞、收藏、评论（含 @ 功能）、私信聊天与多种通知。
- 📹 **多媒体支持**：支持图片、视频上传与播放，以及多种文档类型（PDF、Word、Excel、PPT 等）。
- 🚨 **举报与审核系统**：完整的帖子举报流程，支持管理员下架、作者修改、审核通过/拒绝。
- 🪪 **账号体系**：注册、邮箱验证、登录、忘记密码、隐私设置与关注列表。
- 🧰 **管理员能力**：举报处理、帖子审核、公告管理等。
- 🛡️ **安全认证**：JWT Access Token（30 分钟）+ Refresh Token（7 天）自动续签。

---

## 项目结构

```
paperhub/
├── Backend/paperhub/            # Spring Boot 服务
│   ├── src/main/java/com/example/paperhub/...
│   ├── src/main/resources/application.properties
│   └── 各类实现说明（JWT、刷新、视频等）
├── Frontend/                    # Flutter 前端（Android/iOS/Web/Desktop）
│   ├── lib/                     # 页面、组件、数据模型、服务层
│   ├── assets/                  # 图片与字体
│   ├── android / ios / web ...  # 对应平台工程
│   └── pubspec.yaml
└── README.md                    # 当前文件
```

---

## 环境依赖

| 依赖            | 版本建议                                 |
| --------------- | ---------------------------------------- |
| Flutter SDK     | 3.9.x（参见 `Frontend/pubspec.yaml`）    |
| Dart SDK        | 与 Flutter 版本自带                      |
| Java            | JDK 17（推荐）                           |
| Maven           | 3.8+                                     |
| MySQL           | 8.x（需配置 `application.properties`）   |
| Redis（可选）   | 6.x                                      |

> ⚠️ 请在 `Backend/paperhub/src/main/resources/application.properties` 中配置实际的数据库、邮件、OBS 等账号信息。示例配置（含默认密码）仅供本地演示。

---

## 快速启动

### 1. 后端

```bash
cd Backend/paperhub

# 运行
mvn clean spring-boot:run

# 或打包
mvn clean package
java -jar target/paperhub-*.jar
```

- 本地运行默认访问地址：`http://localhost:8080`
- 主要接口：
  - `POST /auth/login`：登录，返回 accessToken + refreshToken
  - `POST /auth/refresh`：刷新 token
  - `GET /posts`：发现页列表（匿名可访问）
  - `GET /posts/following`：关注流（需登录）
  - 其他接口详见 `Backend/paperhub/src/main/java/com/example/paperhub`

### 2. 前端

```bash
cd Frontend
flutter pub get              # 安装依赖
flutter run -d chrome        # Web 调试

`main()` 启动时会初始化 `SharedPreferences` 并检查本地 token：若未过期则直接进入首页，否则跳转登录；收到 401 会自动调用 `/auth/refresh` 更新 token 并重放原请求。

---

## 使用说明

### 用户注册与登录

1. **注册账号**
   - 访问注册页面，填写邮箱、用户名、密码等信息
   - 系统将发送验证邮件至您的邮箱
   - 点击邮件中的验证链接完成注册

2. **登录系统**
   - 使用注册的邮箱和密码登录
   - 系统会自动保存登录状态（通过 Refresh Token）
   - 登录后自动跳转到首页

3. **忘记密码**
   - 在登录页点击"忘记密码"
   - 输入注册邮箱，系统将发送重置密码链接
   - 通过邮件链接重置密码

### 主要功能使用

1. **发布笔记**
   - 点击首页的"+"按钮创建新笔记
   - 支持添加标题、正文、图片、视频、音频、PDF 附件等
   - 可选择学科标签，设置可见性

2. **浏览内容**
   - **发现页**：查看所有公开笔记，支持按热门/最新排序
   - **关注流**：仅显示已关注用户的动态
   - **学科分区**：按学科标签筛选内容

3. **互动功能**
   - **点赞**：点击笔记或评论的点赞按钮
   - **收藏**：点击收藏按钮保存感兴趣的笔记
   - **评论**：在笔记下方发表评论，支持 @ 其他用户
   - **私信**：点击用户头像进入私信聊天

4. **个人中心**
   - 查看个人资料、发布的笔记、收藏的内容
   - 管理关注列表、隐私设置
   - 查看系统通知

---

## 关键配置

- **JWT & Refresh Token**
  ```properties
  jwt.secret=change-this-to-strong-secret-change
  jwt.expires-in-seconds=1800           # Access Token 30 分钟
  jwt.refresh-expires-in-seconds=604800 # Refresh Token 7 天
  ```
- **刷新机制**：详见 `Backend/paperhub/前端刷新令牌机制实现说明.md`，前端在 `ApiService` 中统一处理 401 → 刷新 → 重试。
- **本地存储**：`lib/services/local_storage.dart` 使用 `SharedPreferences`；`main()` 中 `LocalStorage.instance.init()` 确保刷新页面后仍可读取 token / 用户信息。

---

## 常用脚本

| 目标                   | 命令                                                         |
| ---------------------- | ------------------------------------------------------------ |
| 后端单元测试           | `cd Backend/paperhub && mvn test`                            |
| 后端运行               | `mvn spring-boot:run`                                        |
| Flutter 分析           | `cd Frontend && flutter analyze`                             |
| Flutter 单元测试       | `cd Frontend && flutter test`                                |
| 打包 Android APK       | `cd Frontend && flutter build apk --release`                 |
| 构建 Web 版本          | `cd Frontend && flutter build web`                           |
| 代码格式化（前端）     | `flutter format lib`（或 `dart format lib`）                 |

---

## 贡献指南

1. `git checkout -b feature/xxx` 新建分支。
2. 代码遵循：Java 使用 IDE 自动格式化；Flutter 提交前运行 `flutter analyze` & `dart format`.
3. 提交前确保必要的接口/页面经过自测，可在 README 或 MR 描述中附带截图。
4. 如果修改了数据库/配置文件，务必在文档中说明，避免队友无法启动。

欢迎通过 Issue/MR 报告 Bug、提建议或补充文档。涉及敏感配置（账号、密钥）需转移到环境变量或 `.env`，避免泄露。

---

## 参考文档

- `Backend/paperhub/JWT_TOKEN_FIX.md`：JWT 配置、permitAll 策略与常见问题
- `Backend/paperhub/前端刷新令牌机制实现说明.md`：双 Token 刷新流程
- `Frontend/VIDEO_SUPPORT_SUMMARY.md`：视频上传与播放功能实现
- `Backend/paperhub/FILE_TYPES_SUPPORT.md`：支持的文件类型列表
- `REPORT_POST_SYSTEM_COMPLETE.md`：完整的举报帖子系统实现文档
- `TAG_FILTER_COMPLETE_IMPLEMENTATION.md`：标签过滤功能实现说明
- 其他 `*_SUMMARY.md` 文件：特性实现或 Bug 修复的详细说明

---

## 部署指南

### CI/CD 配置

项目使用 GitLab CI/CD 进行自动化构建和部署，配置文件为 `.gitlab-ci.yml`。

#### 构建流程

CI/CD 流程包含以下阶段：

1. **前端构建** (`build_frontend`)
   - 使用 Flutter 3.35.7 镜像
   - 执行 `flutter pub get` 安装依赖
   - 执行 `flutter build web --release` 构建 Web 版本
   - 产物：`Frontend/build/web`

2. **后端构建** (`build_backend`)
   - 使用 Maven 3.9.9 + JDK 17 镜像
   - 执行 `mvn clean package -DskipTests` 打包
   - 产物：`Backend/paperhub/target/*.jar`

3. **测试** (`test`)
   - 执行后端验证（当前跳过单元测试）
   - 确保构建产物可用

4. **部署** (`deploy`)
   - 根据分支策略自动部署到对应环境

#### 触发条件

- **合并请求**：创建或更新 MR 时触发构建
- **推送事件**：推送到 `main`、`develop` 或 `local-upload` 分支时触发
- **Runner 要求**：需要配置带有 `前端` 和 `后端` 标签的自定义 Runner

#### 手动部署

##### 后端部署

1. **构建 JAR 包**
   ```bash
   cd Backend/paperhub
   mvn clean package -DskipTests
   ```

2. **运行 JAR 包**
   ```bash
   java -jar target/paperhub-*.jar
   ```

3. **使用 systemd 管理（Linux）**
   ```bash
   # 创建服务文件 /etc/systemd/system/paperhub.service
   [Unit]
   Description=PaperHub Backend Service
   After=network.target mysql.service

   [Service]
   Type=simple
   User=your-user
   WorkingDirectory=/path/to/paperhub/Backend/paperhub
   ExecStart=/usr/bin/java -jar target/paperhub-*.jar
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

4. **启动服务**
   ```bash
   sudo systemctl enable paperhub
   sudo systemctl start paperhub
   sudo systemctl status paperhub
   ```

##### 前端部署

1. **构建 Web 版本**
   ```bash
   cd Frontend
   flutter pub get
   flutter build web --release
   ```

2. **部署到 Web 服务器**

   **Nginx 配置示例**：
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       root /path/to/paperhub/Frontend/build/web;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }

       # API 代理
       location /api {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       }
   }
   ```

   **Apache 配置示例**：
   ```apache
   <VirtualHost *:80>
       ServerName your-domain.com
       DocumentRoot /path/to/paperhub/Frontend/build/web

       <Directory /path/to/paperhub/Frontend/build/web>
           Options Indexes FollowSymLinks
           AllowOverride All
           Require all granted
       </Directory>

       # API 代理
       ProxyPass /api http://localhost:8080/api
       ProxyPassReverse /api http://localhost:8080/api
   </VirtualHost>
   ```

3. **部署到静态托管服务**
   - **GitLab Pages**：将 `Frontend/build/web` 目录内容部署到 GitLab Pages
   - **Vercel/Netlify**：连接 Git 仓库，设置构建命令为 `cd Frontend && flutter build web`

#### 环境变量配置

部署前需要配置以下环境变量或配置文件：

**后端** (`application.properties`)：
- 数据库连接信息
- JWT 密钥
- OBS 对象存储配置
- 邮件服务配置

**前端** (`lib/config/app_env.dart`)：
- API 基础 URL
- 其他环境相关配置

#### 数据库迁移

部署前需要执行数据库迁移脚本：

```bash
# 执行所有 SQL 脚本
mysql -u root -p paperhub < Backend/paperhub/REPORT_POST_SYSTEM.sql
# 其他迁移脚本...
```

#### 健康检查

部署后验证服务是否正常运行：

```bash
# 后端健康检查
curl http://localhost:8080/actuator/health

# 前端访问
curl http://your-domain.com
```

---

## License & Status

本仓库为课程项目，默认遵从教学要求，暂未指定开源许可证。  
当前功能持续开发中。
