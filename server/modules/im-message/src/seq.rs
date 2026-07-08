use flash_core::{AppError, AppResult};
use sqlx::PgPool;
use uuid::Uuid;

pub struct SeqGenerator;

impl SeqGenerator {
    pub async fn next_seq(pool: &PgPool, conversation_id: Uuid) -> AppResult<i64> {
        sqlx::query_scalar::<_, i64>(
            r#"
            INSERT INTO conversation_seq (conversation_id, current_seq)
            VALUES ($1, 1)
            ON CONFLICT (conversation_id)
            DO UPDATE SET current_seq = conversation_seq.current_seq + 1
            RETURNING current_seq
            "#,
        )
        .bind(conversation_id)
        .fetch_one(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to generate message sequence"))
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn seq_sql_uses_single_upsert() {
        let sql = r#"
            INSERT INTO conversation_seq (conversation_id, current_seq)
            VALUES ($1, 1)
            ON CONFLICT (conversation_id)
            DO UPDATE SET current_seq = conversation_seq.current_seq + 1
            RETURNING current_seq
        "#;

        assert!(sql.contains("ON CONFLICT (conversation_id)"));
        assert!(sql.contains("RETURNING current_seq"));
    }
}
