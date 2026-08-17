#!/usr/bin/env python3
import base64
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import urllib.parse
from datetime import datetime


BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
PHONE_A = os.environ.get("GROUP_PHONE_A", "13800991001")
PHONE_B = os.environ.get("GROUP_PHONE_B", "13800991002")
PHONE_C = os.environ.get("GROUP_PHONE_C", "13800991003")
PHONE_D = os.environ.get("GROUP_PHONE_D", "13800991004")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DOCS_DIR = os.path.join(SCRIPT_DIR, "..", "doc")
CURL_BIN = shutil.which("curl.exe") or shutil.which("curl")

CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
RESET = "\033[0m"

AUTH = 2
AUTH_RESULT = 3
CHAT_MESSAGE = 4
MESSAGE_ACK = 5
CONVERSATION_UPDATE = 6

DOC_ROWS = []


def step(number, description):
    print(f"{CYAN}========== [{number}] {description} =========={RESET}")


def fail(message):
    print(f"{RED}[FAIL] {message}{RESET}")
    sys.exit(1)


def ok():
    print(f"{GREEN}[PASS]{RESET}")


def shell_join(parts):
    quoted = []
    for item in parts:
        if not item:
            quoted.append("''")
        elif any(character.isspace() or character in "'\"{}:," for character in item):
            quoted.append("'" + item.replace("'", "'\\''") + "'")
        else:
            quoted.append(item)
    return " ".join(quoted)


class Curl:
    @staticmethod
    def request(method, path, body=None, token=None):
        if not CURL_BIN:
            fail("未找到 curl/curl.exe")
        url = f"{BASE_URL}{path}"
        command = [CURL_BIN, "-sS", "-w", "\n%{http_code}", "-X", method, url]
        if token:
            command += ["-H", f"Authorization: Bearer {token}"]
        if body is not None:
            command += [
                "-H",
                "Content-Type: application/json",
                "-d",
                json.dumps(body, ensure_ascii=False),
            ]
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
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
        display_command = [
            "Authorization: Bearer <redacted>"
            if item.startswith("Authorization: Bearer ")
            else item
            for item in command
        ]
        return {
            "status": status,
            "body": response_body,
            "data": data,
            "curl": shell_join(display_command),
        }

    @staticmethod
    def get(path, token=None):
        return Curl.request("GET", path, token=token)

    @staticmethod
    def post(path, body=None, token=None):
        return Curl.request("POST", path, body=body, token=token)

    @staticmethod
    def delete(path, token=None):
        return Curl.request("DELETE", path, token=token)


def expect_status(response, expected, description):
    if response["status"] != expected:
        fail(
            f"{description} 期望 {expected}，实际 {response['status']}: "
            f"{response['body']}"
        )


