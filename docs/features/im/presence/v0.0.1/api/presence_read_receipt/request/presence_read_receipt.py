#!/usr/bin/env python3
"""在线状态与已读回执 API/WS 测试链。"""

import importlib.util
import json
import os
import socket
import time
from datetime import datetime
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
DOCS_DIR = SCRIPT_DIR.parent / "doc"
HELPER_SCRIPT = (
    SCRIPT_DIR.parents[4]
    / "group"
    / "v0.0.1"
    / "api"
    / "group"
    / "request"
    / "group.py"
)
spec = importlib.util.spec_from_file_location("presence_link_helpers", HELPER_SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"无法加载测试链帮助器: {HELPER_SCRIPT}")
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
helpers.DOCS_DIR = str(DOCS_DIR)
helpers.DOC_ROWS = []

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
PHONE_A = os.environ.get("PRESENCE_PHONE_A", "13800995001")
PHONE_B = os.environ.get("PRESENCE_PHONE_B", "13800995002")
PHONE_C = os.environ.get("PRESENCE_PHONE_C", "13800995003")
helpers.BASE_URL = BASE_URL
helpers.WS_URL = WS_URL

Curl = helpers.Curl
step = helpers.step
ok = helpers.ok
fail = helpers.fail
expect_status = helpers.expect_status
write_doc = helpers.write_doc

CHAT_MESSAGE = 4
MESSAGE_ACK = 5
USER_ONLINE = 12
USER_OFFLINE = 13
ONLINE_LIST = 14
READ_RECEIPT = 15


def write_ws_doc(filename, title, result, note=None):
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# {title}",
        "",
        f"WebSocket URL: `{WS_URL}`",
        "",
        "## Result",
        "",
        "```json",
        json.dumps(result, ensure_ascii=False, indent=2),
        "```",
    ]
    if note:
        lines += ["", f"> {note}"]
    (DOCS_DIR / filename).write_text("\n".join(lines) + "\n", encoding="utf-8")
    helpers.DOC_ROWS.append(("WS", "/ws/im", 101, "PASS", filename))


def write_link():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# presence_read_receipt - API test link",
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


def read_presence(client, expected_type):
    payload = helpers.read_until(client, expected_type)
    return payload.get(1, 0)


def read_online_list(client):
    payload = helpers.read_until(client, ONLINE_LIST)
    raw = payload.get(1, b"")
    if isinstance(raw, int):
        return [raw]
    user_ids = []
    index = 0
    while index < len(raw):
        user_id, index = helpers.read_varint(raw, index)
        user_ids.append(user_id)
    return user_ids


def expect_no_presence(client, forbidden_type, description):
    old_timeout = client.sock.gettimeout()
    client.sock.settimeout(0.6)
    try:
        while True:
            frame_type, _ = helpers.decode_frame(client.recv_binary())
            if frame_type == forbidden_type:
                fail(description)
    except socket.timeout:
        return
    finally:
        client.sock.settimeout(old_timeout)


def read_receipt_payload(conversation_id, read_seq):
    return b"".join(
        [
            helpers.field_bytes(1, conversation_id),
            helpers.field_varint(2, 999999),
            helpers.field_varint(3, 999999),
            helpers.field_varint(4, read_seq),
        ]
    )


def parse_receipt(payload):
    return {
        "conversation_id": payload.get(1, b"").decode("utf-8"),
        "reader_id": payload.get(2, 0),
        "previous_read_seq": payload.get(3, 0),
        "read_seq": payload.get(4, 0),
    }


def find_private_conversation(token, peer_id):
    response = Curl.get("/conversations?limit=100", token)
    expect_status(response, 200, "查询私聊会话")
    for conversation in response["data"]:
        if (
            int(conversation.get("type", -1)) == 0
            and int(conversation.get("peer_user_id", 0)) == peer_id
        ):
            return conversation["id"]
    fail(f"未找到与 {peer_id} 的私聊会话")


