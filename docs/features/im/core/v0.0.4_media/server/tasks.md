# IM Core v0.0.4_media — 服务端任务清单

基于 `docs/features/im/core/v0.0.4_media/server/design.md` 设计，拆出可直接执行的服务端实现清单。

全局约束：

- 只做图片、视频、文件三类富媒体消息；不实现语音、云存储、断点续传、删除接口。
- 延续正式 IM 主链路：上传接口独立于消息发送；消息写库后再广播；历史查询继续走 `GET /conversations/{id}/messages`。
- 本版 **不新增 `messages` 表迁移**；继续复用现有 `type` 与 `extra JSONB` 字段。
- 设计里上传接口描述与“暂不实现上传鉴权”存在冲突；按更强的范围约束执行：**本版不加上传鉴权中间件**。
- 上传模块独立为 `app-storage` crate，不依赖 `im-message` 或 `im-ws`。
- 保持 playground 路径与正式路径分离；所有新能力挂到正式服务，不动 `/conversation` 和 `/chat_room/ws` demo 逻辑。
- 参考现有正式链路：
  - `server/modules/im-message/src/models.rs`
  - `server/modules/im-message/src/repository.rs`
  - `server/modules/im-message/src/service.rs`
  - `server/modules/im-ws/src/dispatcher.rs`
  - `server/modules/im-ws/src/broadcaster.rs`
  - `server/src/routes/mod.rs`

---

## 执行顺序

1. ✅ 任务 1 — 更新 workspace 和根依赖（无依赖）
2. ✅ 任务 2 — 新建 `app-storage/Cargo.toml`（依赖任务 1）
3. ✅ 任务 3 — 新建 `app-storage/src/lib.rs`（依赖任务 2）
4. ✅ 任务 4 — 新建 `app-storage/src/image.rs`（依赖任务 2）
5. ✅ 任务 5 — 新建 `app-storage/src/service.rs`（依赖任务 3、4）
6. ✅ 任务 6 — 新建 `app-storage/src/api.rs`（依赖任务 5）
7. ✅ 任务 7 — 扩展 `proto/message.proto` 消息类型（依赖任务 1）
8. ✅ 任务 8 — 扩展 `im-message/models.rs`（依赖任务 7）
9. ✅ 任务 9 — 扩展 `im-message/repository.rs`（依赖任务 8）
10. ✅ 任务 10 — 扩展 `im-message/service.rs` 预览与富媒体校验（依赖任务 8、9）
11. ✅ 任务 11 — 改造 `im-ws/dispatcher.rs` 传递 type/extra（依赖任务 7、10）
12. ✅ 任务 12 — 改造 `im-ws/broadcaster.rs` 透传 extra（依赖任务 7、10）
13. ✅ 任务 13 — 挂载上传路由与 `/uploads` 静态目录（依赖任务 6）
14. ✅ 任务 14 — 服务端测试补齐（依赖任务 5、6、10、11、12、13）
15. ✅ 最后 — 编译验证 + curl / ws 验证路径

---

## 任务 1：`server/Cargo.toml` — 增加 workspace member 与依赖 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/Cargo.toml`

改动类型：配置修改

### 1.1 在 workspace members 中加入 `modules/app-storage` `✅`

```toml
members = [
    ".",
    "modules/flash_core",
    "modules/flash_auth",
    "modules/flash_user",
    "modules/im-ws",
    "modules/im-conversation",
    "modules/im-message",
    "modules/app-storage",
]
```

### 1.2 在根包依赖中加入 `app-storage` 与 `tower-http` `✅`

```toml
app-storage = { path = "modules/app-storage" }
tower-http = { version = "0.6", features = ["fs"] }
```

说明：

- `tower-http` 目前仅在 workspace 其他位置间接使用；根服务需要显式依赖以挂载 `/uploads`。

---

## 任务 2：`server/modules/app-storage/Cargo.toml` — 新建上传模块 crate `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/app-storage/Cargo.toml`

改动类型：新建文件

### 2.1 创建 crate 基础依赖 `✅`

骨架：

