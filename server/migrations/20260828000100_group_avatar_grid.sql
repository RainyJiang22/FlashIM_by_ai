ALTER TABLE conversations
ALTER COLUMN avatar TYPE TEXT;

WITH ranked_member_avatars AS (
    SELECT
        conversation.id AS conversation_id,
        COALESCE(
            NULLIF(BTRIM(profile.avatar_url), ''),
            'identicon:' || member.user_id::TEXT
        ) AS avatar,
        ROW_NUMBER() OVER (
            PARTITION BY conversation.id
            ORDER BY
                (member.user_id = conversation.owner_id) DESC,
                member.joined_at ASC,
                member.user_id ASC
        ) AS position
    FROM conversations conversation
    JOIN conversation_members member
      ON member.conversation_id = conversation.id
     AND member.is_deleted = FALSE
    LEFT JOIN user_profiles profile ON profile.account_id = member.user_id
    WHERE conversation.type = 1
      AND conversation.is_dissolved = FALSE
),
group_avatars AS (
    SELECT
        conversation_id,
        'grid:' || STRING_AGG(avatar, ',' ORDER BY position) AS avatar
    FROM ranked_member_avatars
    WHERE position <= 9
    GROUP BY conversation_id
)
UPDATE conversations conversation
SET avatar = group_avatars.avatar, updated_at = NOW()
FROM group_avatars
WHERE conversation.id = group_avatars.conversation_id;
