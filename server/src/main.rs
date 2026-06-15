use falsh_im::build_app;
use flash_auth::{AuthStore, PostgresAuthStore};
use flash_core::{AppConfig, AppContext, HOST, PORT, print_access_urls};
use std::{net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = AppConfig::from_env()?;
    let context = Arc::new(AppContext::from_config(config).await?);
    let auth_store: Arc<dyn AuthStore> = Arc::new(PostgresAuthStore::new(context.postgres.clone()));
    let app = build_app(context, auth_store);
    let addr: SocketAddr = format!("{HOST}:{PORT}").parse()?;
    let listener = TcpListener::bind(addr).await?;

    print_access_urls(PORT);

    axum::serve(listener, app).await?;
    Ok(())
}
