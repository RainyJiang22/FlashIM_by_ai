#!/usr/bin/env python3
import base64
import json
import os
import shutil
import socket
import struct
import subprocess
import sys
import urllib.parse
from datetime import datetime


BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
PHONE_A = os.environ.get("SEARCH_PHONE_A", "13800994001")
PHONE_B = os.environ.get("SEARCH_PHONE_B", "13800994002")
PHONE_C = os.environ.get("SEARCH_PHONE_C", "13800994003")
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
        command = [
            CURL_BIN,
            "-sS",
            "-w",
            "\n%{http_code}",
            "-X",
            method,
            f"{BASE_URL}{path}",
        ]
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
    def put(path, body=None, token=None):
        return Curl.request("PUT", path, body=body, token=token)

    @staticmethod
    def delete(path, token=None):
        return Curl.request("DELETE", path, token=token)


def expect_status(response, expected, description):
    if response["status"] != expected:
        fail(
            f"{description} 期望 {expected}，实际 {response['status']}: "
            f"{response['body']}"
        )


def write_doc(filename, method, path, description, response, params_desc=None, note=None):
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


def write_link():
    lines = [
        "# search - API test link",
        "",
        f"Base URL: `{BASE_URL}`",
        f"Generated at: `{datetime.now().isoformat(timespec='seconds')}`",
        "",
        "| # | Interface | Status | Result | Doc |",
        "|---|-----------|--------|--------|-----|",
    ]
    for index, (method, path, status, result, filename) in enumerate(DOC_ROWS, 1):
        lines.append(
            f"| {index} | `{method} {path}` | `{status}` | {result} | "
            f"[{filename}]({filename}) |"
        )
    with open(os.path.join(DOCS_DIR, "00_link.md"), "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")


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


def ensure_friend(owner_token, owner_id, friend_token, friend_id):
    cleanup = Curl.delete(f"/api/friends/{friend_id}", owner_token)
    if cleanup["status"] not in (200, 404):
        fail(f"预清理好友关系失败: {cleanup['status']} {cleanup['body']}")
    sent = Curl.post(
        "/api/friends/requests",
        {"to_user_id": friend_id, "message": "综合搜索链路前置好友"},
        owner_token,
    )
    expect_status(sent, 200, "发送前置好友申请")
    received = Curl.get("/api/friends/requests/received", friend_token)
    expect_status(received, 200, "查询前置好友申请")
    request = next(
        (
            item
            for item in received["data"]
            if int(item["from_user"]["account_id"]) == owner_id
        ),
        None,
    )
    if not request:
        fail(f"未找到 {owner_id} -> {friend_id} 的好友申请")
    accepted = Curl.post(f"/api/friends/requests/{request['id']}/accept", token=friend_token)
    expect_status(accepted, 200, "接受前置好友申请")


def encode_varint(value):
    output = bytearray()
    while value > 0x7F:
        output.append((value & 0x7F) | 0x80)
        value >>= 7
    output.append(value)
    return bytes(output)


def field_varint(field, value):
    return encode_varint(field << 3) + encode_varint(value)


def field_bytes(field, value):
    if isinstance(value, str):
        value = value.encode("utf-8")
    return encode_varint((field << 3) | 2) + encode_varint(len(value)) + value


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
            fail(f"不支持的 protobuf wire type: {wire_type}")
    return result


class WsClient:
    def __init__(self):
        parsed = urllib.parse.urlparse(WS_URL)
        self.host = parsed.hostname or "127.0.0.1"
        self.port = parsed.port or 80
        self.path = parsed.path or "/"
        self.socket = socket.create_connection((self.host, self.port), timeout=10)
        self.socket.settimeout(10)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {self.path} HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        ).encode("ascii")
        self.socket.sendall(request)
        response = self._read_until(b"\r\n\r\n")
        if b" 101 " not in response.split(b"\r\n", 1)[0]:
            fail(f"WebSocket 握手失败: {response!r}")

    def _read_exact(self, size):
        data = bytearray()
        while len(data) < size:
            data.extend(self.socket.recv(size - len(data)))
        return bytes(data)

    def _read_until(self, marker):
        data = bytearray()
        while marker not in data:
            data.extend(self.socket.recv(1))
        return bytes(data)

    def send(self, frame_type, payload):
        raw = field_varint(1, frame_type) + field_bytes(2, payload)
        mask = os.urandom(4)
        size = len(raw)
        header = bytearray([0x82])
        if size < 126:
            header.append(0x80 | size)
        elif size <= 0xFFFF:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", size))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", size))
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(raw))
        self.socket.sendall(bytes(header) + mask + masked)

    def receive(self):
        first, second = self._read_exact(2)
        size = second & 0x7F
        if size == 126:
            size = struct.unpack("!H", self._read_exact(2))[0]
        elif size == 127:
            size = struct.unpack("!Q", self._read_exact(8))[0]
        mask = self._read_exact(4) if second & 0x80 else b""
        payload = self._read_exact(size)
        if mask:
            payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        if first & 0x0F != 2:
            return self.receive()
        decoded = decode_message(payload)
        return decoded.get(1), decoded.get(2, b"")

    def close(self):
        self.socket.close()


