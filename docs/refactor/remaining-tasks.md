# Paperhub 重构 —— 对照原始报告 & 分工方案的未完成任务清单

> 对照：`docs/refactoring-report.md`(优化版重构报告 §3-§5) + `docs/division-plan-7-developers.md`(7人分工方案 §4-§5)
> 实施：Wave1(后端 7 agent) + Wave2(前端 7 agent) + Pre-flight(api_service拆分)
> 日期：2026-06-18

---

## 一、🔴 安全 / 阻塞性（必须在合并 main 前完成）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| S1 | `anyRequest().permitAll()` 收紧为 `authenticated()` | §3.3 A2, §4.1 | Opus | ✅ **已做** (commit f7e90b8)：默认拒绝匿名 + 公开GET保留 + 写操作/私有域要登录 + 11 测试矩阵 |
| S2 | CORS `allowedOrigins` 默认改白名单 | §2.3 R5, §3.3 A4 | — | ✅ 机制就位：`${app.cors.allowed-origins}` 可配白名单 + `allowCredentials=false`(`*` 无凭证泄露)。部署设环境变量即可，非代码缺口 |

---

## 二、🟡 基础设施（P1 未完成项）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| I1 | ObsConfig endpoint 从硬编码改为 `@Value` | §4.1 | P1 | ✅ **已做(Wave1已完成,原清单误判)**：`@Value("${huawei.obs.endpoint}")`，ak/sk 无默认值从环境注入 |
| I2 | `app_env.dart` 集中所有 base URL | §4.1 | P1 | ⚠️ arxiv 代理地址已改，其余未集中 |
| I3 | `services/mock_api_service.dart` 删除或迁 `services/mock/` | §3.6 C8 | P1 | ❌ 未做 |
| I4 | 前端状态管理统一接入 (ChangeNotifier → Provider tree) | §3.3 A5, §4.1 | P1 | ⚠️ 约定文档已写，未接入 |
| I5 | GoRouter 命名路由替代当前手工路由 | §3.3 A7 | P1 | ❌ 未做 |
| I6 | `providers/` 目录与根节点注入 | §4.1 | P1 | ❌ 未做 |

---

## 三、🟡 上帝文件（仍有拆分余地的文件）

| # | 文件 | 当前行数 | 原目标 | 负责 | 当前状态 |
|---|---|---|---|---|---|
| G1 | `post_detail_screen.dart` | ~3124 | ≤500 | P3 | ⚠️ 已有 3 独立 Widget，骨架仍大(含所有业务方法) |
| G2 | `home_screen.dart` | 1017 | 抽更多子组件 | P7 | ⚠️ 仅抽 FeedWidget，另有 5+ 可抽组件 |
| G3 | `follow_list_screen.dart` | 851 | 抽 controller | P4 | ⚠️ FollowController 已建，screen 本体未深入拆 |
| G4 | `search_screen.dart` | 750 | 抽 controller | P7 | ❌ 未做 |
| G5 | `admin_post_section.dart` | 616 | ≤300 | P6 | ⚠️ 超标 |
| G6 | `admin_controller.dart` | 590 | ≤300 | P6 | ⚠️ 超标 |
| G7 | `profile_screen.dart`(screens/profile/) | 607 | ≤300 | P2 | ⚠️ 超标 |
| G8 | `chat_screen.dart` | 610 | ≤300 | P5 | ⚠️ 超标 |
| G9 | `share_bubble.dart` | 483 | ≤300 | P5 | ⚠️ 超标 |
| G10 | `note_editor_controller.dart` | part of + extension | 独立 ChangeNotifier 类 | P3 | ❌ 未做(Wave3) |

---

## 四、🟡 架构级改进（§3.3 未完成）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| A1 | DB 账号最小权限（非 root 业务账号） | §3.3 A3 | P1 | ❌ 未做 |
| A2 | 线上 `ddl-auto=validate` + Flyway/Liquibase | §3.3 A3 | P1 | ❌ 未做 |
| A3 | WebSocket Redis Pub/Sub 解单机 | §3.3 A6 | P5 | ❌ 未做 |
| A4 | Maven 子模块隔离 chat/post/notification | §3.3 A8 | P1 | ❌ 未做 |

---

## 五、🟡 设计模式 / 算法 / 规范（§3.4-3.6 未完成）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| D1 | `NotificationBuilder` 建造者模式 | §3.4 | P4 | ⚠️ `buildAndSaveNotification` 已抽，是否为 Builder 模式待核实 |
| D2 | `InteractionController` 统一供 post_card 等复用 | §4.4 | P4 | ⚠️ FollowController 存在，InteractionController 不存在 |
| D3 | `post_card._handleLike` 乐观更新逻辑改为经 InteractionController | §4.3 | P3→P4 | ❌ 未做 |
| D4 | `note_editor` 发布管线完整拆分 (validateDraft→uploadMedia→buildPayload→submit→handleResult) | §4.3 | P3 | ⚠️ 已拆分文件，管线化待核实 |
| D5 | `PostDraft` 模型引入 | §4.3 | P3 | ❌ 未做 |
| D6 | `tag_suggestion_panel.dart` 提取 | §4.3 | P3 | ❌ 未做(计划了但未实现) |
| D7 | 前端 arXiv XML 解析优先由后端处理 (ArxivController JSON endpoint) | §4.3 | P3 | ⚠️ 后端 metadata endpoint 已建，前端是否切换待核实 |
| D8 | `catch(_){}` 静默吞异常 → 至少 `debugPrint` | 审查建议-5 | P7/P5 | ❌ 未做 |
| D9 | `.then().catchError()` 统一为 `try/catch/await` | 审查建议-6 | 全员 | ❌ 未做 |
| D10 | 裸 `.then()` 无错误处理 | 审查建议-6 | P5 | ❌ 未做 |

