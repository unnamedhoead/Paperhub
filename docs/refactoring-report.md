# Paperhub 软件重构报告

> 版本：优化重排稿　|　范围：Paperhub（Spring Boot 后端 + Flutter 多端前端）
> 配套文档：[7 人代码重构分工方案](./division-plan-7-developers.md)

---

## 摘要

Paperhub 是一个论文分享与学术社交平台，采用「Flutter 跨平台前端 + Spring Boot 单体后端」的前后端分离架构。系统功能完整、分层清晰，但在快速迭代中积累了典型的技术债：若干**上帝文件**（前端 `post_detail_screen.dart` 4431 行、`admin_mode_screen.dart` 3053 行；后端 `PostController` 702 行等）、**跨模块重复逻辑**（权限校验、消息发送、本地缓存、列表分页）、以及一处**严重安全缺陷**（JWT 认证过滤器被注释、敏感配置明文入库）。

本报告：(1) 系统分析现有架构与代码坏味道，对照 Fowler《重构》坏味道目录归类；(2) 给出分层、安全、设计模式、算法与代码规范五个维度的改进方案；(3) 按 7 人分工组织分模块重构详述；(4) 给出重构后的测试策略与回归方案。核心原则是**行为保持的小步重构 + 拆一个补一个测试**，不在重构 PR 中混入功能变更。

---

## 一、引言

### 1.1 重构动机

选择 Paperhub 作为重构对象，原因有三：

1. **真实可运行的中等规模系统**：后端约 1.4 万行 Java、前端约 3.2 万行 Dart，覆盖认证、社交、聊天、内容管理等完整业务，重构收益与挑战都具代表性。
2. **技术债集中且典型**：存在教科书式的坏味道（上帝类、重复代码、发散式变化、基本类型偏执、死代码），适合作为重构方法的练兵场。
3. **存在阻塞性缺陷**：安全链失效、配置泄露等问题已影响系统可用性与安全性，重构具有现实紧迫性。

### 1.2 重构目标与范围

| 目标 | 衡量标准 |
|---|---|
| 消除阻塞性安全缺陷 | JWT 过滤器恢复、敏感配置外移、CORS 收敛 |
| 拆解上帝文件 | 单文件 ≤ ~300 行、单方法 ≤ ~50 行 |
| 消除重复逻辑 | 权限/发送/缓存/分页等重复点提取为单一实现 |
| 建立可测试性 | 后端 Service 层 JUnit 覆盖率目标 60%+，前端核心交互 widget test |
| 统一规范 | 统一响应结构、日志框架、DTO 校验、命名/目录 |

**范围**：覆盖后端全部 feature 包与前端全部 `lib/` 源码；不改变对外功能行为（除明确标注的缺陷修复）。

### 1.3 重构原则与方法论

1. **SRP 单一职责**：一个文件/类只做一件事；超过 ~300 行的类、~50 行的方法是拆分信号。
2. **分层与依赖方向**：UI ↔ State/Domain ↔ Service/HTTP ↔ Model；上层依赖下层，禁止反向；后端 `api → service → domain + data`。
3. **行为保持**：每个重构步骤可由测试证明行为不变；重构 commit 不含功能变更。
4. **小步前进 + 一次一件事**：一个 PR 要么纯重构、要么纯改行为；改 API 必须独立 commit 并同步前端。
5. **拆一个补一个**：拆分的同时补单元测试，没有测试的重构是赌博。

---

## 二、现有系统分析

### 2.1 系统架构概览

#### 2.1.1 总体范式：前后端分离 + 单体后端

Paperhub 采用最稳健的客户端-服务端架构：后端以 Spring Boot 单体承载全部业务逻辑，前端以 Flutter 提供 Web / macOS / Android / iOS 多端 UI；两者以 REST 同步通信，WebSocket 处理实时推送。

#### 2.1.2 技术栈

| 层 | 技术 |
|---|---|
| 前端 | Flutter / Dart，`http`，`shared_preferences`，WebSocket |
| 后端 | Spring Boot，Spring Data JPA / Hibernate，Spring Security（部分启用） |
| 存储 | MySQL（远程），Redis（聊天缓存、会话） |
| 外部 | 华为云 OBS（对象存储），阿里云 SMTP（邮件），arXiv API（经后端代理） |

#### 2.1.3 后端：经典三层 + 按 feature 分包

后端是教科书式的「Controller → Service → Repository → Entity」四层结构：

