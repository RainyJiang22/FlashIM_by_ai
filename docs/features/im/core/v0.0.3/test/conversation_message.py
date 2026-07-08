#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.parse
import urllib.request


BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
PHONE = os.environ.get("PHONE", "13800010001")
PASSWORD = os.environ.get("PASSWORD", "111111")


def request(method, path, body=None, token=None, expected=200):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        method=method,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            payload = resp.read().decode("utf-8")
            status = resp.status
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8")
        status = exc.code

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {payload}")

    return json.loads(payload) if payload else None


def login(phone):
    payload = {
        "login_type": "password",
        "identifier": phone,
        "password": PASSWORD,
    }
    data = request("POST", "/auth/login", payload)
    token = data.get("token")
    if not token:
        raise AssertionError("missing token from login response")
    return token


def main():
    request("GET", "/conversations/00000000-0000-0000-0000-000000000001/messages", expected=401)
    request("GET", "/conversations/00000000-0000-0000-0000-000000000001", expected=401)
    request("POST", "/conversations/00000000-0000-0000-0000-000000000001/read", expected=401)

    token = login(PHONE)
    conversations = request("GET", "/conversations?limit=1&offset=0", token=token)
    if not conversations:
        raise AssertionError("seeded conversation list is empty")

    conversation_id = conversations[0]["id"]
    conversation = request("GET", f"/conversations/{conversation_id}", token=token)
    if conversation["id"] != conversation_id:
        raise AssertionError(f"unexpected conversation detail: {conversation}")
    if "peer_nickname" not in conversation or "unread_count" not in conversation:
        raise AssertionError(f"conversation detail missing expected fields: {conversation}")

    read_result = request("POST", f"/conversations/{conversation_id}/read", token=token)
    if read_result.get("message") != "conversation marked as read":
        raise AssertionError(f"unexpected mark read response: {read_result}")

    after_read = request("GET", f"/conversations/{conversation_id}", token=token)
    if after_read["unread_count"] != 0:
        raise AssertionError(f"unread_count should be zero after read: {after_read}")

    first_page = request(
        "GET",
        f"/conversations/{conversation_id}/messages?limit=10",
        token=token,
    )
    if not isinstance(first_page, list):
        raise AssertionError("message history response must be an array")

    paged = request(
        "GET",
        f"/conversations/{conversation_id}/messages?before_seq=999999&limit=5",
        token=token,
    )
    if not isinstance(paged, list):
        raise AssertionError("message history page response must be an array")

    request(
        "GET",
        f"/conversations/{conversation_id}/messages?before_seq=0&limit=5",
        token=token,
        expected=400,
    )

    print(
        json.dumps(
            {
                "ok": True,
                "conversation_id": conversation_id,
                "peer_nickname": conversation.get("peer_nickname"),
                "first_page_count": len(first_page),
                "paged_count": len(paged),
                "unread_after_read": after_read["unread_count"],
            },
            ensure_ascii=True,
        )
    )


if __name__ == "__main__":
    main()
