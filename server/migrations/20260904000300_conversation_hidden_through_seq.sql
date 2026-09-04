ALTER TABLE conversation_members
ADD COLUMN IF NOT EXISTS hidden_through_seq BIGINT NOT NULL DEFAULT 0;

UPDATE conversation_members member
SET hidden_through_seq = COALESCE(sequence.current_seq, 0)
FROM conversation_seq sequence
WHERE member.conversation_id = sequence.conversation_id
  AND member.is_hidden = TRUE;
