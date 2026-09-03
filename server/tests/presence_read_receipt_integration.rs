use falsh_im::build_app;
use flash_auth::{AuthStore, PostgresAuthStore};
use flash_core::{AppConfig, AppContext, PORT};
use std::{path::Path, sync::Arc};
use tokio::{net::TcpListener, process::Command};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "requires the local PostgreSQL integration environment"]
async fn presence_read_receipt_api_and_websocket_link() {
    let config = AppConfig::from_env().expect("load integration environment");
    let context = Arc::new(
        AppContext::from_config(config)
            .await
            .expect("connect integration dependencies"),
    );
    let auth_store: Arc<dyn AuthStore> = Arc::new(PostgresAuthStore::new(context.postgres.clone()));
    let app = build_app(context.clone(), auth_store);
    let listener = TcpListener::bind(("127.0.0.1", PORT))
        .await
        .expect("bind integration server");
    let server = tokio::spawn(async move { axum::serve(listener, app).await });

    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let script = manifest_dir.join(
        "../docs/features/im/presence/v0.0.1/api/\
         presence_read_receipt/request/presence_read_receipt.py",
    );
    let status = Command::new("python3")
        .arg(script)
        .env("BASE_URL", format!("http://127.0.0.1:{PORT}"))
        .env("WS_URL", format!("ws://127.0.0.1:{PORT}/ws/im"))
        .status()
        .await
        .expect("run presence link script");

    server.abort();
    let _ = server.await;
    assert!(status.success(), "presence link script failed: {status}");

    let latest = sqlx::query_as::<_, (uuid::Uuid, uuid::Uuid, i64)>(
        r#"
        SELECT message.id, message.conversation_id, message.sender_id
        FROM messages message
        WHERE message.content LIKE '已读链路 %'
        ORDER BY message.created_at DESC
        LIMIT 1
        "#,
    )
    .fetch_one(context.postgres.pool())
    .await
    .expect("load latest receipt message");
    sqlx::query("UPDATE conversations SET is_dissolved = TRUE WHERE id = $1")
        .bind(latest.1)
        .execute(context.postgres.pool())
        .await
        .expect("temporarily dissolve conversation");
    let dissolved_result = im_message::repository::find_message_for_read_status(
        context.postgres.pool(),
        latest.1,
        latest.0,
        latest.2,
    )
    .await;
    sqlx::query("UPDATE conversations SET is_dissolved = FALSE WHERE id = $1")
        .bind(latest.1)
        .execute(context.postgres.pool())
        .await
        .expect("restore conversation state");

    assert!(
        dissolved_result
            .expect("query dissolved conversation read status")
            .is_some(),
        "history reader should retain read-status access after dissolution"
    );
}
