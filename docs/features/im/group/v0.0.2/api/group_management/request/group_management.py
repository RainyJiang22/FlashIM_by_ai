#!/usr/bin/env python3
"""群详情、成员邀请与解散 API 测试链。"""

import importlib.util
import json
import os
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
helpers.BASE_URL = BASE_URL
PHONE_A = os.environ.get("GROUP_MANAGE_PHONE_A", "13800992001")
PHONE_B = os.environ.get("GROUP_MANAGE_PHONE_B", "13800992002")
PHONE_C = os.environ.get("GROUP_MANAGE_PHONE_C", "13800992003")
PHONE_D = os.environ.get("GROUP_MANAGE_PHONE_D", "13800992004")
PHONE_E = os.environ.get("GROUP_MANAGE_PHONE_E", "13800992005")

Curl = helpers.Curl
step = helpers.step
ok = helpers.ok
fail = helpers.fail
expect_status = helpers.expect_status
write_doc = helpers.write_doc
write_link = helpers.write_link


def patch(path, body, token):
    return Curl.request("PATCH", path, body=body, token=token)


def find_private_conversation(token, peer_id):
    response = Curl.get("/conversations?type=0&limit=100&offset=0", token)
    expect_status(response, 200, "查询私聊会话")
    for conversation in response["data"]:
        if conversation.get("peer_user_id") == str(peer_id):
            return conversation["id"]
    fail(f"未找到与 {peer_id} 的私聊会话")


