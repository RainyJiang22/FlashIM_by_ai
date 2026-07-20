#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime


BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
PHONE_A = os.environ.get("FRIEND_PHONE_A", "13800990001")
PHONE_B = os.environ.get("FRIEND_PHONE_B", "13800990002")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DOCS_DIR = os.path.join(SCRIPT_DIR, "..", "doc")
CURL_BIN = shutil.which("curl.exe") or shutil.which("curl")

CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
RESET = "\033[0m"

DOC_ROWS = []


def step(n, desc):
    print(f"{CYAN}========== [{n}] {desc} =========={RESET}")


def fail(msg):
    print(f"{RED}[FAIL] {msg}{RESET}")
    sys.exit(1)


def ok():
    print(f"{GREEN}[PASS]{RESET}")


def curl(method, path, body=None, token=None):
    if not CURL_BIN:
        fail("未找到 curl/curl.exe")

    url = f"{BASE_URL}{path}"
    cmd = [CURL_BIN, "-sS", "-w", "\n%{http_code}", "-X", method, url]
    if token:
        cmd += ["-H", f"Authorization: Bearer {token}"]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(body, ensure_ascii=False)]

    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        fail(f"curl 执行失败: {result.stderr.strip()}")

    output = result.stdout.rsplit("\n", 1)
    response_body = output[0] if len(output) > 1 else ""
    status = int(output[-1]) if output[-1].isdigit() else 0
    data = None
    if response_body.strip():
        try:
            data = json.loads(response_body)
        except json.JSONDecodeError:
            data = response_body

    return {
        "status": status,
        "body": response_body,
        "data": data,
        "curl": shell_join(cmd),
    }


def shell_join(parts):
    quoted = []
    for item in parts:
        if not item:
            quoted.append("''")
        elif any(ch.isspace() or ch in "'\"{}:," for ch in item):
            quoted.append("'" + item.replace("'", "'\\''") + "'")
        else:
            quoted.append(item)
    return " ".join(quoted)


def expect_status(result, expected, desc):
    if result["status"] != expected:
        fail(f"{desc} 期望 {expected}，实际 {result['status']}: {result['body']}")