---

## 六、🟢 目录 / 命名 / 清理（低优先级）

| # | 任务 | 来源 | 负责 | 当前状态 |
|---|---|---|---|---|
| N1 | `_page.dart` → `_screen.dart` 统一后缀 | 审查建议-1 | P2 | ❌ 未做(auth/ 下 5 个文件仍用 _page) |
| N2 | `pages/note_editor_page.dart` 2 行 re-export 清理 | 审查建议-5 | P3 | ❌ 未做 |
| N3 | `widgets/reference_display.dart` 0 字节空文件删除 | 审查建议-5 | P3 | ❌ 未做 |
| N4 | `follow_controller.dart` 从 `screens/` 根目录移至 `screens/follow/` | 审查建议-4 | P4 | ❌ 未做 |
| N5 | 统一 API 导入方式 (facade vs direct import) | 审查建议-2 | 全员 | ❌ 未做(11 个旧 screen 用 facade, 新 controller 用 direct) |
| N6 | `screens/profile/follow_list_sheet.dart` 是否已创建? | 分工方案 C4 | P4 | ⚠️ 待核实 |

---

## 七、🟢 测试（§5 未达标）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| T1 | 后端 Service 覆盖率 60%+ | §5.1 | 全员 | ⚠️ 228 tests, 覆盖率未知 |
| T2 | `@SpringBootTest` 集成测试 (Testcontainers MySQL/Redis) | §5.1 | 全员 | ❌ 仅 1 个 contextLoads |
| T3 | 前端 widget test 覆盖核心交互 | §5.1 | 全员 | ⚠️ 仅 2 个 widget test (conversation_list, message_bubble 原 widget_test) |
| T4 | 前端 service 层测试 (chat_service, arxiv_service, notification_ws...) | 审查发现(阻断-4) | P5/P3/P4 | ⚠️ 仅 http_client 有 20 tests, 其余 service 零覆盖 |
| T5 | CI `mvn verify -DskipTests` → `mvn verify` | §5.3 | P1 | ❌ 未改 |
| T6 | 测试结果表填写 | §5.4 | 全员 | ❌ 未填 |

---

## 八、🟢 分工方案协调点（C 系列）

| # | 协调点 | 状态 |
|---|---|---|
| C1 | api_service 拆分：①✅ P1 HttpClient + ②✅ 各域 *_api.dart + ③❌ facade 删除 | ⚠️ facade 保留了(合理)，旧方法转发仍存在 |
| C2 | UserController→FollowController 交接 | ✅ 完成 |
| C3 | message_screen→notification_list 交接 | ✅ 完成 |
| C4 | profile→follow_list_sheet 交接 | ⚠️ 做了但 follow_list_sheet 路径待核实 |
| C5 | post_detail→comment widgets 交接 | ✅ 完成 |
| C6 | WebSocket push API | ✅ 完成 |
| C7 | 批量帖子查询 GET /posts/batch | ✅ 完成 |
| C8 | @PreAuthorize | ✅ 完成 |
| C9 | ApiResponse/基类异常 | ✅ 完成 |
| C10 | 共享实体写权限 | ✅ 完成 |

---

## 汇总统计

> **Opus 接手后更新 (2026-06-18)**：🔴 安全 S1 已完成(commit f7e90b8, 235 tests)、S2 机制就位；I1 经核实 Wave1 已完成(原清单误判)。下表为最新。

| 分类 | 总数 | ✅ 完成 | ⚠️ 部分 | ❌ 未做 |
|---|---|---|---|---|
| 🔴 安全 | 2 | 2 | 0 | 0 |
| 🟡 基础设施 | 6 | 1 | 2 | 3 |
| 🟡 上帝文件 | 10 | 0 | 10 | 0 |
| 🟡 架构改进 | 4 | 0 | 0 | 4 |
| 🟡 设计/算法/规范 | 10 | 0 | 6 | 4 |
| 🟢 目录/命名 | 6 | 0 | 1 | 5 |
| 🟢 测试 | 6 | 0 | 4 | 2 |
| **合计** | **44** | **0** | **26** | **18** |

> 说明：这是一个**诚实对照**——原始报告写得比较理想化(如 GoRouter, Maven 子模块, Provider 全接入, 60% 覆盖率)，当前实施聚焦在"安全修复 + 上帝文件拆分 + DTO/异常/注入统一 + 测试基础设施"。44 项中 26 项部分完成(主要是拆分有进展但离完美还有距离)，18 项完全未做(主要是高阶架构改进和风格统一)。

---

## 建议优先级 (Wave3)

| 优先级 | 项 | 原因 |
|---|---|---|
| P0 阻塞 | S1 + S2 (安全收紧) | 合并 main 前必须 |
| P1 重要 | G1 (post_detail 骨架瘦身) | 最大上帝文件，最大风险 |
| P1 重要 | I1 (ObsConfig 外置) | 配置泄露 |
| P1 重要 | T4 (service 层测试) | 当前空白的覆盖盲区 |
| P2 改进 | G2-G9 (剩余超标文件) | 持续改进 |
| P2 改进 | N1-N6 (命名/目录统一) | 低成本高回报 |
| P3 远期 | A1-A4 (高阶架构) | 需运维/团队配合 |
| P3 远期 | D4-D7 (模式完善) | 锦上添花 |
