# Paperhub 7 人代码重构分工方案（方案 A：纵向功能切分）

> 目标：把 Paperhub（Spring Boot 后端 + Flutter 前端）的重构工作拆给 **7 位开发者并行推进**，
> **首要约束是 7 人修改的代码文件尽量不重叠**，其次才是负载均衡。
> 本方案据此先确定「文件 → 负责人」的归属，再据此倒推重构报告中的人员分工章节。

---

## 0. 如何使用本文档

- 第 1–2 节：划分原则 + 已识别冲突热点（理解「为什么这么分」）。
- 第 3 节：7 人角色总览表（一眼看清谁负责什么）。
- 第 4 节：逐人详细分工（每个人的独占文件、重构任务、测试、依赖）。
- 第 5 节：**跨人协调点清单**（无法完全解耦的少数文件，给出明确交接顺序）。
- 第 6 节：共享文件与写权限归属（多人引用、单人可写的文件）。
- 第 7 节：推进阶段与时间线（基础设施先行 → 并行 → 集成）。
- 第 8 节：风险与缓解。
- 附录 A：**完整「文件 → 负责人」映射表**（用于验证零冲突）。

---

## 1. 划分总原则（优先级从高到低）

1. **文件不冲突优先**：同一源文件原则上只有 **1 位写权限负责人**；其余人只读引用。
2. **基础设施先行（P1 是使能者）**：跨切关注点（安全、统一响应、HTTP 客户端、状态管理、路由）先由 1 人抽好，发布「契约」，其余 6 人再在其上并行开发，避免抢改 `config/`、`api_service.dart`、`main.dart`。
3. **「先拆后分」处理上帝文件**：横跨多个功能域的巨型文件（`post_detail_screen` / `message_screen` / `profile_screen` / `admin_mode_screen` / `api_service`）由**主负责人**先拆成子目录/子文件，把属于其它域的部分**切成独立文件**交给对应负责人，彼此通过**类型化接口**调用，落到文件层面互不重叠。
4. **纵向功能切分**：除 P1 外，每人负责一个「后端包 + 对应前端文件」的完整垂直切片，符合项目 CLAUDE.md 的「按 feature 分包」结构。
5. **拆一个补一个**：每位负责人对自己拆出的模块**同步补单元测试**（后端 JUnit + MockMvc，前端 `flutter test`），重构 commit 行为不变并由测试证明。

---

## 2. 已识别的冲突热点（来自代码扫描）

这些是 7 人并行最大的冲突来源，必须用「基础设施先行 + 先拆后分」机制化解：

| 文件 | 行数 | 横跨的功能域 | 处理方式 |
|---|---|---|---|
| `services/api_service.dart` | 2161 | **全部域**（115 个静态方法：auth/user/history/follow/like/favorite/comment/notification/post/admin/report/chat…）| P1 先抽 `HttpClient` 单例；各域负责人**新建自己的 `services/api/<domain>_api.dart`**；旧文件最后由 P1 删除 |
| `screens/post_detail_screen.dart` | 4431 | 帖子正文(P3) + 评论树(P4) + 点赞/收藏(P4) + 举报(P6) + PDF/视频/音频渲染(P3) | P3 拆 `screens/post_detail/`；评论 UI 切成 `widgets/comment/`（P4）；点赞/举报经 P4/P6 的 API 调用 |
| `screens/message_screen.dart` | 1684 | 会话列表(P5) + 系统通知/新增粉丝等通知子页(P4) | P5 拆 `screens/message/`：`conversation_list`(P5) + `notification_list`/通知子页(P4) |
| `screens/profile_screen.dart` | 2312 | 用户资料(P2) + 关注/粉丝列表(P4) + 帖子/收藏/草稿(数据来自 P3) + 举报(P6) | P2 拆 `screens/profile/`；关注列表切成 `follow_list_sheet`(P4)；帖子 tab 经 P3 的 PostApi |
| `screens/admin_mode_screen.dart` | 3053 | 后台 9 个子模块（用户/帖子/举报/公告/权限…）| 全属 P6，单人独占，无跨人冲突 |
| `user/UserController.java` | 541 | 用户资料/隐私/媒体(P2) + 关注/粉丝(P4) | P2 拆出 `UserProfileController` 等；关注端点切成 `follow/FollowController`(P4) |
| `post/PostController.java` `post/PostService.java` | 702 / 520 | 全属帖子域(P3) 单人独占；其中「帖子举报」端点归 P6 的 `report/` 包 | P3 独占拆分，无跨人冲突 |
| `config/SecurityConfig.java` 等 | — | 安全/JWT 影响所有 Controller | P1 独占；各域只在**自己的 Controller**上加 `@PreAuthorize`（改自己文件，不冲突）|
| `websocket/` 各 Handler | — | 推送服务 post(P3)/notification(P4)/admin(P6) 都要用 | P5 独占 `websocket/` 基础设施，对外暴露稳定推送 API；其余人调用不改文件 |

