# server-modularization — Server 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。  
全局约束：
- 以 Cargo workspace 方式在 `server/modules/` 下新增 `flash_core` 与 `flash_auth`，宿主 `server` 继续保留启动与组合职责。
- 本期不改外部 API 路径、不改认证返回字段、不新增数据库迁移文件、不处理 `flash_chat` 之类的新业务模块。
- `flash_core` 只能承载共享运行时基础设施，不能反向依赖 `flash_auth`。
- `flash_auth` 不能再 import 宿主 `server/src/...`，认证代码迁移后必须只依赖 `flash_core` 与自身 crate。
- 当前 `conversation / ws / chat_room_service` 允许暂留宿主 crate，但 `ChatRoomStore` 这类共享运行时状态要从认证内存存储中拆开。
- 实现时优先保持现有接口行为、测试语义和数据库表结构稳定，再做模块归位。

---

## 执行顺序

1. ✅ 任务 1 — `server/Cargo.toml` 改为 workspace 宿主配置（无依赖）
   - ✅ 1.1 增加 workspace members
   - ✅ 1.2 为宿主 crate 添加 `flash_core`、`flash_auth` path 依赖
2. ✅ 任务 2 — `server/modules/flash_core/Cargo.toml` 建立核心模块 package（依赖任务 1）
   - ✅ 2.1 创建 `flash_core` crate 基础元数据
   - ✅ 2.2 声明核心运行时依赖
3. ✅ 任务 3 — `server/modules/flash_core/src/lib.rs` 定义核心导出面（依赖任务 2）
   - ✅ 3.1 导出 config / error / response / context / runtime
   - ✅ 3.2 暴露宿主与业务模块需要的公共类型
4. ✅ 任务 4 — `server/modules/flash_core/src/config.rs` 迁移宿主配置模型（依赖任务 2）
   - ✅ 4.1 迁移 `AppConfig`
   - ✅ 4.2 保持测试配置和访问地址输出能力
5. ✅ 任务 5 — `server/modules/flash_core/src/error.rs` 与 `response.rs` 下沉通用 HTTP 基础设施（依赖任务 2）
   - ✅ 5.1 迁移 `AppError / AppResult`
   - ✅ 5.2 迁移 UTF-8 JSON 响应封装
6. ✅ 任务 6 — `server/modules/flash_core/src/runtime/` 建立共享运行时设施（依赖任务 2）
   - ✅ 6.1 新增 PostgreSQL runtime 封装
   - ✅ 6.2 新增 chat room 连接仓封装
7. ✅ 任务 7 — `server/modules/flash_core/src/context.rs` 建立核心状态上下文（依赖任务 4、任务 5、任务 6）
   - ✅ 7.1 迁移 `AppState` 为核心上下文
   - ✅ 7.2 保持 `from_config` 和测试构造能力
8. ✅ 任务 8 — `server/modules/flash_auth/Cargo.toml` 建立认证模块 package（依赖任务 1、任务 3、任务 7）
   - ✅ 8.1 创建 `flash_auth` crate 基础元数据
   - ✅ 8.2 依赖 `flash_core`
9. ✅ 任务 9 — `server/modules/flash_auth/src/lib.rs` 定义认证模块导出面（依赖任务 8）
   - ✅ 9.1 导出 models / routes / services / store / jwt / password
   - ✅ 9.2 暴露认证路由挂载入口
10. ✅ 任务 10 — `server/modules/flash_auth/src/models/` 迁移认证领域模型（依赖任务 8）
    - ✅ 10.1 迁移 `auth` 请求响应模型
    - ✅ 10.2 迁移 `user profile` 认证相关资料模型
11. ✅ 任务 11 — `server/modules/flash_auth/src/jwt.rs` 与 `password.rs` 迁移认证基础能力（依赖任务 8、任务 10）
    - ✅ 11.1 JWT 改为依赖 `flash_core::AppContext`
    - ✅ 11.2 保持 Argon2 哈希与校验逻辑
12. ✅ 任务 12 — `server/modules/flash_auth/src/store/mod.rs` 重建认证仓储抽象（依赖任务 8、任务 10）
    - ✅ 12.1 迁移 `AuthStore` trait 与记录结构
    - ✅ 12.2 保持 `CredentialType` 和聚合模型
13. ✅ 任务 13 — `server/modules/flash_auth/src/store/memory.rs` 迁移测试内存仓（依赖任务 12）
    - ✅ 13.1 只保留认证内存存储
    - ✅ 13.2 删除聊天室连接管理职责
