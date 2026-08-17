# group_management - API test link

Base URL: `http://127.0.0.1:9600`

> 运行 `../request/group_management.py` 后，本目录会按真实响应生成 01～13 接口文档并刷新本表。脚本覆盖群详情、改名、邀请确认、邀请卡片、同意入群、群主增删成员和解散后不可访问。

> 2026-08-17：本次未直接执行独立 Python 链，因本地 `9600` 端口被未加载新路由的旧 `falsh-im` 进程占用，且未越权中断用户进程。同等 13 步核心契约已由 `server/src/lib.rs` 的真实 PostgreSQL 路由往返测试覆盖并通过；本表保留为新服务启动后的人工联调入口。

| # | Interface | Expected | Doc |
|---|-----------|----------|-----|
| 1 | `GET /groups/{id}` | `200` | 运行后生成 |
| 2 | `PATCH /groups/{id}/name` | `200` | 运行后生成 |
| 3 | `PATCH /groups/{id}/name`（普通成员） | `403` | 运行后生成 |
| 4 | `PATCH /groups/{id}/settings` | `200` | 运行后生成 |
| 5 | `POST /groups/{id}/members`（绕过确认） | `403` | 运行后生成 |
| 6 | `POST /groups/{id}/invitations` | `200` | 运行后生成 |
| 7 | `GET /conversations/{id}/messages` | `200` | 运行后生成 |
| 8 | `POST /group-invitations/{id}/accept` | `200` | 运行后生成 |
| 9 | `POST /groups/{id}/members`（群主） | `200` | 运行后生成 |
| 10 | `DELETE /groups/{id}/members/{user_id}` | `200` | 运行后生成 |
| 11 | `DELETE /groups/{id}`（普通成员） | `403` | 运行后生成 |
| 12 | `DELETE /groups/{id}`（群主） | `200` | 运行后生成 |
| 13 | `GET /groups/{id}`（已解散） | `404` | 运行后生成 |
