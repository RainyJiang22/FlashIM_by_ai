# auth-system-upgrade — server 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。
全局约束：
- 认证存储统一升级为 `PostgreSQL + SQLx`，不得继续把认证主数据留在 `InMemoryStore`。
- 账户模型必须以 `accounts` 为主体，`user_profiles` 1:1，`auth_credentials` 1:N，`sms_codes` 独立。
- 继续保留现有 JWT Header 约定：`Authorization: Bearer <token>`。
- 本期不实现 refresh token、忘记密码、微信 OAuth 联调、多设备踢下线。
- 参考文档：`docs/features/auth-system-upgrade/v1/server/design.md`。

---

## 执行顺序

1. ✅ 任务 1 — `server/Cargo.toml` 依赖升级（无依赖）
   - ✅ 1.1 新增数据库与密码哈希依赖
   - ✅ 1.2 保持现有 axum/jwt/tokio 版本不被意外回退
2. ✅ 任务 2 — `server/src/config.rs` 增加数据库与认证配置（依赖任务 1）
   - ✅ 2.1 增加 `DATABASE_URL` 与验证码有效期配置
   - ✅ 2.2 保持现有 `HOST` / `PORT` / `JWT_TTL` 兼容
3. ✅ 任务 3 — `server/migrations/20260612170000_auth_accounts_core.sql` 创建四张认证核心表（依赖任务 1）
   - ✅ 3.1 创建 `accounts`
   - ✅ 3.2 创建 `user_profiles`
   - ✅ 3.3 创建 `auth_credentials`
   - ✅ 3.4 创建 `sms_codes` 与索引
4. ✅ 任务 4 — `server/src/store/mod.rs` 抽象认证仓储接口（依赖任务 2）
   - ✅ 4.1 定义 store trait
   - ✅ 4.2 导出 `memory` / `postgres`
5. ✅ 任务 5 — `server/src/store/memory.rs` 对齐新账户模型（依赖任务 4）
   - ✅ 5.1 用 account/profile/credential 替代旧内存结构
   - ✅ 5.2 补齐验证码、密码设置、密码修改接口
6. ✅ 任务 6 — `server/src/store/postgres.rs` 落 PostgreSQL 持久化实现（依赖任务 3、任务 4）
   - ✅ 6.1 实现账户、资料、凭据查询与写入
   - ✅ 6.2 实现短信验证码写入、消费与过期过滤
7. ✅ 任务 7 — `server/src/state.rs` 注入可切换的认证 store（依赖任务 5、任务 6）
   - ✅ 7.1 在状态中保存 `Arc<dyn AuthStore>`
   - ✅ 7.2 衔接配置与初始化入口
8. ✅ 任务 8 — `server/src/auth/password.rs` 重写密码工具（依赖任务 1）
   - ✅ 8.1 删除明文 seed 账号依赖
   - ✅ 8.2 提供 hash / verify 能力
9. ✅ 任务 9 — `server/src/models/auth.rs` 更新认证 DTO（依赖任务 2）
   - ✅ 9.1 登录请求切到 `identifier` / `account_id`
   - ✅ 9.2 新增设置密码与修改密码请求响应
10. ✅ 任务 10 — `server/src/models/user.rs` 更新资料 DTO（依赖任务 2）
    - ✅ 10.1 `user_id` 改为 `account_id`
    - ✅ 10.2 新增 `has_password`
11. ✅ 任务 11 — `server/src/services/user_service.rs` 实现账户创建与资料读取（依赖任务 5、任务 6、任务 8、任务 9、任务 10）
    - ✅ 11.1 按手机号查找或创建账户主体
    - ✅ 11.2 统一返回资料视图模型
12. ✅ 任务 12 — `server/src/services/auth_service.rs` 重写认证编排（依赖任务 5、任务 6、任务 8、任务 9、任务 10、任务 11）
    - ✅ 12.1 短信登录接入账户模型与密码状态判断
    - ✅ 12.2 密码登录改为 `identifier + password`
    - ✅ 12.3 新增设置密码与修改密码