```
┌─────────────────────────────────────────────┐
│ Controller 层  —— HTTP 入口、参数校验、响应包装   │
├─────────────────────────────────────────────┤
│ Service 层     —— @Transactional、业务规则、编排  │
├─────────────────────────────────────────────┤
│ Repository 层  —— Spring Data JPA 接口式 DAO      │
├─────────────────────────────────────────────┤
│ Entity 层      —— Hibernate 映射                 │
└─────────────────────────────────────────────┘
```

包结构**按业务子域划分**（`auth/ post/ chat/ comment/ admin/ …`）而非按层划分，是良好实践（DDD 雏形），具备模块化重构乃至未来拆微服务的潜力。

#### 2.1.4 前端：轻量 Service-View 模式

```
lib/
├── main.dart        启动入口 + 全局 NavigatorKey（481 行，职责过载）
├── config/          Base URL、环境切换
├── constants/       颜色、样式、学科常量
├── models/          PostModel / MessageModel / UserProfile …
├── pages/(6)        登录注册流程（与 screens/ 并存，目录语义不统一）
├── screens/(11)     主业务页（home/post_detail/chat/profile/admin …）
├── widgets/(17)     消息气泡、卡片、播放器等组件
├── services/(10)    ApiService / ChatService / WebSocketService …
└── utils/           工具方法
```

**架构亮点**：前端 401 自动续签实现了**单飞模式（single-flight）**——并发请求遇 401 时只发起一次 `/auth/refresh`，其余请求排队等待新 token，避免重复刷新。这一设计比许多生产项目都细致，重构时应予以保留并下沉到统一 `HttpClient`。

#### 2.1.5 横切关注点现状

| 关注点 | 现状 | 问题 |
|---|---|---|
| 认证 | JWT 过滤器**已实现但被注释** | 认证链完全失效（见 2.3 🔴）|
| 缓存 | Redis 缓存聊天最近 30 条 | 仅聊天使用，未统一 |
| 实时 | WebSocket 内存会话（ConcurrentHashMap）| 单机绑定、单 session 丢消息 |
| 异常 | 部分 `@ControllerAdvice` | 返回结构不统一，多处字符串匹配分发 |
| 配置 | 明文写在 `application.properties` | 密钥/密码泄露（见 2.3 🔴）|

### 2.2 代码坏味道总览（对照 Fowler 目录）

下表将散落在各模块的问题按 Fowler《重构》坏味道目录归类，给出代表性位置（完整逐模块分析见第四章）：

| 坏味道（Smell）| 代表位置 | 说明 |
|---|---|---|
| **God Class / Large Class（上帝类）** | `post_detail_screen.dart`(4431)、`admin_mode_screen.dart`(3053)、`profile_screen.dart`(2312)、`note_editor_page.dart`(2284)、`api_service.dart`(2161/115 方法)、`User.java`、`WebSocketService.java`(9 内部类) | 单文件/类承担过多职责 |
| **Duplicated Code（重复代码）** | `LikeService` 点赞/取消、`ChatService.sendMessage` vs `sendMessageWithMedia`(85% 同)、`JwtService.generateToken` vs `generateRefreshToken`(90% 同)、`SimpleWebSocketHandler` 三处广播、`AdminService` 8 处权限校验、前端历史/搜索本地缓存 | 同一逻辑多处复制 |
| **Divergent Change（发散式变化）** | `AdminController`(用户/帖子/举报/公告/权限 6 类职责)、`PostController`/`PostService`、`UserController` | 一个类因多种原因而改 |
| **Shotgun Surgery（霰弹式修改）** | 权限校验分散于 Controller+Service+各处 `isAdmin()`；新增推送类型需改 `WebSocketService` | 一个变化牵动多处 |
| **Primitive Obsession（基本类型偏执）** | `AuthController` 用中文字符串匹配决定 HTTP 状态码；`role/status` 裸字符串比较；上传类型用 `'image'/'pdf'` 字符串分支 | 该用类型/枚举处用了基本类型 |
| **Long Method / Long Parameter List** | `_publishNote`、`_parseXmlResponse`、帖子发布参数列表 | 过长方法/参数 |
| **Dead Code（死代码）** | `chat_screen` 的 `_isTyping/_typingUser/_scrollToBottomRetryCount`、`ReportController` 空壳 | 声明未用/未完成残留 |
| **Data Class / Feature Envy** | `WebSocketService` 9 个 public 字段消息类；`ReportPostService` 内嵌手写 getter/setter | 字段裸露、序列化依赖字段名 |
| **Inappropriate Intimacy（不当耦合）** | `AdminController` 跨层直接 `PostRepository.save`；`ReportUserController` 直接 `new AdminReport()` | Controller 越过 Service |
| **Parallel Inheritance / 重复体系** | report 包 vs admin 包**两套并行举报系统**（实体/枚举/Controller 各一套）| 两套等价体系并存 |

