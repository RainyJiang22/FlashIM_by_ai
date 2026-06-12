# Rust IM 后端关系型数据库选型调研报告

## 1. 文档信息

- 项目：`flash_im`
- 主题：为 Rust 即时通信后端引入关系型数据库以持久化认证与用户数据
- 目标：比较几种主流关系型数据库在 `功能`、`性能`、`生态`、`适用场景` 四个维度的差异，并给出建议
- 时间：`2026-06-07`
- 说明：
  - 数据库产品能力与 Rust 生态现状优先参考官方文档
  - 文中的最终建议，是结合当前项目阶段做的工程判断，不是任何官方方案背书

## 2. 当前问题与选型目标

你现在的认证系统把这些数据都放在内存里：

- 短信验证码
- 用户资料
- 手机号到用户 ID 的映射
- 密码账号
- 登录后依赖的用户查找能力

这会带来几个直接问题：

1. 服务重启后数据全部丢失。
2. 无法支撑多实例部署。
3. 后续没法稳定扩展 `refresh token`、`设备管理`、`登录审计`、`封禁`、`好友/群成员关系`。
4. 现在还能接受，等你把消息、会话、已读状态也接进去后，内存模型会迅速失控。

所以这次数据库选型，不应只看“能不能存用户表”，而应该看它是否适合一个会继续长大的 Rust IM 后端。

## 3. 先给结论

结论先行：

1. **默认推荐：`PostgreSQL`**
2. **次选：`MySQL`**
3. **兼容型替代：`MariaDB`**
4. **仅推荐用于本地开发、单机 Demo、极轻量部署：`SQLite`**
5. **只有在组织环境本来就强依赖微软体系时，才优先考虑 `SQL Server`**

如果把建议说得更直接一点：

- 你这个项目当前最稳的主线是：**`Axum + Tokio + PostgreSQL + SQLx`**
- 如果团队以后更偏 CRUD / 后台管理，也可以在部分非核心域引入 `SeaORM`
- 认证、用户、设备、会话、消息索引这类核心链路，仍建议优先显式 SQL

## 4. 为什么 Rust IM 后端通常优先考虑 PostgreSQL

对 IM 系统来说，数据库不只是“存账号密码”。

后续通常还会逐步引入：

- 用户表
- 登录账号表
- 设备表
- refresh token / session 表
- 好友关系 / 黑名单
- 群、群成员、角色
- 会话表
- 消息表
- 已读回执 / 送达回执
- 审计日志

这类系统的共性是：

- 并发写入多
- 事务边界复杂
- 既有强结构化字段，也经常需要灵活扩展字段
- 未来有分区、归档、复制、分析查询的诉求

`PostgreSQL` 在这些点上的综合平衡通常最好。

PostgreSQL 官方文档明确说明其并发控制基于 `MVCC`，并强调在这种模型下，读取与写入尽量减少锁冲突，读取不会阻塞写入，写入也不会阻塞读取；在多用户环境中，这对事务隔离和性能都很关键。  
同时，官方文档也明确提供了：

- `json` / `jsonb`
- `jsonpath`
- `jsonb` 索引
- 逻辑复制
- 声明式分区

这套能力组合，对 IM 场景非常实用。

## 5. 主流关系型数据库对比

这次对比选 5 个常见候选：

- `PostgreSQL`
- `MySQL`
- `MariaDB`
- `SQLite`
- `SQL Server`

### 5.1 总表

| 数据库 | 功能能力 | 性能特点 | Rust 生态 | 适用场景 | 总体判断 |
| --- | --- | --- | --- | --- | --- |
| `PostgreSQL` | 强 | 强，尤其复杂事务与混合查询场景 | 强 | 中长期主后端、IM、业务核心系统 | **首选** |
| `MySQL` | 中上 | 强，OLTP 成熟 | 强 | 常规互联网业务、团队已有 MySQL 经验 | **次选** |
| `MariaDB` | 中上 | 中上 | 中 | MySQL 兼容诉求明显的场景 | **可选，不是首推** |
| `SQLite` | 中 | 单机场景很强，多写并发有限 | 强 | 本地开发、桌面端、单机服务、轻量 Demo | **不建议做 IM 主库** |
| `SQL Server` | 强 | 强 | 中 | 微软企业环境、已有 SQL Server 资产 | **有组织前提才选** |

---

### 5.2 PostgreSQL

#### 功能

`PostgreSQL` 的优势不只是“传统关系型数据库能力完整”，而是它对现代业务模型非常友好：

- 强事务与并发控制
- `json` / `jsonb` 能力成熟
- 支持 `jsonpath`
- `jsonb` 支持索引
- 支持逻辑复制
- 支持声明式分区

这意味着你可以把：

