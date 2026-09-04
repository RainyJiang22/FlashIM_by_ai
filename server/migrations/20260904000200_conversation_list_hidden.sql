ALTER TABLE conversation_members
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_conversation_members_visible_user
    ON conversation_members(user_id, is_hidden)
    WHERE is_deleted = FALSE;
