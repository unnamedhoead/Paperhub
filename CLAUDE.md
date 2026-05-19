# Paperhub — Claude 工作指南

## 项目结构
- `Backend/paperhub/` — Spring Boot（端口 8080，远程 MySQL `1.95.209.72:3306/paperHub`，本机 Redis `localhost:6379`）
- `Frontend/` — Flutter（Web / macOS / Android / iOS）
- 全局 API 地址在 [Frontend/lib/config/app_env.dart](Frontend/lib/config/app_env.dart) 的 `_cloudHttpBase`
- arXiv 代理在 [Frontend/lib/services/arxiv_service.dart](Frontend/lib/services/arxiv_service.dart) 的 `_proxyBaseUrl`
- 打包 / 部署经验见 `Build/` 目录

---

## Git 提交规范

### Commit message 格式
- **English prefix + 中文正文**，前缀从下列五个里选：
  - `feat:` 新功能
  - `fix:` 修 bug
  - `refactor:` 重构（行为不变）
  - `chore:` 构建/依赖/配置/文档等杂项
  - `merge:` 合并
- **不用 emoji**（commit、UI、代码、文档都不用）。
- 一次 commit 只做一件事；refactor commit 不能含行为变更。

### 工作流
1. 改代码前先 `git pull`。
2. 改完后总结 diff（动了哪些文件、为什么）。
3. **要用户明确同意才能 commit**。同意 commit 即同意 push 到 `origin/main`，中间不要再问。
4. 用 `git add <具体文件>`，**禁止** `git add -A` 或 `git add .`。
5. 禁止 `--no-verify` 跳 hook，禁止 force-push 到 `main`。
6. 禁止提交 `.env`、密钥、凭证、`.DS_Store`、IDE 配置、构建产物。

---

## 重构指南

面向：把现在能跑、但耦合严重的代码逐模块拆成单职责、可测试、可维护的结构。

### 总原则（优先级从高到低）
1. **SRP（单一职责）**：每个文件/类只做一件事。超过 ~300 行的类、超过 ~50 行的方法都是拆分信号。
2. **分层**：UI ↔ State/Domain ↔ Service/HTTP ↔ Model。当前几乎没有 Domain 层，UI 直接调 `api_service`，需要补一层 Repository / UseCase。
3. **命名/目录一致**：同概念用同一个词、同一个目录。
4. **依赖方向**：上层依赖下层，禁止反向。后端禁止 controller 互调，前端禁止 screen 间直接 import。
5. **可测试**：拆分时同步补单元测试（前端 `flutter test`、后端 JUnit + MockMvc）。当前覆盖几乎为零。
6. **不要边重构边加功能**。一次 PR 要么是重构（行为不变 + 测试证明），要么是改行为。

### Frontend 上帝文件（按行数倒序，**优先拆**）
| 文件 | 行数 | 当前问题 | 拆分建议 |
|---|---|---|---|
| [lib/screens/post_detail_screen.dart](Frontend/lib/screens/post_detail_screen.dart) | 4431 | 详情页 UI + 评论树 + 点赞 + 举报 + PDF/视频/音频渲染 + 跳转逻辑挤在一个 State | 拆 `post_detail/` 子目录：`view/` / `controller/` / `subviews/` |
| [lib/screens/admin_mode_screen.dart](Frontend/lib/screens/admin_mode_screen.dart) | 3053 | 所有管理 tab 在一个文件 | 每个 tab 独立 screen + 共用 `admin_repository` |
| [lib/screens/profile_screen.dart](Frontend/lib/screens/profile_screen.dart) | 2312 | 资料 + 关注 + 帖子 + 设置混在一起 | 拆主页 + 各 tab |
| [lib/services/api_service.dart](Frontend/lib/services/api_service.dart) | 2161 | 单个 `ApiService` 类包所有 HTTP（帖子/用户/聊天/举报/管理…）| 按 backend 模块切：`PostApi` / `UserApi` / `ChatApi`…，共享 `HttpClient` 单例处理 token 刷新 |
| [lib/screens/message_screen.dart](Frontend/lib/screens/message_screen.dart) | 1684 | 消息列表 + 系统通知 + 路由判断 | 拆 `conversation_list` / `notification_list` |
| [lib/screens/home_screen.dart](Frontend/lib/screens/home_screen.dart) | 1405 | feed + 搜索入口 + tab 切换 | 抽 feed 为独立 widget |
| [lib/widgets/message_bubble.dart](Frontend/lib/widgets/message_bubble.dart) | 1257 | 所有消息类型在一个 widget 内 switch | 抽象基类 + 每种类型一个子类文件 |
| [lib/widgets/chat_input.dart](Frontend/lib/widgets/chat_input.dart) | 790 | 输入框 + 录音 + 附件 + emoji + 平台分支 | 拆 `ChatInputBar` / `AudioRecorderButton` / `AttachmentPicker` |