- 用户基础信息做强结构化建模
- 设备扩展信息、登录上下文、风控元数据放在 `jsonb`
- 大表如消息表、登录审计表按时间或会话分区

这对 IM 很合适。

#### 性能

`PostgreSQL` 的优势不一定总是“最简单场景下绝对最快”，而是：

- 并发模型稳
- 事务一致性强
- 混合读写场景表现稳定
- 复杂查询、聚合、联表、扩展字段检索能力强

对于认证系统来说，初期压力不大；但后续如果扩展到：

- 设备管理
- 登录审计
- 会话列表
- 消息索引
- 用户关系

`PostgreSQL` 的上限更从容。

#### 生态

对 Rust 非常友好。

常用组合：

- `sqlx`：官方文档明确把 PostgreSQL 作为 Tier 1 支持
- `SeaORM`：官方文档明确支持 `sqlx-postgres`
- `Diesel`：官方文档明确支持 PostgreSQL
- `tokio-postgres`：适合更底层、纯 PostgreSQL async 客户端风格

这意味着：

- 你既可以走显式 SQL
- 也可以走 ORM
- 也可以混用

#### 适用场景

非常适合：

- 用户认证持久化
- IM 主业务数据库
- 中长期可演进的单体后端
- 未来要分库、复制、归档、审计、分析的系统

#### 不足

- 运维和学习成本高于 SQLite
- 对只做极简单 CRUD 的团队，初期感知复杂度比 MySQL 稍高

#### 结论

**如果你想让这套认证系统后续自然长成真正的 IM 后端基础设施，PostgreSQL 是最稳的第一选择。**

---

### 5.3 MySQL

#### 功能

MySQL 官方资料列出的能力非常全：

- 原生 JSON 类型
- JSON table / aggregation / partial update
- ACID 事务
- 行级锁
- 快照隔离
- 多种复制与高可用能力
- `InnoDB Cluster`、`Group Replication`
- 多源复制、延迟复制、GTID

说明它绝不是“只能做简单 Web CRUD”的数据库。

#### 性能

MySQL / InnoDB 在传统 `OLTP` 场景非常成熟，尤其是：

- 常规业务写入
- 读多写多的互联网业务
- 团队已有经验时的交付效率

如果你的团队长期使用 MySQL，那么把认证系统先落在 MySQL 上，也完全是合理工程方案。

#### 生态

Rust 生态也不错：

- `sqlx` 对 MySQL 是 Tier 1 支持
- `SeaORM` 官方支持 `sqlx-mysql`
- `Diesel` 官方也支持 MySQL

所以从 Rust 接入角度，MySQL 不存在明显短板。

#### 适用场景

适合：

- 团队对 MySQL 更熟
- 公司已有 MySQL 基础设施
- 希望先快速上线
- 当前主要目标是认证、用户、简单会话业务

#### 不足

和 PostgreSQL 相比，我更在意这几个点：

- 对复杂业务模型的表达能力和“未来舒展性”通常略弱
- 需要半结构化扩展、复杂查询和后续消息分析时，往往没有 PostgreSQL 那么顺手
- 如果你的系统以后会越来越像“复杂状态系统”，PostgreSQL 通常更自然

#### 结论

**如果你们团队 MySQL 经验明显更深，MySQL 是务实可行的第二选择。**

---

### 5.4 MariaDB

#### 功能

MariaDB 与 MySQL 血缘接近，也保留了很多熟悉体验。

它有自己的一些功能亮点，比如官方文档明确提供：

- `system-versioned tables`
- 变化历史保留
- 审计与时间点分析
- 点时间恢复场景

这对登录审计、认证历史、账号变更追踪等场景是加分项。

#### 性能

一般业务足够用，但在我这里它更像：

- `MySQL` 体系下的兼容型替代
- 不是 Rust IM 新项目的默认优先项

#### 生态

Rust 里通常不把它当成完全独立生态看，而是：

- `sqlx` 通过 MySQL 驱动支持 MariaDB，且官方列为 Tier 1
- `SeaORM` 文档里也明确 `sqlx-mysql` 覆盖 MySQL 和 MariaDB

所以能用，但“专属优化和社区心智”通常还是围绕 MySQL 本体更多。

#### 适用场景

适合：

- 组织已有 MariaDB 存量资产
- 团队明确希望继续留在 MariaDB 体系
- 更看重 MySQL 兼容和已有运维习惯

#### 不足

- 在 Rust 新项目里，默认优先级通常不如 PostgreSQL / MySQL 清晰
- 对外部资料、工程范式、默认示例的可复用度，一般略逊于 PostgreSQL / MySQL

#### 结论

**MariaDB 不是不能选，而是它更像“有明确组织前提时的选择”，不是这个项目我会主动优先推荐的主线。**

---

