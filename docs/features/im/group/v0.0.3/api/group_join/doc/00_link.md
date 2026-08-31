# group_join - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-08-31T11:15:15`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `GET /groups/search?keyword={keyword}` | `200` | PASS | [01_search_by_name.md](01_search_by_name.md) |
| 2 | `GET /groups/search?keyword={uuid}` | `200` | PASS | [02_search_by_number.md](02_search_by_number.md) |
| 3 | `GET /groups/search?keyword=` | `400` | PASS | [03_search_invalid.md](03_search_invalid.md) |
| 4 | `POST /groups/{id}/join` | `200` | PASS | [04_direct_join.md](04_direct_join.md) |
| 5 | `POST /groups/{id}/join` | `400` | PASS | [05_join_existing_member.md](05_join_existing_member.md) |
| 6 | `POST /groups/{id}/join` | `200` | PASS | [06_create_join_request.md](06_create_join_request.md) |
| 7 | `WS /ws/im` | `101` | PASS | [07_owner_pending_ws.md](07_owner_pending_ws.md) |
| 8 | `POST /groups/{id}/join` | `409` | PASS | [08_duplicate_request.md](08_duplicate_request.md) |
| 9 | `GET /groups/join-requests` | `200` | PASS | [09_list_join_requests.md](09_list_join_requests.md) |
| 10 | `POST /groups/{id}/join-requests/{rid}/handle` | `403` | PASS | [10_handle_forbidden.md](10_handle_forbidden.md) |
| 11 | `POST /groups/{id}/join-requests/{rid}/handle` | `200` | PASS | [11_approve_request.md](11_approve_request.md) |
| 12 | `WS /ws/im` | `101` | PASS | [12_applicant_approved_ws.md](12_applicant_approved_ws.md) |
| 13 | `POST /groups/{id}/join-requests/{rid}/handle` | `400` | PASS | [13_handle_again.md](13_handle_again.md) |
| 14 | `POST /groups/{id}/join` | `400` | PASS | [14_join_message_too_long.md](14_join_message_too_long.md) |
| 15 | `POST /groups/{id}/join` | `404` | PASS | [15_join_missing_group.md](15_join_missing_group.md) |
