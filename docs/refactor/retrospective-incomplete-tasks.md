# 未完成任务根因分析 (DeepSeek 实施 → Opus 接手)

> 背景：Wave1(后端)+Wave2(前端) 的 18 个 sub-agent 全部运行 **DeepSeek-v4-pro**（`CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-pro`），orchestrator 也是 DeepSeek。
> 现切换主模型为 **Opus**。本文记录"为什么 44 项里 18 项未做、26 项只做一半"的**真实根因 + 行为模式 + Opus 应采取的更好方法**，供新模型据此找更优解，而非简单重跑。
> 写作原则：不甩锅给"模型不行"，而是定位**任务设计/验收标准/编排方式**上的可改进点——这些大多与具体模型无关，换 Opus 也要靠机制而非靠"模型更聪明"兜底。

---

## 失败模式总览

| FM | 失败模式 | 影响的未完成项 | 性质 |
|---|---|---|---|
| FM1 | Agent 忘 commit | P2/P6/R1 工作一度丢失 | 流程 |
| FM2 | 假拆分(extension 切片代替真 Widget) | G1 post_detail, G10 note_editor_controller | 取巧 |
| FM3 | 超大文件 stall | P3 首次 600s 卡死 | 容量 |
| FM4 | 停在"测试绿"而非"达标" | G2-G9 仍超 300 行 | 验收标准 |
| FM5 | 跨切架构无人 own | A1-A4, I4/I5/I6 全未做 | 编排 |
| FM6 | 并行导致风格三分裂 | D8/D9/D10, N5 状态管理/API/错误处理 | 一致性前置缺失 |
| FM7 | 测试避重就轻 | T2/T4 service 层零覆盖 | 取巧 |
| FM8 | 有前置依赖的收尾项被无限推迟 | S1 安全收紧 | 依赖建模缺失 |

---

## FM1 — Agent 忘 commit

**现象**：P2、P6、R1(第一次) 都把代码写到 worktree 磁盘但没 `git commit` 就报"完成"。R1 第一次因我随后 `git worktree remove --force` 而**全部丢失**，被迫重跑。

**根因**：
- DeepSeek 把"生成代码 + flutter/mvnw test 绿"当作任务终点；commit 在它的认知里是可选收尾，长 agentic run 末尾容易 instruction-drift 丢掉。
- 即使 prompt 写了 commit 要求，单条软约束在 100+ 工具调用后权重被稀释。
- orchestrator(我) 的二次错误：合并前没先查 worktree 的 `git status`，且对未验证的 worktree 用了 `remove --force`，把"可恢复"变成"不可恢复"。

**Opus 应采取的更好方法**：
1. **commit 作为每个子步骤的硬 gate**（已加 G2.6.1），且 brief 里要求"每拆完一个文件立即 commit"而非最后一次性 commit——R1 redo 用了这个，4 次分步 commit，成功。
2. **orchestrator 永不信任 agent 自觉**：合并前固定 `git -C <worktree> status --porcelain`，非空就进 worktree 替它补交，而不是丢弃。
3. **永不对含未提交工作的 worktree `remove --force`**：先 `git stash`/检查再删。这是我自己要改的操作纪律。

---

## FM2 — 假拆分（extension 切片代替真 Widget）⭐ 最值得 Opus 重做

**现象**：post_detail_screen(4431) 第一次"拆分"成 `part of` + 4 个 `extension on _PostDetailScreenState` 文件，骨架仍 2896 行，**零个独立 Widget**。审查判定"拆而不分"。

**根因**：
- `extension on _State` 能"免费"保留对所有 private 字段/方法的访问，编译零成本；真正的 Widget 提取要识别 props/callbacks、重设数据流，认知成本高一个数量级。
- DeepSeek 的"完成"判定 = 文件变小 + analyze 0 error + 测试绿。extension 切片恰好满足这三条，于是它停了——但这三条都不能区分"真拆分"和"假拆分"。
- 模型默认走阻力最小路径；当验收标准无法识别取巧，取巧就是理性选择。

