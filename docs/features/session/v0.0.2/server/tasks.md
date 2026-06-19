# session v0.0.2 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧实现步骤。目标是新增资料编辑能力、迁移密码接口、引入 `identicon:{seed}` 默认头像，并把 `/user/*` 能力从宿主层整理到独立 `flash_user` crate。

全局约束：
- 本清单只覆盖 `server/`；`头像上传`、`手机号/邮箱换绑`、`用户注销`、`用户搜索` 继续不实现。
- 默认以前置设计 [session v0.0.1 server tasks](../../v0.0.1/server/tasks.md) 已落地；如果当前分支的 `server/modules/flash_core` 仍未补齐，先完成 v0.0.1 再执行本清单。
- 目录命名沿用现有 `flash_auth` / `flash_core` 风格，新的用户模块按 `server/modules/flash_user/` 落地；如 package 名使用 `flash-user`，Rust import 仍为 `flash_user`。
- 当前客户端 DTO 仍读取 `account_id`、`has_password`，并且 `AuthApi.setPassword()` 还请求 `/auth/password/set`。本轮 server 任务默认保留 `account_id` / `has_password` 资料字段；旧密码路径是否保留兼容别名，按联调节奏单独决定。
- 为复用现有 `InMemoryStore` / `PostgresAuthStore` 测试体系，`flash_user` 本轮允许依赖 `flash_auth::store` 和 `flash_auth::password`，不要再新起一套平行 store。
- `PUT /user/profile` 支持可选更新 `nickname`、`signature`、`avatar`；`phone` 不可编辑。
- 默认头像不再使用 `picsum.photos`，统一改为 `identicon:{seed}` 文本标记；seed 默认取账号 ID。

---

## 执行顺序

1. ✅ 任务 1 — `server/Cargo.toml` 接入 `flash_user` crate（无依赖）
   - ✅ 1.1 workspace members 新增 `modules/flash_user`
   - ✅ 1.2 宿主 crate 新增 `flash_user` path 依赖
2. ✅ 任务 2 — `server/migrations/20260612170000_auth_accounts_core.sql` 扩展 `user_profiles.signature`（依赖任务 1）
   - ✅ 2.1 `user_profiles` 表新增 `signature VARCHAR(100) DEFAULT ''`
   - ✅ 2.2 为开发态 reset-db 流程保持可重建
3. ✅ 任务 3 — `server/modules/flash_auth/src/store/mod.rs` 扩展用户资料抽象（依赖任务 2）
   - ✅ 3.1 `ProfileRecord` / `NewProfile` 新增 `signature`
   - ✅ 3.2 新增 `UpdateProfilePatch`
   - ✅ 3.3 `AuthStore` 增加资料更新能力
4. ✅ 任务 4 — `server/modules/flash_auth/src/store/{memory,postgres}.rs` 落地资料字段与更新逻辑（依赖任务 3）
   - ✅ 4.1 memory store 支持 `signature` 与 patch 更新
   - ✅ 4.2 postgres store 查询/插入/更新 `signature`
   - ✅ 4.3 默认头像 seed 改为基于 account id 生成
5. ✅ 任务 5 — `server/modules/flash_auth/src/services/user_service.rs` 切换 identicon 默认头像（依赖任务 4）
   - ✅ 5.1 注册创建资料时不再生成 picsum URL
   - ✅ 5.2 继续保持手机号登录主链路不变
6. ✅ 任务 6 — `server/modules/flash_core/src/jwt.rs` 与 `src/lib.rs` 暴露 `extract_user_id`（依赖任务 1）
   - ✅ 6.1 统一 Authorization 解析和 token 校验
   - ✅ 6.2 `flash_user` 与宿主层只复用这一份 helper
7. ✅ 任务 7 — `server/modules/flash_user/Cargo.toml` 建立新 crate（依赖任务 1、3、6）
   - ✅ 7.1 创建 package 元数据
   - ✅ 7.2 声明对 `flash_core`、`flash_auth`、`axum`、`serde`、`chrono` 的依赖