def write_doc(filename, method, path, desc, request_body, response, token=None, params_desc=None, note=None):
    os.makedirs(DOCS_DIR, exist_ok=True)
    lines = [f"# {method} {path}", "", desc, ""]
    if params_desc:
        lines += [
            "## Parameters",
            "",
            "| 参数 | 类型 | 必填 | 说明 |",
            "|------|------|------|------|",
        ]
        for item in params_desc:
            lines.append(f"| {item['name']} | {item['type']} | {item['required']} | {item['desc']} |")
        lines.append("")
    if request_body is not None:
        lines += [
            "## Request",
            "",
            "```json",
            json.dumps(request_body, ensure_ascii=False, indent=2),
            "```",
            "",
        ]
    body = response["body"] if response["body"].strip() else "(empty body)"
    if response["data"] is not None and not isinstance(response["data"], str):
        body = json.dumps(response["data"], ensure_ascii=False, indent=2)
    lines += [
        f"## Response `{response['status']}`",
        "",
        "```json",
        body,
        "```",
        "",
        "## curl",
        "",
        "```bash",
        response["curl"],
        "```",
    ]
    if note:
        lines += ["", f"> {note}"]
    with open(os.path.join(DOCS_DIR, filename), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    DOC_ROWS.append((method, path, response["status"], "PASS", filename))


def write_link():
    os.makedirs(DOCS_DIR, exist_ok=True)
    lines = [
        "# friend - API test link",
        "",
        f"Base URL: `{BASE_URL}`",
        f"Generated at: `{datetime.now().isoformat(timespec='seconds')}`",
        "",
        "| # | Interface | Status | Result | Doc |",
        "|---|-----------|--------|--------|-----|",
    ]
    for index, (method, path, status, result, filename) in enumerate(DOC_ROWS, start=1):
        lines.append(
            f"| {index} | `{method} {path}` | `{status}` | {result} | [{filename}]({filename}) |"
        )
    with open(os.path.join(DOCS_DIR, "00_link.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def login_by_sms(phone):
    sms = curl("POST", "/auth/sms", {"phone": phone})
    expect_status(sms, 200, "发送短信验证码")
    code = sms["data"].get("code")
    if not code:
        fail("短信接口未返回调试 code，确认 EXPOSE_DEBUG_SMS_CODE=true")
    login = curl(
        "POST",
        "/auth/login",
        {"login_type": "sms_code", "phone": phone, "code": code},
    )
    expect_status(login, 200, "短信登录")
    token = login["data"].get("token")
    account_id = login["data"].get("account_id")
    if not token or not account_id:
        fail(f"登录响应缺少 token/account_id: {login['body']}")
    return token, int(account_id)


def find_request(requests, from_user_id):
    for item in requests:
        if int(item["from_user"]["account_id"]) == int(from_user_id):
            return item
    return None


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = login_by_sms(PHONE_A)
    token_b, user_b = login_by_sms(PHONE_B)
    print(f"user_a={user_a}, user_b={user_b}")

    # Keep repeated local runs deterministic.
    cleanup = curl("DELETE", f"/api/friends/{user_b}", token=token_a)
    if cleanup["status"] not in (200, 404):
        fail(f"预清理好友关系失败: {cleanup['status']} {cleanup['body']}")

    step(1, "GET /api/users/search - 搜索目标用户")
    search = curl("GET", f"/api/users/search?q={PHONE_B}", token=token_a)
    expect_status(search, 200, "搜索用户")
    if not any(int(item["account_id"]) == user_b for item in search["data"]):
        fail(f"搜索结果没有目标用户: {search['body']}")
    ok()
    write_doc(
        "01_search_user.md",
        "GET",
        "/api/users/search?q=<phone>",
        "按手机号、闪讯号或昵称搜索用户，并返回当前关系状态。",
        None,
        search,
        token_a,
        params_desc=[{"name": "q", "type": "string", "required": "是", "desc": "搜索关键词"}],
    )

    step(2, "GET /api/users/{account_id} - 查看公开资料")
    profile = curl("GET", f"/api/users/{user_b}", token=token_a)
    expect_status(profile, 200, "查看公开资料")
    if int(profile["data"]["account_id"]) != user_b:
        fail(f"公开资料账号不匹配: {profile['body']}")
    ok()
    write_doc(
        "02_public_user.md",
        "GET",
        "/api/users/{account_id}",
        "查看用户公开资料，并返回当前用户与对方的关系状态。",
        None,
        profile,
        token_a,
        params_desc=[{"name": "account_id", "type": "int", "required": "是", "desc": "目标账号 ID"}],
    )

    step(3, "POST /api/friends/requests - 发送好友申请")
    request_body = {"to_user_id": user_b, "message": "我是小雨"}
    send = curl("POST", "/api/friends/requests", request_body, token_a)
    expect_status(send, 200, "发送好友申请")
    request_id = send["data"]["id"]
    ok()
    write_doc(
        "03_send_request.md",
        "POST",
        "/api/friends/requests",
        "向目标用户发送好友申请；重复发送会覆盖留言并保持 pending 状态。",
        request_body,
        send,
        token_a,
    )

    step(4, "GET /api/friends/requests/received - 接收方查看申请")
    received = curl("GET", "/api/friends/requests/received", token=token_b)
    expect_status(received, 200, "查看收到的申请")
    received_request = find_request(received["data"], user_a)
    if not received_request:
        fail(f"收到的申请列表没有发送方: {received['body']}")
    request_id = received_request["id"]
    ok()
    write_doc(
        "04_received_requests.md",
        "GET",
        "/api/friends/requests/received",
        "接收方查看收到的好友申请列表，默认只返回 pending。",
        None,
        received,
        token_b,
    )

    step(5, "POST /api/friends/requests/{id}/accept - 接受申请")
    accept = curl("POST", f"/api/friends/requests/{request_id}/accept", token=token_b)
    expect_status(accept, 200, "接受好友申请")
    if int(accept["data"]["friend"]["account_id"]) != user_a:
        fail(f"接受响应 friend 不正确: {accept['body']}")
    conversation_id = accept["data"].get("conversation_id")
    if not conversation_id:
        fail(f"接受响应缺少 conversation_id: {accept['body']}")
    ok()
    write_doc(
        "05_accept_request.md",
        "POST",
        "/api/friends/requests/{id}/accept",
        "接收方接受好友申请，服务端建立双向好友关系并创建或复用私聊会话。",
        None,
        accept,
        token_b,
        params_desc=[{"name": "id", "type": "uuid", "required": "是", "desc": "好友申请 ID"}],
    )

    step(6, "GET /api/friends - 查询好友列表")
    friends = curl("GET", "/api/friends", token=token_a)
    expect_status(friends, 200, "查询好友列表")
    if not any(int(item["account_id"]) == user_b for item in friends["data"]):
        fail(f"好友列表没有目标用户: {friends['body']}")
    ok()
    write_doc(
        "06_list_friends.md",
        "GET",
        "/api/friends",
        "查询当前用户的好友列表。",
        None,
        friends,
        token_a,
    )

    step(7, "DELETE /api/friends/{friend_user_id} - 删除好友")
    remove = curl("DELETE", f"/api/friends/{user_b}", token=token_a)
    expect_status(remove, 200, "删除好友")
    ok()
    write_doc(
        "07_remove_friend.md",
        "DELETE",
        "/api/friends/{friend_user_id}",
        "解除双方好友关系，不删除历史会话和消息。",
        None,
        remove,
        token_a,
        params_desc=[{"name": "friend_user_id", "type": "int", "required": "是", "desc": "好友账号 ID"}],
    )

    step(8, "POST /api/friends/requests/{id}/accept - 重复接受失败")
    accept_again = curl("POST", f"/api/friends/requests/{request_id}/accept", token=token_b)
    expect_status(accept_again, 409, "重复接受好友申请")
    ok()
    write_doc(
        "08_accept_again_conflict.md",
        "POST",
        "/api/friends/requests/{id}/accept",
        "重复处理已接受申请时返回 409。",
        None,
        accept_again,
        token_b,
        params_desc=[{"name": "id", "type": "uuid", "required": "是", "desc": "好友申请 ID"}],
    )

    write_link()
    print(json.dumps({"ok": True, "request_id": request_id, "conversation_id": conversation_id}, ensure_ascii=False))


if __name__ == "__main__":
    main()
