#!/usr/bin/env python3
"""
富媒体上传 + 消息发送测试

测试内容：
1. 上传图片 → 验证返回 original_url / thumbnail_url / width / height
2. 上传文件 → 验证返回 file_url / file_name / file_size
3. 静态文件访问 → 验证上传后的文件可通过 GET /uploads/ 访问
4. 通过 WS 发送图片消息 → 验证 ACK + 会话预览 = "[图片]"
5. 通过 WS 发送文件消息 → 验证 ACK + 会话预览 = "[文件]"
6. 历史消息查询 → 验证 msg_type 和 extra 字段

用法: python test_upload.py [--base http://127.0.0.1:9600]

依赖: pip install websockets protobuf
"""

import argparse
import asyncio
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "proto"))
import ws_pb2 as ws
import message_pb2 as msg

BASE = "http://127.0.0.1:9600"
WS_URL = "ws://127.0.0.1:9600/ws/im"
PASSED = 0
FAILED = 0
CURL_BIN = shutil.which("curl.exe") or shutil.which("curl")

def curl_upload(url, file_path, field_name="file", extra_fields=None):
    """用 curl 上传文件，返回 (status, json_data)"""
    if not CURL_BIN:
        print("❌ 未找到 curl/curl.exe")
        sys.exit(1)
    cmd = [CURL_BIN, "-sS", "-w", "\n%{http_code}", "-X", "POST", url]
    content_type = mimetypes.guess_type(file_path)[0] or "application/octet-stream"
    cmd += ["-F", f"{field_name}=@{file_path};type={content_type}"]
    if extra_fields:
        for k, v in extra_fields.items():
            if isinstance(v, str) and os.path.isfile(v):
                content_type = mimetypes.guess_type(v)[0] or "application/octet-stream"
                cmd += ["-F", f"{k}=@{v};type={content_type}"]
            else:
                cmd += ["-F", f"{k}={v}"]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        print(f"❌ curl 上传失败: {result.stderr.strip()}")
        sys.exit(1)
    lines = result.stdout.rsplit("\n", 1)
    body = lines[0] if len(lines) > 1 else ""
    status = int(lines[-1]) if lines[-1].isdigit() else 0
    data = json.loads(body) if body.strip() else None
    return status, data


def curl_get(url):
    """用 curl GET，返回 (status, body)"""
    if not CURL_BIN:
        print("❌ 未找到 curl/curl.exe")
        sys.exit(1)
    cmd = [CURL_BIN, "-sS", "-o", os.devnull, "-w", "%{http_code}", "-X", "GET", url]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    status = int(result.stdout.strip()) if result.stdout and result.stdout.strip().isdigit() else 0
    return status, ""


def curl_json(method, url, json_body=None, token=None):
    """用 curl 发 JSON 请求"""
    if not CURL_BIN:
        print("❌ 未找到 curl/curl.exe")
        sys.exit(1)
    cmd = [CURL_BIN, "-sS", "-w", "\n%{http_code}", "-X", method, url]
    if token:
        cmd += ["-H", f"Authorization: Bearer {token}"]
    if json_body:
        cmd += ["-H", "Content-Type: application/json", "-d", json_body]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        print(f"❌ curl 请求失败: {result.stderr.strip()}")
        sys.exit(1)
    lines = result.stdout.rsplit("\n", 1)
    body = lines[0] if len(lines) > 1 else ""
    status = int(lines[-1]) if lines[-1].isdigit() else 0
    data = json.loads(body) if body.strip() else None
    return status, data


def check(name, condition):
    global PASSED, FAILED
    if condition:
        PASSED += 1
        print(f"  ✅ {name}")
    else:
        FAILED += 1
        print(f"  ❌ {name}")


