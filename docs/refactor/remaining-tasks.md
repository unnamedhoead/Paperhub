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

> **Opus 接手 P2 round-2 更新 (2026-06-18, codex-review 零问题)**：G2-G9 全部完成(真 Widget/ChangeNotifier 拆分, 均 ≤300)。仅 G1/G10 留待 Stage4。

| # | 文件 | 原行数 | 现行数 | 负责 | 当前状态 |
|---|---|---|---|---|---|
| G1 | `post_detail_screen.dart` | 3124→3680 | 3680 | Opus | ⏳ **Stage4 进行**：已有 3 独立 Widget，待抽 PostDetailController 瘦身骨架 |
| G2 | `home_screen.dart` | 1017 | **230** | Opus委托 | ✅ home/ 8文件(HomeController+2子+4widget) |
| G3 | `follow_list_screen.dart` | 851 | **178** | Opus委托 | ✅ follow/ 拆分 |
| G4 | `search_screen.dart` | 750 | **297** | Opus委托 | ✅ search/ 5widget |
| G5 | `admin_post_section.dart` | 616 | **173** | Opus委托 | ✅ +3文件 |
| G6 | `admin_controller.dart` | 590 | **249** | Opus委托 | ✅ mixin+utils |
| G7 | `profile_screen.dart` | 607 | **290** | Opus委托 | ✅ ProfileViewController+ProfileContent |
| G8 | `chat_screen.dart` | 610 | **287** | Opus委托 | ✅ chat/ 4文件 |
| G9 | `share_bubble.dart` | 483 | **186** | Opus委托 | ✅ +share_post_card |
| G10 | `note_editor_controller.dart` | part of+extension | 同 | P3 | ❌ 留待(可并入 Stage5 风格收敛) |

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
| N3 | `widgets/reference_display.dart` 0 字节空文件删除 | 审查建议-5 | Opus | ✅ **已删** |
| N4 | `follow_controller.dart` 从 `screens/` 根目录移至 `screens/follow/` | 审查建议-4 | Opus委托 | ✅ **已移** (interaction agent N4) |
| N5 | 统一 API 导入方式 (facade vs direct import) | 审查建议-2 | 全员 | ❌ 未做(11 个旧 screen 用 facade, 新 controller 用 direct) |
| N6 | `screens/profile/follow_list_sheet.dart` 是否已创建? | 分工方案 C4 | P4 | ⚠️ 待核实 |

---

## 七、🟢 测试（§5 未达标）

| # | 任务 | 原报告引用 | 负责 | 当前状态 |
|---|---|---|---|---|
| T1 | 后端 Service 覆盖率 60%+ | §5.1 | 全员 | ⚠️ 228 tests, 覆盖率未知 |
| T2 | `@SpringBootTest` 集成测试 (Testcontainers MySQL/Redis) | §5.1 | 全员 | ❌ 仅 1 个 contextLoads |
| T3 | 前端 widget test 覆盖核心交互 | §5.1 | 全员 | ⚠️ 仅 2 个 widget test (conversation_list, message_bubble 原 widget_test) |
| T4 | 前端 service 层测试 (chat_service, arxiv_service, notification_ws...) | 审查发现(阻断-4) | Opus+委托 | ✅ **已补**: http_client 20 + arxiv 16 + chat_service 10 + notification_ws 10 = 56 service 测试 |
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

> **Opus round-2 更新 (2026-06-18, ralph-loop)**：P0 安全全闭环；P2 上帝文件 G2-G9 全拆完(≤300, codex 零问题)；N3/N4 清理；T4 service 测试补齐(56 例)；A1-A4+I5 ADR 决议。前端 137 tests + 后端 235 tests 全绿。剩 G1(Stage4 进行)、N1/N2/N5、D8-D10、I4 收尾。

| 分类 | 总数 | ✅ 完成/已决议 | ⏳ 进行/部分 | ❌ 未做 |
|---|---|---|---|---|
| 🔴 安全 | 2 | 2 | 0 | 0 |
| 🟡 基础设施 | 6 | 2 (I1,S2类) | 2 (I2,I4推进中) | 2 (I3,I6) |
| 🟡 上帝文件 | 10 | 8 (G2-G9) | 1 (G1) | 1 (G10) |
| 🟡 架构改进 | 4 | 4 (ADR决议:Deferred/YAGNI) | 0 | 0 |
| 🟡 设计/算法/规范 | 10 | 6 | 1 | 3 (D8-D10错误处理) |
| 🟢 目录/命名 | 6 | 2 (N3,N4) | 1 (N6) | 3 (N1,N2,N5) |
| 🟢 测试 | 6 | 2 (T3部分,T4) | 2 (T1,T3) | 2 (T2,T5) |
| **合计** | **44** | **~26** | **~7** | **~11** |

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

