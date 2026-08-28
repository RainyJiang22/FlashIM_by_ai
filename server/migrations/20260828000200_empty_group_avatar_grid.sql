UPDATE conversations
SET avatar = 'grid:', updated_at = NOW()
WHERE type = 1
  AND (avatar IS NULL OR avatar NOT LIKE 'grid:%');
