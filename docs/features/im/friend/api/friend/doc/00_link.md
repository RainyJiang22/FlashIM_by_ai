# friend - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-07-20T17:39:56`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `GET /api/users/search?q=<phone>` | `200` | PASS | [01_search_user.md](01_search_user.md) |
| 2 | `GET /api/users/{account_id}` | `200` | PASS | [02_public_user.md](02_public_user.md) |
| 3 | `POST /api/friends/requests` | `200` | PASS | [03_send_request.md](03_send_request.md) |
| 4 | `GET /api/friends/requests/received` | `200` | PASS | [04_received_requests.md](04_received_requests.md) |
| 5 | `POST /api/friends/requests/{id}/accept` | `200` | PASS | [05_accept_request.md](05_accept_request.md) |
| 6 | `GET /api/friends` | `200` | PASS | [06_list_friends.md](06_list_friends.md) |
| 7 | `DELETE /api/friends/{friend_user_id}` | `200` | PASS | [07_remove_friend.md](07_remove_friend.md) |
| 8 | `POST /api/friends/requests/{id}/accept` | `409` | PASS | [08_accept_again_conflict.md](08_accept_again_conflict.md) |
