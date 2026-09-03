# presence_read_receipt - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-09-03T13:26:29`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `WS /ws/im` | `101` | PASS | [01_friend_online.md](01_friend_online.md) |
| 2 | `WS /ws/im` | `101` | PASS | [02_multi_device_offline.md](02_multi_device_offline.md) |
| 3 | `WS /ws/im` | `101` | PASS | [03_read_receipt_ws.md](03_read_receipt_ws.md) |
| 4 | `GET /conversations/{id}/messages` | `200` | PASS | [04_history_read_count.md](04_history_read_count.md) |
| 5 | `GET /conversations/{conversation_id}/messages/{message_id}/read-status` | `200` | PASS | [05_message_read_status.md](05_message_read_status.md) |
| 6 | `GET /conversations/{conversation_id}/messages/{message_id}/read-status` | `403` | PASS | [06_read_status_forbidden.md](06_read_status_forbidden.md) |
| 7 | `GET /conversations/{id}/messages` | `404` | PASS | [07_non_member_history.md](07_non_member_history.md) |
