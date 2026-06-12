use falsh_im::{
    build_app,
    config::{AppConfig, HOST, PORT, print_access_urls},
    state::AppState,
};
use std::{net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = AppConfig::from_env()?;
    let state = Arc::new(AppState::from_config(config).await?);
    let app = build_app(state);
    let addr: SocketAddr = format!("{HOST}:{PORT}").parse()?;
    let listener = TcpListener::bind(addr).await?;

    print_access_urls(PORT);

    axum::serve(listener, app).await?;
    Ok(())
}