### 2.3 关键缺陷与风险登记（分级）

#### 🔴 高优先级（安全 / 阻塞性）

| ID | 缺陷 | 位置 | 影响 |
|---|---|---|---|
| R1 | **JWT 过滤器被注释**，`anyRequest().permitAll()` | `SecurityConfig.java:35-39` | 所有端点无需认证；`@AuthenticationPrincipal` 恒为 null，各 Controller 被迫手写 `currentUser==null` |
| R2 | **敏感配置明文**：JWT secret、OBS AK/SK、SMTP 密码、MySQL root 密码 | `application.properties` | 凭证泄露；secret 缺失时静默 fallback 到明文默认值，可伪造任意 Token |
| R3 | `getAuditUsers` **鉴权被注释** | `AdminController.java:189` | 任何登录用户可读全部待审核用户 email/role |
| R4 | Token 无撤销/黑名单、Refresh 不轮换 | `jwt/` | 封禁/退出后旧 Token 最长 7 天有效 |
| R5 | CORS `allowedOrigins="*"` | `SecurityConfig` | 跨域无限制 |

#### 🟡 中优先级（正确性 Bug）

| ID | 缺陷 | 位置 | 影响 |
|---|---|---|---|
| R6 | 搜索用户分页破损（查全部再 `PageImpl`）| `AdminController.java:83-87` | 前端分页控件失效 |
| R7 | 举报列表内存过滤覆盖真实总数 | `AdminService.java:94-100` | 后续页丢失数据 |
| R8 | 禁言过期后 status 未写回 DB | `ChatService.java:441-445` | 后台显示与实际行为不一致 |
| R9 | 状态标签 `'MUTED'` vs 后端 `'MUTE'` | `admin_mode_screen.dart:2295` | 禁言用户显示为「正常」 |
| R10 | `ReportController` 空壳返回虚假「举报成功」| `ReportController.java:14-21` | 无写入却报成功，与正确端点仅差 `/api` 前缀 |
| R11 | 消息查询 N+1（每条消息单独 `findById(sender)`）| `ChatService` | 100 条消息 101 次查询 |
| R12 | 浏览历史弹窗 N+1（逐条 `getPost`）| `profile_screen.dart:185` | 最多 50 次请求 |
| R13 | 多设备登录丢消息（单 session Map）| `ChatWebSocketHandler.java:33` | 后连接覆盖前一个 |

#### 🟢 低优先级（可观测性 / 工程化）

无日志聚合、无指标监控、无限流、`System.out.println` 散布、`ddl-auto=update` 生产风险、CI `-DskipTests`。

---

## 三、重构方案

### 3.1 总体策略与推进顺序

遵循「**地基先行 → 服务层稳定 → UI 层拆分**」三段式（与配套分工方案的 Phase 0/1/2 对应）：

1. **先补基础设施**（最高优先级）：恢复安全链、配置外置、统一响应/异常、前端 `HttpClient` 与状态管理。这是后续一切重构的依赖。
2. **再拆 service / api_service**：业务层稳定后 UI 才有据可依。
3. **最后拆 screen / controller**：上帝文件风险最大，需前两步打底。
4. **每步补测试**：用测试锁定行为，证明重构前后等价。

### 3.2 人员分工（7 人，详见配套方案）

按「**修改文件不冲突**」首要原则，划分为 1 名基础设施负责人 + 6 个垂直功能域：

| 编号 | 领域 | 后端包 | 前端主战场 |
|---|---|---|---|
| P1 | 平台基础设施与安全 | `config/` `jwt/` `common/` | `http_client`、状态管理、`main.dart` 拆分 |
| P2 | 认证与用户账户 | `auth/` `user/` `notify/` | auth 页面、`profile/` |
| P3 | 帖子创作/详情 + arXiv | `post/` `arxiv/` | `post_detail/`、`note_editor/`、`post_card` |
| P4 | 互动系统 | `comment/` `like/` `favorite/` `follow/` `notification/` | 评论 UI、关注列表、通知子页 |
| P5 | 即时通讯与 WebSocket | `chat/` `websocket/` | `chat_screen`、`message/`、`message_bubble` |
| P6 | 后台管理与举报 | `admin/` `report/` | `admin/`、`report_post_dialog` |
| P7 | 内容浏览与检索 | `history/` `hot/` | `home`、`search`、本地历史缓存 |

冲突化解三机制：**基础设施先行**、**上帝文件「先拆后分」**、**`api_service` 按域拆为 `*_api.dart`**。详细文件归属、协调点与时间线见 [分工方案](./division-plan-7-developers.md)。