```toml
[package]
name = "app-storage"
version = "0.1.0"
edition = "2024"
publish = false

[dependencies]
axum = { version = "0.8.9", features = ["multipart"] }
chrono = { version = "0.4.42", features = ["serde"] }
flash_core = { path = "../flash_core" }
image = "0.25"
serde = { version = "1.0.228", features = ["derive"] }
thiserror = "2"
tokio = { version = "1.52.3", features = ["fs", "io-util"] }
uuid = { version = "1", features = ["v4", "serde"] }
```

说明：

- 先不接入对象存储 SDK。

---

## 任务 3：`server/modules/app-storage/src/lib.rs` — 定义模块入口与公共类型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/app-storage/src/lib.rs`

改动类型：新建文件

### 3.1 暴露模块与公共导出 `✅`

骨架：

```rust
pub mod api;
pub mod image;
pub mod service;

pub use api::router;
pub use service::{
    AppStorageService,
    FileUploadResponse,
    ImageUploadResponse,
    StorageError,
    VideoUploadResponse,
};
```

---

## 任务 4：`server/modules/app-storage/src/image.rs` — 图片处理辅助 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/app-storage/src/image.rs`

改动类型：新建文件

### 4.1 定义图片处理返回结构 `✅`

```rust
pub struct ProcessedImage {
    pub width: u32,
    pub height: u32,
    pub thumb_webp: Vec<u8>,
}
```

### 4.2 提供缩略图生成函数 `✅`

签名骨架：

```rust
pub fn process_image(bytes: &[u8]) -> Result<ProcessedImage, image::ImageError> {
    // 1. decode
    // 2. read width / height
    // 3. resize within 200x200
    // 4. encode webp
}
```

说明：

- 缩略图规则与设计保持一致：webp、最大边 200。

---

## 任务 5：`server/modules/app-storage/src/service.rs` — 文件存储核心逻辑 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/app-storage/src/service.rs`

改动类型：新建文件

### 5.1 定义响应模型与错误类型 `✅`

```rust
#[derive(Debug, Serialize)]
pub struct ImageUploadResponse { ... }

#[derive(Debug, Serialize)]
pub struct VideoUploadResponse { ... }

#[derive(Debug, Serialize)]
pub struct FileUploadResponse { ... }

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("missing file")]
    MissingFile,
    #[error("unsupported format")]
    UnsupportedFormat,
    #[error("file too large")]
    FileTooLarge,
    #[error("io error")]
    Io(#[from] std::io::Error),
}
```

### 5.2 定义 `AppStorageService` 与上传方法 `✅`

```rust
#[derive(Clone)]
pub struct AppStorageService {
    root: PathBuf,
}

impl AppStorageService {
    pub fn new(root: impl Into<PathBuf>) -> Self { ... }

    pub async fn upload_image(&self, bytes: Vec<u8>, filename: &str) -> Result<ImageUploadResponse, StorageError>;
    pub async fn upload_video(&self, video: Vec<u8>, video_name: &str, thumb: Vec<u8>, duration_ms: i64, width: u32, height: u32) -> Result<VideoUploadResponse, StorageError>;
    pub async fn upload_file(&self, bytes: Vec<u8>, filename: &str) -> Result<FileUploadResponse, StorageError>;
}
```

### 5.3 统一路径生成规则 `✅`

保留函数骨架：

```rust
fn dated_path(kind: &str, ext: &str, now: DateTime<Utc>) -> PathBuf { ... }
fn public_url(path: &Path) -> String { ... } // "/uploads/..."
```

说明：

- 路径规则必须与 design 一致：`uploads/{type}/{yyyy}/{mm}/{uuid}.{ext}`。

---

## 任务 6：`server/modules/app-storage/src/api.rs` — 暴露上传 HTTP 路由 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/app-storage/src/api.rs`

改动类型：新建文件

### 6.1 定义 router 与 3 个 handler `✅`

骨架：

```rust
pub fn router() -> Router<SharedContext> {
    Router::new()
        .route("/api/upload/image", post(upload_image))
        .route("/api/upload/video", post(upload_video))
        .route("/api/upload/file", post(upload_file))
}
```