def record(number, filename, method, path, description, body, response, params=None, note=None):
    ok()
    write_doc(filename, method, path, description, body, response, params_desc=params, note=note)


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = helpers.login_by_sms(PHONE_A)
    token_b, user_b = helpers.login_by_sms(PHONE_B)
    token_c, user_c = helpers.login_by_sms(PHONE_C)
    token_d, user_d = helpers.login_by_sms(PHONE_D)
    token_e, user_e = helpers.login_by_sms(PHONE_E)

    helpers.ensure_friend(token_a, user_a, token_b, user_b)
    helpers.ensure_friend(token_a, user_a, token_c, user_c)
    helpers.ensure_friend(token_b, user_b, token_d, user_d)
    helpers.ensure_friend(token_a, user_a, token_e, user_e)

    created = Curl.post(
        "/conversations",
        {
            "type": "group",
            "name": f"群管理链路-{datetime.now().strftime('%H%M%S')}",
            "member_ids": [user_b, user_c],
        },
        token_a,
    )
    expect_status(created, 200, "创建测试群")
    group_id = created["data"]["id"]

    step(1, "GET /groups/{id} - 群成员查询完整详情")
    detail = Curl.get(f"/groups/{group_id}", token_b)
    expect_status(detail, 200, "查询群详情")
    if detail["data"].get("member_count") != 3:
        fail(f"群成员数量不正确: {detail['body']}")
    record(
        1,
        "01_group_detail.md",
        "GET",
        "/groups/{id}",
        "有效群成员查询群名、群主、邀请确认设置和完整成员列表。",
        None,
        detail,
    )

    step(2, "PATCH /groups/{id}/name - 群主修改群名")
    renamed = patch(f"/groups/{group_id}/name", {"name": "周末读书会"}, token_a)
    expect_status(renamed, 200, "修改群名")
    if renamed["data"].get("name") != "周末读书会":
        fail(f"群名未更新: {renamed['body']}")
    record(2, "02_update_name.md", "PATCH", "/groups/{id}/name", "仅群主可修改群名。", {"name": "周末读书会"}, renamed)

    step(3, "PATCH /groups/{id}/name - 普通成员修改失败")
    forbidden_name = patch(f"/groups/{group_id}/name", {"name": "越权群名"}, token_b)
    expect_status(forbidden_name, 403, "普通成员修改群名")
    record(3, "03_update_name_forbidden.md", "PATCH", "/groups/{id}/name", "普通成员不能修改群名。", {"name": "越权群名"}, forbidden_name)

    step(4, "PATCH /groups/{id}/settings - 开启邀请确认")
    settings = patch(
        f"/groups/{group_id}/settings",
        {"join_approval_required": True},
        token_a,
    )
    expect_status(settings, 200, "开启邀请确认")
    if settings["data"].get("join_approval_required") is not True:
        fail(f"邀请确认未开启: {settings['body']}")
    record(4, "04_update_settings.md", "PATCH", "/groups/{id}/settings", "群主开启普通成员邀请确认。", {"join_approval_required": True}, settings)

    step(5, "POST /groups/{id}/members - 普通成员不能绕过确认")
    bypass = Curl.post(f"/groups/{group_id}/members", {"member_ids": [user_d]}, token_b)
    expect_status(bypass, 403, "普通成员绕过邀请确认")
    record(5, "05_direct_add_forbidden.md", "POST", "/groups/{id}/members", "邀请确认开启后，普通成员不能直接添加好友。", {"member_ids": [user_d]}, bypass)

    step(6, "POST /groups/{id}/invitations - 发送群邀请卡片")
    invitation = Curl.post(
        f"/groups/{group_id}/invitations",
        {"member_ids": [user_d]},
        token_b,
    )
    expect_status(invitation, 200, "发送群邀请")
    invitation_id = invitation["data"]["invitations"][0]["id"]
    record(6, "06_send_invitation.md", "POST", "/groups/{id}/invitations", "普通成员向自己的好友发送持久化群邀请卡片。", {"member_ids": [user_d]}, invitation)

    step(7, "GET /conversations/{private}/messages - 邀请卡片已持久化")
    private_id = find_private_conversation(token_d, user_b)
    history = Curl.get(f"/conversations/{private_id}/messages?limit=20", token_d)
    expect_status(history, 200, "查询邀请卡片历史")
    cards = [item for item in history["data"] if item.get("msg_type") == 4]
    if not any((item.get("extra") or {}).get("invitation_id") == invitation_id for item in cards):
        fail(f"私聊历史缺少群邀请卡片: {history['body']}")
    record(7, "07_invitation_card_history.md", "GET", "/conversations/{id}/messages", "被邀请人的私聊历史包含 GROUP_INVITATION=4 卡片。", None, history)

    step(8, "POST /group-invitations/{id}/accept - 好友同意入群")
    accepted = Curl.post(f"/group-invitations/{invitation_id}/accept", token=token_d)
    expect_status(accepted, 200, "同意群邀请")
    if accepted["data"].get("id") != group_id:
        fail(f"接受邀请返回群不正确: {accepted['body']}")
    record(8, "08_accept_invitation.md", "POST", "/group-invitations/{id}/accept", "仅被邀请人可同意，成功后才写入群成员。", None, accepted)

    step(9, "POST /groups/{id}/members - 群主直接添加好友")
    owner_add = Curl.post(f"/groups/{group_id}/members", {"member_ids": [user_e]}, token_a)
    expect_status(owner_add, 200, "群主添加成员")
    if owner_add["data"].get("member_count") != 5:
        fail(f"群主添加成员后数量不正确: {owner_add['body']}")
    record(9, "09_owner_add_member.md", "POST", "/groups/{id}/members", "群主不受邀请确认限制，可以直接添加自己的好友。", {"member_ids": [user_e]}, owner_add)

    step(10, "DELETE /groups/{id}/members/{user_id} - 群主删除成员")
    removed = Curl.delete(f"/groups/{group_id}/members/{user_c}", token_a)
    expect_status(removed, 200, "群主删除成员")
    if any(item.get("account_id") == str(user_c) for item in removed["data"].get("members", [])):
        fail(f"被删除成员仍在列表: {removed['body']}")
    record(10, "10_owner_remove_member.md", "DELETE", "/groups/{id}/members/{user_id}", "群主删除非群主成员。", None, removed)

    step(11, "DELETE /groups/{id} - 普通成员解散失败")
    forbidden_dissolve = Curl.delete(f"/groups/{group_id}", token_b)
    expect_status(forbidden_dissolve, 403, "普通成员解散群")
    record(11, "11_dissolve_forbidden.md", "DELETE", "/groups/{id}", "只有群主可以解散群聊。", None, forbidden_dissolve)

    step(12, "DELETE /groups/{id} - 群主解散群聊")
    dissolved = Curl.delete(f"/groups/{group_id}", token_a)
    expect_status(dissolved, 200, "群主解散群")
    record(12, "12_dissolve_group.md", "DELETE", "/groups/{id}", "软解散群聊、撤销全部成员资格并失效待处理邀请。", None, dissolved)

    step(13, "GET /groups/{id} - 解散后不可访问")
    after_dissolve = Curl.get(f"/groups/{group_id}", token_a)
    expect_status(after_dissolve, 404, "解散后查询群")
    record(13, "13_dissolved_group_hidden.md", "GET", "/groups/{id}", "解散群从群详情和通用成员权限链路中移除。", None, after_dissolve)

    write_link()
    print(json.dumps({"ok": True, "group_id": group_id, "invitation_id": invitation_id}, ensure_ascii=False))


if __name__ == "__main__":
    if "--redact-docs" in sys.argv:
        helpers.redact_existing_docs()
    else:
        main()