---

## 3. 7 人角色总览

| 编号 | 角色（领域）| 建议负责人 | 后端包 | 前端主战场 | 负载 |
|---|---|---|---|---|---|
| **P1** | 平台基础设施与安全 | 张云夏 | `config/` `jwt/` 新建`common/` | `core/http_client`、状态管理、`main.dart`拆分、共享 utils/常量 | 中（关键路径）|
| **P2** | 认证与用户账户 | 盛曦 | `auth/` `user/` `notify/` | auth 页面、`profile_screen→profile/`、`privacy_settings`、user 模型 | 高 |
| **P3** | 帖子创作/详情 + arXiv | 屈越 | `post/` `arxiv/` | `post_detail_screen→post_detail/`、`note_editor→note_editor/`、`post_card`、PDF 渲染、`arxiv_service` | **最高** |
| **P4** | 互动系统 | 郑以琳 | `comment/` `like/` `favorite/` `follow/` `notification/` | 评论 UI、`follow_list_screen`、通知子页、点赞/收藏控制器、`unread_service` | 高 |
| **P5** | 即时通讯与 WebSocket | 陈佳怡 | `chat/` `websocket/` | `chat_screen`、`message_screen→message/`、`message_bubble`、`chat_input`、聊天媒体组件 | 高 |
| **P6** | 后台管理与举报 | 待定（第 7 位）| `admin/` `report/` | `admin_mode_screen→admin/`、`report_post_dialog` | 高 |
| **P7** | 内容浏览与检索 | 王杏 | `history/` `hot/` | `home_screen`、`zone_screen`、`search_screen`、`search_results_screen`、历史/搜索本地缓存 | 中 |

> 负责人为「按 Milestone-1 分析连续性」的**建议**，可由团队调整。其中 P3（帖子域）独占两个最大前端文件（post_detail 4431 + note_editor 2284），是关键路径与最重负载，建议安排最熟悉帖子流程者，并最早启动。

---

## 4. 逐人详细分工

### P1 — 平台基础设施与安全（张云夏）

**职责**：先把跨切关注点做好并**发布契约**，让其余 6 人能在稳定地基上并行开发。是关键路径，需在 Phase 0 基本完成。

**独占后端文件 / 任务**
- `config/SecurityConfig.java`：恢复 `addFilterBefore(jwtAuthenticationFilter, …)`；`/auth/**`、`/arxiv/**` 等白名单 `permitAll()`，`/admin/**` / `/api/admin/**` 要求 `hasAnyRole('ADMIN','SUPER_ADMIN')`；P1 阶段其余业务接口先兼容 `permitAll()`，由各域后续在自己的 Controller 上补 `@PreAuthorize` 后再逐步收紧；`@EnableMethodSecurity`；CORS `allowedOrigins` 收敛为白名单。
- `config/JwtAuthenticationFilter.java`：`ROLE_USER` 硬编码改为 `ROLE_ + user.getRole().name()`；异常打日志不静默吞。
- `config/GlobalExceptionHandler.java`：统一返回 `{code, message, data}`；按**基类异常**分发。
- `config/RedisConfig.java` `config/RestTemplateConfig.java` `config/ObsConfig.java`：`ObsConfig.endpoint` 等从配置读取，去硬编码。
- `jwt/JwtService.java`：抽 `buildToken(...)` / `parseTokenSafely(...)` 消除重复；常量 `BEARER_PREFIX/TOKEN_TYPE_CLAIM/TOKEN_TYPE_REFRESH`；secret 去除明文默认值（缺失即启动报错）；`parseToken` 改 `private`；token 内嵌 `userId`、`jti`。
- `application.properties` → **只保留非敏感默认配置**，并通过 `spring.config.import=optional:classpath:application-local.properties` 读取本地私有覆盖；敏感项放在已被 `.gitignore` 忽略的 `application-local.properties` / `application-prod.properties`，**使用真实 Spring 配置键**（如 `jwt.secret`、`spring.datasource.password`、`spring.mail.password`、`huawei.obs.ak`、`huawei.obs.sk`），不要在主配置里写 `${JWT_SECRET}` 这类必须额外解析的中间占位符；禁止覆盖开发者已有的 `application-local.properties`。
- **新建** `common/` 包：
  - `common/dto/ApiResponse.java`（`record {int code, String message, T data}`）。
  - `common/exception/`：`ApiException`、`NotFoundException`、`ForbiddenException`、`BadRequestException` 等基类（各域 throw 这些，由 `GlobalExceptionHandler` 统一捕获）。
  - `common/security/PermissionUtils.java`（`ensureAdmin/ensureSuperAdmin`，供尚未迁到 `@PreAuthorize` 的过渡期使用）。
  - `jwt/TokenBlacklistService.java`（Redis 黑名单：封禁/退出/改密时加入，TTL=原剩余有效期；过滤器验证后查黑名单）。
