#!/usr/bin/env python3
import argparse
import base64
import json
import os
import socket
import struct
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
DEFAULT_WS_URL = os.environ.get("WS_URL", "ws://127.0.0.1:9600/ws/im")
DEFAULT_USERS_JSON = (
    Path(__file__).resolve().parents[1] / "database" / "im_seed" / "users.json"
)

AUTH = 2
AUTH_RESULT = 3
CHAT_MESSAGE = 4
MESSAGE_ACK = 5


class ScriptError(Exception):
    pass


class WsClient:
    def __init__(self, url: str) -> None:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "ws":
            raise ScriptError(f"unsupported websocket scheme: {parsed.scheme}")
        self.host = parsed.hostname or "127.0.0.1"
        self.port = parsed.port or 80
        self.path = parsed.path or "/"
        self.sock = socket.create_connection((self.host, self.port), timeout=10)
        self.sock.settimeout(10)
        self._handshake()

    def _handshake(self) -> None:
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
            raise ScriptError(f"websocket handshake failed: {response!r}")

    def _read_until(self, marker: bytes) -> bytes:
        data = bytearray()
        while marker not in data:
            chunk = self.sock.recv(1)
            if not chunk:
                raise ScriptError("socket closed during websocket handshake")
            data.extend(chunk)
        return bytes(data)

    def _read_exact(self, size: int) -> bytes:
        data = bytearray()
        while len(data) < size:
            chunk = self.sock.recv(size - len(data))
            if not chunk:
                raise ScriptError("socket closed while reading websocket frame")
            data.extend(chunk)
        return bytes(data)

    def send_binary(self, payload: bytes) -> None:
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

    def recv_binary(self) -> bytes:
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
            raise ScriptError("websocket closed by server")
        if opcode != 2:
            return self.recv_binary()
        return payload

    def close(self) -> None:
        try:
            self.sock.sendall(b"\x88\x80" + os.urandom(4))
        except OSError:
            pass
        finally:
            self.sock.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send one IM text message from account id X to account id Y.",
    )
    parser.add_argument("sender_id", type=int, help="sender account id")
    parser.add_argument("receiver_id", type=int, help="receiver account id")
    parser.add_argument("text", help="message text to send")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="HTTP base URL")
    parser.add_argument("--ws-url", default=DEFAULT_WS_URL, help="WebSocket URL")
    parser.add_argument(
        "--users-json",
        default=str(DEFAULT_USERS_JSON),
        help="path to seeded users.json for id -> credential mapping",
    )
    return parser.parse_args()


