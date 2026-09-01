ALTER TABLE conversations
ADD COLUMN IF NOT EXISTS announcement TEXT,
ADD COLUMN IF NOT EXISTS announcement_updated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS announcement_updated_by BIGINT REFERENCES accounts(id) ON DELETE SET NULL;

ALTER TABLE conversations
DROP CONSTRAINT IF EXISTS conversations_announcement_length;

ALTER TABLE conversations
ADD CONSTRAINT conversations_announcement_length
CHECK (
    announcement IS NULL
    OR char_length(announcement) BETWEEN 1 AND 2000
);