- `PaperhubApplication.java`。

**独占前端文件 / 任务**
- **新建** `services/core/http_client.dart`：从 `api_service.dart` 抽出统一请求封装（401 单飞刷新、token 注入、Multipart 重试），供全部 `*_api.dart` 复用。
- `services/local_storage.dart`：token/userId 读写（`http_client` 依赖）。
- `services/background_service.dart`。
- `services/mock_api_service.dart`：P1 阶段先保留，不混入基础设施收尾；后续单独清理时再删除或迁到 `services/mock/`。
- `main.dart` → 拆 `app.dart` / `router.dart`（命名路由 / GoRouter，支持深链接）/ `theme.dart` / `bootstrap.dart`。
- **选定并接入状态管理**（项目统一一个，推荐 Provider）：建立 `providers/` 约定与根节点注入；发布「如何写一个 Controller/Notifier」范式。
- `config/app_env.dart`：集中所有 base URL（含 arXiv 代理地址，供 P3 读取）。
- 共享 UI 与工具（见第 6 节）：`utils/dialog_utils.dart`、`utils/font_utils.dart`、`constants/app_colors.dart`、`constants/dialog_styles.dart`、`constants/discipline_constants.dart`、`widgets/bottom_navigation.dart`、`widgets/animated_title_background.dart`、`widgets/video_background.dart`、`models/dialog_option.dart`。

**P1 必须最先发布的「契约」**（其余人据此动工）：HttpClient 调用方式 → `ApiResponse`/错误结构 → 基类异常 → 状态管理范式 → 路由注册约定（各人提供路由表条目）→ `services/api/<domain>_api.dart` 命名约定。

**测试**：`JwtService`（签发/校验/刷新/黑名单）、`SecurityConfig` 端点放行矩阵（MockMvc）、`GlobalExceptionHandler` 各异常映射、`http_client` 401 刷新单飞。

**依赖**：无（最前置）。**被依赖**：全部 6 人。

---

### P2 — 认证与用户账户（盛曦）

**职责**：auth 登录注册与令牌、用户资料/隐私/媒体；持有 `User` 实体唯一写权限。

**独占后端文件 / 任务**
- `auth/AuthController.java`：令牌生成下沉到 `AuthService.login()`；字符串匹配状态码改为**自定义异常**（继承 P1 基类）；修复 `refresh` 语义（无效 token→401 带响应体、用户不存在→404、未验证→403）。
- `auth/AuthService.java`：抽 `refreshAndSendVerificationCode(User)`；TTL 魔法数字提常量。
- `auth/User.java`：引入 Lombok（`@Getter/@Setter/@NoArgsConstructor`）消除 90 行样板；`role` 默认值前移删 `@PrePersist`；字段按认证/资料/角色/隐私分组。
- `auth/UserRepository.java` `auth/UserRole.java` `auth/UserStatus.java`。
- `auth/dto/AuthDtos.java` → 每个 DTO 独立文件。
- `user/UserController.java` → 拆 `UserProfileController` / `UserPrivacyController` / `UserMediaController` / `UserSearchController`；**禁止直接访问 Repository**，统一经 Service。
  - ⚠️ 其中 `/{userId}/follow`、`/{userId}/unfollow` 等**关注端点切出为 `follow/FollowController`，归 P4**（见协调点 C2）。
- `user/UserService.java` `user/dto/UserDtos.java`。
- `notify/MailService.java`（验证码邮件，auth 流程使用）。

**独占前端文件 / 任务**
- auth 页面迁到 `screens/auth/`：`login_page` `register_page` `forgot_password_page` `reset_password_page` `verify_email_page`。
- `screens/profile_screen.dart` → 拆 `screens/profile/`：`profile_screen`(骨架) / `profile_header` / `profile_tabs` / `profile_edit_sheet` / `profile_controller`。
  - ⚠️ 关注/粉丝列表切成 `screens/profile/follow_list_sheet.dart`，归 P4（见协调点 C4）。
  - 帖子/收藏/草稿 tab 经 **P3 的 PostApi** 取数；举报用户经 **P6 的 ReportApi**。
- `screens/privacy_settings_screen.dart`。
- `models/user_profile.dart` `models/user_summary.dart`：增加 DTO/adapter 层，`role/status` 用枚举；模型层去掉「字段别名兜底」。
- **新建** `services/api/auth_api.dart` `services/api/user_api.dart`（从 `api_service` 迁移 auth/user 相关方法，统一走 `http_client`，含修复绕过 401 刷新的 `updateProfile/uploadAvatarBytes/uploadBackgroundBytes`）。

**测试**：注册/重发验证码/登录/refresh 语义、`User` Lombok 等价性、资料更新与隐私设置、上传走统一 401 刷新。

