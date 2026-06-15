pub mod jwt;
pub mod models;
pub mod password;
pub mod routes;
pub mod services;
pub mod store;

use axum::{Extension, Router};
use flash_core::SharedContext;
use std::sync::Arc;

pub use routes::register_auth_routes;
pub use store::{AuthStore, SharedAuthStore, memory::InMemoryStore, postgres::PostgresAuthStore};

pub fn build_auth_router(store: Arc<dyn AuthStore>) -> Router<SharedContext> {
    register_auth_routes(Router::new()).layer(Extension(store))
}

#[cfg(test)]
mod tests {
    use flash_core::AppContext;

    use crate::{jwt, password};

    #[test]
    fn password_round_trip_succeeds() {
        let hash = password::hash_password("hello-password").expect("hash should succeed");
        let is_valid =
            password::verify_password("hello-password", &hash).expect("verify should succeed");

        assert!(is_valid);
    }

    #[tokio::test]
    async fn jwt_round_trip_succeeds() {
        let context = AppContext::new_for_tests("jwt-secret");
        let token = jwt::sign_token(&context, 10001).expect("sign should succeed");
        let claims = jwt::decode_token(&context, &token).expect("decode should succeed");

        assert_eq!(claims.account_id, 10001);
    }
}
