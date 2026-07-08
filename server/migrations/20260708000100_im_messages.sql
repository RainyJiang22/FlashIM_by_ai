CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    seq BIGINT NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    content TEXT NOT NULL,
    extra JSONB,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (conversation_id, seq)
);

CREATE TABLE IF NOT EXISTS conversation_seq (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    current_seq BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_messages_conversation_seq
    ON messages(conversation_id, seq DESC);

CREATE INDEX idx_messages_conversation_created
    ON messages(conversation_id, created_at DESC);
