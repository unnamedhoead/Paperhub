# Paperhub Wave2 — 前端重构方案

> 基线: `refactor/wave1-base` &nbsp;|&nbsp; 约束: `docs/refactor/wave1-agent-constraints.md`（G2.6.1 + G6 强制）
> Wave1 已完成后端全部 8 个 feature 包重构 + 228 测试绿。Wave2 仅动前端 `lib/`。

---

## 0. 与 Wave1 的关键差异

| | Wave1 (后端) | Wave2 (前端) |
|---|---|---|
| 文件格式 | Java | Dart / Flutter |
| 最大文件 | PostController 702 行 | post_detail_screen **4431 行** |
| 拆分方式 | 按职责拆 Controller/Service/DTO | 按子树拆 View/Controller/SubWidget |
| 状态管理 | Spring DI | **仍未统一**（本 Wave 暂不引入 Provider，用 setState+controller 类过渡）|
| 测试 | JUnit + MockMvc | `flutter test` (widget + unit) |
| 变更联动 | 后端 API 路径不动 | 前端 API 调用方式不动 (只移动文件 + 抽方法) |

---

## 1. 分工（6 个 domain，沿用 Wave1 归属）

| Agent | Domain | 核心文件（按行数倒序）| 负载 |
|---|---|---|---|
| **P2** | auth/user | profile_screen(2312) + 6 auth pages → screens/auth/ | M |
| **P3** | post/arxiv | **post_detail(4431)** + **note_editor(2284)** + post_card(521) + models + arxiv_service | **XL** |
| **P4** | interaction | follow_list(851) + 评论 UI + unread + notification_ws | M |
| **P5** | chat/ws | message_screen(1684) + **message_bubble(1257)** + chat_screen(741) + **chat_input(790)** + chat_service(738) + conversation_item(312) + media widgets | **XL** |
| **P6** | admin/report | **admin_mode(3053)** + report_post_dialog | **L-XL** |
| **P7** | 浏览/检索 | home_screen(1405) + search_screen(750) + search_results(589) + zone(329) + history/browse services + models | M-L |

### 1.1 共享基础设施 (本 Wave 暂不新建 agent，由 orchestrator 预做)

| 任务 | 谁做 | 说明 |
|---|---|---|
| `api_service.dart` 预拆 | orchestrator 在扇出前 | 把 114 个 static 方法**机械按域拆进 `services/api/<domain>_api.dart`**，行为不变，每个 agent 只改自己的 `*_api.dart` |
| `pages/` → `screens/` | orchestrator+各 agent | orchestrator 先 `git mv pages/ screens/auth/`，各 agent 在自己域内部调整 import |
| `main.dart` 路由适配 | orchestrator 收尾 | 各 agent 拆完子目录后，统一更新 `router.dart` 的 import 路径 |

---

## 2. 各 Agent 任务详述

### P2 — auth/user 前端

**文件**:
- `pages/login_page.dart`(260) `register_page.dart`(257) `forgot_password_page.dart` `reset_password_page.dart`(298) `verify_email_page.dart` → 5 个文件由 orchestrator 预迁到 `screens/auth/`，P2 负责修 import + 清理
- `screens/profile_screen.dart`(2312) → 拆 `screens/profile/`:
  - `profile_screen.dart` — 页面骨架 (tab 切换)
  - `profile_header.dart` — 头像/背景/用户名/统计
  - `profile_tabs.dart` — 帖子/收藏/草稿 tab
  - `profile_edit_sheet.dart` — 编辑资料弹窗
  - `profile_controller.dart` — 加载/更新状态逻辑
- `screens/privacy_settings_screen.dart`(255) — 保持
- `models/user_profile.dart` `user_summary.dart` — role/status 字符串 → enum 映射
- 新建 `services/api/auth_api.dart` `services/api/user_api.dart`（从 api_service 迁自己方法）

**不碰**: `follow_list_screen.dart`（归 P4）、任何 backend 文件

### P3 — post/arxiv 前端 【最重 / 关键路径】

**文件**:
- `screens/post_detail_screen.dart`(4431) → 拆 `screens/post_detail/`:
  - `post_detail_screen.dart` — 页面骨架 + header
  - `post_content.dart` — 正文/媒体渲染
  - `post_actions.dart` — 点赞/收藏/举报按钮行
  - `post_controller.dart` — 数据加载/状态管理
  - `subviews/comment_section.dart` — 评论树嵌入点（内部逻辑归 P4）
- `pages/note_editor_page.dart`(2284) → `screens/note_editor/`:
  - `note_editor_screen.dart` — 页面骨架
  - `note_editor_controller.dart` — 编辑状态 + PostDraft 模型
  - `note_media_section.dart` — 图片/PDF 选择
  - `arxiv_metadata_section.dart` — arXiv 信息展示
  - `reference_selector.dart` — 引用选择
  - 修复: `_contentFocusNode.dispose()` + await 后 `mounted` 检查 + `String fileType→enum UploadFileType`