def main():
    print(f"BASE_URL={BASE_URL}")
    token_a, user_a = helpers.login_by_sms(PHONE_A)
    token_b, user_b = helpers.login_by_sms(PHONE_B)
    token_c, user_c = helpers.login_by_sms(PHONE_C)
    helpers.ensure_friend(token_a, user_a, token_b, user_b)
    conversation_id = find_private_conversation(token_a, user_b)

    clients = []
    try:
        step(1, "WS /ws/im - 好友上线与在线列表")
        ws_a = helpers.authenticate(token_a)
        clients.append(ws_a)
        read_online_list(ws_a)
        ws_b1 = helpers.authenticate(token_b)
        clients.append(ws_b1)
        online_b = read_online_list(ws_b1)
        online_event = read_presence(ws_a, USER_ONLINE)
        if user_a not in online_b or online_event != user_b:
            fail(f"在线初始化错误: list={online_b}, event={online_event}")
        ok()
        write_ws_doc(
            "01_friend_online.md",
            "好友上线与在线列表",
            {"online_list_for_b": online_b, "online_event_for_a": online_event},
        )

        step(2, "WS /ws/im - 多端仅末连触发下线")
        ws_b2 = helpers.authenticate(token_b)
        clients.append(ws_b2)
        read_online_list(ws_b2)
        ws_b1.close()
        clients.remove(ws_b1)
        time.sleep(0.15)
        expect_no_presence(ws_a, USER_OFFLINE, "关闭一个设备时不应收到下线事件")
        ws_b2.close()
        clients.remove(ws_b2)
        offline_event = read_presence(ws_a, USER_OFFLINE)
        if offline_event != user_b:
            fail(f"下线账号错误: {offline_event}")
        ok()
        write_ws_doc(
            "02_multi_device_offline.md",
            "多端末连下线",
            {"first_disconnect_event": "none", "last_disconnect_user_id": offline_event},
        )

        step(3, "WS /ws/im - 发送消息并上报已读位置")
        ws_b = helpers.authenticate(token_b)
        clients.append(ws_b)
        read_online_list(ws_b)
        read_presence(ws_a, USER_ONLINE)
        content = f"已读链路 {datetime.now().isoformat(timespec='seconds')}"
        ws_a.send_binary(
            helpers.encode_frame(
                CHAT_MESSAGE,
                helpers.send_message_payload(conversation_id, content),
            )
        )
        ack = helpers.read_until(ws_a, MESSAGE_ACK)
        delivered = helpers.read_until(ws_b, CHAT_MESSAGE)
        message_id = ack.get(1, b"").decode("utf-8")
        read_seq = ack.get(2, 0)
        if delivered.get(1, b"").decode("utf-8") != message_id or read_seq < 1:
            fail(f"消息 ACK/投递不一致: ack={ack}, delivered={delivered}")
        ws_b.send_binary(
            helpers.encode_frame(
                READ_RECEIPT,
                read_receipt_payload(conversation_id, read_seq),
            )
        )
        receipt = parse_receipt(helpers.read_until(ws_a, READ_RECEIPT))
        if receipt["reader_id"] != user_b or receipt["read_seq"] != read_seq:
            fail(f"服务端未重建可信回执: {receipt}")
        ok()
        write_ws_doc(
            "03_read_receipt_ws.md",
            "消息已读回执",
            {"message_id": message_id, **receipt},
            note="脚本故意伪造 reader_id/previous_read_seq，结果必须以认证账号和数据库旧值为准。",
        )

        step(4, "GET /conversations/{id}/messages - 历史返回 read_count")
        history = Curl.get(f"/conversations/{conversation_id}/messages", token_a)
        expect_status(history, 200, "读取消息历史")
        target = next(
            (item for item in history["data"] if item.get("id") == message_id),
            None,
        )
        if target is None or target.get("read_count") != 1:
            fail(f"历史 read_count 错误: {history['body']}")
        ok()
        write_doc(
            "04_history_read_count.md",
            "GET",
            "/conversations/{id}/messages",
            "发送者读取历史并获得权威 read_count。",
            None,
            history,
        )

        step(5, "GET /conversations/{id}/messages/{message_id}/read-status")
        status = Curl.get(
            f"/conversations/{conversation_id}/messages/{message_id}/read-status",
            token_a,
        )
        expect_status(status, 200, "读取单消息已读详情")
        read_ids = {int(item["user_id"]) for item in status["data"]["read_members"]}
        if user_b not in read_ids or status["data"]["unread_members"]:
            fail(f"已读成员分组错误: {status['body']}")
        ok()
        write_doc(
            "05_message_read_status.md",
            "GET",
            "/conversations/{conversation_id}/messages/{message_id}/read-status",
            "仅消息发送者查看当前成员的已读与未读分组。",
            None,
            status,
        )

        step(6, "GET read-status - 非发送者越权失败")
        forbidden = Curl.get(
            f"/conversations/{conversation_id}/messages/{message_id}/read-status",
            token_b,
        )
        expect_status(forbidden, 403, "非发送者读取详情")
        ok()
        write_doc(
            "06_read_status_forbidden.md",
            "GET",
            "/conversations/{conversation_id}/messages/{message_id}/read-status",
            "非消息发送者读取成员级回执详情返回 403。",
            None,
            forbidden,
        )

        step(7, "GET messages - 非成员读取会话失败")
        non_member = Curl.get(f"/conversations/{conversation_id}/messages", token_c)
        expect_status(non_member, 404, "非成员读取消息")
        ok()
        write_doc(
            "07_non_member_history.md",
            "GET",
            "/conversations/{id}/messages",
            "非会话成员不能读取历史，也不能建立合法已读位置。",
            None,
            non_member,
        )
    finally:
        for client in clients:
            try:
                client.close()
            except OSError:
                pass
        write_link()
        helpers.redact_existing_docs()


if __name__ == "__main__":
    main()