### 3.3 架构级改进

| # | 改进 | 方案 |
|---|---|---|
| A1 | 敏感配置外移 | `@Value` + 环境变量 / `application-prod.properties`（`.gitignore`）；secret 缺失即启动报错 |
| A2 | 恢复 JWT 认证链 | `addFilterBefore(jwtAuthenticationFilter,…)`；`/auth/**` 白名单，`/admin/**` 角色校验，其余 `authenticated()`；过滤器动态读角色 `ROLE_+role.name()` |
| A3 | DB 账号最小权限 | 业务账号非 root；线上 `ddl-auto=validate` + Flyway/Liquibase 迁移 |
| A4 | CORS 收敛 | `allowedOrigins` 改白名单 |
| A5 | 前端状态管理 | 全项目统一一个（推荐 Provider），解决跨屏状态共享与重复 `setState` |
| A6 | WebSocket 演进 | 解单机束缚：轻量 Redis Pub/Sub，重型 RabbitMQ/Kafka；服务端心跳 + 离线消息降级 |
| A7 | 命名路由 | 引入 GoRouter，支持深链接与 Web SEO |
| A8 | 模块化单体 | 用 Maven 子模块隔离 `chat/post/notification` 边界；**不过度设计为微服务** |

### 3.4 设计模式改进

| 模式 | 应用点 | 收益 |
|---|---|---|
| **模板方法 / 策略** | 统一互动行为（点赞/收藏/关注/评论）的权限校验与通知触发；`PostVisibilityPolicy` 替代 `getPostDetail` 的 switch | 消除重复、开闭可扩展 |
| **事件发布/订阅** | 业务服务发布事件，`NotificationService` 与 WebSocket 推送订阅 | 解耦通知与业务 |
| **建造者** | `NotificationBuilder` 统一构造通知内容 | 收敛重复构造 |
| **代理** | 后端 `ArxivProxyService` 封装 arXiv 官方 API（解决 CORS、隔离不稳定性）| 前端无需关心外部接口细节 |
| **适配器** | `ArxivMetadataAdapter` 将 Atom XML 转内部 `ArxivMetadataDto` | 外部格式不污染业务层 |
| **自定义异常层级** | 替代 `msg.contains("未注册")` 字符串匹配分发 | Spring 按异常类型精确分发状态码 |

### 3.5 关键算法改进

| # | 问题 | 方案 |
|---|---|---|
| K1 | 评论递归删除栈溢出风险 + 逐条计数 | 数据库级联删除 `ON DELETE CASCADE` 或批量 `DELETE … WHERE path LIKE …` |
| K2 | 点赞/收藏计数内存增减漂移 | 原子 SQL 计数（`UPDATE … SET count=count+1`）|
| K3 | 消息查询 N+1（R11）| `JOIN FETCH` 一次加载，或批量 `findAllById` 构 Map |
| K4 | 浏览历史 N+1（R12）| 后端批量接口 `GET /posts/batch?ids=…` |
| K5 | 用户/举报搜索分页破损（R6/R7）| 过滤条件下推 SQL：`findByNameContainingIgnoreCase(q, pageable)` / `@Query searchReports(...)` |
| K6 | arXiv 正则解析 XML 脆弱 | 引入 XML parser 按 Atom 节点解析 + 实体解码 + 元数据缓存 |
| K7 | WebSocket 僵尸连接 | 心跳 pong + 记录 `lastActiveTime` + `@Scheduled` 60s 清理 90s 无活动 session |
| K8 | Token 无法撤销（R4）| Redis 黑名单 + `jti`；封禁/退出/改密入黑名单，TTL=原剩余有效期；Refresh 轮换 |

### 3.6 代码规范改进

| # | 规范 | 方案 |
|---|---|---|
| C1 | 统一响应结构 | `record ApiResponse<T>(int code, String message, T data)`；前端按 `code` 分支而非解析自然语言 |
| C2 | 统一日志 | `System.out.println`/`printStackTrace` 全部改 SLF4J，分级 debug/info/warn/error |
| C3 | DTO 校验 | 入参 `@Valid`/`@NotBlank`/`@Size`；删 Service 层手写校验；DTO 由 record + 每个独立文件 |
| C4 | Lombok | `User` 等实体用 `@Getter/@Setter` 消除样板；默认值前移 |
| C5 | 枚举替代裸字符串 | `UserRole`/`UserStatus`/`PostStatus`/`UploadFileType`；前后端统一映射 |
| C6 | 构造器注入 | `@Autowired` 字段注入改 final 字段 + 构造器注入 |
| C7 | 常量替代魔法值 | TTL、`BEARER_PREFIX`、容量上限、路径前缀提常量 |
| C8 | 目录/命名统一 | 删 `pages/` 合并到 `screens/`；服务统一 `services/`；删 `mock_api_service` 或迁 `services/mock/` |
| C9 | 分页规范 | 对外 `page` 从 1 起，Controller 内转 0 基 `PageRequest.of(max(page-1,0),size)`；限制 `pageSize` 上限 |