- `widgets/post_card.dart`(521) — 点赞乐观更新抽 InteractionController
- `widgets/reference_display.dart` + `pdf_iframe_view*` — 保持
- `models/post_model.dart`(403) — 状态字符串→enum
- `services/arxiv_service.dart`(428) — 代理地址改 `AppEnv.apiBaseUrl`
- 新建 `services/api/post_api.dart` `services/api/arxiv_api.dart`

### P4 — interaction 前端

**文件**:
- 新建 `widgets/comment/` — 从 post_detail 切出评论 UI (`comment_section`/`comment_item`/reply input)
- `screens/follow_list_screen.dart`(851) — 保持或抽 controller
- `screens/message/` 通知子页 — 从 message_screen 切出
- `services/unread_service.dart`
- `services/notification_websocket_service.dart`
- `models/notification_model.dart`
- 新建 `services/api/interaction_api.dart` `comment_api.dart` `follow_api.dart` `notification_api.dart`

### P5 — chat/websocket 前端

**文件**:
- `screens/message_screen.dart`(1684) → 拆 `screens/message/`:
  - `message_screen.dart` — 骨架 + tab
  - `conversation_list.dart` — 会话列表 (P5)
  - `notification_list.dart` — 通知列表 (归 P4)
- `widgets/message_bubble.dart`(1257) → `widgets/message/` 子目录:
  - 抽象基类 `message_bubble.dart`
  - 6-8 个子类文件 (text/image/video/audio/file/system 按现有 switch 分支)
- `widgets/chat_input.dart`(790) → 拆:
  - `chat_input_bar.dart` — 文本输入+发送
  - `audio_recorder_button.dart` — 录音
  - `attachment_picker.dart` — 附件选择
- `screens/chat_screen.dart`(741) — 2s 轮询改 WebSocket 订阅
- `widgets/conversation_item.dart`(312) + `video_message_player.dart` + `web_audio_recorder*` — 保持
- `services/chat_service.dart`(738) — WebSocket 驱动
- `models/conversation_model.dart` `message_model.dart`
- 新建 `services/api/chat_api.dart`

### P6 — admin/report 前端

**文件**:
- `screens/admin_mode_screen.dart`(3053) → 拆 `screens/admin/`:
  - `admin_screen.dart` — 骨架 (顶栏+侧栏+路由, ~100行)
  - `admin_user_section.dart`
  - `admin_post_section.dart`
  - `admin_report_section.dart`
  - `admin_notice_section.dart`
  - `admin_permission_section.dart`
  - `admin_controller.dart`
  - 修复: `'MUTED'→'MUTE'` 状态标签、补 `AUDIT→待审核`、删举报人重复显示、合并 `_viewPostDetail`、抽 `_getUserDisplayName`
- `widgets/report_post_dialog.dart` — 改查 `body['success']`
- 新建 `services/api/admin_api.dart` `services/api/report_api.dart`

### P7 — 浏览/检索 前端

**文件**:
- `screens/home_screen.dart`(1405) → 抽 `feed_widget.dart`（首页帖子流独立组件）
- `screens/zone_screen.dart`(329) — 保持
- `screens/search_screen.dart`(750) + `search_results_screen.dart`(589) — 保持
- `models/search_model.dart`(312)
- `services/browse_history_service.dart`(255) + `search_history_service.dart`(255) — 抽 `LocalJsonListStore<T>` 泛型缓存工具
- 新建 `models/browse_history_item.dart`（从 service 切出模型）
- 新建 `services/api/history_api.dart` `search_api.dart` `hot_api.dart`

---

## 3. 推进顺序

| 阶段 | 内容 | 谁 |
|---|---|---|
| **Pre-flight** | `api_service.dart` 机械预拆 → 6 个 `*_api.dart` + `pages/` → `screens/auth/` + 约束文档引用 | orchestrator (手动) |
| **Fan-out** | 6 agent 并行做各自前端文件拆分 | P2–P7 agents (worktree) |
| **Merge** | 逐 agent codex-review→fix→ff-merge | orchestrator |
| **Final** | `main.dart`/`router.dart` import 收尾 + 全量 `flutter test` 绿 + `flutter build web` | orchestrator |

## 4. Agent 专用约束（在 Wave1 G1-G6 基础上叠加）

- **G7**: 每个拆分后的 Widget/Dart 文件 ≤ ~300 行。超过说明拆得不够。
- **G8**: `flutter test` 必须绿。至少原 baseline 3 个 widget test + 新 agent 针对自己拆出的 controller/纯函数/模型补 unit test。
- **G9**: 不引入新依赖（pubspec.yaml 不动）。不用 Provider/Riverpod/Bloc。
- **G10**: 拆分后 `flutter build web` 不报错（在 agent worktree 内验证）。
