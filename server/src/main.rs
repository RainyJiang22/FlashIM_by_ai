use axum::{Json, Router, routing::get};
use local_ip_address::local_ip;
use serde::Serialize;
use std::net::SocketAddr;
use tokio::net::TcpListener;

const HOST: &str = "0.0.0.0";
const PORT: u16 = 9600;

#[derive(Serialize)]
struct VersionResponse {
    name: &'static str,
    version: &'static str,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let app = Router::new().route("/v", get(version));
    let addr: SocketAddr = format!("{HOST}:{PORT}").parse()?;
    let listener = TcpListener::bind(addr).await?;

    print_access_urls(PORT);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn version() -> Json<VersionResponse> {
    Json(VersionResponse {
        name: env!("CARGO_PKG_NAME"),
        version: env!("CARGO_PKG_VERSION"),
    })
}

fn print_access_urls(port: u16) {
    println!("server started");
    println!("local:   http://127.0.0.1:{port}/v");

    match local_ip() {
        Ok(ip) => println!("network: http://{ip}:{port}/v"),
        Err(error) => println!("network: unable to detect local ip: {error}"),
    }
}
