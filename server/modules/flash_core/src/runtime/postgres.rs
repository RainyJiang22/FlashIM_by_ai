use sqlx::{PgPool, postgres::PgPoolOptions};
use std::{path::PathBuf, time::Duration};

#[derive(Clone)]
pub struct PostgresRuntime {
    pool: PgPool,
}

impl PostgresRuntime {
    pub async fn connect(database_url: &str) -> Result<Self, sqlx::Error> {
        let pool = PgPoolOptions::new()
            .acquire_timeout(Duration::from_secs(10))
            .connect(database_url)
            .await?;
        Ok(Self { pool })
    }

    pub fn new_lazy(database_url: &str) -> Result<Self, sqlx::Error> {
        let pool = PgPoolOptions::new().connect_lazy(database_url)?;
        Ok(Self { pool })
    }

    pub async fn run_migrations(&self) -> Result<(), sqlx::migrate::MigrateError> {
        let path = migrations_dir();
        let migrator = sqlx::migrate::Migrator::new(path.as_path()).await?;
        migrator.run(&self.pool).await
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
}

fn migrations_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../migrations")
}