def send_searchable_message(token, conversation_id, content):
    client = WsClient()
    client.send(AUTH, field_bytes(1, token))
    frame_type, payload = client.receive()
    auth = decode_message(payload)
    if frame_type != AUTH_RESULT or auth.get(1) != 1:
        fail(f"WebSocket 鉴权失败: type={frame_type}, payload={auth}")
    message = b"".join(
        [
            field_bytes(1, conversation_id),
            field_varint(2, 0),
            field_bytes(3, content),
            field_bytes(5, f"search-link-{datetime.now().timestamp()}"),
        ]
    )
    client.send(CHAT_MESSAGE, message)
    while True:
        frame_type, payload = client.receive()
        if frame_type == MESSAGE_ACK:
            ack = decode_message(payload)
            if not ack.get(1):
                fail(f"消息 ACK 缺少 message_id: {ack}")
            break
    client.close()


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = login_by_sms(PHONE_A)
    token_b, user_b = login_by_sms(PHONE_B)
    token_c, user_c = login_by_sms(PHONE_C)
    marker = datetime.now().strftime("%m%d%H%M%S")
    owner_name = f"搜索发起人{marker}"
    friend_name = f"搜索好友{marker}"
    group_name = f"综合搜索群{marker}"
    message_keyword = f"needle{marker}"
    for token, nickname in [
        (token_a, owner_name),
        (token_b, friend_name),
        (token_c, f"搜索成员{marker}"),
    ]:
        profile = Curl.put("/user/profile", {"nickname": nickname}, token)
        expect_status(profile, 200, "更新搜索链路昵称")
    ensure_friend(token_a, user_a, token_b, user_b)
    ensure_friend(token_a, user_a, token_c, user_c)
    created = Curl.post(
        "/conversations",
        {"type": "group", "name": group_name, "member_ids": [user_b, user_c]},
        token_a,
    )
    expect_status(created, 200, "创建搜索链路群聊")
    conversation_id = created["data"]["id"]
    send_searchable_message(token_a, conversation_id, f"普通消息 {message_keyword}")

    step(1, "GET /api/friends/search - 仅搜索好友")
    encoded_friend = urllib.parse.quote(friend_name)
    friends = Curl.get(f"/api/friends/search?q={encoded_friend}", token_a)
    expect_status(friends, 200, "搜索好友")
    if [int(item["account_id"]) for item in friends["data"]] != [user_b]:
        fail(f"好友搜索范围错误: {friends['body']}")
    ok()
    write_doc(
        "01_search_friends.md",
        "GET",
        "/api/friends/search?q=<keyword>",
        "按昵称或完整闪讯号搜索当前用户的好友。",
        friends,
        [{"name": "q", "type": "string", "required": "是", "desc": "1～100 字符关键词"}],
    )

    step(2, "GET /api/conversations/search-joined-groups - 仅搜索已加入群")
    encoded_group = urllib.parse.quote(group_name)
    groups = Curl.get(
        f"/api/conversations/search-joined-groups?q={encoded_group}", token_a
    )
    expect_status(groups, 200, "搜索已加入群")
    if not any(item["id"] == conversation_id for item in groups["data"]):
        fail(f"已加入群搜索缺少目标群: {groups['body']}")
    ok()
    write_doc(
        "02_search_joined_groups.md",
        "GET",
        "/api/conversations/search-joined-groups?q=<keyword>",
        "搜索当前用户已加入且未解散的群聊。",
        groups,
        [{"name": "q", "type": "string", "required": "是", "desc": "群名关键词"}],
    )

    step(3, "GET /api/messages/search - 跨会话按会话分组")
    global_search = Curl.get(f"/api/messages/search?q={message_keyword}", token_a)
    expect_status(global_search, 200, "跨会话搜索消息")
    target = next(
        (
            item
            for item in global_search["data"]
            if item["conversation"]["id"] == conversation_id
        ),
        None,
    )
    if not target or target["match_count"] != 1 or len(target["messages"]) != 1:
        fail(f"消息分组或系统消息过滤错误: {global_search['body']}")
    ok()
    write_doc(
        "03_search_messages.md",
        "GET",
        "/api/messages/search?q=<keyword>",
        "跨当前用户可见会话搜索普通消息，并按会话分组。",
        global_search,
        [{"name": "q", "type": "string", "required": "是", "desc": "消息内容关键词"}],
        "系统事件消息不会进入结果。",
    )

    step(4, "GET /conversations/{id}/messages/search - 会话内搜索")
    conversation_search = Curl.get(
        f"/conversations/{conversation_id}/messages/search?q={message_keyword}", token_a
    )
    expect_status(conversation_search, 200, "会话内搜索消息")
    if len(conversation_search["data"]) != 1 or conversation_search["data"][0]["msg_type"] != 0:
        fail(f"会话内消息结果错误: {conversation_search['body']}")
    ok()
    write_doc(
        "04_search_conversation_messages.md",
        "GET",
        "/conversations/{id}/messages/search?q=<keyword>",
        "在当前用户可读的指定会话内搜索普通消息。",
        conversation_search,
        [
            {"name": "id", "type": "uuid", "required": "是", "desc": "会话 ID"},
            {"name": "q", "type": "string", "required": "是", "desc": "消息内容关键词"},
        ],
    )

    step(5, "GET /api/messages/search - 空关键词失败")
    invalid = Curl.get("/api/messages/search?q=%20", token_a)
    expect_status(invalid, 400, "空关键词校验")
    ok()
    write_doc(
        "05_empty_keyword.md",
        "GET",
        "/api/messages/search?q=<blank>",
        "空白关键词返回 400。",
        invalid,
    )

    step(6, "GET /api/messages/search - 未认证失败")
    unauthorized = Curl.get(f"/api/messages/search?q={message_keyword}")
    expect_status(unauthorized, 401, "未认证搜索")
    ok()
    write_doc(
        "06_unauthorized.md",
        "GET",
        "/api/messages/search?q=<keyword>",
        "未携带 Bearer token 时返回 401。",
        unauthorized,
    )

    write_link()
    print(
        json.dumps(
            {"ok": True, "conversation_id": conversation_id, "steps": len(DOC_ROWS)},
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
