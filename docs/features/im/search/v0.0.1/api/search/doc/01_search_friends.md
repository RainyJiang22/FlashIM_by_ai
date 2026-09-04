# GET /api/friends/search?q=<keyword>

按昵称或完整闪讯号搜索当前用户的好友。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 1～100 字符关键词 |

## Response `200`

```json
[
  {
    "account_id": 2845,
    "nickname": "搜索好友0904152647",
    "avatar": "identicon:2845",
    "signature": "",
    "flash_id": "flash_2845",
    "relation_status": "friend",
    "created_at": "2026-09-04T07:26:47.358255Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/friends/search?q=%E6%90%9C%E7%B4%A2%E5%A5%BD%E5%8F%8B0904152647' -H 'Authorization: Bearer <redacted>'
```