13. ✅ 任务 13 — `server/src/routes/auth.rs` 暴露新认证接口（依赖任务 9、任务 12）
    - ✅ 13.1 保留 `/auth/sms` 与 `/auth/login`
    - ✅ 13.2 新增 `/auth/password/set` 与 `/auth/password/change`
14. ✅ 任务 14 — `server/src/routes/user.rs` 与 `server/src/routes/mod.rs` 对齐新资料与路由注册（依赖任务 10、任务 12、任务 13）
    - ✅ 14.1 资料接口返回 `has_password`
    - ✅ 14.2 路由表挂载新接口
15. ✅ 任务 15 — `server/src/main.rs`、`server/src/lib.rs` 启动装配与集成测试更新（依赖任务 7、任务 14）
    - ✅ 15.1 用配置化状态替代硬编码初始化
    - ✅ 15.2 更新认证相关集成测试到 `account_id` / 新接口模型
16. ✅ 最后 — 编译验证 + 测试路径（依赖任务 1-15）
    - ✅ 16.1 `cargo fmt --check`
    - ✅ 16.2 `cargo clippy --all-targets --all-features -- -D warnings`
    - ✅ 16.3 `cargo test`
    - ✅ 16.4 本地 `curl` 验证 `/auth/sms`、`/auth/login`、`/auth/password/set`、`/auth/password/change`、`/user/profile`

---

## 任务 1：Cargo.toml — 认证持久化依赖升级 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/Cargo.toml`

改动类型：`修改`

### 1.1 新增数据库与密码哈希依赖 `✅`

补齐服务端数据库与密码工具依赖，为后续 SQLx store 和 Argon2 做准备。

关键代码片段：

```toml
[dependencies]
sqlx = { version = "...", features = ["runtime-tokio-rustls", "postgres", "macros", "migrate"] }
argon2 = "..."
chrono = { version = "...", features = ["serde"] }
```

### 1.2 保持现有运行时主链路稳定 `✅`

不要顺手调整 `axum`、`tokio`、`jsonwebtoken` 的既有版本范围，避免把认证升级变成底座升级。

关键代码片段：

```toml
axum = { version = "0.8.9", features = ["ws"] }
tokio = { version = "1.52.3", features = ["full"] }
jsonwebtoken = { version = "10.2.0", features = ["rust_crypto"] }
```

## 任务 2：config.rs — 数据库与认证配置入口 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/config.rs`

改动类型：`修改`

### 2.1 增加 `DATABASE_URL`、验证码 TTL 与 debug 配置 `✅`

为 PostgreSQL 连接、短信验证码过期控制和本地调试开关提供统一读取入口。

关键代码片段：

```rust
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}

impl AppConfig {
    pub fn from_env() -> Result<Self, ConfigError> { ... }
}
```

### 2.2 保留现有基础监听配置 `✅`

继续暴露 `HOST`、`PORT`、`JWT_TTL`，避免把非认证启动逻辑也一起重构。

关键代码片段：

```rust
pub const HOST: &str = "0.0.0.0";
pub const PORT: u16 = 9600;
pub const JWT_TTL: Duration = Duration::from_secs(24 * 60 * 60);
```

## 任务 3：20260612170000_auth_accounts_core.sql — 创建账户四表模型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/migrations/20260612170000_auth_accounts_core.sql`

改动类型：`新建`

### 3.1 创建 `accounts` 与 `user_profiles` `✅`

先落账户主体和展示资料 1:1 结构。

关键代码片段：