**依赖**：P1（HttpClient/异常基类/状态管理）。**被依赖**：P4（`User` 实体、`UserController` 拆分后的 follow 端点壳）、P3/P6（资料页内嵌帖子/举报）。

---

### P3 — 帖子创作/详情 + arXiv（屈越）【最重 / 关键路径】

**职责**：帖子后端全栈（CRUD/流/草稿/媒体/搜索后端）+ 帖子详情与笔记编辑前端 + arXiv 文献元数据。**`post/` 包单人独占 → 后端零拆分冲突。**

**独占后端文件 / 任务**
- `post/PostController.java` → 拆 `PostCrudController` / `PostFeedController` / `PostSearchController` / `PostMediaController`（**帖子举报端点不在此**，归 P6 的 `report/`）。新增批量帖子查询 `GET /posts/batch?ids=...`（供 P7 历史 N+1 优化，见 C7）。
- `post/PostService.java` → 拆 `PostCrudService` / `PostFeedService` / `PostDraftService` / `PostSearchService` / `PostMediaService`。
- `post/RecommendationService.java` `post/FollowFeedRepository.java` `post/Post.java` `post/PostMapper.java` `post/PostRepository.java` `post/PostStatus.java` `post/UserInterest.java` `post/dto/PostDtos.java`（统一 `CreatePostReq/UpdatePostReq/PostMediaReq`）。
- `arxiv/ArxivController.java` + **新建** `arxiv/ArxivProxyService.java`（代理模式：构造官方请求、设 UA/Accept、处理超时/404）、`arxiv/ArxivMetadataAdapter.java`（适配器：XML→DTO）、`arxiv/dto/ArxivMetadataDto.java`；统一 SLF4J 与错误码 `{code:"ARXIV_NOT_FOUND",...}`。

**独占前端文件 / 任务**
- `screens/post_detail_screen.dart` → 拆 `screens/post_detail/`：`view/`（header/content/media/action_bar）+ `controller/` + `subviews/`。
  - ⚠️ 评论树 UI 切成 `widgets/comment/`（`comment_section`/`comment_item`/reply），**归 P4**，P3 在详情页以 widget 形式嵌入并定义插槽（见 C3）。点赞/收藏经 P4 的 InteractionApi；举报经 P6 的 ReportApi。
- `pages/note_editor_page.dart` → `screens/note_editor/`：`note_editor_screen` / `note_editor_controller` / `note_media_section` / `arxiv_metadata_section` / `reference_selector` / `tag_suggestion_panel`；引入 `PostDraft` 模型；`_publishNote` 拆 `validateDraft→uploadMedia→buildPayload→submit→handleResult` 管线；补 `mounted` 守卫与 `FocusNode.dispose()`；上传文件类型用 `enum UploadFileType`。
- `widgets/post_card.dart`（**P3 写权限**，被 P2/P5/P7 只读引用，见第 6 节）：点赞乐观更新逻辑改用 P4 的 InteractionController/provider。
- `widgets/reference_display.dart`。
- PDF 渲染组件 `widgets/pdf_iframe_view.dart` `pdf_iframe_view_web.dart` `pdf_iframe_view_stub.dart`（仅 `post_detail` 使用）。
- `models/post_model.dart`：状态用枚举映射。
- `services/arxiv_service.dart`：代理地址改 `'${AppEnv.apiBaseUrl}/arxiv'`；优先由后端解析 XML，前端只消费 JSON。
- **新建** `services/api/post_api.dart` `services/api/arxiv_api.dart`。

**测试**：发布/编辑/草稿/删除/无权限；标签提取纯函数；arXiv ID 提取/非法/无结果/字段缺失；XML→DTO 适配。

**依赖**：P1。**被依赖**：P4（评论插槽、点赞入口）、P6（下架帖子调用 Post 服务）、P7（PostApi、`post_card`、批量端点）、P2（资料页帖子 tab）。

---

### P4 — 互动系统（郑以琳）

**职责**：评论、点赞、收藏、关注、通知五个后端包 + 对应前端 UI；用「模板方法/事件发布」统一互动行为。

**独占后端文件 / 任务**
- `comment/`：`CommentController`（抽 `handleLikeResponse/buildErrorResponse`，补匿名空检查）、`CommentService`（递归删除改数据库级联 / 批量删除）、`Comment` `CommentRepository` `comment/dto/CommentDtos`。
- `like/`：`LikeService`（抽公共交互模板 `ensureUserCanInteract` + 计数同步；计数改原子 SQL）、`PostLike` `PostLikeRepository` `CommentLike` `CommentLikeRepository`。
- `favorite/`：`FavoriteService`（`toggleFavorite` 统一）、`FavoritePost` `FavoritePostRepository`。
- `follow/`：`FollowService`、`UserFollow` `UserFollowRepository`，**新建 `follow/FollowController.java`**（接收 P2 从 `UserController` 切出的关注端点，见 C2）。
- `notification/`：`NotificationController`、`NotificationService`（抽 `buildAndSaveNotification`）、**新建 `NotificationPushService`**（把 WebSocket 推送从通知创建中分离，调用 P5 的 websocket 推送 API）、`Notification` `NotificationRepository` `NotificationType` `notification/dto/NotificationDtos`。

