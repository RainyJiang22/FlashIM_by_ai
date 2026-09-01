#!/usr/bin/env python3
"""群治理、群信息 WS 与解散只读历史 API 测试链。"""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
DOCS_DIR = SCRIPT_DIR.parent / "doc"
V1_SCRIPT = SCRIPT_DIR.parents[3] / "v0.0.1" / "api" / "group" / "request" / "group.py"
spec = importlib.util.spec_from_file_location("group_v1_link_helpers", V1_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"无法加载测试链公共帮助器: {V1_SCRIPT}")
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
helpers.DOCS_DIR = str(DOCS_DIR)
helpers.DOC_ROWS = []

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
helpers.BASE_URL = BASE_URL
helpers.WS_URL = WS_URL
PHONE_A = os.environ.get("GROUP_GOVERNANCE_PHONE_A", "13800994001")
PHONE_B = os.environ.get("GROUP_GOVERNANCE_PHONE_B", "13800994002")
PHONE_C = os.environ.get("GROUP_GOVERNANCE_PHONE_C", "13800994003")
PHONE_D = os.environ.get("GROUP_GOVERNANCE_PHONE_D", "13800994004")

Curl = helpers.Curl
step = helpers.step
ok = helpers.ok
fail = helpers.fail
expect_status = helpers.expect_status
write_doc = helpers.write_doc
GROUP_INFO_UPDATE = 11


def patch(path, body, token):
    return Curl.request("PATCH", path, body=body, token=token)


def record(filename, method, path, description, body, response, params=None, note=None):
    ok()
    write_doc(
        filename,
        method,
        path,
        description,
        body,
        response,
        params_desc=params,
        note=note,
    )


def read_group_info(client, group_id, change_type):
    for _ in range(12):
        payload = helpers.read_until(client, GROUP_INFO_UPDATE)
        received_group = payload.get(1, b"").decode("utf-8")
        received_change = payload.get(12, b"").decode("utf-8")
        if received_group == group_id and received_change == change_type:
            return {
                "conversation_id": received_group,
                "owner_id": payload.get(4, 0),
                "member_count": payload.get(5, 0),
                "is_dissolved": bool(payload.get(9, 0)),
                "membership_active": bool(payload.get(10, 0)),
                "current_user_role": payload.get(11, b"").decode("utf-8"),
                "change_type": received_change,
            }
    fail(f"未收到目标 GROUP_INFO_UPDATE: {group_id}/{change_type}")


def write_ws_doc(filename, title, result):
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# {title}",
        "",
        "通过 `/ws/im` 二进制帧验证 `GROUP_INFO_UPDATE=11` 定向推送。",
        "",
        "## Result",
        "",
        "```json",
        json.dumps(result, ensure_ascii=False, indent=2),
        "```",
    ]
    (DOCS_DIR / filename).write_text("\n".join(lines) + "\n", encoding="utf-8")
    helpers.DOC_ROWS.append(("WS", "/ws/im", 101, "PASS", filename))