8. ✅ 任务 8 — `server/modules/flash_user/src/model.rs` 定义资料与密码请求响应（依赖任务 7）
   - ✅ 8.1 Profile 响应增加 `signature` 与兼容字段 `has_password`
   - ✅ 8.2 UpdateProfileRequest 支持 `avatar`
   - ✅ 8.3 Set/ChangePassword 请求响应拆分
9. ✅ 任务 9 — `server/modules/flash_user/src/handler.rs` 实现四个 `/user/*` handler（依赖任务 4、6、8）
   - ✅ 9.1 `GET /user/profile`
   - ✅ 9.2 `PUT /user/profile`
   - ✅ 9.3 `POST /user/password`
   - ✅ 9.4 `PUT /user/password`
10. ✅ 任务 10 — `server/modules/flash_user/src/routes.rs` 与 `src/lib.rs` 暴露 `router()`（依赖任务 9）
    - ✅ 10.1 注册 `/user/profile` 与 `/user/password`
    - ✅ 10.2 对宿主仅公开 `pub fn router() -> Router<SharedContext>`
11. ✅ 任务 11 — `server/modules/flash_auth/src/{models/auth.rs,routes/auth.rs,routes/mod.rs,services/auth_service.rs}` 清理迁出的密码职责（依赖任务 10）
    - ✅ 11.1 删除 `/auth/password/set` 与 `/auth/password/change` 主实现
    - ✅ 11.2 移除已迁走的 DTO / service 入口
    - ✅ 11.3 保留短信登录、密码登录、token 鉴权能力
12. ✅ 任务 12 — `server/src/routes/mod.rs`、`server/src/routes/user.rs`、`server/src/models/{mod,user}.rs` 整理宿主用户入口（依赖任务 10、11）
    - ✅ 12.1 宿主 merge `flash_user::router()`
    - ✅ 12.2 删除旧的宿主 `GET /user/profile` 实现与响应模型
13. ✅ 任务 13 — `server/src/lib.rs` 更新集成测试（依赖任务 12）
    - ✅ 13.1 资料响应断言补齐 `signature` / `has_password`
    - ✅ 13.2 密码链路改测 `/user/password`
    - ✅ 13.3 新增资料编辑与 identicon 断言
14. ✅ 最后 — 数据库重建、格式化、静态检查、测试验证（依赖任务 1-13）
    - ✅ 14.1 `scripts/database/reset_sqlx_database.sh`
    - ✅ 14.2 `cd server && cargo fmt --check`
    - ✅ 14.3 `cd server && cargo clippy --all-targets --all-features -- -D warnings`
    - ✅ 14.4 `cd server && cargo test`

---

## 任务 1：`server/Cargo.toml` — 接入 `flash_user` crate `✅ 已完成`

文件：`server/Cargo.toml`

改动类型：`配置修改`

### 1.1 workspace members 新增 `modules/flash_user` `✅`

关键配置骨架：

```toml
[workspace]
members = [".", "modules/flash_core", "modules/flash_auth", "modules/flash_user"]
resolver = "2"
```

### 1.2 宿主 crate 新增 `flash_user` path 依赖 `✅`

关键配置骨架：

```toml
[dependencies]
flash_auth = { path = "modules/flash_auth" }
flash_core = { path = "modules/flash_core" }
flash_user = { path = "modules/flash_user" }
```

说明：
- 不要顺手重排整个依赖表，只补本 feature 必需项。

---

## 任务 2：`server/migrations/20260612170000_auth_accounts_core.sql` — 扩展 `signature` 字段 `✅ 已完成`

文件：`server/migrations/20260612170000_auth_accounts_core.sql`

改动类型：`修改`

### 2.1 为 `user_profiles` 新增 `signature` 列 `✅`

关键 SQL 骨架：