---

## 四、分模块重构详述

> 每个模块按「**问题（坏味道 + 缺陷）→ 重构方案 → 负责人**」组织；问题统一采用「位置 / 类型 / 说明」格式。本章已合并初稿中分散在「代码味道分析」与「改进建议」两处的重复内容。

### 4.1 平台基础设施与安全（jwt / config / 跨切）— P1

**问题**
- `SecurityConfig.java:35-39`｜安全失效（R1）｜JWT 过滤器被注释、`permitAll()`。
- `JwtAuthenticationFilter.java:56`｜RBAC 被绕过｜硬编码 `ROLE_USER`，`@PreAuthorize` 无法区分角色，是各处手写 `isAdmin()` 的根因。
- `JwtService.java:35-57`｜重复代码｜`generateToken` 与 `generateRefreshToken` 90% 相同；`validateToken`/`validateRefreshToken` try-catch 重复。
- `JwtService.java:73-78`｜封装泄露｜`parseToken` 为 public，暴露原始 Claims。
- `JwtService.java:23`｜安全｜secret 缺失静默 fallback 明文默认值（R2）。
- `application.properties`｜配置泄露（R2）。

**重构方案**
- 恢复认证链（A2）+ 配置外移（A1）+ CORS 收敛（A4）。
- 抽 `buildToken(subject, ttl, extraClaims)` 与 `parseTokenSafely(token)`；`parseToken` 改 private；常量化 `BEARER_PREFIX/TOKEN_TYPE_*`（C7）。
- Token 黑名单 + 轮换（K8）；Token 内嵌 `userId`，前端不再手动解析 JWT payload。
- 新建 `common/`：`ApiResponse`（C1）、异常基类、`PermissionUtils`。
- 前端：抽 `HttpClient` 单例（保留 single-flight 401 刷新）；选定状态管理（A5）；`main.dart` 拆 `app/router/theme/bootstrap`（A7）。

### 4.2 认证与用户账户（auth / user）— P2

**问题**
- `AuthController.java:88-97`｜基本类型偏执｜中文字符串匹配决定状态码。
- `AuthController.java:42-46`｜业务逻辑泄漏到 Controller｜令牌生成应归 `AuthService.login()`。
- `AuthController.java:62-86`｜缺陷｜`refresh` 不走统一异常，语义错乱（用户不存在返回 400 而非 404）。
- `AuthService.java:24-57`｜重复代码｜注册与重发验证码「生成→设过期→保存→发邮件」5 行重复。
- `User.java`｜上帝对象｜混合认证/资料/角色/隐私四类职责，90 行手写 getter/setter。
- `AuthDtos.java`｜数据类堆砌｜8 个 record 堆在一个文件。
- `UserController.java`(541)｜发散式变化｜资料/隐私/媒体/关注/收藏/帖子/搜索混在一个 Controller，且直接访问 Repository。
- `api_service.dart:246-555`｜缺陷｜`updateProfile`/`uploadAvatarBytes` 等绕过统一 401 刷新。
- `user_profile.dart:56-101`｜模型越位｜模型层兼容多种字段别名，承担适配层职责。

**重构方案**
- 自定义异常层级（3.4）+ 修复 refresh 语义；令牌生成下沉 Service。
- 抽 `refreshAndSendVerificationCode`；TTL 常量（C7）。
- `User` 引入 Lombok（C4）、字段按职责分组、`role` 默认值前移。
- `AuthDtos` 按 DTO 拆独立文件（C3）。
- `UserController` 拆 `UserProfile/Privacy/Media/Search` 多 Controller；关注端点切给 P4；统一经 Service。
- 前端：`auth/` 页面归位、`profile_screen` 拆 `screens/profile/`、模型加 DTO/adapter 层 + 枚举（C5）、上传走统一 `HttpClient`。

### 4.3 帖子创作/详情 + arXiv（post / arxiv）— P3

