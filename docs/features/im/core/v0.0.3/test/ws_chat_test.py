#!/usr/bin/env python3
import base64
import socket
import struct
import json
import os
import urllib.request
import urllib.parse


BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
PASSWORD = os.environ.get("PASSWORD", "111111")
SENDER_PHONE = os.environ.get("SENDER_PHONE", "13800010001")
RECEIVER_PHONE = os.environ.get("RECEIVER_PHONE", "13800010002")

PING = 0
PONG = 1
AUTH = 2
AUTH_RESULT = 3
CHAT_MESSAGE = 4
MESSAGE_ACK = 5
CONVERSATION_UPDATE = 6


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
            self.sock.sendall(b"\x88\x80" + os.urandom(4))
        finally:
            self.sock.close()


def http_json(method, path, body=None, token=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{BASE_URL}{path}", data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def login(phone):
    data = http_json(
        "POST",
        "/auth/login",
        {"login_type": "password", "identifier": phone, "password": PASSWORD},
    )
    return data["token"], data["account_id"]


def encode_varint(value):
    out = bytearray()
    while value > 0x7F:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


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


def frame(frame_type, payload=b""):
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
            value = data[index : index + size]
            index += size
            result[field] = value
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
        ]
    )


def authenticate(token):
    ws = WsClient(WS_URL)
    ws.send_binary(frame(AUTH, auth_payload(token)))
    frame_type, payload = decode_frame(ws.recv_binary())
    if frame_type != AUTH_RESULT:
        raise AssertionError(f"expected AUTH_RESULT, got {frame_type}")
    result = decode_message(payload)
    if result.get(1) != 1:
        raise AssertionError(f"auth failed: {result}")
    return ws


def read_until(ws, expected_type):
    while True:
        frame_type, payload = decode_frame(ws.recv_binary())
        if frame_type == expected_type:
            return decode_message(payload)


def main():
    sender_token, _ = login(SENDER_PHONE)
    receiver_token, _ = login(RECEIVER_PHONE)
    conversations = http_json("GET", "/conversations?limit=1&offset=0", token=sender_token)
    if not conversations:
        raise AssertionError("seeded conversation list is empty")
    conversation_id = conversations[0]["id"]

    sender_ws = authenticate(sender_token)
    receiver_ws = authenticate(receiver_token)
    try:
        content = "ws test message"
        sender_ws.send_binary(frame(CHAT_MESSAGE, send_message_payload(conversation_id, content)))

        ack = read_until(sender_ws, MESSAGE_ACK)
        delivered = read_until(receiver_ws, CHAT_MESSAGE)
        sender_update = read_until(sender_ws, CONVERSATION_UPDATE)
        receiver_update = read_until(receiver_ws, CONVERSATION_UPDATE)

        message_id = ack.get(1, b"").decode("utf-8")
        seq = ack.get(2)
        delivered_content = delivered.get(6, b"").decode("utf-8")
        sender_name = delivered.get(10, b"").decode("utf-8")
        sender_avatar = delivered.get(11, b"").decode("utf-8")
        sender_total_unread = sender_update.get(5)
        receiver_total_unread = receiver_update.get(5)
        if not message_id or not seq:
            raise AssertionError(f"invalid ack: {ack}")
        if delivered_content != content:
            raise AssertionError(f"unexpected delivered content: {delivered_content}")
        if not sender_name:
            raise AssertionError(f"missing sender_name: {delivered}")
        if not sender_avatar:
            raise AssertionError(f"missing sender_avatar: {delivered}")
        if sender_total_unread is None:
            raise AssertionError(f"missing sender total_unread: {sender_update}")
        if receiver_total_unread is None:
            raise AssertionError(f"missing receiver total_unread: {receiver_update}")

        history = http_json(
            "GET",
            f"/conversations/{conversation_id}/messages?before_seq=999999&limit=5",
            token=sender_token,
        )
        if not history or history[0]["content"] != content:
            raise AssertionError(f"history did not contain sent message: {history}")

        print(
            json.dumps(
                {
                    "ok": True,
                    "message_id": message_id,
                    "seq": seq,
                    "sender_name": sender_name,
                    "sender_avatar": sender_avatar,
                    "sender_total_unread": sender_total_unread,
                    "receiver_total_unread": receiver_total_unread,
                    "sender_update_fields": sorted(sender_update.keys()),
                    "receiver_update_fields": sorted(receiver_update.keys()),
                },
                ensure_ascii=True,
            )
        )
    finally:
        sender_ws.close()
        receiver_ws.close()


if __name__ == "__main__":
    main()