```sql
CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    primary_identifier VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_profiles (
    account_id BIGINT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    nickname VARCHAR(64) NOT NULL,
    avatar_url TEXT NOT NULL,
    bio TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 3.2 创建 `auth_credentials` `✅`

统一承载手机号、邮箱、微信、本地密码等认证方式。

关键代码片段：

```sql
CREATE TABLE auth_credentials (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    credential_type VARCHAR(32) NOT NULL,
    identifier VARCHAR(128) NOT NULL,
    password_hash TEXT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    verified_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (credential_type, identifier)
);
```

### 3.3 创建 `sms_codes` 与索引 `✅`

验证码表要支持按手机号 + 用途消费最新有效记录。

关键代码片段：

```sql
CREATE TABLE sms_codes (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose VARCHAR(32) NOT NULL DEFAULT 'login',
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sms_codes_phone_purpose
    ON sms_codes (phone, purpose, created_at DESC);
```

## 任务 4：store/mod.rs — 抽象认证仓储接口 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/mod.rs`

改动类型：`修改`

### 4.1 定义统一 store trait `✅`

把短信码、账户、资料、凭据操作抽成统一接口，让 service 不感知内存或 PostgreSQL 细节。

关键代码片段：

```rust
#[async_trait]
pub trait AuthStore: Send + Sync {
    async fn save_sms_code(&self, phone: &str, code: &str, purpose: &str, expires_at: DateTime<Utc>) -> AppResult<()>;
    async fn consume_sms_code(&self, phone: &str, code: &str, purpose: &str) -> AppResult<bool>;
    async fn find_account_by_credential(&self, credential_type: CredentialType, identifier: &str) -> AppResult<Option<AccountRecord>>;
    async fn create_account_with_phone(&self, phone: &str, profile: NewProfile) -> AppResult<AccountAggregate>;
    async fn upsert_password_credential(&self, account_id: i64, identifier: &str, password_hash: &str) -> AppResult<()>;
    async fn verify_password_credential(&self, identifier: &str) -> AppResult<Option<CredentialRecord>>;
}
```

### 4.2 导出实现模块 `✅`

为后续状态注入暴露 `memory` 与 `postgres` 两个实现。

关键代码片段：

```rust
pub mod memory;
pub mod postgres;
```

## 任务 5：memory.rs — 对齐新账户模型的内存实现 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/memory.rs`

改动类型：`修改`

### 5.1 替换旧内存结构 `✅`

把 `users_by_id` / `password_accounts` 改成 account/profile/credential 三层结构，保证测试路径与新设计一致。

关键代码片段：

```rust
pub struct InMemoryStore {
    sms_codes: RwLock<HashMap<String, SmsCodeRecord>>,
    accounts_by_id: RwLock<HashMap<i64, AccountRecord>>,
    profiles_by_account_id: RwLock<HashMap<i64, UserProfileRecord>>,
    credentials_by_key: RwLock<HashMap<(CredentialType, String), CredentialRecord>>,
    next_account_id: AtomicI64,
}
```

### 5.2 补齐新接口语义 `✅`

内存实现要能跑通短信登录、密码登录、设置密码、修改密码和资料查询测试。

关键代码片段：

```rust
async fn create_account_with_phone(&self, phone: &str, profile: NewProfile) -> AppResult<AccountAggregate>;
async fn upsert_password_credential(&self, account_id: i64, identifier: &str, password_hash: &str) -> AppResult<()>;
async fn account_has_password(&self, account_id: i64) -> AppResult<bool>;
```

## 任务 6：postgres.rs — SQLx 持久化实现 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/postgres.rs`

改动类型：`新建`

### 6.1 封装 PostgreSQL store 与查询骨架 `✅`

实现与 `AuthStore` 对应的数据库落地层。

关键代码片段：

```rust
pub struct PostgresStore {
    pool: PgPool,
}

impl PostgresStore {
    pub fn new(pool: PgPool) -> Self { ... }
}
```

### 6.2 实现账户、凭据、验证码核心 SQL `✅`

至少覆盖以下关键 SQL 路径：

```rust
sqlx::query!(
    r#"INSERT INTO sms_codes (phone, code, purpose, expires_at) VALUES ($1, $2, $3, $4)"#,
    phone, code, purpose, expires_at
);

sqlx::query!(
    r#"SELECT id, account_id, credential_type, identifier, password_hash
       FROM auth_credentials
       WHERE credential_type = $1 AND identifier = $2"#,
    credential_type.as_str(),
    identifier
);
```

### 6.3 保证建号事务一致性 `✅`

短信首登要在一个事务里创建 `accounts`、`user_profiles`、手机号 credential。

关键代码片段：

```rust
let mut tx = self.pool.begin().await?;
// insert accounts
// insert user_profiles
// insert auth_credentials(type=phone)
tx.commit().await?;
```

## 任务 7：state.rs — 注入可切换认证存储 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/state.rs`

改动类型：`修改`

### 7.1 改造 `AppState` 结构 `✅`

把旧的具体 `InMemoryStore` 依赖改成抽象 store。

关键代码片段：

```rust
pub struct AppState {
    pub(crate) store: Arc<dyn AuthStore>,
    pub(crate) jwt_secret: Arc<String>,
    pub(crate) config: Arc<AppConfig>,
}
```

### 7.2 提供初始化入口 `✅`

根据配置创建 PostgreSQL store；必要时保留内存实现给测试或回退路径。

关键代码片段：

```rust
impl AppState {
    pub async fn from_config(config: AppConfig) -> AppResult<Self> { ... }
}
```

## 任务 8：password.rs — 密码哈希与校验工具 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/password.rs`

改动类型：`修改`

### 8.1 移除 seed 密码账号结构 `✅`

当前文件里的 `seeded_password_accounts()` 不再是主实现，需要改成密码工具模块。

关键代码片段：

```rust
pub fn hash_password(password: &str) -> AppResult<String>;
pub fn verify_password(password: &str, password_hash: &str) -> AppResult<bool>;
```

### 8.2 补凭据类型常量或枚举 `✅`

减少 service / store 里到处写裸字符串。

关键代码片段：

```rust
pub enum CredentialType {
    Phone,
    Password,
    Email,
    Wechat,
}
```

## 任务 9：models/auth.rs — 认证请求响应模型升级 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/models/auth.rs`

改动类型：`修改`

### 9.1 更新登录请求与登录响应 `✅`

登录响应要切到 `account_id`，密码登录请求要支持 `identifier`。

关键代码片段：

```rust
pub struct LoginRequest {
    pub login_type: LoginType,
    pub phone: Option<String>,
    pub code: Option<String>,
    pub identifier: Option<String>,
    pub password: Option<String>,
}

pub struct LoginResponse {
    pub token: String,
    pub account_id: i64,
    pub password_setup_required: bool,
}
```

### 9.2 新增设置密码与修改密码 DTO `✅`

关键代码片段：

```rust
pub struct SetPasswordRequest {
    pub new_password: String,
}

pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}

pub struct PasswordUpdateResponse {
    pub password_setup_required: Option<bool>,
    pub updated_at: DateTime<Utc>,
}
```

## 任务 10：models/user.rs — 资料响应模型升级 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/models/user.rs`

改动类型：`修改`

### 10.1 将主键语义切到 `account_id` `✅`

关键代码片段：

```rust
pub struct ProfileResponse {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
    pub has_password: bool,
}
```

### 10.2 如有需要补账户聚合结构 `✅`

为 service/store 层传输账户主体 + 资料 + 凭据状态预留聚合模型。

关键代码片段：

```rust
pub struct AccountAggregate {
    pub account: AccountRecord,
    pub profile: UserProfileRecord,
    pub phone: String,
    pub has_password: bool,
}
```

## 任务 11：user_service.rs — 账户创建与资料读取 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/services/user_service.rs`

改动类型：`修改`

### 11.1 重写短信首登建号逻辑 `✅`

短信登录成功后要按手机号 credential 查账户，不存在则创建账户主体、资料和手机号 credential。

关键代码片段：

```rust
pub async fn find_or_create_account_by_phone(
    state: &AppState,
    phone: &str,
) -> AppResult<AccountAggregate>;
```

### 11.2 提供统一资料读取接口 `✅`

给 `auth_service::load_profile()` 提供聚合后的资料能力。

关键代码片段：

```rust
pub async fn load_account_profile(
    state: &AppState,
    account_id: i64,
) -> AppResult<ProfileResponse>;
```

## 任务 12：auth_service.rs — 认证编排主逻辑 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/services/auth_service.rs`

改动类型：`修改`

### 12.1 重写短信登录与密码登录 `✅`

服务层要从旧 `user_id` 语义切到 `account_id`，并在登录响应中计算 `password_setup_required`。

关键代码片段：

```rust
pub(crate) async fn login(state: &AppState, request: LoginRequest) -> AppResult<LoginResponse>;

async fn login_with_sms_code(...) -> AppResult<AccountAggregate>;
async fn login_with_password(...) -> AppResult<AccountAggregate>;
```

逻辑步骤：
1. 校验请求字段。
2. 验证短信码或密码。
3. 找到账户主体。
4. 计算 `has_password`。
5. 签发 JWT。
6. 返回 `account_id + password_setup_required`。

### 12.2 新增设置密码与修改密码 `✅`

关键代码片段：

```rust
pub(crate) async fn set_password(
    state: &AppState,
    token: &str,
    request: SetPasswordRequest,
) -> AppResult<PasswordUpdateResponse>;

pub(crate) async fn change_password(
    state: &AppState,
    token: &str,
    request: ChangePasswordRequest,
) -> AppResult<PasswordUpdateResponse>;
```

### 12.3 更新资料加载与 JWT 解析结果 `✅`

关键代码片段：

```rust
pub(crate) async fn load_profile(state: &AppState, token: &str) -> AppResult<ProfileResponse>;
pub(crate) async fn authenticate_account(state: &AppState, token: &str) -> AppResult<AccountAggregate>;
```

## 任务 13：routes/auth.rs — 暴露新认证接口 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/auth.rs`

改动类型：`修改`

### 13.1 保留短信与登录入口 `✅`

继续沿用 `POST /auth/sms`、`POST /auth/login`，只改内部 DTO 和 service 调用。

关键代码片段：

```rust
pub async fn send_sms_code(...) -> AppResult<impl IntoResponse>;
pub async fn login(...) -> AppResult<impl IntoResponse>;
```

### 13.2 新增设置密码与修改密码 handler `✅`

关键代码片段：

```rust
pub async fn set_password(
    State(state): State<SharedState>,
    headers: HeaderMap,
    Json(request): Json<SetPasswordRequest>,
) -> AppResult<impl IntoResponse>;

pub async fn change_password(...) -> AppResult<impl IntoResponse>;
```

## 任务 14：user.rs + mod.rs — 资料返回与路由注册 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/user.rs`

改动类型：`修改`

### 14.1 资料接口返回新字段 `✅`

`GET /user/profile` 要透出 `account_id` 和 `has_password`。

关键代码片段：

```rust
let profile = auth_service::load_profile(state.as_ref(), token).await?;
Ok(utf8_json(Json(profile)))
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/mod.rs`

改动类型：`修改`

### 14.2 注册新认证路由 `✅`

关键代码片段：

```rust
.route("/auth/password/set", post(auth::set_password))
.route("/auth/password/change", post(auth::change_password))
```

## 任务 15：main.rs + lib.rs — 启动装配与集成测试更新 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/main.rs`

改动类型：`修改`

### 15.1 用配置化状态初始化应用 `✅`

关键代码片段：

```rust
let config = AppConfig::from_env()?;
let state = Arc::new(AppState::from_config(config).await?);
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs`

改动类型：`修改`

### 15.2 更新集成测试到新协议 `✅`

把测试断言从 `user_id` 改成 `account_id`，并新增设置密码 / 修改密码的 happy path 与冲突路径。

关键代码片段：

```rust
#[tokio::test]
async fn sms_login_returns_password_setup_required_for_new_account() { ... }

#[tokio::test]
async fn set_password_then_password_login_succeeds() { ... }

#[tokio::test]
async fn change_password_requires_old_password() { ... }
```

## 任务 16：编译验证 + 测试路径 `✅ 已完成`

文件：`无单一文件，执行验证`

改动类型：`配置/验证`

### 16.1 Rust 静态与单元验证 `✅`

执行：

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

### 16.2 接口手工验证 `✅`

至少覆盖以下路径：

```bash
curl -s -X POST http://127.0.0.1:9600/auth/sms ...
curl -s -X POST http://127.0.0.1:9600/auth/login ...
curl -s -X POST http://127.0.0.1:9600/auth/password/set ...
curl -s -X POST http://127.0.0.1:9600/auth/password/change ...
curl -s http://127.0.0.1:9600/user/profile -H 'Authorization: Bearer ...'
```