**问题**
- `PostController.java`(702) / `PostService.java`(520)｜发散式变化｜列表/关注流/推荐/详情/发布/编辑/上传/点赞/收藏/搜索/草稿/删除/举报全挤在一起。
- `PostController`｜规范｜多处 `System.out.println`。
- `note_editor_page.dart`(2284)｜上帝类 + 过长方法｜UI/文件选择/上传/arXiv/标签/引用/发布耦合；`_publishNote`(355-576) 一方法多阶段；状态散落 33-84；`_uploadFileToServer` 用字符串区分类型；`_contentFocusNode` 未 dispose；await 后缺 `mounted` 守卫。
- `arxiv_service.dart`｜缺乏抽象 + 过长方法｜静态方法 + 硬编码代理地址；`_parseXmlResponse`(201-416) 正则解析脆弱（R 风险）。

**重构方案**
- 后端 `PostController`/`PostService` 按职责拆 `Crud/Feed/Search/Media` + 对应 Service（帖子举报归 P6）；新增 `GET /posts/batch`（K4）；SLF4J（C2）。
- 前端 `post_detail_screen` 拆 `screens/post_detail/`（view/controller/subviews，评论 UI 切给 P4）；`note_editor` 拆 `screens/note_editor/` + `PostDraft` 模型 + 发布管线（C 化 Long Method）+ `UploadFileType` 枚举 + 资源释放/`mounted` 修复。
- arXiv：代理模式 `ArxivProxyService` + 适配器 `ArxivMetadataAdapter`（3.4）；XML 结构化解析 + 缓存（K6）；代理地址改 `AppEnv`（C7）。

### 4.4 互动系统（comment / like / favorite / follow / notification）— P4

**问题**
- `NotificationService`｜SRP 违背｜同时负责通知创建、WebSocket 推送、未读数更新；直接访问多个 Repository。
- `LikeService`/`FavoriteService`/`FollowService`｜重复代码｜各自手写权限校验、计数更新、通知发送；`ensureUserCanInteract` 重复。
- `CommentController`｜过长方法 + 不当职责｜混入调试打印、异常处理、WebSocket 推送。
- `CommentService.deleteCommentRecursively`｜算法风险｜递归删除栈溢出 + 逐条计数（R/K1）。
- `LikeService.getPostLikesCount`｜缺陷｜捕获所有异常返回 0，掩盖 DB 错误。
- 前端｜重复代码｜`ZoneScreen/SearchResultsScreen/ProfileScreen` 多处重复 like 请求与刷新；`post_card._handleLike` 回滚顺序敏感。

**重构方案**
- 模板方法/策略统一互动行为 + 事件发布订阅解耦通知（3.4）；`NotificationService` 分离 `NotificationBuilder` + `NotificationPushService`。
- 计数原子 SQL（K2）；评论级联删除（K1）；异常不静默吞（暴露真实错误）。
- 前端统一 `InteractionController`/provider，供 `post_card`、各列表页复用；评论 UI 独立到 `widgets/comment/`、通知子页与关注列表独立成文件。

### 4.5 即时通讯与 WebSocket（chat / websocket）— P5

**问题**
- `ChatService.java:176-261`｜重复代码｜`sendMessage` 与 `sendMessageWithMedia` 85% 相同。
- `ChatService.java:32-47`｜字段注入｜6 处 `@Autowired` 字段注入，与其它 Service 风格不一致。
- `ChatService`｜算法｜消息查询 N+1（R11）；禁言过期 status 未写回（R8）。
- `WebSocketService.java:69-201`｜上帝文件 + 数据类｜9 个消息类作为 public 字段内部类堆砌，序列化依赖字段名。
- `SimpleWebSocketHandler.java:96-191`｜重复代码｜三处广播逻辑逐字重复；路径用 `contains("/admin")` 易误路由；`System.out.println`；`getUri()` 无空检查。
- `ChatWebSocketHandler.java:33`｜缺陷｜单 session Map 多设备丢消息（R13）。
- 前端 `chat_screen.dart`｜架构倒退 + 死代码｜2 秒轮询绕开 WebSocket；`_isTyping`/`_scrollToBottomRetryCount` 等死代码；`_initializeConversation` 三段重复。
- `message_bubble.dart`(1257)/`chat_input.dart`(790)｜上帝组件｜所有消息类型/输入能力挤在单 widget。

**重构方案**
- 抽 `doSendMessage` 公共内核（策略，3.4）；构造器注入（C6）；N+1 用 JOIN FETCH（K3）；禁言过期写回 + `@Scheduled` 清理（K7 相邻）。
- 消息类提取到 `websocket/message/`（`private final + @JsonProperty`）；`SimpleWebSocketHandler` 按会话域拆 + 抽 `AbstractBroadcastHandler.broadcastToSessions` + `startsWith` 精确匹配 + `WsPaths` 常量 + SLF4J（C2/C7）；`ChatWebSocketHandler` 改 `Map<Long,Map<String,Session>>` 多设备（R13）。
- 前端轮询改 WebSocket 订阅（断线降级）；抽 `_setupConversation`、删死代码、`addPostFrameCallback` 退避；`message_bubble` 抽象基类 + 子类、`chat_input` 拆 `ChatInputBar/AudioRecorderButton/AttachmentPicker`。

