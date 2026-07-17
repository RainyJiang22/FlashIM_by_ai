#!/usr/bin/env python3
"""
发送富媒体消息（图片 / 视频 / 文件）

用法:
  python send_message.py image
  python send_message.py video
  python send_message.py file
  python send_message.py image --from 1 --to 2

自动使用 assets/ 目录下的测试资源。
依赖: pip install websockets protobuf
"""

import asyncio
import argparse
import json
import mimetypes
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "proto"))
import ws_pb2 as ws
import message_pb2 as msg

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, "assets")
CURL_BIN = shutil.which("curl.exe") or shutil.which("curl")


def asset(name):
    return os.path.join(ASSETS_DIR, name)


def curl(method, url, json_body=None, token=None):
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


def curl_upload(url, file_path, field_name="file", extra_fields=None):
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


def login_by_id(base, user_id):
    phone = f"138000{10000 + user_id}"
    s, data = curl("POST", f"{base}/auth/login", json.dumps({
        "login_type": "password",
        "identifier": phone,
        "password": "111111",
    }))
    if s != 200 or not data or not data.get("token") or not data.get("account_id"):
        print(f"❌ 登录失败: test_user={user_id}, status={s}, response={data}")
        sys.exit(1)
    return data["token"], int(data["account_id"]), phone


