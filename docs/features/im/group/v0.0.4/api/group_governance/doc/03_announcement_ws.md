# 成员收到公告更新

通过 `/ws/im` 二进制帧验证 `GROUP_INFO_UPDATE=11` 定向推送。

## Result

```json
{
  "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
  "owner_id": 2844,
  "member_count": 3,
  "is_dissolved": false,
  "membership_active": true,
  "current_user_role": "member",
  "change_type": "announcement_updated"
}
```