def write_doc(
    filename,
    method,
    path,
    description,
    request_body,
    response,
    params_desc=None,
    note=None,
):
    os.makedirs(DOCS_DIR, exist_ok=True)
    lines = [f"# {method} {path}", "", description, ""]
    if params_desc:
        lines += [
            "## Parameters",
            "",
            "| 参数 | 类型 | 必填 | 说明 |",
            "|------|------|------|------|",
        ]
        for item in params_desc:
            lines.append(
                f"| {item['name']} | {item['type']} | {item['required']} | {item['desc']} |"
            )
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
    with open(os.path.join(DOCS_DIR, filename), "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    DOC_ROWS.append((method, path, response["status"], "PASS", filename))


def write_ws_doc(result):
    filename = "11_group_message_ws.md"
    lines = [
        "# WebSocket 群消息复用链路",
        "",
        "通过现有 `/ws/im`、`CHAT_MESSAGE`、`MESSAGE_ACK` 和 `CONVERSATION_UPDATE` 验证群成员消息收发。",
        "",
        f"WebSocket URL: `{WS_URL}`",
        "",
        "## Result",
        "",
        "```json",
        json.dumps(result, ensure_ascii=False, indent=2),
        "```",
        "",
        "> 本步骤不新增群消息协议；二进制帧编码完全沿用现有消息链路。",
    ]
    with open(os.path.join(DOCS_DIR, filename), "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    DOC_ROWS.append(("WS", "/ws/im", 101, "PASS", filename))


def write_link():
    os.makedirs(DOCS_DIR, exist_ok=True)
    lines = [
        "# group - API test link",
        "",
        f"Base URL: `{BASE_URL}`",
        f"Generated at: `{datetime.now().isoformat(timespec='seconds')}`",
        "",
        "| # | Interface | Status | Result | Doc |",
        "|---|-----------|--------|--------|-----|",
    ]
    for index, (method, path, status, result, filename) in enumerate(DOC_ROWS, start=1):
        lines.append(
            f"| {index} | `{method} {path}` | `{status}` | {result} | "
            f"[{filename}]({filename}) |"
        )
    with open(os.path.join(DOCS_DIR, "00_link.md"), "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")


def redact_existing_docs():
    pattern = re.compile(r"Authorization: Bearer [^'\s]+")
    for filename in os.listdir(DOCS_DIR):
        if not filename.endswith(".md"):
            continue
        path = os.path.join(DOCS_DIR, filename)
        with open(path, encoding="utf-8") as file:
            content = file.read()
        redacted = pattern.sub("Authorization: Bearer <redacted>", content)
        if redacted != content:
            with open(path, "w", encoding="utf-8") as file:
                file.write(redacted)


def login_by_sms(phone):
    sms = Curl.post("/auth/sms", {"phone": phone})
    expect_status(sms, 200, "发送短信验证码")
    code = sms["data"].get("code")
    if not code:
        fail("短信接口未返回调试 code，确认 EXPOSE_DEBUG_SMS_CODE=true")
    login = Curl.post(
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


def ensure_friend(owner_token, owner_id, friend_token, friend_id):
    cleanup = Curl.delete(f"/api/friends/{friend_id}", owner_token)
    if cleanup["status"] not in (200, 404):
        fail(f"预清理好友关系失败: {cleanup['status']} {cleanup['body']}")
    request = Curl.post(
        "/api/friends/requests",
        {"to_user_id": friend_id, "message": "群聊链路前置好友"},
        owner_token,
    )
    expect_status(request, 200, "发送前置好友申请")
    received = Curl.get("/api/friends/requests/received", friend_token)
    expect_status(received, 200, "查询前置好友申请")
    item = find_request(received["data"], owner_id)
    if not item:
        fail(f"未找到 {owner_id} -> {friend_id} 的好友申请")
    accepted = Curl.post(f"/api/friends/requests/{item['id']}/accept", token=friend_token)
    expect_status(accepted, 200, "接受前置好友申请")


def encode_varint(value):
    output = bytearray()
    while value > 0x7F:
        output.append((value & 0x7F) | 0x80)
        value >>= 7
    output.append(value)
    return bytes(output)


def read_varint(data, index):
    shift = 0
    value = 0
    while True:
        byte = data[index]
        index += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, index
        shift += 7


def field_varint(field, value):
    return encode_varint(field << 3) + encode_varint(value)


def field_bytes(field, value):
    if isinstance(value, str):
        value = value.encode("utf-8")
    return encode_varint((field << 3) | 2) + encode_varint(len(value)) + value


def encode_frame(frame_type, payload=b""):
    return field_varint(1, frame_type) + field_bytes(2, payload)


def decode_message(data):
    index = 0
    result = {}
    while index < len(data):
        key, index = read_varint(data, index)
        field = key >> 3
        wire_type = key & 7
        if wire_type == 0:
            result[field], index = read_varint(data, index)
        elif wire_type == 2:
            size, index = read_varint(data, index)
            result[field] = data[index : index + size]
            index += size
        else:
            raise AssertionError(f"unsupported wire type: {wire_type}")
    return result


def decode_frame(data):
    decoded = decode_message(data)
    return decoded.get(1), decoded.get(2, b"")


def auth_payload(token):
    return field_bytes(1, token)


def send_message_payload(conversation_id, content):
    return b"".join(
        [
            field_bytes(1, conversation_id),
            field_varint(2, 0),
            field_bytes(3, content),
            field_bytes(5, f"group-link-{datetime.now().timestamp()}"),
        ]
    )


class WsClient:
    def __init__(self, url):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "ws":
            raise AssertionError(f"unsupported ws scheme: {parsed.scheme}")
        self.host = parsed.hostname or "127.0.0.1"
        self.port = parsed.port or 80
        self.path = parsed.path or "/"
        self.sock = socket.create_connection((self.host, self.port), timeout=10)
        self.sock.settimeout(10)
        self._handshake()

    def _handshake(self):
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {self.path} HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        ).encode("ascii")
        self.sock.sendall(request)
        response = self._read_until(b"\r\n\r\n")
        if b" 101 " not in response.split(b"\r\n", 1)[0]:
            raise AssertionError(f"websocket handshake failed: {response!r}")

    def _read_until(self, marker):
        data = bytearray()
        while marker not in data:
            chunk = self.sock.recv(1)
            if not chunk:
                raise AssertionError("socket closed")
            data.extend(chunk)
        return bytes(data)

    def _read_exact(self, size):
        data = bytearray()
        while len(data) < size:
            chunk = self.sock.recv(size - len(data))
            if not chunk:
                raise AssertionError("socket closed")
            data.extend(chunk)
        return bytes(data)

    def send_binary(self, payload):
        header = bytearray([0x82])
        size = len(payload)
        if size < 126:
            header.append(0x80 | size)
        elif size <= 0xFFFF:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", size))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", size))
        mask = os.urandom(4)
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(bytes(header) + mask + masked)

    def recv_binary(self):
        first, second = self._read_exact(2)
        opcode = first & 0x0F
        masked = bool(second & 0x80)
        size = second & 0x7F
        if size == 126:
            size = struct.unpack("!H", self._read_exact(2))[0]
        elif size == 127:
            size = struct.unpack("!Q", self._read_exact(8))[0]
        mask = self._read_exact(4) if masked else b""
        payload = self._read_exact(size)
        if masked:
            payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        if opcode == 8:
            raise AssertionError("websocket closed")
        if opcode != 2:
            return self.recv_binary()
        return payload

    def close(self):
        try:
            mask = os.urandom(4)
            self.sock.sendall(b"\x88\x80" + mask)
        finally:
            self.sock.close()