14. ✅ 任务 14 — `server/modules/flash_auth/src/store/postgres.rs` 迁移 PostgreSQL 认证实现（依赖任务 6、任务 12）
    - ✅ 14.1 认证查询改为复用 `flash_core` 的数据库 runtime
    - ✅ 14.2 保持现有 SQL 行为不变
15. ✅ 任务 15 — `server/modules/flash_auth/src/services/` 迁移认证服务（依赖任务 10、任务 11、任务 12、任务 13、任务 14）
    - ✅ 15.1 迁移 `auth_service`
    - ✅ 15.2 迁移 `user_service`
16. ✅ 任务 16 — `server/modules/flash_auth/src/routes/` 迁移认证路由（依赖任务 10、任务 15）
    - ✅ 16.1 迁移 `/auth/*` 路由处理器
    - ✅ 16.2 迁移 `/user/profile` 处理器与路由注册
17. ✅ 任务 17 — `server/src/lib.rs`、`main.rs`、宿主 `routes/` / `services/` 重构为组合层（依赖任务 7、任务 9、任务 16）
    - ✅ 17.1 宿主改为从模块 crate 组装 app
    - ✅ 17.2 清理宿主中已迁移的 auth 代码引用
18. ✅ 任务 18 — `server/src/auth`、`state.rs`、`config.rs`、`error.rs`、`response.rs`、`store/` 等旧位置清理（依赖任务 17）
    - ✅ 18.1 删除或缩减已迁移文件
    - ✅ 18.2 保留未模块化业务所需最小宿主代码
19. ✅ 任务 19 — 测试迁移与回归（依赖任务 17、任务 18）
    - ✅ 19.1 宿主集成测试继续覆盖认证主链路
    - ✅ 19.2 为模块新增最小单测或编译验证
20. ✅ 最后 — 格式化、静态检查、测试验证（依赖任务 1-19）
    - ✅ 20.1 `cargo fmt --check`
    - ✅ 20.2 `cargo clippy --all-targets --all-features -- -D warnings`
    - ✅ 20.3 `cargo test`

---

> 当前状态：任务 1-20 已完成并验证通过，下面保留的是本次落地时对应的实现骨架记录。

## 任务 1：`server/Cargo.toml` — 切换为 workspace 宿主配置 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/Cargo.toml`

改动类型：`修改`

### 1.1 增加 workspace members `⬜`

关键配置骨架：

```toml
[workspace]
members = [
  ".",
  "modules/flash_core",
  "modules/flash_auth",
]
resolver = "2"
```

### 1.2 宿主 crate 添加模块依赖 `⬜`

关键配置骨架：

```toml
[dependencies]
flash_core = { path = "modules/flash_core" }
flash_auth = { path = "modules/flash_auth" }
```

说明：
- 保留现有宿主启动所需依赖。
- 逐步删除宿主不再直接使用的认证依赖，避免一次性删过头。

---

## 任务 2：`flash_core/Cargo.toml` — 建立核心模块 package `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/Cargo.toml`

改动类型：`新建`

### 2.1 创建 crate 元数据 `⬜`

关键配置骨架：

```toml
[package]
name = "flash_core"
version = "0.1.0"
edition = "2024"
publish = false
```

### 2.2 声明核心运行时依赖 `⬜`

关键配置骨架：

```toml
[dependencies]
axum = { version = "0.8.9", features = ["ws"] }
chrono = { version = "0.4.42", features = ["serde"] }
local-ip-address = "0.6.13"
serde = { version = "1.0.228", features = ["derive"] }
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros", "migrate", "chrono", "json"] }
tokio = { version = "1.52.3", features = ["full"] }
```

说明：
- 只放共享基础设施需要的依赖。
- `jsonwebtoken`、`argon2` 不应放进 `flash_core`。

---

## 任务 3：`flash_core/src/lib.rs` — 核心模块导出面 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/lib.rs`

改动类型：`新建`

### 3.1 导出核心子模块 `⬜`

关键代码骨架：

```rust
pub mod config;
pub mod context;
pub mod error;
pub mod response;
pub mod runtime;
```

### 3.2 统一 re-export 宿主常用类型 `⬜`

关键代码骨架：

```rust
pub use config::{AppConfig, HOST, PORT, print_access_urls};
pub use context::{AppContext, SharedContext, ContextInitError};
pub use error::{AppError, AppResult};
```

---

## 任务 4：`flash_core/src/config.rs` — 迁移配置模型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/config.rs`

改动类型：`新建`

### 4.1 迁移 `AppConfig` `⬜`

关键代码骨架：

```rust
pub const HOST: &str = "0.0.0.0";
pub const PORT: u16 = 9600;
pub const JWT_TTL: Duration = Duration::from_secs(24 * 60 * 60);

#[derive(Clone)]
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_ttl: Duration,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}
```

