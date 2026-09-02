use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use im_conversation::ConversationListItem;

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupSummaryRow {
    pub id: Uuid,
    pub name: Option<String>,
    pub avatar: Option<String>,
    pub owner_id: i64,
    pub join_approval_required: bool,
    pub announcement: Option<String>,
    pub announcement_updated_at: Option<DateTime<Utc>>,
    pub announcement_updated_by: Option<i64>,
    pub is_dissolved: bool,
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
    pub avatar: String,
    pub owner_id: String,
    pub join_approval_required: bool,
    pub announcement: String,
    pub announcement_updated_at: Option<DateTime<Utc>>,
    pub announcement_updated_by: Option<String>,
    pub announcement_updated_by_name: String,
    pub is_dissolved: bool,
    pub current_user_role: &'static str,
    pub current_user_nickname: String,
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
        let current_user_nickname = members
            .iter()
            .find(|member| member.account_id == current_user_id.to_string())
            .map(|member| member.nickname.clone())
            .unwrap_or_else(|| format!("用户 {current_user_id}"));
        let announcement_updated_by_name = summary
            .announcement_updated_by
            .and_then(|updated_by| {
                members
                    .iter()
                    .find(|member| member.account_id == updated_by.to_string())
                    .map(|member| member.nickname.clone())
                    .or_else(|| Some(format!("用户 {updated_by}")))
            })
            .unwrap_or_default();

        Self {
            conversation_id: summary.id,
            name: summary.name.unwrap_or_else(|| "群聊".to_string()),
            avatar: summary.avatar.unwrap_or_else(|| {
                format!(
                    "grid:{}",
                    members
                        .iter()
                        .take(9)
                        .map(|member| member.avatar.as_str())
                        .collect::<Vec<_>>()
                        .join(",")
                )
            }),
            owner_id: summary.owner_id.to_string(),
            join_approval_required: summary.join_approval_required,
            announcement: summary.announcement.unwrap_or_default(),
            announcement_updated_at: summary.announcement_updated_at,
            announcement_updated_by: summary.announcement_updated_by.map(|id| id.to_string()),
            announcement_updated_by_name,
            is_dissolved: summary.is_dissolved,
            current_user_role,
            current_user_nickname,
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

#[derive(Clone, Debug, Deserialize)]
pub struct UpdateGroupAnnouncementBody {
    pub announcement: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct UpdateGroupNicknameBody {
    pub nickname: String,
}

#[derive(Clone, Copy, Debug, Deserialize)]
pub struct TransferGroupOwnerBody {
    pub owner_id: i64,
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

#[derive(Clone, Debug, Deserialize)]
pub struct GroupSearchQuery {
    pub keyword: String,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupSearchRow {
    pub conversation_id: Uuid,
    pub name: Option<String>,
    pub avatar: Option<String>,
    pub member_count: i64,
    pub join_approval_required: bool,
    pub is_member: bool,
    pub has_pending_request: bool,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct GroupSearchItem {
    pub conversation_id: Uuid,
    pub group_number: String,
    pub name: String,
    pub avatar: String,
    pub member_count: i64,
    pub join_approval_required: bool,
    pub is_member: bool,
    pub has_pending_request: bool,
}

impl From<GroupSearchRow> for GroupSearchItem {
    fn from(row: GroupSearchRow) -> Self {
        Self {
            conversation_id: row.conversation_id,
            group_number: row.conversation_id.to_string(),
            name: row.name.unwrap_or_else(|| "群聊".to_string()),
            avatar: row.avatar.unwrap_or_default(),
            member_count: row.member_count,
            join_approval_required: row.join_approval_required,
            is_member: row.is_member,
            has_pending_request: row.has_pending_request,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct GroupSearchResponse {
    pub groups: Vec<GroupSearchItem>,
}

#[derive(Clone, Debug, Default, Deserialize)]
pub struct JoinGroupBody {
    pub message: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct JoinGroupResponse {
    pub auto_approved: bool,
    pub request_id: Option<Uuid>,
    pub conversation: Option<ConversationListItem>,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct GroupJoinRequestRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub owner_id: i64,
    pub group_name: Option<String>,
    pub group_avatar: Option<String>,
    pub applicant_id: i64,
    pub applicant_name: Option<String>,
    pub applicant_avatar: Option<String>,
    pub message: String,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub handled_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct GroupJoinRequestItem {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub group_name: String,
    pub group_avatar: String,
    pub applicant_id: String,
    pub applicant_name: String,
    pub applicant_avatar: String,
    pub message: String,
    pub status: &'static str,
    pub created_at: DateTime<Utc>,
    pub handled_at: Option<DateTime<Utc>>,
}

impl GroupJoinRequestItem {
    pub fn from_row(row: &GroupJoinRequestRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            group_name: row.group_name.clone().unwrap_or_else(|| "群聊".to_string()),
            group_avatar: row.group_avatar.clone().unwrap_or_default(),
            applicant_id: row.applicant_id.to_string(),
            applicant_name: row
                .applicant_name
                .clone()
                .filter(|value| !value.trim().is_empty())
                .unwrap_or_else(|| format!("用户 {}", row.applicant_id)),
            applicant_avatar: row
                .applicant_avatar
                .clone()
                .filter(|value| !value.trim().is_empty())
                .unwrap_or_else(|| format!("identicon:{}", row.applicant_id)),
            message: row.message.clone(),
            status: match row.status {
                1 => "approved",
                2 => "rejected",
                _ => "pending",
            },
            created_at: row.created_at,
            handled_at: row.handled_at,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct GroupJoinRequestListResponse {
    pub pending_count: usize,
    pub requests: Vec<GroupJoinRequestItem>,
}

#[derive(Clone, Copy, Debug, Deserialize)]
pub struct HandleJoinRequestBody {
    pub approved: bool,
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
                avatar: Some("grid:identicon:1".to_string()),
                owner_id: 1,
                join_approval_required: true,
                announcement: Some("欢迎加入".to_string()),
                announcement_updated_at: None,
                announcement_updated_by: Some(1),
                is_dissolved: false,
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
        assert_eq!(detail.avatar, "grid:identicon:1");
        assert_eq!(detail.members[0].nickname, "用户 1");
        assert!(detail.members[0].is_owner);
        assert_eq!(detail.announcement, "欢迎加入");
        assert_eq!(detail.announcement_updated_by_name, "用户 1");
    }
}
