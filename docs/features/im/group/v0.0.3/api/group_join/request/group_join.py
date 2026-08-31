#!/usr/bin/env python3
"""搜索加群、入群申请与群主审批 API/WS 测试链。"""

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
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
helpers.BASE_URL = BASE_URL
helpers.WS_URL = WS_URL
PHONE_A = os.environ.get("GROUP_JOIN_PHONE_A", "13800993001")
PHONE_B = os.environ.get("GROUP_JOIN_PHONE_B", "13800993002")
PHONE_C = os.environ.get("GROUP_JOIN_PHONE_C", "13800993003")
PHONE_D = os.environ.get("GROUP_JOIN_PHONE_D", "13800993004")
PHONE_E = os.environ.get("GROUP_JOIN_PHONE_E", "13800993005")

Curl = helpers.Curl
step = helpers.step
ok = helpers.ok
fail = helpers.fail
expect_status = helpers.expect_status
write_doc = helpers.write_doc

GROUP_JOIN_REQUEST = 10


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


def create_group(token, name, member_ids):
    response = Curl.post(
        "/conversations",
        {"type": "group", "name": name, "member_ids": member_ids},
        token,
    )
    expect_status(response, 200, "创建测试群")
    group_id = response["data"].get("id")
    if not group_id:
        fail(f"创建群响应缺少 id: {response['body']}")
    return group_id


def expect_group(groups, group_id):
    for item in groups:
        if item.get("conversation_id") == group_id:
            return item
    fail(f"搜索结果缺少群 {group_id}: {groups}")


def read_join_event(client, expected_request_id, expected_status):
    payload = helpers.read_until(client, GROUP_JOIN_REQUEST)
    request_id = payload.get(1, b"").decode("utf-8")
    status = payload.get(9, 0)
    if request_id != expected_request_id or status != expected_status:
        fail(
            "GROUP_JOIN_REQUEST 不匹配: "
            f"request_id={request_id}, status={status}, expected={expected_request_id}/{expected_status}"
        )
    return {"request_id": request_id, "status": status}