**独占前端文件 / 任务**
- **新建** `widgets/comment/`：`comment_section` / `comment_item` / 回复输入（从 `post_detail` 切出，嵌入 P3 详情页）。
- `screens/follow_list_screen.dart` + **新建** `screens/profile/follow_list_sheet.dart`（从 profile 切出，见 C4）。
- **新建** `screens/message/notification_list.dart` 及系统通知/新增粉丝等通知子页（从 `message_screen` 切出，见 C3）。
- `services/unread_service.dart`、`services/notification_websocket_service.dart`（通知 WS 客户端；后端 WS 基础设施属 P5）。
- 点赞/收藏统一 `InteractionController`/provider（供 `post_card`(P3)、各列表页复用）。
- **新建** `services/api/interaction_api.dart`（like/favorite）`services/api/comment_api.dart` `services/api/follow_api.dart` `services/api/notification_api.dart`。

**测试**：递归删除评论、点赞/取消幂等、关注状态变化、通知发送条件与去重、回关判断。

**依赖**：P1、P2（`UserController` 关注端点交接、`User` 实体）、P3（评论插槽）、P5（websocket 推送 API）。**被依赖**：P3（点赞/评论入口）。

---

### P5 — 即时通讯与 WebSocket（陈佳怡）

**职责**：聊天后端 + WebSocket 基础设施（对全站推送提供稳定 API）+ 聊天前端（含从轮询改为推送）。

**独占后端文件 / 任务**
- `chat/`：`ChatController`、`ChatFileController`、`ChatService`（构造器注入；抽 `doSendMessage` 公共内核；消息查询 N+1 用 `JOIN FETCH`/批量 `findAllById`；禁言过期写回 `NORMAL`）→ 视情拆 `ConversationService/MessageService/ChatNotificationService`；`Conversation` `ConversationParticipant` `Message` 及 `*Repository`、`ConversationType` `MessageType` `RedisKeys`、`chat/dto/*`。
- `websocket/`（**全站推送基础设施，单人独占**）：`ChatWebSocketHandler`（`Map<Long,Map<String,WebSocketSession>>` 支持多设备）、`ChatWebSocketService`、`SimpleWebSocketConfig`、`SimpleWebSocketHandler`（按会话域拆 `PostWebSocketHandler/AdminWebSocketHandler/NotificationWebSocketHandler` + 抽 `AbstractBroadcastHandler` 公共 `broadcastToSessions`；`startsWith` 精确前缀匹配；`getUri()` 空检查；服务端心跳 + `@Scheduled` 清僵尸；SLF4J）、`WebSocketService`（9 个内部消息类提取到**新建 `websocket/message/`** 包，`private final + @JsonProperty`）、**新建 `websocket/WsPaths.java`** 路径常量。
  - 对外暴露稳定推送 API：`pushToUser/pushToPost/pushToAdmins`，供 P4(通知)/P3(帖子)/P6(管理) 调用而不改本包文件。

**独占前端文件 / 任务**
- `screens/chat_screen.dart`：2 秒轮询改为订阅 WebSocket 推送（断线降级轮询）；抽 `_setupConversation`；删死代码（`_isTyping/_typingUser/_scrollToBottomRetryCount/_previousMaxExtent`）；`_scrollToBottom` 改 `addPostFrameCallback`。
- `screens/message_screen.dart` → 拆 `screens/message/`：`message_screen`(骨架) + `conversation_list`(P5)；`notification_list` 及通知子页归 P4（见 C3）。
- `widgets/message_bubble.dart` → 抽象基类 + 每种消息类型一个子类（`widgets/message/` 子目录）。
- `widgets/chat_input.dart` → 拆 `ChatInputBar` / `AudioRecorderButton` / `AttachmentPicker`。
- `widgets/conversation_item.dart`、`widgets/video_message_player.dart`、`widgets/web_audio_recorder.dart` `web_audio_recorder_stub.dart`、`widgets/html_stub.dart` `widgets/html_web.dart`（message_bubble 的 web 条件导入 stub）。
- `models/conversation_model.dart` `models/message_model.dart`。
- `services/chat_service.dart`（WS 驱动）。
- **新建** `services/api/chat_api.dart`。

**测试**：`doSendMessage` 公共内核、消息分页无 N+1、多设备会话不丢消息、禁言过期、前端轮询→推送切换。

**依赖**：P1。**被依赖**：P4（通知推送 API）、P3/P6（帖子/管理推送 API）。

---

### P6 — 后台管理与举报（待定 / 第 7 位成员）