def find_conversation(base, token, peer_account_id):
    status, conversations = curl(
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


def upload_image(base):
    path = asset("test.webp")
    print(f"\n📸 上传图片: {os.path.basename(path)}")
    s, data = curl_upload(f"{base}/api/upload/image", path)
    if s != 200 or not data:
        print(f"❌ 失败: status={s}")
        sys.exit(1)
    print(f"   {data['width']}x{data['height']}, {data['size']} bytes")
    print(f"   original:  {data['original_url']}")
    print(f"   thumbnail: {data['thumbnail_url']}")
    return data


def upload_video(base):
    path = asset("test.mp4")
    print(f"\n🎬 上传视频: {os.path.basename(path)}")

    with open(asset("test_meta.json"), "r", encoding="utf-8") as f:
        meta = json.load(f)["video"]

    s, data = curl_upload(
        f"{base}/api/upload/video", path, field_name="video",
        extra_fields={
            "thumbnail": asset(meta["thumbnail"]),
            "duration_ms": str(meta["duration_ms"]),
            "width": str(meta["width"]),
            "height": str(meta["height"]),
        }
    )
    if s != 200 or not data:
        print(f"❌ 失败: status={s}")
        sys.exit(1)
    print(f"   {data['width']}x{data['height']}, {data['duration_ms']}ms, {data['file_size']} bytes")
    print(f"   video:     {data['video_url']}")
    print(f"   thumbnail: {data['thumbnail_url']}")
    return data


def upload_file(base):
    path = asset("sky_engine.zip")
    print(f"\n📄 上传文件: {os.path.basename(path)}")
    s, data = curl_upload(f"{base}/api/upload/file", path)
    if s != 200 or not data:
        print(f"❌ 失败: status={s}")
        sys.exit(1)
    print(f"   {data['file_name']}, {data['file_size']} bytes")
    print(f"   url: {data['file_url']}")
    return data


async def ws_send(ws_conn, req):
    """发送消息帧并等待 ACK"""
    frame = ws.WsFrame()
    frame.type = ws.CHAT_MESSAGE
    frame.payload = req.SerializeToString()
    await ws_conn.send(frame.SerializeToString())

    for _ in range(10):
        try:
            data = await asyncio.wait_for(ws_conn.recv(), timeout=5)
            f = ws.WsFrame()
            f.ParseFromString(data)
            if f.type == ws.MESSAGE_ACK:
                ack = msg.MessageAck()
                ack.ParseFromString(f.payload)
                print(f"   ✅ ACK: id={ack.message_id}, seq={ack.seq}")
                return ack
        except asyncio.TimeoutError:
            break
    print("   ⚠️ ACK 超时")
    return None


async def ws_connect(ws_url, token, label):
    import websockets

    ws_conn = await websockets.connect(ws_url)
    auth_req = ws.AuthRequest()
    auth_req.token = token
    frame = ws.WsFrame()
    frame.type = ws.AUTH
    frame.payload = auth_req.SerializeToString()
    await ws_conn.send(frame.SerializeToString())
    data = await asyncio.wait_for(ws_conn.recv(), timeout=5)
    resp = ws.WsFrame()
    resp.ParseFromString(data)
    result = ws.AuthResult()
    result.ParseFromString(resp.payload)
    if resp.type != ws.AUTH_RESULT or not result.success:
        print(f"❌ {label} WebSocket 认证失败: {result.message}")
        await ws_conn.close()
        sys.exit(1)
    print(f"✅ {label} WebSocket 认证成功")
    return ws_conn


async def ws_receive(receiver_ws, req, sender_account_id):
    for _ in range(10):
        try:
            data = await asyncio.wait_for(receiver_ws.recv(), timeout=5)
        except asyncio.TimeoutError:
            break
        frame = ws.WsFrame()
        frame.ParseFromString(data)
        if frame.type != ws.CHAT_MESSAGE:
            continue
        received = msg.ChatMessage()
        received.ParseFromString(frame.payload)
        try:
            received_extra = json.loads(received.extra) if received.extra else None
            expected_extra = json.loads(req.extra) if req.extra else None
        except json.JSONDecodeError:
            received_extra = received.extra
            expected_extra = req.extra
        matches = (
            received.conversation_id == req.conversation_id
            and received.sender_id == sender_account_id
            and received.type == req.type
            and received.content == req.content
            and received_extra == expected_extra
        )
        if matches:
            print(
                f"   ✅ 接收方收到: sender={received.sender_id}, "
                f"type={received.type}, content={received.content}"
            )
            return received
    print("   ❌ 接收方未收到匹配的富媒体消息")
    return None


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("type", choices=["image", "video", "file"], help="消息类型")
    parser.add_argument("--from", dest="from_id", type=int, default=1)
    parser.add_argument("--to", dest="to_id", type=int, default=2)
    parser.add_argument("--base", default="http://127.0.0.1:9600")
    parser.add_argument("--ws", default="ws://127.0.0.1:9600/ws/im")
    args = parser.parse_args()

    # 测试账号编号 1/2 分别映射到手机号 13800010001/13800010002；
    # 服务端实际 account_id 从登录响应读取，不能直接把测试编号当 account_id。
    sender_token, sender_account_id, sender_phone = login_by_id(
        args.base, args.from_id
    )
    receiver_token, receiver_account_id, receiver_phone = login_by_id(
        args.base, args.to_id
    )
    if sender_account_id == receiver_account_id:
        print("❌ 发送方和接收方不能是同一账号")
        sys.exit(1)
    print(
        f"✅ 发送方: test_user={args.from_id}, phone={sender_phone}, "
        f"account_id={sender_account_id}"
    )
    print(
        f"✅ 接收方: test_user={args.to_id}, phone={receiver_phone}, "
        f"account_id={receiver_account_id}"
    )

    conv_id = find_conversation(args.base, sender_token, receiver_account_id)
    print(f"✅ 会话: {conv_id}")

    sender_ws = await ws_connect(args.ws, sender_token, "发送方")
    receiver_ws = await ws_connect(args.ws, receiver_token, "接收方")

    req = msg.SendMessageRequest()
    req.conversation_id = conv_id

    if args.type == "image":
        img = upload_image(args.base)
        req.type = msg.IMAGE
        req.content = img["original_url"]
        req.extra = json.dumps({
            "width": img["width"],
            "height": img["height"],
            "size": img["size"],
            "format": img["format"],
            "thumbnail_url": img["thumbnail_url"],
        }, ensure_ascii=False)

    elif args.type == "video":
        vid = upload_video(args.base)
        req.type = msg.VIDEO
        req.content = vid["video_url"]
        req.extra = json.dumps({
            "thumbnail_url": vid["thumbnail_url"],
            "duration_ms": vid["duration_ms"],
            "width": vid["width"],
            "height": vid["height"],
            "file_size": vid["file_size"],
        }, ensure_ascii=False)

    elif args.type == "file":
        fil = upload_file(args.base)
        req.type = msg.FILE
        req.content = fil["file_url"]
        req.extra = json.dumps({
            "file_name": fil["file_name"],
            "file_size": fil["file_size"],
            "file_url": fil["file_url"],
            "file_type": fil["file_type"],
        }, ensure_ascii=False)

    ack = await ws_send(sender_ws, req)
    received = await ws_receive(receiver_ws, req, sender_account_id)
    await sender_ws.close()
    await receiver_ws.close()
    if ack is None or received is None:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
