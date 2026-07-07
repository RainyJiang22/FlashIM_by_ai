CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type SMALLINT NOT NULL DEFAULT 0,
    name VARCHAR(100),
    avatar VARCHAR(500),
    owner_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    last_message_at TIMESTAMPTZ,
    last_message_preview VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversations_type ON conversations(type);
CREATE INDEX idx_conversations_last_message
    ON conversations(last_message_at DESC NULLS LAST);

CREATE TABLE conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    unread_count INT NOT NULL DEFAULT 0,
    last_read_seq BIGINT NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conversation_members_user
    ON conversation_members(user_id);

CREATE TABLE conversation_seq (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    current_seq BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
