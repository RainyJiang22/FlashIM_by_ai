# search - API test link

Base URL: `http://127.0.0.1:9600`
Generated at: `2026-09-04T15:26:47`

| # | Interface | Status | Result | Doc |
|---|-----------|--------|--------|-----|
| 1 | `GET /api/friends/search?q=<keyword>` | `200` | PASS | [01_search_friends.md](01_search_friends.md) |
| 2 | `GET /api/conversations/search-joined-groups?q=<keyword>` | `200` | PASS | [02_search_joined_groups.md](02_search_joined_groups.md) |
| 3 | `GET /api/messages/search?q=<keyword>` | `200` | PASS | [03_search_messages.md](03_search_messages.md) |
| 4 | `GET /conversations/{id}/messages/search?q=<keyword>` | `200` | PASS | [04_search_conversation_messages.md](04_search_conversation_messages.md) |
| 5 | `GET /api/messages/search?q=<blank>` | `400` | PASS | [05_empty_keyword.md](05_empty_keyword.md) |
| 6 | `GET /api/messages/search?q=<keyword>` | `401` | PASS | [06_unauthorized.md](06_unauthorized.md) |