### 4.2 保持测试配置与启动打印 `⬜`

关键代码骨架：

```rust
impl AppConfig {
    pub fn from_env() -> Result<Self, ConfigError> { ... }

    #[cfg(test)]
    pub fn for_tests(jwt_secret: impl Into<String>) -> Self { ... }
}

pub fn print_access_urls(port: u16) { ... }
```

---

## 任务 5：`flash_core/src/error.rs` 与 `response.rs` — 下沉通用 HTTP 基础设施 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/error.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/response.rs`

改动类型：`新建`

### 5.1 统一错误模型 `⬜`

关键代码骨架：

```rust
#[derive(Clone, Copy, Debug)]
pub struct AppError {
    status: StatusCode,
    message: &'static str,
}

pub type AppResult<T> = Result<T, AppError>;
```

### 5.2 统一 JSON 响应封装 `⬜`

关键代码骨架：

```rust
pub fn utf8_json<T>(json: Json<T>) -> Response
where
    Json<T>: IntoResponse,
{ ... }

pub fn json_error(status: StatusCode, message: &'static str) -> Response { ... }
```

---

## 任务 6：`flash_core/src/runtime/` — 建立共享运行时设施 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/runtime/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/runtime/postgres.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/runtime/chat_room.rs`

改动类型：`新建`

### 6.1 PostgreSQL runtime 封装 `⬜`

关键代码骨架：

```rust
#[derive(Clone)]
pub struct PostgresRuntime {
    pool: PgPool,
}

impl PostgresRuntime {
    pub async fn connect(database_url: &str) -> Result<Self, sqlx::Error> { ... }
    pub async fn run_migrations(&self) -> Result<(), sqlx::migrate::MigrateError> { ... }
    pub fn pool(&self) -> &PgPool { ... }
}
```

### 6.2 chat room 连接仓拆出 `⬜`

关键代码骨架：

```rust
#[derive(Clone)]
pub struct ChatRoomConnection {
    pub sender: mpsc::UnboundedSender<String>,
}

pub struct ChatRoomStore {
    chat_connections: RwLock<HashMap<usize, ChatRoomConnection>>,
    next_chat_message_id: AtomicU64,
}
```

说明：
- 这里仅迁移共享连接管理，不迁移具体聊天业务服务。

---

## 任务 7：`flash_core/src/context.rs` — 建立核心状态上下文 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/context.rs`

改动类型：`新建`

### 7.1 迁移共享上下文结构 `⬜`

关键代码骨架：

```rust
#[derive(Clone)]
pub struct AppContext {
    pub postgres: Arc<PostgresRuntime>,
    pub chat_room_store: Arc<ChatRoomStore>,
    pub jwt_secret: Arc<String>,
    pub jwt_ttl: Duration,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}

pub type SharedContext = Arc<AppContext>;
```

### 7.2 保持生产和测试初始化入口 `⬜`

关键代码骨架：

```rust
impl AppContext {
    pub async fn from_config(config: AppConfig) -> Result<Self, ContextInitError> { ... }

    #[cfg(test)]
    pub fn new_for_tests(jwt_secret: impl Into<String>) -> Self { ... }
}
```

说明：
- 测试构造里不要再依赖宿主 `server::state`。
- 需要预留测试替换认证 store 的能力，供 `flash_auth` 后续注入。

---

## 任务 8：`flash_auth/Cargo.toml` — 建立认证模块 package `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/Cargo.toml`

改动类型：`新建`

### 8.1 创建 crate 元数据 `⬜`

关键配置骨架：

```toml
[package]
name = "flash_auth"
version = "0.1.0"
edition = "2024"
publish = false
```

### 8.2 声明依赖 `flash_core` `⬜`

关键配置骨架：

```toml
[dependencies]
argon2 = "0.5.3"
async-trait = "0.1.89"
axum = { version = "0.8.9", features = ["ws"] }
chrono = { version = "0.4.42", features = ["serde"] }
flash_core = { path = "../flash_core" }
jsonwebtoken = { version = "10.2.0", features = ["rust_crypto"] }
rand = "0.9.2"
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.145"
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros", "migrate", "chrono", "json"] }
```

---

## 任务 9：`flash_auth/src/lib.rs` — 认证模块导出面 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/lib.rs`

改动类型：`新建`

### 9.1 导出认证子模块 `⬜`

关键代码骨架：

```rust
pub mod jwt;
pub mod models;
pub mod password;
pub mod routes;
pub mod services;
pub mod store;
```

### 9.2 提供路由挂载入口 `⬜`

关键代码骨架：

