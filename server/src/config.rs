use local_ip_address::local_ip;
use std::time::Duration;

pub const HOST: &str = "0.0.0.0";
pub const PORT: u16 = 9600;
pub const JWT_TTL: Duration = Duration::from_secs(24 * 60 * 60);

pub fn print_access_urls(port: u16) {
    println!("server started");
    println!("local:   http://127.0.0.1:{port}/v");

    match local_ip() {
        Ok(ip) => println!("network: http://{ip}:{port}/v"),
        Err(error) => println!("network: unable to detect local ip: {error}"),
    }
}