### 5.5 SQLite

#### 功能

SQLite 的最大特点不是“功能弱”，而是：

- 零运维
- 单文件
- 嵌入式
- 很适合本地环境、桌面、移动端、测试环境

官方文档也说明了：

- `WAL` 模式在很多场景下明显更快
- 读写可以并发进行

所以如果只是：

- 本地 Playground
- 单机场景
- 开发期调试
- 命令行工具

SQLite 非常舒服。

#### 性能

单机场景下往往出奇地好。

但官方文档同样明确写了一个关键限制：

- `WAL` 模式要求所有进程在同一台主机上，不能工作在网络文件系统场景

这基本决定了它不适合拿来做真正的 IM 主库。

因为 IM 后端后续大概率会走向：

- 多实例
- 多进程
- 远程备份 / 高可用
- 独立数据库服务

SQLite 不适合作为这类系统的长期权威存储。

#### 生态

Rust 生态是强的：

- `sqlx` 支持 SQLite
- `SeaORM` 支持 SQLite
- `Diesel` 支持 SQLite
- 还有 `rusqlite`

所以它很适合本地开发和测试。

#### 适用场景

推荐用于：

- 本地开发
- 原型阶段
- 单机部署
- 自动化测试
- 小工具或桌面应用

不推荐用于：

- 多实例 IM 主后端
- 权威认证中心
- 需要高可用和横向扩展的生产环境

#### 结论

**SQLite 很适合作为开发 / 测试 / 单机版本的数据库，但不适合作为你这个 Rust IM 项目的长期生产主库。**

---

### 5.6 SQL Server

#### 功能

SQL Server 功能是强的，特别是在企业数据平台场景里。

官方文档明确展示了：

- `system-versioned temporal tables`
- 自动保存历史版本
- 时间点分析

这对审计和历史追踪非常友好。

#### 性能

企业 OLTP 场景性能没问题，微软体系下还可以叠加：

- In-Memory OLTP
- Azure SQL
- 企业级管理与监控

#### 生态

这是它在当前项目里的主要减分点。

虽然：

- `sqlx` 把 SQL Server 列在支持矩阵里

但官方文档也明确标了：

- `mssql` 驱动在 “Pending a full rewrite”

这意味着：

- 在 Rust 生态里，SQL Server 并不是最顺手、最稳妥的默认目标

#### 适用场景

适合：

- 公司已经深度使用微软数据库体系
- 必须对接现有 SQL Server / Azure SQL 资产
- 组织标准先于技术偏好

#### 不足

- 对当前这个 Rust IM 新项目来说，不是自然的一线选择
- 社区资料、默认实践、Rust 端心智都不如 PostgreSQL / MySQL 顺手

#### 结论

**如果没有明确的组织约束，不建议把 SQL Server 作为这个项目的第一选择。**

## 6. 从四个维度做最终比较

### 6.1 功能维度

如果看“长期业务承载能力”：

1. `PostgreSQL`
2. `SQL Server`
3. `MySQL`
4. `MariaDB`
5. `SQLite`

解释：

- `PostgreSQL` 胜在事务、JSONB、复制、分区、扩展性组合最均衡
- `SQL Server` 企业功能强，但不适合当前 Rust 项目作为默认首选
- `MySQL` 足够成熟，但面向复杂状态系统时通常略逊于 PostgreSQL
- `MariaDB` 有亮点，但不够“默认主线”
- `SQLite` 功能不算弱，但部署模型决定了上限

### 6.2 性能维度

如果看“这个项目未来可能变成真正 IM 后端”的性能上限：

1. `PostgreSQL`
2. `MySQL`
3. `SQL Server`
4. `MariaDB`
5. `SQLite`

这里的意思不是“跑分绝对值”，而是结合：

- 并发读写
- 多表事务
- 后续消息索引
- 扩展字段查询
- 复制与大表管理

综合之后的工程判断。

### 6.3 Rust 生态维度

按当前 Rust 实战便利度，我会这样排：

1. `PostgreSQL`
2. `MySQL`
3. `SQLite`
4. `MariaDB`
5. `SQL Server`

原因：

- `PostgreSQL` 有 `sqlx`、`tokio-postgres`、`SeaORM`、`Diesel`，最平衡
- `MySQL` 也很好，但在 Rust 核心后端社区的“默认推荐心智”一般略弱于 PostgreSQL
- `SQLite` 在开发/测试场景里非常方便
- `MariaDB` 更多依赖 MySQL 驱动兼容
- `SQL Server` 在 Rust 端目前不是最舒服的一档

### 6.4 适用场景维度