### 6.2 处理 multipart 解析与大小/格式校验 `✅`

签名骨架：

```rust
async fn upload_image(
    State(context): State<SharedContext>,
    mut multipart: Multipart,
) -> AppResult<impl IntoResponse> { ... }
```

关键步骤：

1. 读取字段
2. 校验是否缺失
3. 校验扩展名 / MIME / 大小
4. 调 `AppStorageService`
5. 把 `StorageError` 映射到 `400/500`

说明：

- 本版不要加 Bearer Token 校验。

---

## 任务 7：`proto/message.proto` — 扩展消息类型枚举 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/proto/message.proto`

改动类型：修改文件

### 7.1 补充 `MessageType` 枚举值 `✅`

如果当前 proto 尚未定义完整枚举，则补成：

```proto
enum MessageType {
  TEXT = 0;
  IMAGE = 1;
  VIDEO = 2;
  FILE = 3;
}
```

### 7.2 确认 `ChatMessage` / `SendMessageRequest` 继续保留 `type` 和 `extra` `✅`

不新增新帧，不改字段编号。

---

## 任务 8：`server/modules/im-message/src/models.rs` — 扩展消息模型字段 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-message/src/models.rs`

改动类型：修改文件

### 8.1 扩展 `NewMessage` 与相关响应结构 `✅`

补字段：

```rust
pub struct NewMessage {
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
}
```

### 8.2 确认历史返回结构带上 `msg_type` 与 `extra` `✅`

如果现有 `MessageWithSender` 已有相关字段，只需保持命名和序列化不变。

---

## 任务 9：`server/modules/im-message/src/repository.rs` — 写入并读取 type/extra `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-message/src/repository.rs`

改动类型：修改文件

### 9.1 修改 INSERT SQL，显式写入 `type` 和 `extra` `✅`

目标 SQL：

```rust
INSERT INTO messages (conversation_id, sender_id, seq, type, content, extra)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, conversation_id, sender_id, seq, type, content, extra, status, created_at
```

### 9.2 确认历史查询 SELECT 保持 `m.type` 与 `m.extra` `✅`

如果字段已在 `find_before_sql()` 中返回，只需补测试覆盖，避免回归。

---

## 任务 10：`server/modules/im-message/src/service.rs` — 富媒体消息校验与 preview 生成 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-message/src/service.rs`

改动类型：修改文件

### 10.1 放开消息类型校验 `✅`

当前只接受 `msg_type == 0`。改成允许：

```rust
match input.msg_type {
    0 | 1 | 2 | 3 => {}
    _ => return Err(AppError::bad_request("unsupported message type")),
}
```

### 10.2 增加 `extra` 结构校验 `✅`

按类型拆函数骨架：

```rust
fn validate_image_extra(extra: &Option<Value>) -> AppResult<()>;
fn validate_video_extra(extra: &Option<Value>) -> AppResult<()>;
fn validate_file_extra(extra: &Option<Value>) -> AppResult<()>;
```

至少检查：

- 图片：`width / height / thumbnail_url`
- 视频：`thumbnail_url / duration_ms`
- 文件：`file_name / file_url / file_type`

### 10.3 新增 `generate_preview` 逻辑 `✅`

骨架：

```rust
fn build_preview(msg_type: i16, content: &str) -> String {
    match msg_type {
        1 => "[图片]".to_string(),
        2 => "[视频]".to_string(),
        3 => "[文件]".to_string(),
        _ => content.chars().take(100).collect(),
    }
}
```

并更新 `send(...)` 中调用点。

### 10.4 保持文本链路不回归 `✅`

文字消息仍按当前逻辑工作；不要为富媒体改动 seq、ACK、未读聚合流程。

---

## 任务 11：`server/modules/im-ws/src/dispatcher.rs` — 传递媒体 type/extra `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-ws/src/dispatcher.rs`

改动类型：修改文件

### 11.1 从 `SendMessageRequest` 读取 `type` 与 `extra` `✅`

现有骨架上补：

```rust
let extra = parse_extra(request.extra.trim())?;

SendMessageInput {
    conversation_id,
    sender_id: account_id,
    msg_type: request.r#type as i16,
    content: request.content,
    extra,
}
```