**职责**：后台管理全栈 + **合并两套并行举报系统**（`report/` 与 `admin/` 各一套）。`admin/`+`report/` 单人独占。

**独占后端文件 / 任务**
- `admin/AdminController.java` → 拆 `AdminUserController` / `AdminPostController` / `AdminNoticeController` / `AdminReportController` / `AdminPermissionController`；全部改 `@PreAuthorize`；修复 `getAuditUsers` 被注释的鉴权漏洞；Controller 不直接操作 `PostRepository`（下沉 `AdminService.hidePost()`）。
- `admin/AdminService.java`：补 `ensureAdmin()`；`searchUsers` 改 Repository 分页查询、`listReports` 关键词过滤下推 SQL（修分页破损）；禁言时长换算下沉；删 `System.out.println`。
- `admin/AdminDtos.java` → 每个 DTO 独立文件；`admin/AdminNotice` `AdminReport` 及 `*Repository`、`AdminApplication` `AdminApplicationRepository`、`admin/ReportStatus` `admin/ReportTargetType`。
- `report/`（**合并入 admin 体系**）：删 `ReportController.java`（空壳死代码）；`ReportPostService.java` 拆 `ReportPostUserService`/`ReportPostAdminService`，内嵌 `PostDetailResponse` 提为独立 record；`ReportUserController.java` 抽 `ReportUserService`、响应统一 `OperationResponse`、补发通知；统一 `ReportStatus` 枚举（消除 `PROCESSED` vs `RESOLVED`）；`report/dto/ReportPostDtos.java` 拆分；`getPostDetail` 的 switch 用 `PostVisibilityPolicy` 策略 + 分页下推 SQL。
- 下架帖子/封禁用户经 **P3 PostService / P2 UserService**（不直接改其实体）。

**独占前端文件 / 任务**
- `screens/admin_mode_screen.dart` → 拆 `screens/admin/`：各子模块独立 Section Widget（`admin_user_section`/`admin_post_section`/`admin_report_section`/`admin_notice_section`/`admin_permission_section`）+ `admin_controller`，骨架仅留顶栏/侧栏/路由。修 `'MUTED'→'MUTE'` 状态标签、补 `AUDIT→待审核`；删举报人重复显示；合并 `_viewPostDetail`(带 `showManageButton` 参数)；抽 `_getUserDisplayName`。
- `widgets/report_post_dialog.dart`：改为先查 HTTP 200 再查业务 `success` 字段。
- **新建** `services/api/admin_api.dart` `services/api/report_api.dart`。

**测试**：权限矩阵（`@PreAuthorize`）、用户/举报搜索分页正确性、举报全流程（举报→处理→通知）、两套举报合并后状态一致。

**依赖**：P1（安全/`@PreAuthorize`）、P3（PostService）、P2（UserService）、P5（管理推送 API）。**被依赖**：P2/P3（资料页/详情页的举报入口经 ReportApi）。

---

### P7 — 内容浏览与检索（王杏）

**职责**：浏览历史、搜索历史、热搜后端 + 首页流/分区/搜索前端（消费 P3 的帖子 API）。

**独占后端文件 / 任务**
- `history/`：`BrowseHistoryController` `BrowseHistoryService`（修 `findTop50` 清理逻辑：改 Repository 统计 + 删 N 条之后）`BrowseHistory` `BrowseHistoryRepository`；`SearchHistoryController` `SearchHistoryService` `SearchHistory` `SearchHistoryRepository`；两者补 DTO（`BrowseHistoryItemResp` 等）替代 `Map`、`@Valid` 校验。
- `hot/`：`HotSearchController` `HotSearchService` `HotSearch` `HotSearchRepository`。

**独占前端文件 / 任务**
- `screens/home_screen.dart`：抽出 feed widget；搜索入口跳转到本人 `search_screen`；feed 数据经 **P3 的 PostApi**、列表项用 **P3 的 `post_card`**（只读引用）。
- `screens/zone_screen.dart`。
- `screens/search_screen.dart` `screens/search_results_screen.dart`。
- `models/search_model.dart`；**新建** `models/browse_history_item.dart`（从 service 切出）。
- `services/browse_history_service.dart` `services/search_history_service.dart`：抽 **新建** `services/core/local_json_list_store.dart`（`LocalJsonListStore<T>` 泛型本地缓存，统一编解码/排序/容量/逐条容错）；容量常量统一；不再静默吞异常。
- **新建** `services/api/history_api.dart` `services/api/search_api.dart` `services/api/hot_api.dart`。

**测试**：历史新增/去重/容量/云端失败回退本地、坏数据逐条跳过、搜索分页、批量帖子加载替代 N+1。

**依赖**：P1、P3（PostApi、`post_card`、批量端点 `GET /posts/batch`）。**被依赖**：无（叶子）。

---

## 5. 跨人协调点清单（必须按顺序交接）