| 场景 | 更推荐 |
| --- | --- |
| 本地开发 / 单机 Demo | `SQLite` |
| 团队已有成熟 MySQL 经验 | `MySQL` |
| 组织已有 MariaDB 体系 | `MariaDB` |
| 微软企业环境 | `SQL Server` |
| Rust IM 后端主库 / 认证中心 / 长期业务核心 | `PostgreSQL` |

## 7. 针对 `flash_im` 的建议

### 7.1 我建议你现在就选 PostgreSQL

理由非常直接：

1. 你现在要解决的是“认证与用户持久化”，但项目显然不止会停在这里。
2. 这是一个 Rust 即时通信后端，不是单纯的后台管理系统。
3. 后续大概率会继续接：
   - refresh token
   - 设备绑定
   - 登录审计
   - 好友 / 群 / 会话
   - 消息存储与索引
4. 如果今天为了“简单”选一个后面不够舒展的数据库，未来迁移成本比现在一次选对更高。

所以我建议：

**生产主线：`PostgreSQL`**

### 7.2 技术栈建议

建议的第一阶段组合：

- Web 框架：`Axum`
- Runtime：`Tokio`
- 数据库：`PostgreSQL`
- 数据访问：`SQLx`
- Migration：`sqlx migrate` 或独立 migration 工具

原因：

- 认证、用户、session 这类链路事务边界明确
- 你当前服务端已经做了结构化重构
- 直接上 `SQLx` 最贴合你现在的风格

### 7.3 认证系统第一批建议落库的数据

第一批就可以持久化这些表：

1. `users`
2. `user_login_accounts`
3. `user_devices`
4. `auth_refresh_tokens`
5. `auth_login_audits`

一个合理的职责划分大概是：

- `users`：用户主资料
- `user_login_accounts`：手机号、账号名、密码哈希、登录方式
- `user_devices`：设备标识、最后登录时间、设备名
- `auth_refresh_tokens`：长期登录态续期
- `auth_login_audits`：登录成功/失败、IP、UA、时间

### 7.4 数据库落地策略建议

建议按这个顺序推进：

1. 先把当前内存 `users / phone 映射 / password 账号` 改成 PostgreSQL 持久化
2. 短信验证码先可以保留内存，或者单独做短 TTL 存储
3. 再补 `refresh token`
4. 再补 `login audit`
5. 后续消息和会话表再进入下一阶段设计

这样做的好处是：

- 改动边界清晰
- 不需要一次把整套 IM 数据层全重写
- 可以先把“服务重启后数据不丢”这个核心问题解决

## 8. 最终建议

### 8.1 一句话结论

**对于当前这个 Rust 即时通信后端项目，我建议把认证与用户持久化主库选为 `PostgreSQL`。**

### 8.2 备选结论

- 如果团队强 MySQL 背景、目标是更快落地：可以选 `MySQL`
- 如果只是本地开发和 Demo：可以先用 `SQLite`
- `MariaDB` 与 `SQL Server` 都不是这个项目的默认首推路线

### 8.3 推荐级别

| 数据库 | 推荐级别 | 说明 |
| --- | --- | --- |
| `PostgreSQL` | 强烈推荐 | 最适合这个 Rust IM 后端的长期主线 |
| `MySQL` | 推荐 | 团队熟悉时是务实次选 |
| `SQLite` | 有条件推荐 | 仅开发 / 测试 / 单机 |
| `MariaDB` | 谨慎推荐 | 有存量前提时再考虑 |
| `SQL Server` | 谨慎推荐 | 有组织级微软约束时再考虑 |

## 9. 参考来源

### 数据库官方文档

- PostgreSQL MVCC：<https://www.postgresql.org/docs/15/mvcc-intro.html>
- PostgreSQL JSON Types：<https://www.postgresql.org/docs/16/datatype-json.html>
- PostgreSQL Logical Replication：<https://www.postgresql.org/docs/current/logical-replication.html>
- PostgreSQL Table Partitioning：<https://www.postgresql.org/docs/current/ddl-partitioning.html>
- MySQL Technical Specifications：<https://www.mysql.com/products/enterprise/techspec.html>
- MySQL InnoDB and Replication：<https://dev.mysql.com/doc/refman/9.7/en/innodb-and-mysql-replication.html>
- MariaDB System-Versioned Tables：<https://mariadb.com/docs/server/reference/sql-structure/temporal-tables/system-versioned-tables>
- SQLite WAL：<https://www.sqlite.org/wal.html>
- SQL Server Temporal Tables：<https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables?view=sql-server-ver17>

### Rust 数据访问生态官方资料

- SQLx support matrix：<https://docs.rs/sqlx/latest/sqlx/database/index.html>
- Diesel getting started：<https://diesel.rs/guides/getting-started/>
- SeaORM database drivers：<https://www.sea-ql.org/SeaORM/docs/install-and-config/database-and-async-runtime/>