```rust
pub fn build_auth_router() -> Router<SharedContext> { ... }
pub fn register_auth_routes(router: Router<SharedContext>) -> Router<SharedContext> { ... }
```

说明：
- 保持宿主接入简单，避免宿主重新拼一遍 `/auth/*`。

---

## 任务 10：`flash_auth/src/models/` — 迁移认证领域模型 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/models/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/models/auth.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/models/user.rs`

改动类型：`新建`

### 10.1 迁移认证请求响应模型 `⬜`

关键代码骨架：

```rust
#[derive(Deserialize)]
pub struct LoginRequest {
    #[serde(default)]
    pub login_type: LoginType,
    pub phone: Option<String>,
    pub code: Option<String>,
    pub identifier: Option<String>,
    pub password: Option<String>,
}
```

### 10.2 迁移资料响应与内部用户记录 `⬜`

关键代码骨架：

```rust
#[derive(Clone, Serialize, Deserialize)]
pub struct UserRecord {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
    pub has_password: bool,
}
```

---

## 任务 11：`flash_auth/src/jwt.rs` 与 `password.rs` — 迁移认证基础能力 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/jwt.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/password.rs`

改动类型：`新建`

### 11.1 JWT 改为依赖核心上下文 `⬜`

关键代码骨架：

```rust
use flash_core::AppContext;

pub fn sign_token(
    context: &AppContext,
    account_id: i64,
) -> Result<String, jsonwebtoken::errors::Error> { ... }
```

### 11.2 保持密码安全能力 `⬜`

关键代码骨架：

```rust
pub fn hash_password(password: &str) -> Result<String, argon2::password_hash::Error> { ... }
pub fn verify_password(password: &str, hash: &str) -> Result<bool, argon2::password_hash::Error> { ... }
```

---

## 任务 12：`flash_auth/src/store/mod.rs` — 重建认证仓储抽象 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/store/mod.rs`

改动类型：`新建`

### 12.1 迁移 `AuthStore` 与聚合结构 `⬜`

关键代码骨架：

```rust
#[async_trait]
pub trait AuthStore: Send + Sync {
    async fn save_sms_code(&self, phone: &str, code: &str, purpose: &str, expires_at: DateTime<Utc>) -> AppResult<()>;
    async fn consume_sms_code(&self, phone: &str, code: &str, purpose: &str) -> AppResult<bool>;
    async fn find_account_by_id(&self, account_id: i64) -> AppResult<Option<AccountAggregate>>;
    ...
}
```

### 12.2 保持凭据类型和账户聚合 `⬜`

关键代码骨架：

```rust
pub enum CredentialType {
    Phone,
    Password,
    Email,
    Wechat,
}
```

说明：
- `AppResult` 改为来自 `flash_core`。

---

## 任务 13：`flash_auth/src/store/memory.rs` — 迁移测试内存仓 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/store/memory.rs`

改动类型：`新建`

### 13.1 只保留认证内存存储 `⬜`

关键代码骨架：

```rust
pub struct InMemoryStore {
    sms_codes: RwLock<HashMap<(String, String), Vec<SmsCodeRecord>>>,
    accounts_by_id: RwLock<HashMap<i64, AccountRecord>>,
    profiles_by_account_id: RwLock<HashMap<i64, ProfileRecord>>,
    credentials_by_id: RwLock<HashMap<i64, CredentialRecord>>,
    ...
}
```

### 13.2 删除聊天室职责 `⬜`

说明：
- `ChatRoomStore`、`ChatRoomConnection` 不再出现在本文件。
- 测试认证仓只负责账户、凭据、验证码的内存行为。

---

## 任务 14：`flash_auth/src/store/postgres.rs` — 迁移 PostgreSQL 认证实现 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/store/postgres.rs`

改动类型：`新建`

### 14.1 改为复用核心数据库 runtime `⬜`

关键代码骨架：

```rust
use flash_core::runtime::postgres::PostgresRuntime;

#[derive(Clone)]
pub struct PostgresAuthStore {
    postgres: Arc<PostgresRuntime>,
}
```

### 14.2 保持现有 SQL 行为不变 `⬜`

说明：
- 查询 SQL 继续针对 `accounts / user_profiles / auth_credentials / sms_codes`。
- 不借这次迁移顺手改字段名、改索引、改返回语义。

---

## 任务 15：`flash_auth/src/services/` — 迁移认证服务 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/services/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/services/auth_service.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/services/user_service.rs`

改动类型：`新建`

### 15.1 迁移 `auth_service` `⬜`

关键代码骨架：

