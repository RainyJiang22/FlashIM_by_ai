use std::sync::Arc;

use async_trait::async_trait;
use flash_core::{AppResult, SharedContext};
use im_conversation::notification::GroupCreationNotifier;
use im_message::service::MessageService;
use im_ws::broadcaster::WsBroadcaster;
use uuid::Uuid;

#[derive(Clone)]
pub struct GroupCreationMessageNotifier {
    broadcaster: Arc<WsBroadcaster>,
}

impl GroupCreationMessageNotifier {
    pub fn new(broadcaster: Arc<WsBroadcaster>) -> Self {
        Self { broadcaster }
    }
}

#[async_trait]
impl GroupCreationNotifier for GroupCreationMessageNotifier {
    async fn notify_group_created(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        creator_id: i64,
    ) -> AppResult<()> {
        MessageService::new(self.broadcaster.clone())
            .send_group_created(context, conversation_id, creator_id)
            .await
            .map(|_| ())
    }
}
