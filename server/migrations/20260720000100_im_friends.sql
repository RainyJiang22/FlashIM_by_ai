CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS flash_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_flash_id
    ON user_profiles(flash_id)
    WHERE flash_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_nickname
    ON user_profiles(nickname);

CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    to_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    message VARCHAR(200) NOT NULL DEFAULT '',
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    handled_at TIMESTAMPTZ,
    from_deleted_at TIMESTAMPTZ,
    to_deleted_at TIMESTAMPTZ,
    UNIQUE (from_user_id, to_user_id),
    CHECK (from_user_id <> to_user_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_to_status
    ON friend_requests(to_user_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_friend_requests_from_status
    ON friend_requests(from_user_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS friend_relations (
    user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    friend_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    source_request_id UUID REFERENCES friend_requests(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_user_id),
    CHECK (user_id <> friend_user_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_relations_friend_user
    ON friend_relations(friend_user_id);
