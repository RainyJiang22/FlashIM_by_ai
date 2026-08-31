CREATE TABLE IF NOT EXISTS group_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    applicant_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    message VARCHAR(200) NOT NULL,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    handled_at TIMESTAMPTZ,
    CHECK (status IN (0, 1, 2))
);

CREATE INDEX IF NOT EXISTS idx_group_join_requests_conversation_status
    ON group_join_requests(conversation_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_group_join_requests_applicant_status
    ON group_join_requests(applicant_id, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_group_join_requests_pending
    ON group_join_requests(conversation_id, applicant_id)
    WHERE status = 0;