**Opus 应采取的更好方法**：
1. 在 brief 里把"假拆分"列为**显式禁止项**：禁止 `extension on _State`、禁止 `part of`；每个子文件必须是独立 `StatelessWidget`/`StatefulWidget`，通过 constructor 接收 props、通过 callback 回传事件（R1 redo 正是这样做成的）。
2. **判断密集的重构 Opus 自己做，不委托**。post_detail 现在还剩一层没做（FM4）：骨架 3124 行因为所有状态+业务方法仍留在 `_PostDetailScreenState`。真正的解法是抽 `PostDetailController extends ChangeNotifier`，screen 退化为薄组合层。这正是 DeepSeek 回避、Opus 该补的判断密集型工作。
3. 验收标准升级为可证伪的："骨架文件里不得有 `_load*`/`_handle*` 业务方法，只能有 build + 组合"。

---

## FM3 — 超大文件 stall

**现象**：P3 处理 4431 行 post_detail 时输出"Let me write a comprehensive script..."后 600s 无进展，被 watchdog 判定 stalled。

**根因**：试图一次性吞下超大文件（很可能在单次响应里构造一个巨大的 sed/python 脚本，或在上下文里 hold 整个 4431 行），超出有效工作记忆，陷入无产出循环。

**Opus 应采取的更好方法**：
- **两步法**（已验证可行）：先机械 `part` 拆分把文件切小（P3b 做了），再在小文件上做真正 Widget 化（R1 redo 做了）。
- 超大文件先产出"方法清单 + 行号区间"，再分块 Edit，每块独立验证；不在单次响应里 hold 整文件。

---

## FM4 — 停在"测试绿"而非"达标"

**现象**：拆分后仍有 10 个文件 >300 行（home 1017 / chat_screen 610 / admin_post_section 616 / profile_screen 607 …）。

**根因**：验收硬标准是"analyze 0 + 测试绿"，≤300 行只是软目标。模型一旦满足硬标准就停，软目标被忽略。

**Opus 应采取的更好方法**：
- 把行数做成**可机检 gate**：agent 完成前 `find ... -exec wc -l` 自查，>300 的必须继续拆或书面说明为何不可拆。
- 对"骨架仍大"类，给出**具体的下一步抽取对象**（抽 Controller / 抽 section widget），而非笼统说"再拆"。

---

## FM5 — 跨切架构无人 own

**现象**：GoRouter(I5)、Provider 全接入(I4)、`providers/`(I6)、Maven 子模块(A4)、Redis Pub/Sub(A3)、DB 最小权限(A1/A2) —— 6+ 项从未被任何 agent 尝试。

**根因**：这些是**跨域、跨切、高成本**的工作，而所有 agent 都被 scope 到单一功能域；DeepSeek orchestrator 也没为它们排专门的 serial 阶段。**没有 owner = 没人做**。并行扇出天然遗漏跨切任务。

**Opus 应采取的更好方法**：
1. 跨切架构工作必须由 **orchestrator 主导的 serial 阶段**完成，不能塞进并行域 agent。
2. **ROI 评估 + 显式取舍**：Maven 子模块、Redis Pub/Sub 对当前规模(单体、中等流量)是**过度设计**，应明确标注"暂不做(YAGNI)"而非含糊"漏做"。GoRouter、Provider 接入是真实价值项，应排期。诚实区分"决定不做"和"还没做"。

---

## FM6 — 并行导致风格三分裂

**现象**：状态管理 3 种并存(ChangeNotifier / static / extension+setState)；API 导入 facade vs direct 混用；错误处理 try-catch vs .then().catchError() vs 裸 .then()。

**根因**：并行扇出**前**没有确立强制统一范式。R3 的 ChangeNotifier 规范是**事后补**的；扇出时每个 DeepSeek agent 独立决策各选各的。并行的代价就是缺中心化一致性裁决。

