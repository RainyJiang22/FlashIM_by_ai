use crate::models::user::UserRecord;

#[derive(Clone)]
pub struct PasswordAccountRecord {
    pub account: String,
    pub password: String,
    pub user_id: u64,
}

pub fn seeded_password_accounts() -> Vec<(PasswordAccountRecord, UserRecord)> {
    vec![
        seeded_account(
            1001,
            "rainy",
            "rainy123",
            "Rainy",
            "13800138001",
            "https://picsum.photos/seed/rainy/120/120",
        ),
        seeded_account(
            1002,
            "alice",
            "alice123",
            "Alice",
            "13800138002",
            "https://picsum.photos/seed/alice/120/120",
        ),
        seeded_account(
            1003,
            "bob",
            "bob123",
            "Bob",
            "13800138003",
            "https://picsum.photos/seed/bob/120/120",
        ),
    ]
}

fn seeded_account(
    user_id: u64,
    account: &str,
    password: &str,
    nickname: &str,
    phone: &str,
    avatar: &str,
) -> (PasswordAccountRecord, UserRecord) {
    (
        PasswordAccountRecord {
            account: account.to_string(),
            password: password.to_string(),
            user_id,
        },
        UserRecord {
            user_id,
            nickname: nickname.to_string(),
            avatar: avatar.to_string(),
            phone: phone.to_string(),
        },
    )
}
