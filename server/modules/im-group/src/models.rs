use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupSummaryRow {
    pub id: Uuid,
    pub name: Option<String>,
    pub owner_id: i64,
    pub join_approval_required: bool,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupMemberRow {
    pub account_id: i64,
    pub nickname: Option<String>,
    pub avatar: Option<String>,
    pub joined_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct GroupMember {
    pub account_id: String,
    pub nickname: String,
    pub avatar: String,
    pub is_owner: bool,
    pub joined_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct GroupDetail {
    pub conversation_id: Uuid,
    pub name: String,
    pub owner_id: String,
    pub join_approval_required: bool,
    pub current_user_role: &'static str,
    pub member_count: usize,
    pub members: Vec<GroupMember>,
}

impl GroupDetail {
    pub fn from_rows(
        summary: GroupSummaryRow,
        current_user_id: i64,
        member_rows: Vec<GroupMemberRow>,
    ) -> Self {
        let members = member_rows
            .into_iter()
            .map(|row| GroupMember {
                account_id: row.account_id.to_string(),
                nickname: row
                    .nickname
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or_else(|| format!("用户 {}", row.account_id)),
                avatar: row
                    .avatar
                    .unwrap_or_else(|| format!("identicon:{}", row.account_id)),
                is_owner: row.account_id == summary.owner_id,
                joined_at: row.joined_at,
            })
            .collect::<Vec<_>>();
        let member_count = members.len();
        let current_user_role = if current_user_id == summary.owner_id {
            "owner"
        } else {
            "member"
        };

        Self {
            conversation_id: summary.id,
            name: summary.name.unwrap_or_else(|| "群聊".to_string()),
            owner_id: summary.owner_id.to_string(),
            join_approval_required: summary.join_approval_required,
            current_user_role,
            member_count,
            members,
        }
    }
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupInvitationRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub inviter_id: i64,
    pub invitee_id: i64,
    pub status: i16,
}

#[derive(Clone, Debug, Serialize)]
pub struct GroupInvitationItem {
    pub id: Option<Uuid>,
    pub conversation_id: Uuid,
    pub invitee_id: String,
    pub status: &'static str,
    pub delivered: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct GroupInvitationListResponse {
    pub invitations: Vec<GroupInvitationItem>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct UpdateGroupNameBody {
    pub name: String,
}

#[derive(Clone, Copy, Debug, Deserialize)]
pub struct UpdateGroupSettingsBody {
    pub join_approval_required: bool,
}

#[derive(Clone, Debug, Deserialize)]
pub struct GroupMemberIdsBody {
    pub member_ids: Vec<i64>,
}

#[derive(Clone, Copy, Debug, Serialize)]
pub struct GroupActionResponse {
    pub message: &'static str,
}

#[cfg(test)]
mod tests {
    use chrono::Utc;
    use uuid::Uuid;

    use super::{GroupDetail, GroupMemberRow, GroupSummaryRow};

    #[test]
    fn detail_maps_owner_and_profile_fallbacks() {
        let detail = GroupDetail::from_rows(
            GroupSummaryRow {
                id: Uuid::nil(),
                name: Some("测试群".to_string()),
                owner_id: 1,
                join_approval_required: true,
            },
            1,
            vec![GroupMemberRow {
                account_id: 1,
                nickname: None,
                avatar: None,
                joined_at: Utc::now(),
            }],
        );

        assert_eq!(detail.current_user_role, "owner");
        assert_eq!(detail.members[0].nickname, "用户 1");
        assert!(detail.members[0].is_owner);
    }
}