| # | 协调点 | 涉及 | 交接顺序 |
|---|---|---|---|
| **C1** | `api_service.dart` 拆分 | P1 + 全部 | ① P1 抽 `http_client.dart` 并发布约定 → ② 各域负责人新建自己的 `services/api/<domain>_api.dart` 迁移方法 → ③ 全部迁完后 P1 删除 `api_service.dart` |
| **C2** | `UserController` 关注端点 | P2 → P4 | ① P2 先做 `UserController` 拆分（refactor commit）→ ② 关注端点切到 `follow/FollowController` 交 P4 接管 |
| **C3** | `message_screen.dart` 拆分 | P5 → P4 | ① P5 拆 `screens/message/` 骨架 + `conversation_list` → ② `notification_list`/通知子页交 P4 填充 |
| **C4** | `profile_screen.dart` 关注列表 | P2 → P4 | ① P2 拆 `screens/profile/` → ② `follow_list_sheet` 交 P4 |
| **C5** | `post_detail_screen.dart` 评论树 | P3 → P4 | ① P3 拆 `post_detail/` 并定义评论插槽 widget → ② P4 在 `widgets/comment/` 实现，P3 嵌入 |
| **C6** | WebSocket 推送 API | P5 → P3/P4/P6 | ① P5 先定义 `pushToUser/pushToPost/pushToAdmins` 稳定签名 → ② P3/P4/P6 只调用不改 `websocket/` |
| **C7** | 批量帖子查询 | P3 → P7 | ① P3 在 `PostController` 加 `GET /posts/batch` → ② P7 历史页改批量取数消除 N+1 |
| **C8** | `@PreAuthorize` 注解 | P1 → 各域 | ① P1 开 `@EnableMethodSecurity` + 动态角色 → ② 各人在**自己的 Controller**加注解（改自己文件，不冲突）|
| **C9** | 统一 `ApiResponse` / 基类异常 | P1 → 各域 | ① P1 提供 `common/` → ② 各人 Controller throw 基类异常 + 返回 `ApiResponse`（改自己文件）|
| **C10** | 共享实体写权限 | P2/P3 → 其余 | `User`(P2)、`Post`(P3) 仅写权限人改字段；其余人经 Service/API 读取 |

---

## 6. 共享文件与写权限归属

多人引用、**仅 1 人可写**，其余人只读 import；需改动时向写权限人提需求：

| 文件 | 写权限 | 只读引用方 |
|---|---|---|
| `widgets/post_card.dart` | P3 | P2(profile) / P5(message_bubble) / P7(home,zone,search_results) |
| `widgets/message_bubble.dart` | P5 | （内部引用 post_card）|
| `widgets/report_post_dialog.dart` | P6 | P3（`post_detail` 调用举报弹窗）|
| `widgets/bottom_navigation.dart`、`animated_title_background.dart`、`video_background.dart` | P1 | 各 screen |
| `utils/dialog_utils.dart`（7 处引用）、`font_utils.dart` | P1 | 全体 |
| `constants/*`（颜色/样式/学科常量）| P1 | 全体 |
| `config/app_env.dart` | P1 | P3(arxiv 代理) 等 |
| `auth/User.java` | P2 | P3/P4/P6（经 Service 读）|
| `post/Post.java` `post/PostStatus.java` | P3 | P6(下架)/P7 |
| `websocket/` 推送 API | P5 | P3/P4/P6 |
| `services/core/http_client.dart` | P1 | 全部 `*_api.dart` |

> `html_stub.dart`/`html_web.dart` 为 web 条件导入 shim，归 P5（`message_bubble` 使用）；若 P3 的 PDF web 端也需 `dart:html`，其已有 `pdf_iframe_view_web.dart` 自带，不共用同一文件。

---

## 7. 推进阶段与时间线

- **Phase 0｜地基（P1 单独，约 1 周）**：P1 完成安全链恢复、`http_client`、`common/ApiResponse`+异常基类、状态管理范式、`main.dart` 拆分、配置外置，并**发布全部契约**。其余 6 人此阶段只读代码、规划各自拆分草图、写测试骨架，不深改共享文件。
- **Phase 1｜并行重构（P2–P7，约 2–3 周）**：
  - 每人先**新建自己的 `*_api.dart`**（C1 第②步）；
  - 后端在自己包内拆 Controller/Service；前端拆自己的上帝文件子目录；
  - 协调点 C2–C5 按「主负责人先拆、次要方后填」顺序推进；C6/C7 先定接口签名再并行。
  - **拆一个补一个测试**。
- **Phase 2｜集成与清理（约 1 周）**：P1 删除旧 `api_service.dart`（C1 第③步）；全链路联调；`@PreAuthorize` 权限矩阵回归；CI 由 `mvn verify -DskipTests` 改回 `mvn verify`，前端跑 `flutter test`。

---

## 8. 风险与缓解