def write_link():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# group_governance - API test link",
        "",
        f"Base URL: `{BASE_URL}`",
        f"Generated at: `{datetime.now().isoformat(timespec='seconds')}`",
        "",
        "| # | Interface | Status | Result | Doc |",
        "|---|-----------|--------|--------|-----|",
    ]
    for index, (method, path, status, result, filename) in enumerate(
        helpers.DOC_ROWS, start=1
    ):
        lines.append(
            f"| {index} | `{method} {path}` | `{status}` | {result} | "
            f"[{filename}]({filename}) |"
        )
    (DOCS_DIR / "00_link.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def cleanup_group(group_id):
    database_url = os.environ.get("CLEANUP_DATABASE_URL") or os.environ.get("DATABASE_URL")
    psql = shutil.which("psql")
    if not group_id or not database_url or not psql:
        return
    subprocess.run(
        [psql, database_url, "-v", "ON_ERROR_STOP=1", "-c", f"DELETE FROM conversations WHERE id = '{group_id}'::uuid"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = helpers.login_by_sms(PHONE_A)
    token_b, user_b = helpers.login_by_sms(PHONE_B)
    token_c, user_c = helpers.login_by_sms(PHONE_C)
    token_d, user_d = helpers.login_by_sms(PHONE_D)
    helpers.ensure_friend(token_a, user_a, token_b, user_b)
    helpers.ensure_friend(token_a, user_a, token_c, user_c)
    helpers.ensure_friend(token_a, user_a, token_d, user_d)

    marker = datetime.now().strftime("%Y%m%d%H%M%S%f")
    created = Curl.post(
        "/conversations",
        {"type": "group", "name": f"治理链路-{marker}", "member_ids": [user_b, user_d]},
        token_a,
    )
    expect_status(created, 200, "创建治理测试群")
    group_id = created["data"].get("id")
    if not group_id:
        fail(f"创建群响应缺少 id: {created['body']}")

    clients = []
    try:
        owner_ws = helpers.authenticate(token_a)
        member_ws = helpers.authenticate(token_b)
        joining_ws = helpers.authenticate(token_c)
        history_ws = helpers.authenticate(token_d)
        clients.extend([owner_ws, member_ws, joining_ws, history_ws])

        step(1, "GET /groups/{id} - 读取治理详情")
        detail = Curl.get(f"/groups/{group_id}", token_a)
        expect_status(detail, 200, "读取群详情")
        if detail["data"].get("announcement") != "" or detail["data"].get("is_dissolved"):
            fail(f"初始治理字段不正确: {detail['body']}")
        record("01_group_detail.md", "GET", "/groups/{id}", "读取群角色、成员、公告和解散状态。", None, detail)

        step(2, "PATCH /groups/{id}/announcement - 群主发布公告")
        announcement = patch(
            f"/groups/{group_id}/announcement",
            {"announcement": "  周五 18:00 发布  "},
            token_a,
        )
        expect_status(announcement, 200, "发布群公告")
        if announcement["data"].get("announcement") != "周五 18:00 发布":
            fail(f"公告未规范化: {announcement['body']}")
        record("02_update_announcement.md", "PATCH", "/groups/{id}/announcement", "群主发布 1～2000 字当前公告。", {"announcement": "周五 18:00 发布"}, announcement)

        step(3, "WS /ws/im - 成员收到公告更新")
        announcement_event = read_group_info(member_ws, group_id, "announcement_updated")
        if not announcement_event["membership_active"]:
            fail(f"公告事件成员状态错误: {announcement_event}")
        ok()
        write_ws_doc("03_announcement_ws.md", "成员收到公告更新", announcement_event)

        step(4, "PATCH /groups/{id}/announcement - 空公告失败")
        invalid_announcement = patch(
            f"/groups/{group_id}/announcement", {"announcement": " "}, token_a
        )
        expect_status(invalid_announcement, 400, "空公告")
        record("04_invalid_announcement.md", "PATCH", "/groups/{id}/announcement", "空白公告返回稳定 400。", {"announcement": " "}, invalid_announcement)

        step(5, "PATCH /groups/{id}/name - 修改群名并实时同步")
        renamed = patch(f"/groups/{group_id}/name", {"name": "治理群"}, token_a)
        expect_status(renamed, 200, "修改群名")
        record("05_update_name.md", "PATCH", "/groups/{id}/name", "复用既有改名接口并生成治理消息和群信息事件。", {"name": "治理群"}, renamed)
        renamed_event = read_group_info(member_ws, group_id, "name_updated")
        if renamed_event["current_user_role"] != "member":
            fail(f"改名事件角色错误: {renamed_event}")

        step(6, "POST /groups/{id}/members - 增加成员")
        added = Curl.post(f"/groups/{group_id}/members", {"member_ids": [user_c]}, token_a)
        expect_status(added, 200, "增加成员")
        record("06_add_member.md", "POST", "/groups/{id}/members", "复用既有增员接口并补齐系统消息和 type 11。", {"member_ids": [user_c]}, added)
        added_event = read_group_info(joining_ws, group_id, "members_added")
        if not added_event["membership_active"] or added_event["member_count"] != 4:
            fail(f"增员事件错误: {added_event}")

        step(7, "PATCH /groups/{id}/owner - 转让群主")
        transferred = patch(f"/groups/{group_id}/owner", {"owner_id": user_b}, token_a)
        expect_status(transferred, 200, "转让群主")
        record("07_transfer_owner.md", "PATCH", "/groups/{id}/owner", "群主把所有权原子转让给另一活跃成员。", {"owner_id": user_b}, transferred)
        new_owner_event = read_group_info(member_ws, group_id, "owner_transferred")
        if new_owner_event["owner_id"] != user_b or new_owner_event["current_user_role"] != "owner":
            fail(f"转让事件错误: {new_owner_event}")

        step(8, "PATCH /groups/{id}/announcement - 原群主越权失败")
        forbidden = patch(
            f"/groups/{group_id}/announcement", {"announcement": "不应成功"}, token_a
        )
        expect_status(forbidden, 403, "原群主更新公告")
        record("08_former_owner_forbidden.md", "PATCH", "/groups/{id}/announcement", "转让后原群主立即失去群主权限。", {"announcement": "不应成功"}, forbidden)

        step(9, "PATCH /groups/{id}/owner - 新群主转回")
        transferred_back = patch(f"/groups/{group_id}/owner", {"owner_id": user_a}, token_b)
        expect_status(transferred_back, 200, "转回群主")
        record("09_transfer_owner_back.md", "PATCH", "/groups/{id}/owner", "新群主可继续转让给其他活跃成员。", {"owner_id": user_a}, transferred_back)
        read_group_info(owner_ws, group_id, "owner_transferred")

        step(10, "POST /groups/{id}/leave - 普通成员退群")
        left = Curl.post(f"/groups/{group_id}/leave", token=token_c)
        expect_status(left, 200, "普通成员退群")
        record("10_leave_group.md", "POST", "/groups/{id}/leave", "普通成员软删除自己的群成员关系。", None, left)
        left_event = read_group_info(joining_ws, group_id, "member_left")
        if left_event["membership_active"]:
            fail(f"退群事件未标记失效: {left_event}")

        step(11, "POST /groups/{id}/leave - 群主退群失败")
        owner_leave = Curl.post(f"/groups/{group_id}/leave", token=token_a)
        expect_status(owner_leave, 400, "群主退群")
        record("11_owner_leave_forbidden.md", "POST", "/groups/{id}/leave", "群主必须先转让或解散，不能直接退群。", None, owner_leave)

        step(12, "DELETE /groups/{id}/members/{uid} - 移除成员")
        removed = Curl.delete(f"/groups/{group_id}/members/{user_b}", token_a)
        expect_status(removed, 200, "移除成员")
        record("12_remove_member.md", "DELETE", "/groups/{id}/members/{uid}", "群主移除成员并向目标发送 membership_active=false。", None, removed)
        removed_event = read_group_info(member_ws, group_id, "member_removed")
        if removed_event["membership_active"]:
            fail(f"移除事件未标记失效: {removed_event}")

        step(13, "DELETE /groups/{id} - 解散并保留历史")
        dissolved = Curl.delete(f"/groups/{group_id}", token_a)
        expect_status(dissolved, 200, "解散群聊")
        record("13_dissolve_group.md", "DELETE", "/groups/{id}", "群主解散群聊，保留原成员关系和消息作为只读历史。", None, dissolved)
        dissolved_event = read_group_info(history_ws, group_id, "dissolved")
        if not dissolved_event["is_dissolved"] or not dissolved_event["membership_active"]:
            fail(f"解散事件错误: {dissolved_event}")
        write_ws_doc("14_dissolved_ws.md", "原成员收到解散状态", dissolved_event)

        step(15, "GET /conversations/{id} - 原成员读取解散会话")
        dissolved_conversation = Curl.get(f"/conversations/{group_id}", token_d)
        expect_status(dissolved_conversation, 200, "读取解散会话")
        if dissolved_conversation["data"].get("is_dissolved") is not True:
            fail(f"解散会话缺少状态: {dissolved_conversation['body']}")
        record("15_dissolved_conversation.md", "GET", "/conversations/{id}", "原成员仍可读取已解散会话摘要。", None, dissolved_conversation)

        step(16, "GET /conversations/{id}/messages - 读取解散历史")
        history = Curl.get(f"/conversations/{group_id}/messages", token_d)
        expect_status(history, 200, "读取解散历史")
        events = [
            item.get("extra", {}).get("system_event")
            for item in history["data"]
            if isinstance(item, dict) and isinstance(item.get("extra"), dict)
        ]
        required_events = {
            "announcement_updated",
            "group_name_updated",
            "member_invited",
            "owner_transferred",
            "member_left",
            "member_removed",
            "group_dissolved",
        }
        if not required_events.issubset(set(events)):
            fail(f"治理系统消息不完整: {events}")
        record("16_dissolved_history.md", "GET", "/conversations/{id}/messages", "解散后仍可读取完整 type=5 治理消息历史。", None, history)

        step(17, "GET /conversations - 主列表保留、我的群聊过滤")
        main_list = Curl.get("/conversations?limit=100&offset=0", token_d)
        group_list = Curl.get("/conversations?type=1&limit=100&offset=0", token_d)
        expect_status(main_list, 200, "读取主会话列表")
        expect_status(group_list, 200, "读取我的群聊")
        if not any(item.get("id") == group_id for item in main_list["data"]):
            fail("主会话列表未保留解散群")
        if any(item.get("id") == group_id for item in group_list["data"]):
            fail("我的群聊不应包含解散群")
        record("17_dissolved_list_rules.md", "GET", "/conversations", "主列表保留解散历史，type=1 我的群聊继续只显示活跃群。", None, main_list, note="同一步额外验证 `/conversations?type=1` 不包含目标群。")

        write_link()
        print(json.dumps({"ok": True, "steps": 17}, ensure_ascii=False))
    finally:
        for client in clients:
            client.close()
        cleanup_group(group_id)


if __name__ == "__main__":
    if "--redact-docs" in sys.argv:
        helpers.redact_existing_docs()
    else:
        main()