### Frontend 一致性问题
- **`pages/` vs `screens/` 并存**：[lib/pages/](Frontend/lib/pages/) 放登录/注册/笔记，[lib/screens/](Frontend/lib/screens/) 放主流程。统一到 `screens/`，删 `pages/`。
- **`mock_api_service.dart` 与真实 service 共存**：不用就删；要保留放 `services/mock/`。
- **状态管理缺失**：状态全在 `StatefulWidget.setState`。**全项目只选一个**（Provider / Riverpod / Bloc），不要混用。
- **入口分散**：[lib/main.dart](Frontend/lib/main.dart) 481 行 = 路由 + 主题 + 全局错误 + 服务初始化。拆 `app.dart` / `router.dart` / `theme.dart` / `bootstrap.dart`。

### Backend 上帝文件
| 文件 | 行数 | 拆分建议 |
|---|---|---|
| [post/PostController.java](Backend/paperhub/src/main/java/com/example/paperhub/post/PostController.java) | 702 | `PostController`（CRUD）/ `PostInteractionController`（点赞收藏）/ `PostFeedController`（推荐/关注） |
| [admin/AdminController.java](Backend/paperhub/src/main/java/com/example/paperhub/admin/AdminController.java) | 554 | 按对象拆 `AdminUserController` / `AdminPostController` / `AdminReportController` |
| [user/UserController.java](Backend/paperhub/src/main/java/com/example/paperhub/user/UserController.java) | 541 | `UserProfileController` / `UserSettingsController` / `UserFollowController` |
| [post/PostService.java](Backend/paperhub/src/main/java/com/example/paperhub/post/PostService.java) | 520 | `PostCrudService` / `PostInteractionService` |
| [comment/CommentController.java](Backend/paperhub/src/main/java/com/example/paperhub/comment/CommentController.java) | 454 | CRUD 与举报/审核分开 |
| [chat/ChatService.java](Backend/paperhub/src/main/java/com/example/paperhub/chat/ChatService.java) | 448 | `ConversationService` / `MessageService` / `ChatNotificationService` |

### Backend 包结构规范
当前每个 feature 包平铺所有类型。**重构后每个 feature 包内层级**：
```
post/
  api/      ← Controller + DTO
  domain/   ← Entity + Enum + 领域逻辑
  data/     ← Repository
  service/  ← 应用服务（编排 domain + data）
```
依赖方向：`api → service → domain + data`，`domain` 不依赖上层。

### Backend 跨切关注点
- **配置安全**：[application.properties](Backend/paperhub/src/main/resources/application.properties) 明文存了 DB 密码、JWT secret、阿里云邮箱密码、华为 OBS AK/SK。**必须迁到环境变量或 Spring Profile**（`application-prod.properties` 不进 git）。
- **统一异常**：补 `@ControllerAdvice`，统一返回 `{code, message, data}`。
- **DTO 校验**：入参补 `@Valid` / `@NotBlank` / `@Size`，删 service 层手写校验。
- **事务边界**：每个写操作 service 方法检查 `@Transactional`。

### 测试现状
- Frontend：只有默认脚手架 [test/widget_test.dart](Frontend/test/widget_test.dart)
- Backend：[src/test/java](Backend/paperhub/src/test/) 几乎空
- 重构要求：拆一个补一个，没测试的重构是赌博。

### 重构禁忌
1. **一次 PR 只做一件事**：refactor commit 不能含行为变更；改了 API 必须独立 commit + 同步前端。
2. **删代码前先 `grep` 引用**，特别是被外部 controller / 其他模块用的 service 方法。
3. **不要动 `Build/` 记录的配置**（明文 HTTP、阿里云镜像、JDK 17）除非同步更新打包文档。

### 推进顺序建议
1. **先补基础设施**：Frontend 定状态管理库；Backend 加全局异常 + DTO 校验 + 配置外置。这是后续所有重构的依赖。
2. **再拆 service / api_service**：业务层稳定，UI 才有据可依。
3. **最后拆 screen / controller**：上帝文件最难拆但风险最大，要前两步打底。
4. **每步都补测试**。

---

## 启动前后端
```bash
# 后端
cd Backend/paperhub && ./mvnw spring-boot:run

# 前端 Web（Chrome）— 注意 macOS 的 5000 端口被 AirPlay 占
cd Frontend && flutter run -d chrome --web-port=8090 \
  --dart-define=API_BASE_URL=http://1.95.209.72:8080
```
后端启动条件：本机 Redis 在跑（`redis-cli ping` = `PONG`）；远程 MySQL `1.95.209.72:3306` 可达。
