use rand::Rng;

use crate::{models::user::UserRecord, state::AppState};

pub(crate) async fn find_or_create_user(state: &AppState, phone: &str) -> UserRecord {
    if let Some(user) = state.store.user_by_phone(phone).await {
        return user;
    }

    state
        .store
        .find_or_create_user(phone, random_avatar_url())
        .await
}

fn random_avatar_url() -> String {
    let mut rng = rand::rng();
    let seed = rng.random::<u64>();
    format!("https://picsum.photos/seed/{seed}/120/120")
}