### 4.6 后台管理与举报（admin / report）— P6

**问题**
- `AdminController.java`(554)｜发散式变化 + 霰弹式修改｜用户/帖子/举报/公告/权限 6 类职责；`isAdmin()` 重复十余处且 `getAuditUsers` 漏写鉴权（R3）。
- `AdminController.java:284-288`｜不当耦合｜直接 `PostRepository.save` 越过 Service；禁言时长换算写在 Controller。
- `AdminService.java`｜重复代码 + 规范｜8 处权限校验重复、缺 `ensureAdmin()`；残留 `System.out.println`；搜索/举报分页破损（R6/R7）。
- `AdminDtos.java`｜数据类堆砌｜13 个类型一个文件。
- report 包｜**两套并行举报系统**｜`ReportPost+AdminReportPostController` vs `AdminReport+AdminController`，实体/枚举/流程重复；`ReportPostService`(421) 用户端+管理端混杂 + 内嵌手写 getter/setter；`ReportUserController` 跨层直接操作 Entity；`ReportController` 空壳返回虚假成功（R10）；两套 `ReportStatus`（`PROCESSED` vs `RESOLVED`）。
- `admin_mode_screen.dart`(3053)｜上帝组件｜9 子模块挤一个 StatefulWidget；`_viewPostDetail` 两方法高度重复；`_getUserDisplayName` lambda 重复；状态标签 `'MUTED'` 拼写错误（R9）；举报人重复显示。

**重构方案**
- `AdminController` 拆 5 个职责单一 Controller + 全面 `@PreAuthorize`（修 R3）；越层逻辑下沉 Service；`ensureAdmin()` + 分页下推 SQL（K5）+ SLF4J；`AdminDtos` 拆分。
- **合并两套举报系统**到 `admin` 的 `AdminReport` 体系：删 `ReportController` 空壳（R10）；`ReportPostService` 拆用户端/管理端 + `PostDetailResponse` 提独立 record；`ReportUserController` 抽 Service + 统一 `OperationResponse` + 补通知；统一 `ReportStatus`；`PostVisibilityPolicy` 策略替代 switch（3.4）。
- 前端 `admin_mode_screen` 拆 `screens/admin/` 各 Section + Controller；合并详情方法（`showManageButton` 参数）；抽 `_getUserDisplayName`；修状态标签（R9）与举报人重复；`report_post_dialog` 改查业务 success 字段。

### 4.7 内容浏览与检索（history / hot / search）— P7

**问题**
- `BrowseHistoryService`/`SearchHistoryService`｜重复代码 + 边界不清｜后端 API + 本地 SharedPreferences + 降级 + 转换混在静态服务；本地 CRUD（读/写/排序/截断/删除）两服务重复；`BrowseHistoryItem` 与 Service 同文件。
- `BrowseHistoryService.recordHistory`｜算法缺陷｜`findTop50` 后判断容量，超 50 的清理逻辑永不触发。
- `BrowseHistory/SearchHistoryController`｜规范｜用 `Map` 收发、校验分散。
- 容量上限分散（浏览 50 / 搜索 20）；异常 `catch(_){}` 静默吞。
- `home_screen.dart`(1405)｜混杂｜feed + 搜索入口 + tab 切换。

**重构方案**
- 抽 `HistoryRepository` + `RemoteDataSource`/`LocalCache`；前端抽泛型 `LocalJsonListStore<T>` 统一本地缓存（编解码/排序/容量/逐条容错）；`BrowseHistoryItem` 移到 `models/`。
- 修容量清理（K5 相邻：Repository 统计 + 删 N 条后）；补 DTO + `@Valid`（C3）；容量常量统一（C7）；异常至少 debug 日志。
- N+1 改批量接口（K4，依赖 P3）；`home_screen` 抽 feed widget、搜索入口跳转。

---

## 五、重构后软件系统测试报告

> 现状：前端仅有脚手架 `test/widget_test.dart`，后端 `src/test/java` 近乎为空。重构要求「拆一个补一个测试」，本章给出测试策略与各模块最小测试集，作为重构验收标准。

### 5.1 测试策略