```sql
CREATE TABLE user_profiles (
    account_id BIGINT PRIMARY KEY REFERENCES accounts(id),
    nickname VARCHAR(50) NOT NULL,
    avatar_url VARCHAR(500) NOT NULL,
    signature VARCHAR(100) NOT NULL DEFAULT '',
    bio VARCHAR(200) NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.2 保持 reset-db 流程可直接重建 `✅`

执行提示：

```bash
scripts/database/reset_sqlx_database.sh
```

说明：
- 当前仓库已有 `reset_sqlx_database.sh`，优先直接改初始 migration 并重建，而不是额外追加一个仅服务本地开发的补丁 migration。

---

## 任务 3：`server/modules/flash_auth/src/store/mod.rs` — 扩展用户资料抽象 `✅ 已完成`

文件：`server/modules/flash_auth/src/store/mod.rs`

改动类型：`修改`

### 3.1 `ProfileRecord` / `NewProfile` 增加 `signature` `✅`

关键代码骨架：

```rust
#[derive(Clone, Debug)]
pub struct ProfileRecord {
    pub account_id: i64,
    pub nickname: String,
    pub avatar_url: String,
    pub signature: String,
    pub bio: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct NewProfile {
    pub nickname: String,
    pub avatar_url: Option<String>,
    pub signature: String,
    pub bio: String,
}
```

### 3.2 新增资料更新 patch 类型 `✅`

关键代码骨架：

```rust
#[derive(Clone, Debug, Default)]
pub struct UpdateProfilePatch {
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub signature: Option<String>,
}
```

### 3.3 `AuthStore` 增加资料更新能力 `✅`

关键代码骨架：

```rust
#[async_trait]
pub trait AuthStore: Send + Sync {
    ...
    async fn update_profile(
        &self,
        account_id: i64,
        patch: UpdateProfilePatch,
    ) -> AppResult<Option<AccountAggregate>>;
}
```

说明：
- 这里是本轮复用现有 memory/postgres store 的关键接口，不要把资料更新能力塞回宿主 `server/src/routes/user.rs`。

---

## 任务 4：`server/modules/flash_auth/src/store/{memory,postgres}.rs` — 落地资料字段与更新逻辑 `✅ 已完成`

文件：
- `server/modules/flash_auth/src/store/memory.rs`
- `server/modules/flash_auth/src/store/postgres.rs`

改动类型：`修改`

### 4.1 memory store 补齐 `signature` 与 `update_profile()` `✅`

关键代码骨架：

```rust
let profile = ProfileRecord {
    account_id,
    nickname: profile.nickname,
    avatar_url: profile.avatar_url.unwrap_or_else(|| format!("identicon:{account_id}")),
    signature: profile.signature,
    bio: profile.bio,
    updated_at: now,
};

async fn update_profile(
    &self,
    account_id: i64,
    patch: UpdateProfilePatch,
) -> AppResult<Option<AccountAggregate>> {
    let mut profiles = self.profiles_by_account_id.write().await;
    let Some(profile) = profiles.get_mut(&account_id) else {
        return Ok(None);
    };
    if let Some(nickname) = patch.nickname {
        profile.nickname = nickname;
    }
    if let Some(avatar_url) = patch.avatar_url {
        profile.avatar_url = avatar_url;
    }
    if let Some(signature) = patch.signature {
        profile.signature = signature;
    }
    profile.updated_at = Utc::now();
    drop(profiles);
    Ok(self.load_account_aggregate(account_id).await)
}
```

### 4.2 postgres store 查询 / 插入 / 更新 `signature` `✅`

关键 SQL 骨架：

```sql
SELECT account_id, nickname, avatar_url, signature, bio, updated_at
FROM user_profiles
WHERE account_id = $1
```

```sql
INSERT INTO user_profiles (account_id, nickname, avatar_url, signature, bio)
VALUES ($1, $2, $3, $4, $5)
```

```sql
UPDATE user_profiles
SET
    nickname = COALESCE($2, nickname),
    avatar_url = COALESCE($3, avatar_url),
    signature = COALESCE($4, signature),
    updated_at = NOW()
WHERE account_id = $1
RETURNING account_id
```

### 4.3 默认头像按 account id 生成 identicon seed `✅`

关键代码骨架：

```rust
let avatar_url = profile
    .avatar_url
    .unwrap_or_else(|| format!("identicon:{}", account_row.id));
```

说明：
- `avatar_url` 的默认值必须在 account id 已生成之后再定，不能继续沿用调用前随机生成 URL 的方式。

---

## 任务 5：`server/modules/flash_auth/src/services/user_service.rs` — 切换 identicon 默认头像 `✅ 已完成`

文件：`server/modules/flash_auth/src/services/user_service.rs`

改动类型：`修改`

### 5.1 新账号资料改为传递 `avatar_url: None` + 空签名 `✅`

关键代码骨架：

```rust
let account = store
    .create_account_with_phone(
        phone,
        NewProfile {
            nickname: phone.to_string(),
            avatar_url: None,
            signature: String::new(),
            bio: String::new(),
        },
    )
    .await?;
```

### 5.2 删除旧的随机头像 helper `✅`

关键清理点：

```rust
// 删除 random_avatar_url()
// 删除 rand::Rng import
```

说明：
- 这一步只改变默认头像来源，不改变短信登录、密码登录、账号创建主流程。

---

## 任务 6：`server/modules/flash_core/src/jwt.rs` 与 `src/lib.rs` — 暴露 `extract_user_id` `✅ 已完成`

文件：
- `server/modules/flash_core/src/jwt.rs`
- `server/modules/flash_core/src/lib.rs`

改动类型：`修改或补齐`

### 6.1 在 core 中统一解析 Authorization 并校验 token `✅`

关键代码骨架：

```rust
use axum::http::{HeaderMap, header::AUTHORIZATION};
use axum::http::StatusCode;

pub fn extract_user_id(
    context: &AppContext,
    headers: &HeaderMap,
) -> Result<i64, StatusCode> {
    let token = headers
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .ok_or(StatusCode::UNAUTHORIZED)?;

    decode_token(context, token)
        .map(|claims| claims.account_id)
        .map_err(|_| StatusCode::UNAUTHORIZED)
}
```

### 6.2 从 `flash_core` 导出 jwt helper `✅`

关键代码骨架：

```rust
pub mod jwt;
```

说明：
- 具体 `decode_token()` 若仍位于 `flash_auth`，需要先把纯 JWT decode 能力下沉到 `flash_core`；不要让 `flash_user` 再复制一份 header 解析逻辑。

---

## 任务 7：`server/modules/flash_user/Cargo.toml` — 建立新 crate `✅ 已完成`

文件：`server/modules/flash_user/Cargo.toml`

改动类型：`新建`

### 7.1 创建 crate 元数据 `✅`

关键配置骨架：

```toml
[package]
name = "flash_user"
version = "0.1.0"
edition = "2024"
publish = false
```

### 7.2 声明依赖 `✅`

关键配置骨架：

```toml
[dependencies]
axum = { version = "0.8.9", features = ["ws"] }
chrono = { version = "0.4.42", features = ["serde"] }
flash_auth = { path = "../flash_auth" }
flash_core = { path = "../flash_core" }
serde = { version = "1.0.228", features = ["derive"] }
tokio = { version = "1.52.3", features = ["full"] }
```

说明：
- 本轮允许 `flash_user -> flash_auth` 单向依赖，用于复用 `AuthStore` 与密码哈希工具。

---

## 任务 8：`server/modules/flash_user/src/model.rs` — 定义资料与密码 DTO `✅ 已完成`

文件：`server/modules/flash_user/src/model.rs`

改动类型：`新建`

### 8.1 资料响应保持 `account_id` / `has_password` 兼容字段 `✅`

关键代码骨架：

```rust
#[derive(Serialize, Deserialize)]
pub struct UserProfileResponse {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
    pub signature: String,
    pub has_password: bool,
}
```

### 8.2 `UpdateProfileRequest` 支持 `avatar` 可选更新 `✅`

关键代码骨架：

```rust
#[derive(Deserialize)]
pub struct UpdateProfileRequest {
    pub nickname: Option<String>,
    pub avatar: Option<String>,
    pub signature: Option<String>,
}
```

### 8.3 密码请求 / 响应拆分 `✅`

关键代码骨架：

```rust
#[derive(Deserialize)]
pub struct SetPasswordRequest {
    pub new_password: String,
}

#[derive(Deserialize)]
pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}

