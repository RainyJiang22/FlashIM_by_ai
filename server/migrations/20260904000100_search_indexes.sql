CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_user_profiles_nickname_trgm
    ON user_profiles USING GIN (nickname gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_conversations_name_trgm
    ON conversations USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_messages_content_search_trgm
    ON messages USING GIN (content gin_trgm_ops)
    WHERE type <> 5;