def write_ws_doc(filename, title, result):
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# {title}",
        "",
        "通过 `/ws/im` 二进制帧验证 `GROUP_JOIN_REQUEST=10` 定向推送。",
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
        "# group_join - API test link",
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


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = helpers.login_by_sms(PHONE_A)
    token_b, user_b = helpers.login_by_sms(PHONE_B)
    token_c, user_c = helpers.login_by_sms(PHONE_C)
    token_d, user_d = helpers.login_by_sms(PHONE_D)
    token_e, user_e = helpers.login_by_sms(PHONE_E)

    helpers.ensure_friend(token_a, user_a, token_b, user_b)
    helpers.ensure_friend(token_a, user_a, token_c, user_c)
    marker = datetime.now().strftime("%Y%m%d%H%M%S%f")
    direct_name = f"直接入群-{marker}"
    approval_name = f"审批入群-{marker}"
    direct_group = create_group(token_a, direct_name, [user_b, user_c])
    approval_group = create_group(token_a, approval_name, [user_b, user_c])
    settings = patch(
        f"/groups/{approval_group}/settings",
        {"join_approval_required": True},
        token_a,
    )
    expect_status(settings, 200, "开启主动入群审批")

    owner_ws = helpers.authenticate(token_a)
    applicant_ws = helpers.authenticate(token_e)
    try:
        step(1, "GET /groups/search - 群名模糊搜索")
        searched = Curl.get(f"/groups/search?keyword={direct_name}", token_d)
        expect_status(searched, 200, "群名搜索")
        item = expect_group(searched["data"]["groups"], direct_group)
        if item.get("is_member") or item.get("join_approval_required"):
            fail(f"直接入群搜索状态不正确: {searched['body']}")
        record(
            "01_search_by_name.md",
            "GET",
            "/groups/search?keyword={keyword}",
            "按群名模糊搜索未解散群，并返回成员数与入群状态。",
            None,
            searched,
            [{"name": "keyword", "type": "string", "required": "是", "desc": "1～100 字群名或完整群号"}],
        )

        step(2, "GET /groups/search - 完整 UUID 群号搜索")
        exact = Curl.get(f"/groups/search?keyword={approval_group}", token_e)
        expect_status(exact, 200, "群号精确搜索")
        exact_item = expect_group(exact["data"]["groups"], approval_group)
        if exact_item.get("join_approval_required") is not True:
            fail(f"审批群搜索状态不正确: {exact['body']}")
        record("02_search_by_number.md", "GET", "/groups/search?keyword={uuid}", "输入完整 UUID 群号时精确匹配群聊。", None, exact)

        step(3, "GET /groups/search - 空关键词失败")
        invalid_search = Curl.get("/groups/search?keyword=", token_d)
        expect_status(invalid_search, 400, "空关键词搜索")
        record("03_search_invalid.md", "GET", "/groups/search?keyword=", "空搜索词返回稳定 400。", None, invalid_search)

        step(4, "POST /groups/{id}/join - 无需审批直接加入")
        direct_join = Curl.post(f"/groups/{direct_group}/join", {}, token_d)
        expect_status(direct_join, 200, "直接加入群聊")
        if direct_join["data"].get("auto_approved") is not True:
            fail(f"直接加入响应不正确: {direct_join['body']}")
        record("04_direct_join.md", "POST", "/groups/{id}/join", "关闭入群验证时直接恢复或新增成员，并返回群会话。", None, direct_join)

        step(5, "POST /groups/{id}/join - 已是成员失败")
        duplicate_member = Curl.post(f"/groups/{direct_group}/join", {}, token_d)
        expect_status(duplicate_member, 400, "成员重复加入")
        record("05_join_existing_member.md", "POST", "/groups/{id}/join", "已在群内的用户不能重复加入。", None, duplicate_member)

        step(6, "POST /groups/{id}/join - 创建待审批申请")
        pending = Curl.post(
            f"/groups/{approval_group}/join",
            {"message": "请群主通过"},
            token_e,
        )
        expect_status(pending, 200, "创建入群申请")
        request_id = pending["data"].get("request_id")
        if pending["data"].get("auto_approved") is not False or not request_id:
            fail(f"待审批响应不正确: {pending['body']}")
        record("06_create_join_request.md", "POST", "/groups/{id}/join", "开启入群验证时创建唯一 pending 申请。", {"message": "请群主通过"}, pending)

        step(7, "WS /ws/im - 群主收到 pending 通知")
        pending_event = read_join_event(owner_ws, request_id, 0)
        ok()
        write_ws_doc("07_owner_pending_ws.md", "群主收到入群申请 WS 通知", pending_event)

        step(8, "POST /groups/{id}/join - 重复待审批申请失败")
        duplicate_request = Curl.post(f"/groups/{approval_group}/join", {}, token_e)
        expect_status(duplicate_request, 409, "重复入群申请")
        record("08_duplicate_request.md", "POST", "/groups/{id}/join", "部分唯一索引阻止同一用户并发产生多条 pending。", None, duplicate_request)

        step(9, "GET /groups/join-requests - 群主查询申请")
        request_list = Curl.get("/groups/join-requests", token_a)
        expect_status(request_list, 200, "群主查询入群申请")
        if not any(item.get("id") == request_id for item in request_list["data"].get("requests", [])):
            fail(f"申请列表缺少目标申请: {request_list['body']}")
        record("09_list_join_requests.md", "GET", "/groups/join-requests", "查询当前用户作为群主的全部入群申请，pending 优先。", None, request_list)

        step(10, "POST /groups/{id}/join-requests/{rid}/handle - 非群主失败")
        forbidden = Curl.post(
            f"/groups/{approval_group}/join-requests/{request_id}/handle",
            {"approved": True},
            token_b,
        )
        expect_status(forbidden, 403, "非群主处理申请")
        record("10_handle_forbidden.md", "POST", "/groups/{id}/join-requests/{rid}/handle", "普通成员不能审批入群申请。", {"approved": True}, forbidden)

        step(11, "POST /groups/{id}/join-requests/{rid}/handle - 群主同意")
        approved = Curl.post(
            f"/groups/{approval_group}/join-requests/{request_id}/handle",
            {"approved": True},
            token_a,
        )
        expect_status(approved, 200, "群主同意申请")
        if approved["data"].get("status") != "approved":
            fail(f"同意申请状态不正确: {approved['body']}")
        record("11_approve_request.md", "POST", "/groups/{id}/join-requests/{rid}/handle", "群主同意后在同一事务中写入成员、刷新群头像并更新申请状态。", {"approved": True}, approved)

        step(12, "WS /ws/im - 申请者收到 approved 结果")
        approved_event = read_join_event(applicant_ws, request_id, 1)
        ok()
        write_ws_doc("12_applicant_approved_ws.md", "申请者收到审批结果 WS 通知", approved_event)

        step(13, "POST /groups/{id}/join-requests/{rid}/handle - 已处理失败")
        handled_again = Curl.post(
            f"/groups/{approval_group}/join-requests/{request_id}/handle",
            {"approved": False},
            token_a,
        )
        expect_status(handled_again, 400, "重复处理申请")
        record("13_handle_again.md", "POST", "/groups/{id}/join-requests/{rid}/handle", "同一申请只能处理一次。", {"approved": False}, handled_again)

        step(14, "POST /groups/{id}/join - 超长留言失败")
        invalid_message = Curl.post(
            f"/groups/{approval_group}/join",
            {"message": "字" * 201},
            token_d,
        )
        expect_status(invalid_message, 400, "超长申请留言")
        record("14_join_message_too_long.md", "POST", "/groups/{id}/join", "申请留言去除首尾空格后最多 200 个 Unicode 字符。", {"message": "字" * 201}, invalid_message)

        step(15, "POST /groups/{id}/join - 不存在群失败")
        missing = Curl.post(
            "/groups/00000000-0000-0000-0000-000000000000/join",
            {},
            token_d,
        )
        expect_status(missing, 404, "加入不存在群")
        record("15_join_missing_group.md", "POST", "/groups/{id}/join", "不存在或已解散的群不可加入。", None, missing)
    finally:
        owner_ws.close()
        applicant_ws.close()

    write_link()
    print(json.dumps({"ok": True, "direct_group": direct_group, "approval_group": approval_group}, ensure_ascii=False))


if __name__ == "__main__":
    if "--redact-docs" in sys.argv:
        helpers.redact_existing_docs()
    else:
        main()