| 层 | 工具 | 目标 |
|---|---|---|
| 后端 Service | JUnit 5 + Mockito | 业务规则、边界、异常路径；覆盖率 60%+ |
| 后端 Controller | Spring `@WebMvcTest` + MockMvc | 端点路由、参数校验、权限矩阵、响应结构 |
| 后端集成 | `@SpringBootTest` + Testcontainers（MySQL/Redis）| 持久化、事务、N+1 验证 |
| 前端 | `flutter test`（widget/unit）| 核心交互、状态管理、解析逻辑 |
| 回归 | 重构前后行为对比 | 证明行为保持 |

### 5.2 各模块最小测试集（验收清单）

| 模块 | 关键测试用例 |
|---|---|
| P1 安全/JWT | 端点放行矩阵；Token 签发/校验/刷新/黑名单；401 单飞刷新；异常→状态码映射 |
| P2 auth/user | 注册/重发验证码/登录/refresh 语义；`User` Lombok 等价；资料更新；隐私设置；上传走 401 刷新 |
| P3 post/arxiv | 发布/编辑/草稿/删除/无权限；标签提取纯函数；arXiv ID 提取/非法/无结果/XML 字段缺失；XML→DTO |
| P4 互动 | 递归删除评论；点赞/取消幂等；关注状态变化；通知发送条件与去重；回关判断 |
| P5 chat/ws | `doSendMessage` 内核；消息分页无 N+1；多设备不丢消息；禁言过期；轮询→推送切换 |
| P6 admin/report | 权限矩阵（`@PreAuthorize`）；用户/举报搜索分页正确；举报全流程；两套合并后状态一致 |
| P7 history/search | 历史新增/去重/容量/云端失败回退；坏数据逐条跳过；搜索分页；批量加载替代 N+1 |

### 5.3 回归与持续集成

- **行为保持验证**：对每个重构 PR，先为目标行为补特征测试（characterization test）锁定现状，再重构，确保测试仍绿。
- **CI**：将 `mvn verify -DskipTests` 改回 `mvn verify`，前端流水线加入 `flutter test`；PR 必须测试通过方可合并。

### 5.4 测试结果（重构实施后实测，2026-06-18）

| 层 | 用例数 | 通过率 | 说明 |
|---|---|---|---|
| 后端 (JUnit + @WebMvcTest + 单元) | **235** | 100% | baseline ~5 → 235；含安全端点矩阵、各域 Controller/Service |
| 前端 (`flutter test`) | **191** | 100% | baseline 5 → 191；含 service 层(http_client/arxiv/chat/notification_ws 56 例)、各 controller/纯函数/widget、publishNote DI 5 例 |
| **合计** | **426** | **100%** | analyze 0 error（COMMITTED HEAD 核实） |

**回归发现并修复**：审查发现的 4 个 API 契约阻断（follow 路径/丢失端点/SecurityException→500）+ Wave2 审查 4 阻断（post_detail 假拆分/notification_list/状态管理/http_client 覆盖）+ 收尾共审 1 阻断（N1 import 漏 commit 致 HEAD 不可编译，FM1 复发）均已修复。

> 测试覆盖率（行/分支百分比）未量化统计——属遗留项 T1，建议接入 JaCoCo(后端)/`flutter test --coverage`(前端) 后填充。

---

## 六、总结与展望

本次重构以「**安全优先、地基先行、行为保持、拆一个补一个测试**」为纲：先消除 JWT 失效与配置泄露等阻塞性缺陷，再用模板方法、策略、事件订阅、代理、适配器等模式消除重复与发散式变化，最后拆解上帝文件并建立测试网。7 人分工以「修改文件不冲突」为首要约束，通过基础设施先行与上帝文件「先拆后分」实现高度并行。

**展望**：在模块边界清晰后，可渐进引入消息队列异步化（邮件/通知/转码）、可观测性（Actuator + Prometheus/Grafana）、以及前后端 OpenAPI 契约自动生成 Dart Model，进一步降低手写解析错误与维护成本；但应坚持「**先模块化单体、按需再微服务**」，避免过度设计。

---

## 参考文献

1. Martin Fowler. *Refactoring: Improving the Design of Existing Code* (2nd ed.). Addison-Wesley, 2018.
2. Robert C. Martin. *Clean Code: A Handbook of Agile Software Craftsmanship*. Prentice Hall, 2008.
3. Robert C. Martin. *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall, 2017.
4. Eric Evans. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley, 2003.
5. Erich Gamma, et al. *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley, 1994.
6. Spring Framework / Spring Security / Spring Data JPA 官方文档. https://spring.io/projects
7. Flutter 官方文档与状态管理指南. https://docs.flutter.dev
8. OWASP Top 10 (2021). https://owasp.org/Top10/