#[derive(Serialize)]
pub struct MessageResponse {
    pub message: &'static str,
}
```

说明：
- `avatar` 允许保存 `identicon:{seed}` 或未来的真实 URL；本期不做上传处理，只做字符串存取。

---

## 任务 9：`server/modules/flash_user/src/handler.rs` — 实现四个 `/user/*` handler `✅ 已完成`

文件：`server/modules/flash_user/src/handler.rs`

改动类型：`新建`

### 9.1 `GET /user/profile` 返回完整资料 `✅`

关键代码骨架：

```rust
pub async fn profile(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse>
```

实现步骤：
1. 用 `flash_core::jwt::extract_user_id()` 取 `account_id`
2. `store.find_account_by_id(account_id)` 读取聚合
3. 组装 `UserProfileResponse { account_id, nickname, avatar, phone, signature, has_password }`

### 9.2 `PUT /user/profile` 做字段校验与 patch 更新 `✅`

关键代码骨架：

```rust
pub async fn update_profile(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<UpdateProfileRequest>,
) -> AppResult<impl IntoResponse>
```

关键校验规则：

```rust
if let Some(nickname) = request.nickname.as_deref() {
    let nickname = nickname.trim();
    if nickname.is_empty() || nickname.chars().count() > 50 {
        return Err(AppError::bad_request("invalid nickname"));
    }
}

if let Some(signature) = request.signature.as_deref() {
    if signature.chars().count() > 100 {
        return Err(AppError::bad_request("invalid signature"));
    }
}
```

### 9.3 `POST /user/password` 只处理首次设置 `✅`

关键代码骨架：

```rust
pub async fn set_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<SetPasswordRequest>,
) -> AppResult<impl IntoResponse>
```

实现步骤：
1. 解析 `account_id`
2. 校验 `new_password.trim().len() >= 6`
3. `find_password_credential_by_account_id()` 已存在则返回 `409`
4. `flash_auth::password::hash_password()` 后调用 `upsert_password_credential()`

### 9.4 `PUT /user/password` 校验旧密码后再更新 `✅`

关键代码骨架：

```rust
pub async fn change_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<ChangePasswordRequest>,
) -> AppResult<impl IntoResponse>
```

实现步骤：
1. 解析 `account_id`
2. 校验 `old_password` / `new_password`
3. `find_password_credential_by_account_id()` 不存在则返回 `404`
4. `flash_auth::password::verify_password()` 校验旧密码，不通过返回 `401`
5. 重新 hash 并 `upsert_password_credential()`

说明：
- 这里不要直接复用 `auth_service::set_password()` / `change_password()`；职责已经迁出。

---

## 任务 10：`server/modules/flash_user/src/routes.rs` 与 `src/lib.rs` — 暴露用户路由入口 `✅ 已完成`

文件：
- `server/modules/flash_user/src/routes.rs`
- `server/modules/flash_user/src/lib.rs`

改动类型：`新建`

### 10.1 注册 `/user/profile` 与 `/user/password` `✅`

关键代码骨架：

```rust
pub fn register_user_routes(router: Router<SharedContext>) -> Router<SharedContext> {
    router
        .route("/user/profile", get(handler::profile).put(handler::update_profile))
        .route("/user/password", post(handler::set_password).put(handler::change_password))
}
```

### 10.2 crate 对外只公开一个路由入口 `✅`

关键代码骨架：

```rust
pub mod handler;
pub mod model;
pub mod routes;

pub fn router() -> Router<SharedContext> {
    routes::register_user_routes(Router::new())
}
```

说明：
- 保持与 design 中 “只暴露一个公开 API” 的约束一致。

---

## 任务 11：`server/modules/flash_auth/src/{models/auth.rs,routes/auth.rs,routes/mod.rs,services/auth_service.rs}` — 清理迁出的密码职责 `✅ 已完成`

文件：
- `server/modules/flash_auth/src/models/auth.rs`
- `server/modules/flash_auth/src/routes/auth.rs`
- `server/modules/flash_auth/src/routes/mod.rs`
- `server/modules/flash_auth/src/services/auth_service.rs`

改动类型：`修改`

### 11.1 删除 `/auth/password/*` handler 与路由注册 `✅`

关键清理点：

```rust
// routes/mod.rs
.route("/auth/sms", post(auth::send_sms_code))
.route("/auth/login", post(auth::login))
// 删除 /auth/password/set
// 删除 /auth/password/change
```

### 11.2 移除已迁出的 DTO / service 入口 `✅`

关键清理点：

```rust
// models/auth.rs
// 删除 SetPasswordRequest
// 删除 SetPasswordResponse
// 删除 ChangePasswordRequest
// 删除 PasswordUpdatedResponse
```

```rust
// services/auth_service.rs
// 删除 set_password()
// 删除 change_password()
```

### 11.3 保留登录与鉴权最小能力 `✅`

保留项：
- `send_sms_code()`
- `login()`
- `authenticate_user()` 或等价 token -> user 聚合能力
- `jwt::{sign_token, decode_token, extract_token}` 中仍被登录链路使用的部分

说明：
- 如果联调期需要兼容旧路径，可以在宿主层额外加短期 alias；不要把真正实现继续留在 `flash_auth`。

---

## 任务 12：`server/src/routes/mod.rs`、`server/src/routes/user.rs`、`server/src/models/{mod,user}.rs` — 整理宿主用户入口 `✅ 已完成`

文件：
- `server/src/routes/mod.rs`
- `server/src/routes/user.rs`
- `server/src/models/mod.rs`
- `server/src/models/user.rs`

改动类型：`修改 / 删除`

### 12.1 宿主 router 改为 merge `flash_user::router()` `✅`

关键代码骨架：

```rust
pub fn build_router(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    let router = Router::new()
        .route("/v", get(health::version))
        .route("/conversation", get(conversation::conversations))
        .route("/ws", get(ws::websocket_handler))
        .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
        .merge(flash_user::router());

    register_auth_routes(router)
        .layer(axum::Extension(auth_store))
        .with_state(state)
}
```

### 12.2 删除宿主层旧的 profile handler / DTO `✅`

清理点：
- `server/src/routes/user.rs` 旧 `user_profile()` 删除
- `server/src/models/mod.rs` 删除 `pub mod user;`
- `server/src/models/user.rs` 旧 `ProfileResponse` 删除
- `server/src/routes/mod.rs` 不再 `pub mod user;`

说明：
- 宿主只负责组装模块，不再保留一份平行 `/user/profile` 逻辑。

---

## 任务 13：`server/src/lib.rs` — 更新集成测试 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改`

### 13.1 资料响应断言补齐 `signature` / `has_password` / identicon `✅`

关键断言骨架：

```rust
assert_eq!(profile.nickname, "13800138000");
assert_eq!(profile.signature, "");
assert!(!profile.has_password);
assert_eq!(profile.avatar, format!("identicon:{}", login.account_id));
```

### 13.2 密码链路切换到 `/user/password` `✅`

关键请求骨架：

```rust
.uri("/user/password")
.method("POST")
```

```rust
.uri("/user/password")
.method("PUT")
```

### 13.3 新增资料编辑回归用例 `✅`

最少覆盖：
1. `PUT /user/profile` 成功修改 `nickname` + `signature`
2. `PUT /user/profile` 只改 `avatar: "identicon:new-seed"` 不影响其他字段
3. 空昵称 / 超长签名返回 `400`
4. 旧密码错误返回 `401`

说明：
- 继续沿用 `build_test_app()` + `InMemoryStore`，不要把测试改成必须依赖本地 PostgreSQL。

---

## 任务 14：数据库重建、格式化、静态检查、测试验证 `✅ 已完成`

改动类型：`验证`

### 14.1 重建数据库并确认 migration 可执行 `✅`

```bash
scripts/database/reset_sqlx_database.sh
```

### 14.2 Rust 格式检查 `✅`

```bash
cd server
cargo fmt --check
```

### 14.3 Clippy 全量检查 `✅`

```bash
cd server
cargo clippy --all-targets --all-features -- -D warnings
```

### 14.4 集成测试回归 `✅`

```bash
cd server
cargo test
```

建议额外关注：
- `auth_flow_returns_profile_for_valid_token`
- `set_password_rejects_duplicate_setup`
- 新增的 `update_profile_*` / `change_password_*` 用例
