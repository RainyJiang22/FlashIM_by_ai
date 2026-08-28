use async_trait::async_trait;
use flash_core::{AppResult, SharedContext};
use uuid::Uuid;

#[async_trait]
pub trait GroupCreationNotifier: Send + Sync {
    async fn notify_group_created(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        creator_id: i64,
    ) -> AppResult<()>;
}

#[derive(Clone, Default)]
pub struct NoopGroupCreationNotifier;

#[async_trait]
impl GroupCreationNotifier for NoopGroupCreationNotifier {
    async fn notify_group_created(
        &self,
        _context: &SharedContext,
        _conversation_id: Uuid,
        _creator_id: i64,
    ) -> AppResult<()> {
        Ok(())
    }
}