def create_test_image(path, width=100, height=80):
    """创建一个简单的 JPEG 测试图片"""
    # 最小的有效 JPEG：用 PPM 转 JPEG 太复杂，直接写一个 1x1 BMP 然后让服务端处理
    # 更简单：用纯色 PNG bytes
    import struct
    import zlib

    def create_png(w, h):
        def make_chunk(chunk_type, data):
            c = chunk_type + data
            crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
            return struct.pack(">I", len(data)) + c + crc

        header = b"\x89PNG\r\n\x1a\n"
        ihdr = make_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        # RGB raw data: each row = filter byte (0) + RGB pixels
        raw = b""
        for _ in range(h):
            raw += b"\x00" + b"\xff\x00\x00" * w  # red pixels
        compressed = zlib.compress(raw)
        idat = make_chunk(b"IDAT", compressed)
        iend = make_chunk(b"IEND", b"")
        return header + ihdr + idat + iend

    data = create_png(width, height)
    with open(path, "wb") as f:
        f.write(data)
    return data

def login_by_id(base, user_id):
    phone = f"138000{10000 + user_id}"
    status, data = curl_json("POST", f"{base}/auth/login", json.dumps({
        "login_type": "password",
        "identifier": phone,
        "password": "111111",
    }))
    if status != 200 or not data or not data.get("token") or not data.get("account_id"):
        print(f"❌ 登录失败: test_user={user_id}, status={status}, response={data}")
        sys.exit(1)
    return data["token"], int(data["account_id"]), phone


def find_conversation(base, token, peer_account_id):
    status, conversations = curl_json(
        "GET",
        f"{base}/conversations?limit=100&offset=0",
        token=token,
    )
    if status != 200 or not isinstance(conversations, list):
        print(f"❌ 查询会话失败: status={status}, response={conversations}")
        sys.exit(1)
    target = next(
        (
            item
            for item in conversations
            if str(item.get("peer_user_id")) == str(peer_account_id)
        ),
        None,
    )
    if not target:
        print(f"❌ 未找到与 account_id={peer_account_id} 的种子会话")
        sys.exit(1)
    return target["id"]


def test_upload_image(base):
    print("\n📸 测试 1：上传图片")
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        create_test_image(f.name, 200, 150)
        tmp_path = f.name

    try:
        status, data = curl_upload(f"{base}/api/upload/image", tmp_path)
        check("状态码 200", status == 200)
        check("返回 original_url", data and "original_url" in data)
        check("返回 thumbnail_url", data and "thumbnail_url" in data)
        check("返回 width", data and data.get("width", 0) > 0)
        check("返回 height", data and data.get("height", 0) > 0)
        check("返回 size > 0", data and data.get("size", 0) > 0)
        check("返回 format = png", data and data.get("format") == "png")

        # 测试静态文件访问
        if data and data.get("original_url"):
            url = f"{base}{data['original_url']}"
            s, _ = curl_get(url)
            check("原图可访问 (GET 200)", s == 200)

        if data and data.get("thumbnail_url"):
            url = f"{base}{data['thumbnail_url']}"
            s, _ = curl_get(url)
            check("缩略图可访问 (GET 200)", s == 200)

        return data
    finally:
        os.unlink(tmp_path)


def test_upload_file(base):
    print("\n📄 测试 2：上传文件")
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f:
        f.write("hello world test file content")
        tmp_path = f.name

    try:
        status, data = curl_upload(f"{base}/api/upload/file", tmp_path)
        check("状态码 200", status == 200)
        check("返回 file_url", data and "file_url" in data)
        check("返回 file_name", data and "file_name" in data)
        check("返回 file_size > 0", data and data.get("file_size", 0) > 0)
        check("返回 file_type = txt", data and data.get("file_type") == "txt")

        if data and data.get("file_url"):
            url = f"{base}{data['file_url']}"
            s, _ = curl_get(url)
            check("文件可访问 (GET 200)", s == 200)

        return data
    finally:
        os.unlink(tmp_path)


def test_reject_oversize(base):
    print("\n🚫 测试 3：拒绝超大文件")
    # 创建一个 > 10MB 的临时文件作为图片上传
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        f.write(b"\xff\xd8\xff\xe0" + b"\x00" * (11 * 1024 * 1024))  # 11MB fake JPEG
        tmp_path = f.name

    try:
        status, _ = curl_upload(f"{base}/api/upload/image", tmp_path)
        check("超大图片被拒绝 (400)", status == 400)
    finally:
        os.unlink(tmp_path)


