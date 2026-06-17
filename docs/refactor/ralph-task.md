# Ralph Loop 任务清单 — 完成 Paperhub remaining-tasks.md 全部项

> 这是 ralph-loop 的标准指令，每轮迭代都读它。目标：把 `docs/refactor/remaining-tasks.md` 所有未完成项做完，经 codex + 自审通过后输出 `RALPH-ALL-DONE` 停止。
> 分支固定 `refactor/wave1-base`。每轮先 `git log --oneline -5` 看进度，从下面"执行顺序"里挑下一个未完成阶段继续。

## 执行顺序（严格按此推进，一轮做一个可验收的小阶段）

### 阶段 1 — P2 机械批（委托并行 worktree sub-agent）
- G2-G9 剩余超 300 行文件二轮拆分，目标每文件 ≤300 行的**真 Widget 拆分**：
  - home_screen 1017 / chat_screen 610 / admin_post_section 616 / admin_controller 590 / profile_screen 607 / search_screen 750 / follow_list_screen 851 / share_bubble 483
- N1-N5 命名目录统一：`_page.dart` → `_screen.dart` 后缀；删 `widgets/reference_display.dart` 空文件；`pages/note_editor_page.dart` re-export 清理；`follow_controller.dart` 移入 `screens/follow/`；API 导入方式统一为 direct import。
- T4 service 层测试：chat_service / arxiv_service / notification_websocket_service，用本地 stub HttpServer 法，每个 ≥5 测试。

### 阶段 2 — codex-review P2
- codex 额度已重置。从干净 worktree 跑 `codex-review-for-claude --base <P2前的commit>`。
- 对有效发现修改；误报书面说明理由。

### 阶段 3 — 更新 wave2 文档
- `docs/refactor/wave2-frontend-report.html` + `wave2-token-tracker.md` + `remaining-tasks.md` 反映最新进度。

### 阶段 4 — G1（Opus 自己做，判断密集，不委托）
- `post_detail_screen.dart`(3124) 抽 `PostDetailController extends ChangeNotifier`：把状态字段 + 业务方法（_loadPost / like / favorite / comment / websocket）移出；screen 退化为薄组合层，≤500 行，骨架内不得有 `_load*`/`_handle*` 业务方法（用 grep 核）。

### 阶段 5 — remaining-tasks 其余项
- I4 状态管理接入（ChangeNotifier 统一，按 state-management-convention.md）。
- 风格收敛：ProfileController static→实例、note_editor_controller extension→独立 ChangeNotifier、D8/D9/D10 错误处理统一。
- I5 GoRouter、A1-A4 高阶架构：逐项**ROI 评估**，过度设计的明确写 YAGNI 决议（不是漏做），有价值的实现。

## 硬性约束（每个 sub-agent + 每步都遵守，来自根因日志 retrospective-incomplete-tasks.md）
1. G2.6.1：完成前必须 `git commit` 且 `git status --porcelain` 为空；orchestrator 合并前先 `git -C <worktree> status --porcelain` 检查，非空则进 worktree 补交，**绝不对未提交工作 force-remove**。
2. 禁止假拆分：禁止 `extension on _State` / `part of` 冒充拆分，必须独立 Widget + constructor props/callbacks。
3. 每步验收可证伪：`flutter analyze` 零 error + `flutter test` 全绿 + 后端 `sh ./mvnw test` 全绿；行数 `wc -l` 机检 ≤300；骨架无业务方法用 `grep` 核。
4. 行为保持，JSON 字段名 / API 路径不变；commit English prefix + 中文正文，结尾 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`；不 push。
5. sub-agent worktree 从 `refactor/wave1-base` 切（`.claude/settings.json` 已设 baseRef=head，会话固定在该分支）。

## 完成定义（达成才输出 RALPH-ALL-DONE）
- remaining-tasks.md 所有项 = ✅ 或明确 YAGNI 决议。
- 前端 `flutter test` + 后端 `sh ./mvnw test` 全绿。
- codex-review 与自审均无阻断项。
- wave2 文档已更新。

## 每轮收尾
- 每轮结束更新 `docs/refactor/ralph-progress.md`（追加一行：轮次/做了什么/测试结果/下一步），便于人类休息后回看。
