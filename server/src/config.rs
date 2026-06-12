use local_ip_address::local_ip;
use std::{env, error::Error, fmt, time::Duration};

pub const HOST: &str = "0.0.0.0";
pub const PORT: u16 = 9600;
pub const JWT_TTL: Duration = Duration::from_secs(24 * 60 * 60);
const DEFAULT_SMS_CODE_TTL: Duration = Duration::from_secs(5 * 60);
const DEFAULT_JWT_SECRET: &str = "flash-im-playground-secret";

#[derive(Clone)]
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_ttl: Duration,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}

impl AppConfig {
    pub fn from_env() -> Result<Self, ConfigError> {
        let database_url = required_env("DATABASE_URL")?;
        let jwt_secret = env::var("JWT_SECRET").unwrap_or_else(|_| DEFAULT_JWT_SECRET.to_string());
        let jwt_ttl = duration_from_env("JWT_TTL_SECS", JWT_TTL)?;
        let sms_code_ttl = duration_from_env("SMS_CODE_TTL_SECS", DEFAULT_SMS_CODE_TTL)?;
        let expose_debug_sms_code = bool_from_env("EXPOSE_DEBUG_SMS_CODE", true)?;

        Ok(Self {
            database_url,
            jwt_secret,
            jwt_ttl,
            sms_code_ttl,
            expose_debug_sms_code,
        })
    }

    #[cfg(test)]
    pub fn for_tests(jwt_secret: impl Into<String>) -> Self {
        Self {
            database_url: "postgres://unused-for-tests".to_string(),
            jwt_secret: jwt_secret.into(),
            jwt_ttl: JWT_TTL,
            sms_code_ttl: DEFAULT_SMS_CODE_TTL,
            expose_debug_sms_code: true,
        }
    }
}

#[derive(Debug)]
pub struct ConfigError {
    message: String,
}

impl ConfigError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl Error for ConfigError {}

pub fn print_access_urls(port: u16) {
    println!("server started");
    println!("local:   http://127.0.0.1:{port}/v");

    match local_ip() {
        Ok(ip) => println!("network: http://{ip}:{port}/v"),
        Err(error) => println!("network: unable to detect local ip: {error}"),
    }
}

fn required_env(key: &str) -> Result<String, ConfigError> {
    let value = env::var(key).map_err(|_| ConfigError::new(format!("{key} is required")))?;
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(ConfigError::new(format!("{key} is required")));
    }
    Ok(trimmed.to_string())
}

fn duration_from_env(key: &str, default: Duration) -> Result<Duration, ConfigError> {
    match env::var(key) {
        Ok(raw) => {
            let seconds = raw
                .trim()
                .parse::<u64>()
                .map_err(|_| ConfigError::new(format!("{key} must be a positive integer")))?;
            Ok(Duration::from_secs(seconds))
        }
        Err(env::VarError::NotPresent) => Ok(default),
        Err(env::VarError::NotUnicode(_)) => {
            Err(ConfigError::new(format!("{key} must be valid utf-8")))
        }
    }
}

fn bool_from_env(key: &str, default: bool) -> Result<bool, ConfigError> {
    match env::var(key) {
        Ok(raw) => match raw.trim().to_ascii_lowercase().as_str() {
            "1" | "true" | "yes" | "on" => Ok(true),
            "0" | "false" | "no" | "off" => Ok(false),
            _ => Err(ConfigError::new(format!("{key} must be a boolean"))),
        },
        Err(env::VarError::NotPresent) => Ok(default),
        Err(env::VarError::NotUnicode(_)) => {
            Err(ConfigError::new(format!("{key} must be valid utf-8")))
        }
    }
}
