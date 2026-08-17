# group - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-08-16T20:08:56`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `POST /conversations` | `401` | PASS | [01_create_unauthorized.md](01_create_unauthorized.md) |
| 2 | `POST /conversations` | `200` | PASS | [02_create_group.md](02_create_group.md) |
| 3 | `GET /conversations?type=1&limit=100&offset=0` | `200` | PASS | [03_list_groups.md](03_list_groups.md) |
| 4 | `GET /conversations/{id}` | `200` | PASS | [04_group_detail.md](04_group_detail.md) |
| 5 | `POST /conversations` | `400` | PASS | [05_too_few_members.md](05_too_few_members.md) |
| 6 | `POST /conversations` | `400` | PASS | [06_duplicate_members.md](06_duplicate_members.md) |
| 7 | `POST /conversations` | `400` | PASS | [07_owner_in_members.md](07_owner_in_members.md) |
| 8 | `POST /conversations` | `400` | PASS | [08_non_friend_member.md](08_non_friend_member.md) |
| 9 | `GET /conversations?type=2` | `400` | PASS | [09_invalid_type_filter.md](09_invalid_type_filter.md) |
| 10 | `GET /conversations/{id}` | `404` | PASS | [10_non_member_detail.md](10_non_member_detail.md) |
| 11 | `WS /ws/im` | `101` | PASS | [11_group_message_ws.md](11_group_message_ws.md) |
| 12 | `GET /conversations/{id}/messages?before_seq=999999&limit=10` | `200` | PASS | [12_group_message_history.md](12_group_message_history.md) |