| 风险 | 缓解 |
|---|---|
| P1 是关键路径，拖慢则全员阻塞 | P1 优先**发布接口契约与空壳/stub**，让 P2–P7 先按接口编码，P1 再补实现 |
| P3 负载最重（两个最大前端文件 + 帖子后端）| 最早启动；`post_detail` 与 `note_editor` 可分两个 sprint；必要时团队内临时支援 |
| 上帝文件「先拆后分」期间主/次方并发改同一文件 | 严格按 C2–C5 顺序；主负责人拆分作为**独立 refactor commit** 先合入，次要方再基于新结构动工 |
| 安全链恢复（启用 JWT 过滤器）可能瞬间打挂所有「裸调用」接口 | P1 在 Phase 0 采用兼容启用：JWT 过滤器先恢复并识别登录态，`/admin/**` / `/api/admin/**` 先收紧管理员角色，其余业务接口暂时 `permitAll()`；各域补全 token 透传与 `@PreAuthorize` 后再逐步收紧普通接口 |
| 重构混入行为变更 | 每个 PR 要么纯重构（测试证明行为不变）要么纯改行为；改 API 必须独立 commit + 同步前端 |
| 共享 widget（`post_card`/`message_bubble`）被多方需求拉扯 | 写权限归单人；他人提 issue/PR 评审，不直接改 |

---

## 附录 A：完整「文件 → 负责人」映射表（零冲突核对）

### 后端 `Backend/paperhub/src/main/java/com/example/paperhub/`
| 包 / 文件 | 负责人 |
|---|---|
| `PaperhubApplication.java` | P1 |
| `config/*`（Security/JwtFilter/GlobalException/Redis/RestTemplate/Obs）| P1 |
| `jwt/JwtService.java` + 新建 `TokenBlacklistService` | P1 |
| 新建 `common/*` | P1 |
| `auth/*`（含 `User`、`dto/AuthDtos`）| P2 |
| `user/*`（拆出的 follow 端点除外）| P2 |
| `notify/MailService.java` | P2 |
| `post/*`、`arxiv/*` | P3 |
| `comment/*` `like/*` `favorite/*` `follow/*`（含新建 `FollowController`）`notification/*` | P4 |
| `chat/*` `websocket/*`（含新建 `message/`、`WsPaths`）| P5 |
| `admin/*` `report/*` | P6 |
| `history/*` `hot/*` | P7 |

### 前端 `Frontend/lib/`
| 文件 / 目录 | 负责人 |
|---|---|
| `main.dart`→`app/router/theme/bootstrap`、`config/app_env.dart`、`constants/*`、`utils/*`、`services/core/http_client.dart`、`services/local_storage.dart`、`services/background_service.dart`、`services/mock_api_service.dart`、`widgets/{bottom_navigation,animated_title_background,video_background}.dart`、`models/dialog_option.dart` | P1 |
| `screens/auth/*`(原 `pages/` 登录注册系列)、`screens/profile/*`(follow_list_sheet 除外)、`screens/privacy_settings_screen.dart`、`models/{user_profile,user_summary}.dart`、`services/api/{auth_api,user_api}.dart` | P2 |
| `screens/post_detail/*`(评论 UI 除外)、`screens/note_editor/*`、`widgets/{post_card,reference_display,pdf_iframe_view,pdf_iframe_view_web,pdf_iframe_view_stub}.dart`、`models/post_model.dart`、`services/arxiv_service.dart`、`services/api/{post_api,arxiv_api}.dart` | P3 |
| `widgets/comment/*`、`screens/follow_list_screen.dart`、`screens/profile/follow_list_sheet.dart`、`screens/message/notification_list.dart`+通知子页、`services/{unread_service,notification_websocket_service}.dart`、`models/notification_model.dart`、`services/api/{interaction_api,comment_api,follow_api,notification_api}.dart` | P4 |
| `screens/chat_screen.dart`、`screens/message/*`(notification 除外)、`widgets/{message_bubble,chat_input,conversation_item,video_message_player,web_audio_recorder,web_audio_recorder_stub,html_stub,html_web}.dart`、`widgets/message/*`、`models/{conversation_model,message_model}.dart`、`services/chat_service.dart`、`services/api/chat_api.dart` | P5 |
| `screens/admin/*`、`widgets/report_post_dialog.dart`、`services/api/{admin_api,report_api}.dart` | P6 |
| `screens/{home_screen,zone_screen,search_screen,search_results_screen}.dart`、`models/search_model.dart`、`models/browse_history_item.dart`、`services/{browse_history_service,search_history_service}.dart`、`services/core/local_json_list_store.dart`、`services/api/{history_api,search_api,hot_api}.dart` | P7 |

> 核对结论：每个**现有源文件**只归属 1 位负责人；新拆出的子文件在拆分时即划定归属；唯一需要两人先后接触同一文件的是协调点 C1–C5，均已给出「先拆后分」的串行顺序，不存在并发写同一文件的情况。