### 11.2 保持 `parse_extra` 容错规则 `✅`

- 空字符串 -> `None`
- 非法 JSON -> `bad_request("invalid message extra")`

---

## 任务 12：`server/modules/im-ws/src/broadcaster.rs` — 广播时透传 extra `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-ws/src/broadcaster.rs`

改动类型：修改文件

### 12.1 在 `ChatMessage` 中透传类型与 extra `✅`

构造骨架要确保：

```rust
ChatMessage {
    id: ...,
    conversation_id: ...,
    sender_id: ...,
    seq: ...,
    r#type: message.msg_type as i32,
    content: message.content.clone(),
    extra: message
        .extra
        .as_ref()
        .map(|value| value.to_string())
        .unwrap_or_default(),
    status: ...,
    created_at: ...,
    sender_name: ...,
    sender_avatar: ...,
}
```

说明：

- 不再写死 `extra = ""` 或空字节。

---

## 任务 13：正式路由挂载上传接口与 `/uploads` 静态目录 `✅ 已完成`

文件：

- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/mod.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs`

改动类型：修改文件

### 13.1 在 `routes/mod.rs` merge 上传 router `✅`

```rust
use app_storage::router as build_storage_router;

let router = Router::new()
    .route("/v", get(health::version))
    ...
    .merge(build_storage_router());
```

### 13.2 在 `build_app(...)` 或同层挂 `/uploads` 静态服务 `✅`

骨架：

```rust
use tower_http::services::ServeDir;

build_router(state, auth_store).nest_service(
    "/uploads",
    ServeDir::new("uploads"),
)
```

说明：

- 继续保留现有正式业务 router 结构，不把上传逻辑塞到 playground 路由中。

---

## 任务 14：服务端测试补齐 `✅ 已完成`

文件：

- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-message/src/repository.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-message/src/service.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-ws/src/dispatcher.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/modules/im-ws/src/broadcaster.rs`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs`

改动类型：修改文件

### 14.1 `repository.rs` — 覆盖 SQL 字段写入 `✅`

至少补：

- INSERT SQL 包含 `type` 与 `extra`
- 历史查询 SQL 继续包含 `m.type`、`m.extra`

### 14.2 `service.rs` — 覆盖 preview 与类型校验 `✅`

至少补：

- 文本 preview
- 图片 / 视频 / 文件 preview
- 非法类型拒绝
- 缺失 `extra` 关键字段拒绝

### 14.3 `dispatcher.rs` / `broadcaster.rs` — 覆盖 type/extra 透传 `✅`

至少补：

- `parse_extra("") -> None`
- 合法 JSON 透传到 `SendMessageInput`
- 广播 `ChatMessage.extra` 非空时保持原值

### 14.4 `server/src/lib.rs` — 增加上传路由集成测试 `✅`

至少补：

- `POST /api/upload/image`
- `POST /api/upload/video`
- `POST /api/upload/file`
- `GET /uploads/...` 可访问

---

## 最后：编译验证 + curl / ws 验证路径 `✅ 已完成`

按顺序执行：

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/server
cargo fmt --check
cargo build
cargo test
```

重点验证命令：

```bash
curl -F "file=@/path/to/test.jpg" http://127.0.0.1:9600/api/upload/image
curl -F "video=@/path/to/test.mp4" -F "thumbnail=@/path/to/thumb.jpg" -F "duration_ms=5000" http://127.0.0.1:9600/api/upload/video
curl -F "file=@/path/to/test.pdf" http://127.0.0.1:9600/api/upload/file
```

媒体消息链路验证：

1. 上传图片 / 视频 / 文件，拿到返回 URL
2. 用客户端或 Python 脚本发送 `type=1/2/3` 的 `CHAT_MESSAGE`
3. 确认 `messages.type`、`messages.extra` 正确入库
4. 确认 `conversations.last_message_preview` 变成 `[图片] / [视频] / [文件]`
5. 确认接收方 WS 收到正确的 `type + extra`
6. 调 `GET /conversations/{id}/messages`，确认历史消息返回 `msg_type + extra`
