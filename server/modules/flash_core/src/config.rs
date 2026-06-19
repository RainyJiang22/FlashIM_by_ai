use local_ip_address::local_ip;
use std::{env, error::Error, fmt, time::Duration};

pub const HOST: &str = "0.0.0.0";
pub const PORT: u16 = 9600;
const DEFAULT_JWT_TTL_SECS: u64 = 24 * 60 * 60;
const DEFAULT_SMS_CODE_TTL_SECS: u64 = 5 * 60;

#[derive(Clone, Debug)]
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_ttl: Duration,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}

impl AppConfig {
    pub fn from_env() -> Result<Self, ConfigError> {
        let database_url = read_required_var("DATABASE_URL")?;
        let jwt_secret = read_required_var("JWT_SECRET")?;
        let jwt_ttl = read_duration_secs("JWT_TTL_SECS", DEFAULT_JWT_TTL_SECS)?;
        let sms_code_ttl = read_duration_secs("SMS_CODE_TTL_SECS", DEFAULT_SMS_CODE_TTL_SECS)?;
        let expose_debug_sms_code = read_bool("EXPOSE_DEBUG_SMS_CODE", false)?;

        Ok(Self {
            database_url,
            jwt_secret,
            jwt_ttl,
            sms_code_ttl,
            expose_debug_sms_code,
        })
    }

    pub fn for_tests(jwt_secret: impl Into<String>) -> Self {
        Self {
            database_url: "postgres://127.0.0.1:5432/flash_im_test".to_string(),
            jwt_secret: jwt_secret.into(),
            jwt_ttl: Duration::from_secs(DEFAULT_JWT_TTL_SECS),
            sms_code_ttl: Duration::from_secs(DEFAULT_SMS_CODE_TTL_SECS),
            expose_debug_sms_code: true,
        }
    }
}

pub fn print_access_urls(port: u16) {
    println!("server started:");
    println!("  local:   http://127.0.0.1:{port}/v");

    if let Ok(ip) = local_ip() {
        println!("  network: http://{ip}:{port}/v");
    }
}

#[derive(Debug)]
pub enum ConfigError {
    MissingVar(&'static str),
    InvalidVar {
        name: &'static str,
        message: &'static str,
    },
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingVar(name) => write!(f, "{name} is required"),
            Self::InvalidVar { name, message } => write!(f, "{name} {message}"),
        }
    }
}

impl Error for ConfigError {}

fn read_required_var(name: &'static str) -> Result<String, ConfigError> {
    let value = env::var(name).map_err(|_| ConfigError::MissingVar(name))?;
    let value = value.trim().to_string();
    if value.is_empty() {
        return Err(ConfigError::MissingVar(name));
    }
    Ok(value)
}

fn read_duration_secs(name: &'static str, default_secs: u64) -> Result<Duration, ConfigError> {
    match env::var(name) {
        Ok(value) => {
            let secs = value.parse::<u64>().map_err(|_| ConfigError::InvalidVar {
                name,
                message: "must be a positive integer",
            })?;
            if secs == 0 {
                return Err(ConfigError::InvalidVar {
                    name,
                    message: "must be a positive integer",
                });
            }
            Ok(Duration::from_secs(secs))
        }
        Err(_) => Ok(Duration::from_secs(default_secs)),
    }
}

fn read_bool(name: &'static str, default: bool) -> Result<bool, ConfigError> {
    match env::var(name) {
        Ok(value) => match value.trim().to_ascii_lowercase().as_str() {
            "1" | "true" | "yes" | "on" => Ok(true),
            "0" | "false" | "no" | "off" => Ok(false),
            _ => Err(ConfigError::InvalidVar {
                name,
                message: "must be a boolean",
            }),
        },
        Err(_) => Ok(default),
    }
}
