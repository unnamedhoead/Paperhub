# Wave1 Agent-Group 约束与契约

> 作用：给 P2–P6 的 `isolation:worktree` 子 agent 共用的硬约束、已存在的共享契约、以及禁止事项清单。
> 每个 agent 接收的任务 prompt 将**逐条引用本文件的条款编号**，agent 必须在实现中严格遵守。

---

## G1. 基线分支

所有 agent 的 worktree **隐式从当前会话 HEAD 切出**（`.claude/settings.json` 设了 `worktree.baseRef: "head"`，当前会话固定在 `refactor/wave1-base`）。

该基线已包含：
- P1 基础设施（`common/` 异常 + `ApiResponse` + `common/security/PermissionUtils` + JWT 修复 + `SecurityConfig` + `JwtAuthenticationFilter` + `GlobalExceptionHandler` + `HttpClient` + `main.dart` 拆分）
- M0 修复（`NoResourceFoundException→404` + `SecurityConfigTest` 修复 + `application-test.properties` H2 离线测试配置）
- P7 试点（`history/` + `hot/` DTO 化 + `@Valid` 校验 + 统一异常 + 容量 bug 修复 + 测试）

---

## G2. 通用硬约束（每个 agent 强制遵守）

### G2.1 行为保持
- **除明确标注的 bug 修复外，不得改变任何对外行为**。JSON 字段名、HTTP 路径、HTTP 方法、业务逻辑必须保持等价。
- 行为保持必须由测试证明：重构前先补 characterization test 锁定现状。

### G2.2 JSON 兼容性（最高优先级）
- **当前前端未改动**。所有 endpoint 的响应 JSON 结构必须与原格式**逐字段兼容**。
- 响应成功时：**不要**套 `ApiResponse<T>` 的 `data` 层（前端直接读 `body['items']` / `body['count']` 等顶层字段，套了会打挂）。沿用 `AuthController` 模式——成功返回扁平 DTO，仅错误走 `ApiResponse`（由 `GlobalExceptionHandler` 统一包）。
- 如果必须改字段名或结构：**停止实现，报告冲突**。

### G2.3 不能改的文件（写权限归他人）
- **`config/*`** / **`jwt/*`** / **`common/*`** → P1 独占，只能 import/throw/调用，不能编辑
- **`auth/User.java`** / **`auth/UserRole.java`** / **`auth/UserStatus.java`** → P2 实体写权限，其余人只读
- **`post/Post.java`** / **`post/PostStatus.java`** → P3 实体写权限
- **`websocket/*`** → P5 基础设施
- **`services/core/http_client.dart`** → P1 基础设施
- **`services/api_service.dart`** → 所有 agent 都**只能删自己迁移走的方法**，不能同时改（避免冲突）
- 若确实需要改非自己域的文件：**停止实现，报告冲突**。

### G2.4 必须复用的契约（不能自己另搞一套）
- 异常：throw `common/exception/` 下的 `ApiException` / `BadRequestException` / `NotFoundException` / `ForbiddenException` / `UnauthorizedException`，**不要**自己新造异常类型或返回原始 `Map`
- 响应错误：不手写 `Map.of(...)`，靠 `GlobalExceptionHandler` 统一转为 `ApiResponse {code, message, data}`
- 校验：入参 DTO 用 Jakarta `@Valid` + `@NotBlank/@NotNull/@Size/@Pattern`，删掉 controller/service 层手写校验 if
- 日志：SLF4J `Logger`（`log.info/warn/error`），**禁止** `System.out.println` / `e.printStackTrace()`
- 注入：构造器注入 `final` 字段，**禁止** `@Autowired` 字段注入

### G2.5 测试要求
- 每个重构步骤**必须**有测试；`./mvnw test` 必须绿。
- `@WebMvcTest` / `@DataJpaTest` 切片优先；需要加载完整 context 的 `@SpringBootTest` 必须加 **`@ActiveProfiles("test")`**（H2 内存库，否则连远程 MySQL 失败）。
- 测试必须证明**重构前后行为等价**（不是测 Spring 框架，是测你的业务逻辑）。

### G2.6 Git 规范
- Commit 格式：**English prefix + 中文正文**（feat/fix/refactor/chore/merge 五选一，不用 emoji）
- `git add <具体文件>`，**禁止** `git add -A` / `git add .`
- 禁止 `--no-verify` / force-push / push（只本地 commit）
- 每次 commit 结尾加：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- 在 worktree 内直接提交到自己的 worktree 分支；不要 merge 到别的分支。

---

## G3. 各域文件归属（互斥，零交叉）

> 每个 agent 只能修改自己 domain 列出的文件；其他域的文件 import/调用可读，不能写。

| Domain | 后端包 | 前端文件（本 wave 只做后端，前端暂不涉及） |
|---|---|---|
| P2 auth/user | `auth/` `user/` `notify/MailService.java` | — |
| P3 post/arxiv | `post/` `arxiv/` | — |
| P4 interaction | `comment/` `like/` `favorite/` `follow/` `notification/` | — |
| P5 chat/websocket | `chat/` `websocket/` | — |
| P6 admin/report | `admin/` `report/` | — |

---

## G4. 跨域共享调用（只读 import / 调用已有 API）

| 你需要… | 怎么获得（不碰他人文件） |
|---|---|
| 获取当前登录用户 | `@AuthenticationPrincipal User currentUser`（P1 已修复 JWT 过滤器 → SecurityContext 可用） |
| 权限校验 | Controller 加 `@PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")`（`SecurityConfig` 已开 `@EnableMethodSecurity`）或过渡期调 `PermissionUtils.ensureAdmin(user)` |
| 查 User 实体 | inject `UserRepository` 只读调用，不改 `User.java` |
| 查 Post 实体 | inject `PostRepository` 只读调用，不改 `Post.java` |
| 发 WebSocket 推送 | 调 `WebSocketService.pushToUser/pushToPost/pushToAdmins`（P5 暴露的 API），不改 `websocket/` 源文件 |
| 统一响应/异常 | import `common/dto/ApiResponse` / `common/exception/*`；throw `NotFoundException` 等 |

---

## G5. 禁止事项速查

| 禁止 | 原因 |
|---|---|
| Controller 直接操作 Repository（跨过 Service）| 破坏分层 |
| 自己新建异常类型（不继承 `ApiException`）| 导致 `GlobalExceptionHandler` 无法统一捕获 |
| 手写 `Map.of("success", ...)` 作为 controller 返回值 | 不统一，前端解析逻辑各异 |
| `System.out.println` / `e.printStackTrace()` | 日志不可控 |
| `@Autowired` 字段注入 | 不可测试、风格不一致 |
| 静态方法做业务逻辑 | 不可测试、不可替换 |
| 改 `api_service.dart` 中不属于自己域的方法 | 共享文件冲突 |
| Push / force-push / merge 到别的分支 | 分支隔离 |
| 新增外部依赖不报告 | pom.xml 改动需知会 |