def http_json(method: str, base_url: str, path: str, body=None, token=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        method=method,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = response.read().decode("utf-8")
            status = response.status
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8")
        status = exc.code
    except urllib.error.URLError as exc:
        raise ScriptError(f"http request failed: {method} {path}: {exc}") from exc

    if status < 200 or status >= 300:
        raise ScriptError(f"{method} {path} failed: HTTP {status}: {payload}")

    return json.loads(payload) if payload else None


def load_users(path: str) -> dict[int, dict]:
    try:
        users = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ScriptError(f"users json not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ScriptError(f"users json is invalid: {path}: {exc}") from exc

    mapping: dict[int, dict] = {}
    for user in users:
        user_id = int(user["id"])
        mapping[user_id] = user
    return mapping


def login(base_url: str, identifier: str, password: str) -> dict:
    payload = {
        "login_type": "password",
        "identifier": identifier,
        "password": password,
    }
    return http_json("POST", base_url, "/auth/login", payload)


def find_private_conversation_id(
    base_url: str,
    sender_token: str,
    receiver_id: int,
    page_size: int = 100,
) -> str:
    offset = 0
    receiver_id_text = str(receiver_id)
    while True:
        conversations = http_json(
            "GET",
            base_url,
            f"/conversations?limit={page_size}&offset={offset}",
            token=sender_token,
        )
        if not isinstance(conversations, list) or not conversations:
            break
        for item in conversations:
            if str(item.get("peer_user_id", "")) == receiver_id_text:
                conversation_id = item.get("id")
                if isinstance(conversation_id, str) and conversation_id:
                    return conversation_id
        if len(conversations) < page_size:
            break
        offset += page_size
    raise ScriptError(
        "sender has no private conversation with "
        f"receiver_id={receiver_id}; seed the conversation first with "
        "scripts/database/seed_im_conversations.sh"
    )


def encode_varint(value: int) -> bytes:
    out = bytearray()
    while value > 0x7F:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def read_varint(data: bytes, index: int) -> tuple[int, int]:
    shift = 0
    value = 0
    while True:
        byte = data[index]
        index += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, index
        shift += 7


def field_varint(field: int, value: int) -> bytes:
    return encode_varint(field << 3) + encode_varint(value)


def field_bytes(field: int, value) -> bytes:
    if isinstance(value, str):
        value = value.encode("utf-8")
    return encode_varint((field << 3) | 2) + encode_varint(len(value)) + value


def frame(frame_type: int, payload: bytes = b"") -> bytes:
    return field_varint(1, frame_type) + field_bytes(2, payload)


def decode_message(data: bytes) -> dict[int, object]:
    index = 0
    result: dict[int, object] = {}
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
            raise ScriptError(f"unsupported wire type in protobuf payload: {wire_type}")
    return result


def decode_frame(data: bytes) -> tuple[int | None, bytes]:
    decoded = decode_message(data)
    frame_type = decoded.get(1)
    payload = decoded.get(2, b"")
    if frame_type is not None and not isinstance(frame_type, int):
        raise ScriptError(f"invalid frame type payload: {decoded}")
    if not isinstance(payload, bytes):
        raise ScriptError(f"invalid frame body payload: {decoded}")
    return frame_type, payload


def auth_payload(token: str) -> bytes:
    return field_bytes(1, token)


def send_message_payload(conversation_id: str, content: str) -> bytes:
    return b"".join(
        [
            field_bytes(1, conversation_id),
            field_varint(2, 0),
            field_bytes(3, content),
        ]
    )


def read_until(ws: WsClient, expected_type: int) -> dict[int, object]:
    while True:
        frame_type, payload = decode_frame(ws.recv_binary())
        if frame_type == expected_type:
            return decode_message(payload)


def authenticate_ws(ws_url: str, token: str) -> WsClient:
    ws = WsClient(ws_url)
    ws.send_binary(frame(AUTH, auth_payload(token)))
    frame_type, payload = decode_frame(ws.recv_binary())
    if frame_type != AUTH_RESULT:
        ws.close()
        raise ScriptError(f"expected AUTH_RESULT frame, got {frame_type}")
    result = decode_message(payload)
    if result.get(1) != 1:
        ws.close()
        raise ScriptError(f"websocket auth failed: {result}")
    return ws


def main() -> int:
    args = parse_args()
    if not args.text.strip():
        raise ScriptError("text must not be empty")
    if args.sender_id == args.receiver_id:
        raise ScriptError("sender_id and receiver_id must be different")

    users = load_users(args.users_json)
    sender = users.get(args.sender_id)
    receiver = users.get(args.receiver_id)
    if sender is None:
        raise ScriptError(f"sender_id={args.sender_id} not found in {args.users_json}")
    if receiver is None:
        raise ScriptError(
            f"receiver_id={args.receiver_id} not found in {args.users_json}"
        )
    if not sender.get("phone") or not sender.get("password"):
        raise ScriptError(
            f"sender_id={args.sender_id} is missing phone/password in {args.users_json}"
        )

    sender_login = login(args.base_url, sender["phone"], sender["password"])
    sender_token = sender_login.get("token")
    if not isinstance(sender_token, str) or not sender_token:
        raise ScriptError(f"login response missing token: {sender_login}")

    conversation_id = find_private_conversation_id(
        args.base_url,
        sender_token,
        args.receiver_id,
    )

    ws = authenticate_ws(args.ws_url, sender_token)
    try:
        ws.send_binary(
            frame(CHAT_MESSAGE, send_message_payload(conversation_id, args.text))
        )
        ack = read_until(ws, MESSAGE_ACK)
    finally:
        ws.close()

    message_id = ack.get(1, b"")
    seq = ack.get(2)
    if not isinstance(message_id, bytes) or not message_id:
        raise ScriptError(f"message ack missing message id: {ack}")
    if not isinstance(seq, int) or seq <= 0:
        raise ScriptError(f"message ack missing seq: {ack}")

    print(
        json.dumps(
            {
                "ok": True,
                "sender_id": args.sender_id,
                "receiver_id": args.receiver_id,
                "conversation_id": conversation_id,
                "message_id": message_id.decode("utf-8"),
                "seq": seq,
                "text": args.text,
            },
            ensure_ascii=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ScriptError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