def authenticate(token):
    client = WsClient(WS_URL)
    client.send_binary(encode_frame(AUTH, auth_payload(token)))
    frame_type, payload = decode_frame(client.recv_binary())
    if frame_type != AUTH_RESULT:
        raise AssertionError(f"expected AUTH_RESULT, got {frame_type}")
    result = decode_message(payload)
    if result.get(1) != 1:
        raise AssertionError(f"auth failed: {result}")
    return client


def read_until(client, expected_type):
    while True:
        frame_type, payload = decode_frame(client.recv_binary())
        if frame_type == expected_type:
            return decode_message(payload)


def verify_group_message(sender_token, receiver_token, conversation_id):
    sender = authenticate(sender_token)
    receiver = authenticate(receiver_token)
    content = f"群聊复用链路 {datetime.now().isoformat(timespec='seconds')}"
    try:
        sender.send_binary(
            encode_frame(CHAT_MESSAGE, send_message_payload(conversation_id, content))
        )
        ack = read_until(sender, MESSAGE_ACK)
        delivered = read_until(receiver, CHAT_MESSAGE)
        receiver_update = read_until(receiver, CONVERSATION_UPDATE)
        result = {
            "conversation_id": conversation_id,
            "content": delivered.get(6, b"").decode("utf-8"),
            "message_id": ack.get(1, b"").decode("utf-8"),
            "seq": ack.get(2),
            "sender_name": delivered.get(10, b"").decode("utf-8"),
            "sender_avatar": delivered.get(11, b"").decode("utf-8"),
            "receiver_unread_count": receiver_update.get(4),
            "receiver_total_unread": receiver_update.get(5),
        }
        if result["content"] != content:
            fail(f"群消息内容不匹配: {result}")
        if not result["message_id"] or not result["seq"]:
            fail(f"群消息 ACK 不完整: {result}")
        if not result["sender_name"] or not result["sender_avatar"]:
            fail(f"群消息缺少发送者资料: {result}")
        return result
    finally:
        sender.close()
        receiver.close()


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = login_by_sms(PHONE_A)
    token_b, user_b = login_by_sms(PHONE_B)
    token_c, user_c = login_by_sms(PHONE_C)
    token_d, user_d = login_by_sms(PHONE_D)
    print(f"users={user_a},{user_b},{user_c},{user_d}")

    # 前置：A 分别与 B、C 建立好友；B 与 C、D 保持非好友。
    Curl.delete(f"/api/friends/{user_c}", token_b)
    Curl.delete(f"/api/friends/{user_d}", token_b)
    ensure_friend(token_a, user_a, token_b, user_b)
    ensure_friend(token_a, user_a, token_c, user_c)

    valid_body = {
        "type": "group",
        "name": f"群聊链路-{datetime.now().strftime('%H%M%S')}",
        "member_ids": [user_b, user_c],
    }

    step(1, "POST /conversations - 未认证创建失败")
    unauthorized = Curl.post("/conversations", valid_body)
    expect_status(unauthorized, 401, "未认证创建群聊")
    ok()
    write_doc(
        "01_create_unauthorized.md",
        "POST",
        "/conversations",
        "未携带 Bearer Token 创建群聊时返回 401。",
        valid_body,
        unauthorized,
    )

    step(2, "POST /conversations - 创建群聊")
    created = Curl.post("/conversations", valid_body, token_a)
    expect_status(created, 200, "创建群聊")
    conversation = created["data"]
    conversation_id = conversation.get("id")
    if not conversation_id or conversation.get("type") != 1:
        fail(f"创建响应会话字段不正确: {created['body']}")
    if conversation.get("owner_id") != str(user_a):
        fail(f"创建响应 owner_id 不正确: {created['body']}")
    if len(conversation.get("member_avatars", [])) != 3:
        fail(f"创建响应 member_avatars 不正确: {created['body']}")
    ok()
    write_doc(
        "02_create_group.md",
        "POST",
        "/conversations",
        "从当前用户好友中选择至少两人创建群聊，服务端自动加入群主。",
        valid_body,
        created,
        params_desc=[
            {"name": "type", "type": "string", "required": "是", "desc": "固定为 group"},
            {"name": "name", "type": "string", "required": "是", "desc": "1～100 字群名"},
            {"name": "member_ids", "type": "int[]", "required": "是", "desc": "2～199 个好友 ID"},
        ],
    )

    step(3, "GET /conversations?type=1 - 查询我的群聊")
    group_list = Curl.get("/conversations?type=1&limit=100&offset=0", token_a)
    expect_status(group_list, 200, "查询我的群聊")
    if not any(item.get("id") == conversation_id for item in group_list["data"]):
        fail(f"群列表缺少新群聊: {group_list['body']}")
    for token in (token_b, token_c):
        member_list = Curl.get("/conversations?type=1&limit=100&offset=0", token)
        expect_status(member_list, 200, "成员查询群聊")
        if not any(item.get("id") == conversation_id for item in member_list["data"]):
            fail("群成员列表缺少新群聊")
    ok()
    write_doc(
        "03_list_groups.md",
        "GET",
        "/conversations?type=1&limit=100&offset=0",
        "只查询当前用户有效加入的群聊，保留现有分页与排序。",
        None,
        group_list,
        params_desc=[
            {"name": "type", "type": "int", "required": "否", "desc": "1 表示群聊，0 表示私聊"},
            {"name": "limit", "type": "int", "required": "否", "desc": "1～100"},
            {"name": "offset", "type": "int", "required": "否", "desc": "分页偏移"},
        ],
    )

    step(4, "GET /conversations/{id} - 查询群聊详情")
    detail = Curl.get(f"/conversations/{conversation_id}", token_b)
    expect_status(detail, 200, "查询群聊详情")
    if detail["data"].get("owner_id") != str(user_a):
        fail(f"群聊详情 owner_id 不正确: {detail['body']}")
    ok()
    write_doc(
        "04_group_detail.md",
        "GET",
        "/conversations/{id}",
        "群成员查询群聊详情，响应包含群主和组合头像成员数据。",
        None,
        detail,
        params_desc=[{"name": "id", "type": "uuid", "required": "是", "desc": "群会话 ID"}],
    )

    error_cases = [
        (
            5,
            "05_too_few_members.md",
            "成员不足",
            {"type": "group", "name": "人数不足", "member_ids": [user_b]},
        ),
        (
            6,
            "06_duplicate_members.md",
            "重复成员",
            {"type": "group", "name": "重复成员", "member_ids": [user_b, user_b]},
        ),
        (
            7,
            "07_owner_in_members.md",
            "成员包含群主本人",
            {"type": "group", "name": "包含本人", "member_ids": [user_a, user_b]},
        ),
        (
            8,
            "08_non_friend_member.md",
            "包含非好友",
            {"type": "group", "name": "非好友", "member_ids": [user_a, user_c]},
        ),
    ]
    for number, filename, description, body in error_cases:
        step(number, f"POST /conversations - {description}失败")
        token = token_b if filename == "08_non_friend_member.md" else token_a
        response = Curl.post("/conversations", body, token)
        expect_status(response, 400, description)
        ok()
        write_doc(
            filename,
            "POST",
            "/conversations",
            f"{description}时服务端拒绝创建且不写入半成品会话。",
            body,
            response,
        )

    step(9, "GET /conversations?type=2 - 非法类型失败")
    invalid_filter = Curl.get("/conversations?type=2", token_a)
    expect_status(invalid_filter, 400, "非法会话类型")
    ok()
    write_doc(
        "09_invalid_type_filter.md",
        "GET",
        "/conversations?type=2",
        "会话列表只接受 type=0、type=1 或省略 type。",
        None,
        invalid_filter,
    )

    step(10, "GET /conversations/{id} - 非成员不可查询")
    forbidden_detail = Curl.get(f"/conversations/{conversation_id}", token_d)
    expect_status(forbidden_detail, 404, "非成员查询群聊")
    ok()
    write_doc(
        "10_non_member_detail.md",
        "GET",
        "/conversations/{id}",
        "非群成员查询详情时按不存在处理，避免暴露群信息。",
        None,
        forbidden_detail,
    )

    step(11, "WS /ws/im - 复用现有群消息链路")
    ws_result = verify_group_message(token_a, token_b, conversation_id)
    ok()
    write_ws_doc(ws_result)

    step(12, "GET /conversations/{id}/messages - 群消息历史回放")
    history = Curl.get(
        f"/conversations/{conversation_id}/messages?before_seq=999999&limit=10",
        token_c,
    )
    expect_status(history, 200, "查询群消息历史")
    if not any(item.get("id") == ws_result["message_id"] for item in history["data"]):
        fail(f"群消息历史缺少刚发送的消息: {history['body']}")
    ok()
    write_doc(
        "12_group_message_history.md",
        "GET",
        "/conversations/{id}/messages?before_seq=999999&limit=10",
        "群成员通过现有历史消息接口回放群消息。",
        None,
        history,
        note="该消息由步骤 11 的现有 WebSocket CHAT_MESSAGE 链路写入。",
    )

    write_link()
    print(
        json.dumps(
            {
                "ok": True,
                "conversation_id": conversation_id,
                "owner_id": user_a,
                "member_ids": [user_b, user_c],
                "message_id": ws_result["message_id"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    if "--redact-docs" in sys.argv:
        redact_existing_docs()
    else:
        main()