```rust
pub async fn issue_sms_code(context: &AppContext, store: &dyn AuthStore, phone: &str) -> AppResult<SmsResponse> { ... }
pub async fn login(context: &AppContext, store: &dyn AuthStore, request: LoginRequest) -> AppResult<LoginResponse> { ... }
pub async fn authenticate_user(context: &AppContext, store: &dyn AuthStore, token: &str) -> AppResult<UserRecord> { ... }
```

### 15.2 迁移 `user_service` `⬜`

关键代码骨架：

```rust
pub async fn find_or_create_account_by_phone(store: &dyn AuthStore, phone: &str) -> AppResult<UserRecord> { ... }
pub async fn load_user_by_account_id(store: &dyn AuthStore, account_id: i64) -> AppResult<UserRecord> { ... }
```

说明：
- 明确把“核心配置上下文”和“认证仓储”作为依赖传入，减少隐式耦合。

---

## 任务 16：`flash_auth/src/routes/` — 迁移认证路由 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/routes/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/routes/auth.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/routes/user.rs`

改动类型：`新建`

### 16.1 迁移 `/auth/*` 路由处理器 `⬜`

关键代码骨架：

```rust
pub async fn login(
    State(context): State<SharedContext>,
    Json(request): Json<LoginRequest>,
) -> AppResult<impl IntoResponse> { ... }
```

### 16.2 迁移 `/user/profile` 和统一注册入口 `⬜`

关键代码骨架：

```rust
pub fn register_auth_routes(router: Router<SharedContext>) -> Router<SharedContext> {
    router
        .route("/auth/sms", post(auth::send_sms_code))
        .route("/auth/login", post(auth::login))
        .route("/auth/password/set", post(auth::set_password))
        .route("/auth/password/change", post(auth::change_password))
        .route("/user/profile", get(user::user_profile))
}
```

---

## 任务 17：宿主 `server/src/` — 重构为组合层 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/main.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/ws.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/services/chat_room_service.rs`

改动类型：`修改`

### 17.1 宿主用模块 crate 组装 app `⬜`

关键代码骨架：

```rust
use flash_auth::register_auth_routes;
use flash_core::SharedContext;

pub fn build_app(context: SharedContext) -> Router {
    let router = Router::new()
        .route("/v", get(health::version))
        .route("/conversation", get(conversation::conversations))
        .route("/ws", get(ws::websocket_handler))
        .route("/chat_room/ws", get(ws::chat_room_websocket_handler));

    register_auth_routes(router).with_state(context)
}
```

### 17.2 `main.rs` 改为从 `flash_core` 启动 `⬜`

关键代码骨架：

```rust
use flash_core::{AppConfig, AppContext, HOST, PORT, print_access_urls};

let config = AppConfig::from_env()?;
let context = Arc::new(AppContext::from_config(config).await?);
let app = build_app(context);
```

说明：
- `ws` 和 `chat_room_service` 需要改成依赖 `flash_core::SharedContext`。

---

## 任务 18：旧宿主认证文件清理 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/jwt.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/password.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/config.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/error.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/response.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/state.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/auth.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/user.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/services/auth_service.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/services/user_service.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/memory.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/store/postgres.rs`

改动类型：`删除/修改`

### 18.1 删除已迁移入口 `⬜`

说明：
- 认证代码迁移完成后，宿主不应再保留第二套同名实现。

### 18.2 保留最小宿主代码面 `⬜`

说明：
- 只保留 `health / conversation / ws / chat_room_service` 当前确实还需要的宿主实现。
- 如果某些旧文件仍被测试或宿主引用，先改引用，再删除文件。

---

## 任务 19：测试迁移与回归 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs` 中的现有集成测试
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_core/src/lib.rs` 或 `tests/`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/flash_auth/src/lib.rs` 或 `tests/`

改动类型：`修改/新建`

### 19.1 宿主集成测试继续覆盖认证主链路 `⬜`

重点保留：

```rust
#[tokio::test]
async fn auth_flow_returns_profile_for_valid_token() { ... }

#[tokio::test]
async fn missing_or_invalid_token_returns_401() { ... }
```

### 19.2 模块增加最小编译或行为测试 `⬜`

建议最小范围：
- `flash_auth` 的 JWT / password 工具测试
- `flash_core` 的配置解析或 context 初始化测试

---

## 任务 20：格式化、静态检查、测试验证 `✅ 已完成`

改动类型：`验证`

### 20.1 格式化 `⬜`

```bash
cd server && cargo fmt --check
```

### 20.2 静态检查 `⬜`

```bash
cd server && cargo clippy --all-targets --all-features -- -D warnings
```

### 20.3 测试 `⬜`

```bash
cd server && cargo test
```
