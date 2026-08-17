ALTER TABLE conversations
ADD COLUMN IF NOT EXISTS join_approval_required BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_dissolved BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS dissolved_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS group_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    inviter_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    invitee_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    handled_at TIMESTAMPTZ,
    CHECK (inviter_id <> invitee_id),
    CHECK (status IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_status
    ON group_invitations(invitee_id, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_group_invitations_pending
    ON group_invitations(conversation_id, invitee_id)
    WHERE status = 0;