def test_reject_bad_format(base):
    print("\n🚫 测试 4：拒绝不支持的格式")
    with tempfile.NamedTemporaryFile(suffix=".exe", delete=False) as f:
        f.write(b"MZ" + b"\x00" * 100)
        tmp_path = f.name

    try:
        status, _ = curl_upload(f"{base}/api/upload/image", tmp_path)
        check("不支持的格式被拒绝 (400)", status == 400)
    finally:
        os.unlink(tmp_path)

async def test_ws_media_message(base, ws_url):
    """测试通过 WS 发送图片/文件消息，验证 ACK + 会话预览 + 历史查询"""
    import websockets

    print("\n🔌 测试 5：WS 发送图片消息 + 会话预览")

    # 测试账号 1（13800010001）发送给测试账号 2（13800010002）。
    token, sender_account_id, sender_phone = login_by_id(base, 1)
    _, receiver_account_id, receiver_phone = login_by_id(base, 2)
    print(
        f"  登录成功: {sender_phone}(account_id={sender_account_id}) -> "
        f"{receiver_phone}(account_id={receiver_account_id})"
    )

    conv_id = find_conversation(base, token, receiver_account_id)
    print(f"  会话: {conv_id}")

    # 先上传一张图片
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        create_test_image(f.name, 64, 64)
        tmp_path = f.name

    _, upload_data = curl_upload(f"{base}/api/upload/image", tmp_path)
    os.unlink(tmp_path)
    image_url = upload_data["original_url"]
    print(f"  图片上传: {image_url}")

    # 连接 WS + 认证
    ws_conn = await websockets.connect(ws_url)
    auth = ws.AuthRequest()
    auth.token = token
    frame = ws.WsFrame()
    frame.type = ws.AUTH
    frame.payload = auth.SerializeToString()
    await ws_conn.send(frame.SerializeToString())

    data = await asyncio.wait_for(ws_conn.recv(), timeout=5)
    resp = ws.WsFrame()
    resp.ParseFromString(data)
    result = ws.AuthResult()
    result.ParseFromString(resp.payload)
    check("WS 认证成功", result.success)

    # 发送图片消息: type=IMAGE(1), content=url
    req = msg.SendMessageRequest()
    req.conversation_id = conv_id
    req.type = msg.IMAGE
    req.content = image_url
    req.extra = json.dumps({
        "width": upload_data["width"],
        "height": upload_data["height"],
        "size": upload_data["size"],
        "format": upload_data["format"],
        "thumbnail_url": upload_data["thumbnail_url"],
    }, ensure_ascii=False)
    send_frame = ws.WsFrame()
    send_frame.type = ws.CHAT_MESSAGE
    send_frame.payload = req.SerializeToString()
    await ws_conn.send(send_frame.SerializeToString())

    # 等待 ACK
    ack_received = False
    for _ in range(10):
        try:
            data = await asyncio.wait_for(ws_conn.recv(), timeout=5)
            f = ws.WsFrame()
            f.ParseFromString(data)
            if f.type == ws.MESSAGE_ACK:
                ack = msg.MessageAck()
                ack.ParseFromString(f.payload)
                check("图片消息 ACK 收到", True)
                check("ACK message_id 非空", len(ack.message_id) > 0)
                check("ACK seq > 0", ack.seq > 0)
                ack_received = True
                print(f"  消息 id={ack.message_id}, seq={ack.seq}")
                break
        except asyncio.TimeoutError:
            break

    if not ack_received:
        check("图片消息 ACK 收到", False)

    # 验证会话预览
    _, conv_list = curl_json("GET", f"{base}/conversations", token=token)
    if conv_list:
        target = next((c for c in conv_list if c["id"] == conv_id), None)
        if target:
            preview = target.get("last_message_preview", "")
            check("会话预览 = [图片]", preview == "[图片]")
        else:
            check("会话预览 = [图片]", False)
    else:
        check("会话预览 = [图片]", False)

    # 验证历史消息
    _, messages = curl_json("GET", f"{base}/conversations/{conv_id}/messages", token=token)
    if messages and len(messages) > 0:
        last_msg = messages[0]  # 最新的（按 seq DESC）
        check("历史消息 msg_type = 1 (IMAGE)", last_msg.get("msg_type") == 1)
        check("历史消息 content = 图片URL", last_msg.get("content") == image_url)
    else:
        check("历史消息 msg_type = 1 (IMAGE)", False)
        check("历史消息 content = 图片URL", False)

    # --- 测试 6：发送文件消息 ---
    print("\n📎 测试 6：WS 发送文件消息 + 会话预览")

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False, mode="w") as f:
        f.write("fake pdf content")
        tmp_path = f.name

    _, file_data = curl_upload(f"{base}/api/upload/file", tmp_path)
    os.unlink(tmp_path)
    file_url = file_data["file_url"]

    file_extra = json.dumps({
        "file_name": file_data["file_name"],
        "file_size": file_data["file_size"],
        "file_url": file_data["file_url"],
        "file_type": file_data["file_type"],
    }, ensure_ascii=False)

    req2 = msg.SendMessageRequest()
    req2.conversation_id = conv_id
    req2.type = msg.FILE
    req2.content = file_url
    req2.extra = file_extra
    send_frame2 = ws.WsFrame()
    send_frame2.type = ws.CHAT_MESSAGE
    send_frame2.payload = req2.SerializeToString()
    await ws_conn.send(send_frame2.SerializeToString())

    ack_received = False
    for _ in range(10):
        try:
            data = await asyncio.wait_for(ws_conn.recv(), timeout=5)
            f = ws.WsFrame()
            f.ParseFromString(data)
            if f.type == ws.MESSAGE_ACK:
                ack = msg.MessageAck()
                ack.ParseFromString(f.payload)
                check("文件消息 ACK 收到", True)
                ack_received = True
                break
        except asyncio.TimeoutError:
            break

    if not ack_received:
        check("文件消息 ACK 收到", False)

    # 验证会话预览
    _, conv_list = curl_json("GET", f"{base}/conversations", token=token)
    if conv_list:
        target = next((c for c in conv_list if c["id"] == conv_id), None)
        if target:
            preview = target.get("last_message_preview", "")
            check("会话预览 = [文件]", preview == "[文件]")
        else:
            check("会话预览 = [文件]", False)
    else:
        check("会话预览 = [文件]", False)

    # 验证历史消息 extra
    _, messages = curl_json("GET", f"{base}/conversations/{conv_id}/messages", token=token)
    if messages and len(messages) > 0:
        last_msg = messages[0]
        check("历史消息 msg_type = 3 (FILE)", last_msg.get("msg_type") == 3)
        extra = last_msg.get("extra")
        check("历史消息 extra 含 file_name", extra and "file_name" in extra)
    else:
        check("历史消息 msg_type = 3 (FILE)", False)
        check("历史消息 extra 含 file_name", False)

    await ws_conn.close()

async def main():
    parser = argparse.ArgumentParser(description="富媒体上传测试")
    parser.add_argument("--base", default="http://127.0.0.1:9600")
    parser.add_argument("--ws", default="ws://127.0.0.1:9600/ws/im")
    args = parser.parse_args()

    global BASE, WS_URL
    BASE = args.base
    WS_URL = args.ws

    # HTTP 上传测试
    test_upload_image(BASE)
    test_upload_file(BASE)
    test_reject_oversize(BASE)
    test_reject_bad_format(BASE)

    # WS 消息测试
    await test_ws_media_message(BASE, WS_URL)

    # 汇总
    print(f"\n{'='*40}")
    print(f"结果: {PASSED} passed, {FAILED} failed")
    if FAILED > 0:
        print("❌ SOME TESTS FAILED")
        sys.exit(1)
    else:
        print("✅ ALL PASSED")


if __name__ == "__main__":
    asyncio.run(main())
