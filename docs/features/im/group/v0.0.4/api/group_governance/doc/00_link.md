# group_governance - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-09-01T10:15:25`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `GET /groups/{id}` | `200` | PASS | [01_group_detail.md](01_group_detail.md) |
| 2 | `PATCH /groups/{id}/announcement` | `200` | PASS | [02_update_announcement.md](02_update_announcement.md) |
| 3 | `WS /ws/im` | `101` | PASS | [03_announcement_ws.md](03_announcement_ws.md) |
| 4 | `PATCH /groups/{id}/announcement` | `400` | PASS | [04_invalid_announcement.md](04_invalid_announcement.md) |
| 5 | `PATCH /groups/{id}/name` | `200` | PASS | [05_update_name.md](05_update_name.md) |
| 6 | `POST /groups/{id}/members` | `200` | PASS | [06_add_member.md](06_add_member.md) |
| 7 | `PATCH /groups/{id}/owner` | `200` | PASS | [07_transfer_owner.md](07_transfer_owner.md) |
| 8 | `PATCH /groups/{id}/announcement` | `403` | PASS | [08_former_owner_forbidden.md](08_former_owner_forbidden.md) |
| 9 | `PATCH /groups/{id}/owner` | `200` | PASS | [09_transfer_owner_back.md](09_transfer_owner_back.md) |
| 10 | `POST /groups/{id}/leave` | `200` | PASS | [10_leave_group.md](10_leave_group.md) |
| 11 | `POST /groups/{id}/leave` | `400` | PASS | [11_owner_leave_forbidden.md](11_owner_leave_forbidden.md) |
| 12 | `DELETE /groups/{id}/members/{uid}` | `200` | PASS | [12_remove_member.md](12_remove_member.md) |
| 13 | `DELETE /groups/{id}` | `200` | PASS | [13_dissolve_group.md](13_dissolve_group.md) |
| 14 | `WS /ws/im` | `101` | PASS | [14_dissolved_ws.md](14_dissolved_ws.md) |
| 15 | `GET /conversations/{id}` | `200` | PASS | [15_dissolved_conversation.md](15_dissolved_conversation.md) |
| 16 | `GET /conversations/{id}/messages` | `200` | PASS | [16_dissolved_history.md](16_dissolved_history.md) |
| 17 | `GET /conversations` | `200` | PASS | [17_dissolved_list_rules.md](17_dissolved_list_rules.md) |
