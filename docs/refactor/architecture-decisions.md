# 架构改进项决议 (ADR) — A1-A4 + I5

> 对照 remaining-tasks.md 的"🟡 架构改进"与基础设施大项。原则(来自原报告 §六)：**先模块化单体、按需再演进，不过度设计**。
> 每项给**诚实 ROI 评估**：当前规模(单体后端单实例、中等流量、学生团队项目)下值不值得做。结论分三类：✅做 / ⏸️Deferred(有价值但需专门一轮) / 🚫YAGNI(当前过度设计)。

---

## A1 — DB 账号最小权限（业务账号非 root）

- **现状**：业务连远程 MySQL 用高权限账号。
- **评估**：是真实安全改进，但属**运维/DBA 任务**而非代码改动——需要 DBA 在 MySQL 侧 `CREATE USER paperhub_app` + `GRANT SELECT,INSERT,UPDATE,DELETE ON paperHub.*`（不给 DDL/GRANT），再把 `DB_USERNAME/DB_PASSWORD` 环境变量指向新账号。代码侧已支持（连接信息全走环境变量，见 application.properties）。
- **决议**：⏸️ **Deferred 到部署阶段**（运维执行）。代码无缺口。已在 ENVIRONMENT.md 记录所需环境变量。**建议的最小授权 SQL 见本文末附录**。

## A2 — `ddl-auto=validate` + Flyway/Liquibase 迁移

- **现状**：`spring.jpa.hibernate.ddl-auto=update`（Hibernate 自动同步 schema）。
- **评估**：迁到 `validate` + 迁移工具是生产级正确做法，但成本高：需把当前 18 张表的 schema 反向工程成基线迁移脚本，且项目 schema 仍在演进（每加字段都要写迁移）。对仍在迭代的学生项目，`update` 的便利 > 迁移工具的严谨。
- **决议**：⏸️ **Deferred 到准生产**。**触发条件**：schema 稳定 + 准备上线时，引入 Flyway 写 `V1__baseline.sql` 并切 `validate`。当前 YAGNI。

## A3 — WebSocket 改 Redis Pub/Sub

- **现状**：WebSocket 会话存内存 `ConcurrentHashMap`（P5 已修多设备 + 心跳 + 僵尸清理）。
- **评估**：Redis Pub/Sub 只在**多后端实例水平扩展**时才需要（跨实例广播）。当前是**单实例部署**，内存会话完全够用。原报告明确："不要一上来就微服务化，那是过度设计"。
- **决议**：🚫 **YAGNI**。**触发条件**：后端扩到 >1 实例时再做。当前单实例下零收益、徒增 Redis 耦合与故障面。

## A4 — Maven 子模块隔离 (chat/post/notification)

- **现状**：单 Maven 模块，按 feature 分包(`com.example.paperhub.{post,chat,...}`)。
- **评估**：Maven 子模块的价值是**编译期强制模块边界**（防跨模块乱 import）。但当前包结构已提供逻辑模块化，且 Wave1 重构已用"文件归属 + 依赖方向"约束达成边界。拆子模块成本高（重构构建、循环依赖治理），收益对单团队中等项目有限。
- **决议**：🚫 **YAGNI**。包级模块化已足够；强制边界可用 ArchUnit 测试低成本达成（未来可选），不必拆 Maven 子模块。

## I5 — GoRouter 命名路由

- **现状**：`router.dart` 手工路由 + 各处 `Navigator.push(MaterialPageRoute(...))`。
- **评估**：GoRouter 带来命名路由/深链接/Web SEO，是**真实价值项**。但迁移要改动**几乎每个 screen 的导航调用**（数十处 `Navigator.push`），跨所有域，与当前并行重构强冲突，且属行为敏感改动（导航栈语义）。
- **决议**：⏸️ **Deferred 到专门一轮 (Wave3)**。有价值但必须单独串行做（不能并行扇出），且需回归测试导航栈。当前不做以免与 P2/G1 冲突。

---

## 决议汇总

| 项 | 结论 | 触发条件 |
|---|---|---|
| A1 DB 最小权限 | ⏸️ Deferred(运维) | 部署时 DBA 执行 |
| A2 Flyway 迁移 | ⏸️ Deferred | schema 稳定 + 准生产 |
| A3 Redis Pub/Sub | 🚫 YAGNI | 后端多实例时 |
| A4 Maven 子模块 | 🚫 YAGNI | 大团队/超大规模时(可改用 ArchUnit) |
| I5 GoRouter | ⏸️ Deferred | Wave3 专门串行 |

> 这 5 项在 remaining-tasks.md 中据此标记为"明确决议"(非"漏做")，符合根因日志 FM5 的要求：诚实区分"决定不做"和"还没做"。

---

## 附录：A1 建议的最小授权 SQL（运维参考，勿入代码库）

```sql
CREATE USER 'paperhub_app'@'%' IDENTIFIED BY '<strong-password-from-secret-manager>';
GRANT SELECT, INSERT, UPDATE, DELETE ON paperHub.* TO 'paperhub_app'@'%';
-- 不授予 CREATE/ALTER/DROP/GRANT；DDL 由迁移工具或 DBA 单独执行
FLUSH PRIVILEGES;
```