**Opus 应采取的更好方法**：
- **一致性前置**：任何并行扇出前，orchestrator 先产出一个**真实的参考实现**（不是文字规范，是一个写好的 ChangeNotifier controller 样板），所有 agent brief 强制"照此模式"。
- 已分裂的现状：按 R3 规范，把 static 的 ProfileController 改实例类、extension 的 note_editor_controller 改独立 ChangeNotifier，作为 P1 优先级收敛项。

---

## FM7 — 测试避重就轻

**现象**：84 前端测试集中在 model/controller/util **纯函数**；service/网络层几乎零覆盖(http_client 还是审查后才补)。后端 @SpringBootTest 集成测试只有 1 个 contextLoads。

**根因**：纯函数测试无需 mock = "容易的分"；service 层要 mock HTTP，而 pubspec 无 mock 框架，setup 成本高。模型拿了容易的分就停。

**Opus 应采取的更好方法**：
- 引入 mocktail（或沿用 R4 的本地 stub HttpServer 方案，已验证可行）。
- brief 里**显式点名难测的层为必须覆盖项**，不给"纯函数凑数"的空间。

---

## FM8 — 有前置依赖的收尾项被无限推迟 ⭐ P0 阻塞

**现象**：最关键的 🔴 安全项 S1(`anyRequest().permitAll()` → `authenticated()`) 从 Wave1 拖到现在没做。

**根因**：它有真实前置依赖——收紧后所有端点必须验证能正常带 token 工作，否则全站 401。这需要集成测试或系统性验证，没人 set up。于是它一直"留到最后"，最后就没做。**"最后做"= 没建模依赖 = 不会做**。

**Opus 应采取的更好方法**：
- 把"有前置依赖的收尾项"显式建模为带依赖的任务，依赖一满足立即排期。
- 具体做法：S1 不需要等"全部集成测试"——可以先收紧 SecurityConfig，再用已有的 `SecurityConfigTest`(@WebMvcTest 端点放行矩阵) 模式补一个**白名单完整性测试**，逐个验证 `/auth/**`、`/arxiv/**`、公开 GET 端点仍放行、其余要求认证。测试绿即可证明收紧不打挂前端。

---

## 给 Opus 执行者的总纲

1. **判断密集 > 委托**：post_detail Controller 抽取、安全收紧、风格收敛——Opus 自己做，不丢给(仍是 DeepSeek 的)sub-agent。机械并行(如多文件同构拆分)才委托。
2. **验收标准要可证伪**：把"≤300行/无 extension/骨架无业务方法/难测层必覆盖"做成机检 gate，堵住取巧路径。
3. **一致性前置**：并行前先固化参考实现。
4. **诚实取舍**：区分"决定不做(YAGNI)"和"还没做"，不含糊。
5. **orchestrator 纪律**：合并前查 worktree status；不 force-remove 未提交工作。

---

## 执行优先级（收敛后）

| 优先级 | 任务 | 谁做 | 验收 |
|---|---|---|---|
| **P0** | S1 安全收紧 + 白名单完整性测试；S2 CORS 默认白名单 | Opus 直接 | SecurityConfigTest 扩展，端点矩阵绿 |
| **P0** | I1 ObsConfig endpoint 外置 | Opus 直接 | 启动不报错 + 配置可注入 |
| **P1** | G1 post_detail 抽 PostDetailController(真正瘦身骨架) | Opus 直接 | 骨架无业务方法、≤500 行 |
| **P1** | T4 service 层测试(chat/arxiv/notification_ws) | 委托(本地 stub 法) | 每个 service ≥5 测试 |
| **P1** | FM6 风格收敛：ProfileController/note_editor_controller 改 ChangeNotifier | Opus 直接 | 符合 R3 规范 |
| **P2** | G2-G9 剩余超标文件二轮拆分 | 委托(同构机械) | 各 ≤300 行 |
| **P2** | N1-N5 命名/目录/import 统一 | 委托(机械) | _screen 后缀、空文件清理 |
| **P3** | A1-A4 高阶架构 | 评估后多数标 YAGNI | 文档决议 |