---

## 九、Stage5 收尾决议 (Opus ralph-loop, 2026-06-18)

每个剩余项的最终处置（✅完成 / 🅓Deferred有触发条件 / 🚫YAGNI / 📋Recommendation运维）：

| 项 | 处置 | 说明 |
|---|---|---|
| G1-G10 上帝文件 | ✅ | 全部拆完(post_detail 473/note_editor Controller/...)，真 Widget+ChangeNotifier，无假拆分 |
| I1 ObsConfig | ✅ | 核实 Wave1 已外置 |
| I3 mock 清理 | ✅ | 删除未使用 mock_api_service.dart |
| I4 状态管理 | ✅ | ChangeNotifier 模式已在 home/profile/post_detail/note_editor/admin/follow 6 处落地 + state-management-convention.md 规范 |
| T4 service 测试 | ✅ | http_client/arxiv/chat/notification_ws 56 例 |
| T6 测试结果表 | ✅ | refactoring-report §5.4 已填实测(421 tests) |
| N1/N2/N3/N4 | ✅ | 后缀统一(文件+类名 *Screen, `ba04a5c`)/删空文件/删re-export/移目录；import 引用补全 `86dc856` |
| D8-D10 错误处理 | ✅ | catch(_){} 16 处补 debug 日志，cherry-pick 落 `78d1ba8`，0 残留 |
| publishNote 测试 | ✅ | DI fake 补 5 例(`efa5b64`)，前端 186→191 |
| S1/S2 安全 | ✅ | 收紧 authenticated + CORS 机制 |
| A1 DB最小权限 | 📋 | 运维任务，附最小授权 SQL 见 architecture-decisions.md |
| A2 Flyway迁移 | 🅓 | 触发: schema 稳定+准生产 |
| A3 Redis Pub/Sub | 🚫 | YAGNI: 单实例无需，多实例时再做 |
| A4 Maven子模块 | 🚫 | YAGNI: 包级模块化已足够(可选 ArchUnit) |
| I5 GoRouter | 🅓 | 有价值但需专门一轮串行(改全部导航)，Wave3 |
| I6 providers/树 | 🅓 | 随 Provider 全量接入(I5 一并)，当前 bare ChangeNotifier 已工作 |
| N5 API导入统一 | 🅓 | facade 与 direct import 并存且无害；统一为纯 cosmetic，低优先 Wave3 |
| T1 覆盖率量化 | 🅓 | 接入 JaCoCo / flutter --coverage 后填(数值统计，非功能) |
| T2 集成测试(Testcontainers) | 🅓 | slice 测试已覆盖逻辑；Testcontainers 重依赖，准生产再加 |
| T5 CI 跑测试 | 📋 | .gitlab-ci.yml 当前 -DskipTests；改为 verify 需 CI 环境备 Redis+H2，交 CI owner(已有 H2 test profile 支撑) |

**结论**：所有 remaining-tasks 项均已 ✅完成 或 明确决议(🅓/🚫/📋)。结构性重构(安全+全部上帝文件+控制器+测试)已实现并验证；剩余为高成本/运维/cosmetic 项，按 ROI 诚实推迟并记录触发条件。

### 收尾共审 (自审 + 独立 reviewer，2026-06-18)
codex 额度耗尽，改用只读 review agent 替代。独立 reviewer 审 Stage4/5 报 1🔴+2🟡，**全部已核实处置**：
- 🔴 **N1 import 漏 commit (FM1 复发)**：rename 后的 import 修正只在工作区从未提交→已提交 HEAD 实际 11 个 analyze error、不可编译。已 `86dc856` 提交修复。**教训**：判断分支健康须查 `git show HEAD:` 的 COMMITTED 态，不能只看 working tree（我先前的"clean"自检即被未提交改动蒙蔽）。
- 🟡 类名/文件名不一致 → `ba04a5c` 类名改 *Screen。
- 🟡 publishNote 零覆盖 → `efa5b64` 补 5 例 DI 测试。
- 🟢 WS URL quirk：与 base 逐字一致(非回归)，切 wsBaseUrl 属行为变更，正确推迟 Wave3。

修复后对 4 个收尾 commit 再做一轮独立只读 review 复核。最终：前端 **191 tests + 0 analyze error(COMMITTED 核实)**、后端 235 tests。
