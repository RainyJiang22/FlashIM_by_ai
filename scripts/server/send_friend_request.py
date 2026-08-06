#!/usr/bin/env python3
"""Batch-send friend requests through the Flash IM HTTP API.

Examples:
  # Preview the requests without logging in or changing server state.
  python scripts/server/send_friend_request.py \
    --sender-id 1 --target-ids 2,3,4 --dry-run

  # Send requests using the seeded user's password.
  python scripts/server/send_friend_request.py \
    --sender-id 1 --target-ids 2 3 4 --message "你好，可以加个好友吗？" --yes

  # Send requests and have every seeded target accept their own request.
  python scripts/server/send_friend_request.py \
    --sender-id 1 --targets-file scripts/database/im_seed/users.json \
    --auto-accept --yes

  # Use an existing JWT and read target account IDs from a file.
  FRIEND_REQUEST_TOKEN=... python scripts/server/send_friend_request.py \
    --sender-id 1 --targets-file targets.txt --yes

The targets file accepts one account ID per line, comma/space-separated IDs,
or a JSON array containing integers or objects with an ``id``/``account_id``
field. Lines beginning with ``#`` are ignored.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


DEFAULT_BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:9600")
DEFAULT_MESSAGE = os.environ.get("FRIEND_REQUEST_MESSAGE", "你好，可以加个好友吗？")
DEFAULT_USERS_JSON = (
    Path(__file__).resolve().parents[1] / "database" / "im_seed" / "users.json"
)
DEFAULT_DELAY = float(os.environ.get("FRIEND_REQUEST_DELAY", "0.2"))
DEFAULT_RETRIES = int(os.environ.get("FRIEND_REQUEST_RETRIES", "2"))
DEFAULT_RETRY_DELAY = float(os.environ.get("FRIEND_REQUEST_RETRY_DELAY", "1"))
DEFAULT_TIMEOUT = float(os.environ.get("FRIEND_REQUEST_TIMEOUT", "10"))
TRANSIENT_STATUS_CODES = {408, 425, 429, 500, 502, 503, 504}


class ScriptError(Exception):
    """An expected, user-facing script error."""


@dataclass
class ApiError(ScriptError):
    method: str
    path: str
    status: int
    body: str

    @property
    def retryable(self) -> bool:
        return self.status == 0 or self.status in TRANSIENT_STATUS_CODES

    def __str__(self) -> str:
        status = f"HTTP {self.status}" if self.status else "network error"
        detail = self.body.strip() or "no response body"
        if len(detail) > 600:
            detail = f"{detail[:600]}..."
        return f"{self.method} {self.path} failed ({status}): {detail}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "批量发送 Flash IM 好友申请，可选地让目标账号自动接受。"
            "默认只预览，发送时必须追加 --yes。"
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--sender-id",
        type=int,
        required=True,
        help="发送方账号 ID",
    )
    parser.add_argument(
        "--target-id",
        dest="single_target_ids",
        action="append",
        type=int,
        default=[],
        help="目标账号 ID；可重复传入",
    )
    parser.add_argument(
        "--target-ids",
        dest="target_ids_values",
        nargs="+",
        default=[],
        metavar="ID",
        help="目标账号 ID，支持空格或逗号分隔",
    )
    parser.add_argument(
        "--targets-file",
        "--target-file",
        dest="targets_file",
        type=Path,
        help="目标账号文件：每行一个 ID，或 JSON 数组",
    )
    parser.add_argument(
        "--message",
        default=DEFAULT_MESSAGE,
        help="好友申请留言，服务端限制不超过 200 个字符",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="服务端 HTTP 地址",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("FRIEND_REQUEST_TOKEN"),
        help="已有 JWT；也可使用 FRIEND_REQUEST_TOKEN 环境变量",
    )
    parser.add_argument(
        "--identifier",
        help="登录账号标识，未传时从 users.json 按 sender-id 读取手机号",
    )
    parser.add_argument(
        "--password",
        default=os.environ.get("IM_PASSWORD"),
        help="登录密码；也可使用 IM_PASSWORD 环境变量",
    )
    parser.add_argument(
        "--users-json",
        default=str(DEFAULT_USERS_JSON),
        help="账号 ID 到手机号/密码的映射文件",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DEFAULT_DELAY,
        help="每个请求之间的间隔秒数",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=DEFAULT_RETRIES,
        help="临时网络/服务端错误的重试次数",
    )
    parser.add_argument(
        "--retry-delay",
        type=float,
        default=DEFAULT_RETRY_DELAY,
        help="重试的初始等待秒数，后续按 2 倍退避",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help="单次 HTTP 请求超时秒数",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只打印发送计划，不登录、不发送请求",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="确认执行真实批量发送；非 dry-run 模式必填",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="遇到第一个失败就停止，默认会继续处理剩余目标",
    )
    parser.add_argument(
        "--auto-accept",
        action="store_true",
        help="发送成功后，让每个目标账号登录并接受对应好友申请",
    )
    return parser.parse_args()


def parse_positive_id(value: Any, source: str) -> int:
    try:
        account_id = int(value)
    except (TypeError, ValueError) as exc:
        raise ScriptError(f"{source} 中存在无效账号 ID: {value!r}") from exc
    if account_id <= 0:
        raise ScriptError(f"{source} 中账号 ID 必须大于 0: {account_id}")
    return account_id


def parse_id_tokens(tokens: list[str], source: str) -> list[int]:
    account_ids: list[int] = []
    for token in tokens:
        for value in re.split(r"[\s,]+", token.strip()):
            if value:
                account_ids.append(parse_positive_id(value, source))
    return account_ids


def parse_target_file(path: Path) -> list[int]:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ScriptError(f"目标文件不存在: {path}") from exc
    except OSError as exc:
        raise ScriptError(f"读取目标文件失败: {path}: {exc}") from exc

    stripped = text.strip()
    if not stripped:
        return []

    if stripped.startswith("["):
        try:
            payload = json.loads(stripped)
        except json.JSONDecodeError as exc:
            raise ScriptError(f"目标文件 JSON 格式错误: {path}: {exc}") from exc
        if not isinstance(payload, list):
            raise ScriptError(f"目标文件 JSON 必须是数组: {path}")
        account_ids: list[int] = []
        for index, item in enumerate(payload, start=1):
            if isinstance(item, dict):
                value = item.get("account_id", item.get("id"))
            else:
                value = item
            account_ids.append(parse_positive_id(value, f"{path} 第 {index} 项"))
        return account_ids

    tokens: list[str] = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            tokens.append(line)
    return parse_id_tokens(tokens, str(path))


def unique_ids(account_ids: list[int]) -> list[int]:
    seen: set[int] = set()
    result: list[int] = []
    for account_id in account_ids:
        if account_id not in seen:
            seen.add(account_id)
            result.append(account_id)
    return result


def collect_target_ids(args: argparse.Namespace) -> list[int]:
    account_ids: list[int] = []
    account_ids.extend(args.single_target_ids)
    # ``--target-ids`` is kept separate by argparse so comma-separated values
    # and repeated ``--target-id`` options can share the same validation path.
    account_ids.extend(parse_id_tokens(args.target_ids_values, "--target-ids"))
    if args.targets_file:
        account_ids.extend(parse_target_file(args.targets_file))

    account_ids = unique_ids(account_ids)
    if not account_ids:
        raise ScriptError("至少提供一个目标账号：--target-id、--target-ids 或 --targets-file")
    if args.sender_id in account_ids:
        print(f"[SKIP] 忽略发送方账号自身: target_id={args.sender_id}")
        account_ids = [
            account_id for account_id in account_ids if account_id != args.sender_id
        ]
    if not account_ids:
        raise ScriptError("排除发送方账号后没有可发送的目标")
    return account_ids


def load_users(path: str) -> dict[int, dict[str, Any]]:
    try:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ScriptError(f"users.json 不存在: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ScriptError(f"users.json 格式错误: {path}: {exc}") from exc
    except OSError as exc:
        raise ScriptError(f"读取 users.json 失败: {path}: {exc}") from exc

    if not isinstance(payload, list):
        raise ScriptError(f"users.json 必须是数组: {path}")

    users: dict[int, dict[str, Any]] = {}
    for item in payload:
        if not isinstance(item, dict) or "id" not in item:
            raise ScriptError(f"users.json 存在缺少 id 的用户记录: {item!r}")
        user_id = parse_positive_id(item["id"], path)
        users[user_id] = item
    return users


def decode_payload(raw: bytes) -> tuple[str, Any]:
    text = raw.decode("utf-8", errors="replace")
    if not text.strip():
        return text, None
    try:
        return text, json.loads(text)
    except json.JSONDecodeError:
        return text, text


def request_json(
    method: str,
    base_url: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: float,
) -> Any:
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    headers = {"Accept": "application/json", "User-Agent": "flash-im-send-friend-request/1.0"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"

    url = f"{base_url.rstrip('/')}{path}"
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            status = response.status
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        body_text, _ = decode_payload(raw)
        raise ApiError(method, path, exc.code, body_text) from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ApiError(method, path, 0, str(exc)) from exc

    body_text, payload = decode_payload(raw)
    if status < 200 or status >= 300:
        raise ApiError(method, path, status, body_text)
    return payload


def with_retries(
    operation: Callable[[], Any],
    *,
    retries: int,
    retry_delay: float,
    label: str,
) -> Any:
    for attempt in range(retries + 1):
        try:
            return operation()
        except ApiError as exc:
            if not exc.retryable or attempt >= retries:
                raise
            wait_seconds = retry_delay * (2**attempt)
            print(
                f"[RETRY] {label} 第 {attempt + 1} 次失败，"
                f"{wait_seconds:g}s 后重试: {exc}"
            )
            time.sleep(wait_seconds)
    raise AssertionError("unreachable")


def login_account(
    args: argparse.Namespace,
    account_id: int,
    users: dict[int, dict[str, Any]],
    *,
    token: str | None = None,
    identifier: str | None = None,
    password: str | None = None,
) -> str:
    if token:
        return token

    user = users.get(account_id)
    if user is None and not identifier:
        raise ScriptError(
            f"users.json 中找不到账号 {account_id}，请提供对应的登录信息"
        )

    identifier = identifier or str(user.get("phone", ""))
    password = password or (str(user.get("password", "")) if user else "")
    if not identifier:
        raise ScriptError("缺少登录标识，请传 --identifier")
    if not password:
        raise ScriptError("缺少登录密码，请传 --password 或 IM_PASSWORD")

    response = request_json(
        "POST",
        args.base_url,
        "/auth/login",
        body={
            "login_type": "password",
            "identifier": identifier,
            "password": password,
        },
        timeout=args.timeout,
    )
    if not isinstance(response, dict) or not response.get("token"):
        raise ScriptError(f"登录响应缺少 token: {response!r}")
    response_account_id = response.get("account_id")
    if response_account_id is not None:
        try:
            logged_in_account_id = int(response_account_id)
        except (TypeError, ValueError) as exc:
            raise ScriptError(
                f"登录响应中的 account_id 无效: {response_account_id!r}"
            ) from exc
        if logged_in_account_id != account_id:
            raise ScriptError(
                f"登录账号与目标账号不一致：登录得到 {response_account_id}，"
                f"期望 {account_id}"
            )
    print(f"登录成功：account_id={account_id}")
    return str(response["token"])


def resolve_sender_token(
    args: argparse.Namespace,
    users: dict[int, dict[str, Any]],
) -> str:
    return login_account(
        args,
        args.sender_id,
        users,
        token=args.token,
        identifier=args.identifier,
        password=args.password,
    )


def validate_args(args: argparse.Namespace) -> None:
    if args.sender_id <= 0:
        raise ScriptError("--sender-id 必须大于 0")
    if len(args.message) > 200:
        raise ScriptError("--message 不能超过 200 个字符")
    if args.delay < 0:
        raise ScriptError("--delay 不能小于 0")
    if args.retries < 0:
        raise ScriptError("--retries 不能小于 0")
    if args.retry_delay < 0:
        raise ScriptError("--retry-delay 不能小于 0")
    if args.timeout <= 0:
        raise ScriptError("--timeout 必须大于 0")


def send_requests(
    args: argparse.Namespace,
    target_ids: list[int],
    token: str,
) -> tuple[int, dict[int, str], set[int]]:
    successes: list[int] = []
    already_friends: set[int] = set()
    failures: list[tuple[int, str]] = []
    request_ids: dict[int, str] = {}

    for index, target_id in enumerate(target_ids):
        path = "/api/friends/requests"
        body = {"to_user_id": target_id, "message": args.message}
        try:
            response = with_retries(
                lambda: request_json(
                    "POST",
                    args.base_url,
                    path,
                    body=body,
                    token=token,
                    timeout=args.timeout,
                ),
                retries=args.retries,
                retry_delay=args.retry_delay,
                label=f"target_id={target_id}",
            )
        except ApiError as exc:
            if (
                args.auto_accept
                and exc.status == 409
                and "already friends" in exc.body
            ):
                already_friends.add(target_id)
                print(f"[SKIP] target_id={target_id}: 已经是好友")
            else:
                failures.append((target_id, str(exc)))
                print(f"[FAIL] target_id={target_id}: {exc}")
                if args.fail_fast:
                    break
        except ScriptError as exc:
            failures.append((target_id, str(exc)))
            print(f"[FAIL] target_id={target_id}: {exc}")
            if args.fail_fast:
                break
        else:
            request_id = response.get("id") if isinstance(response, dict) else None
            status = response.get("status") if isinstance(response, dict) else None
            detail = f"request_id={request_id}" if request_id else "request accepted"
            if status:
                detail += f", status={status}"
            successes.append(target_id)
            if isinstance(request_id, str) and request_id:
                request_ids[target_id] = request_id
            print(f"[PASS] target_id={target_id}: {detail}")

        if index < len(target_ids) - 1 and args.delay and not (
            args.fail_fast and failures
        ):
            time.sleep(args.delay)

    print(
        f"完成：成功 {len(successes)}，已是好友 {len(already_friends)}，"
        f"失败 {len(failures)}，"
        f"总计 {len(target_ids)}"
    )
    if failures:
        print("失败目标：")
        for target_id, reason in failures:
            print(f"  - {target_id}: {reason}")
        return 1, request_ids, already_friends
    return 0, request_ids, already_friends


def accept_requests(
    args: argparse.Namespace,
    target_ids: list[int],
    request_ids: dict[int, str],
    already_friends: set[int],
    users: dict[int, dict[str, Any]],
) -> int:
    successes: list[int] = []
    already_friend_count = 0
    failures: list[tuple[int, str]] = []

    for index, target_id in enumerate(target_ids):
        if target_id in already_friends:
            already_friend_count += 1
            print(f"[ACCEPT-SKIP] target_id={target_id}: 已经是好友")
            continue
        request_id = request_ids.get(target_id)
        if not request_id:
            failures.append((target_id, "发送响应缺少好友申请 ID"))
            print(f"[ACCEPT-FAIL] target_id={target_id}: 发送响应缺少好友申请 ID")
            if args.fail_fast:
                break
            continue

        try:
            recipient_token = with_retries(
                lambda: login_account(
                    args,
                    target_id,
                    users,
                    password=args.password,
                ),
                retries=args.retries,
                retry_delay=args.retry_delay,
                label=f"登录 target_id={target_id}",
            )
            path = f"/api/friends/requests/{request_id}/accept"
            response = with_retries(
                lambda: request_json(
                    "POST",
                    args.base_url,
                    path,
                    token=recipient_token,
                    timeout=args.timeout,
                ),
                retries=args.retries,
                retry_delay=args.retry_delay,
                label=f"接受 target_id={target_id}",
            )
        except (ApiError, ScriptError) as exc:
            failures.append((target_id, str(exc)))
            print(f"[ACCEPT-FAIL] target_id={target_id}: {exc}")
            if args.fail_fast:
                break
        else:
            conversation_id = (
                response.get("conversation_id")
                if isinstance(response, dict)
                else None
            )
            detail = "accepted"
            if conversation_id:
                detail += f", conversation_id={conversation_id}"
            successes.append(target_id)
            print(f"[ACCEPT-PASS] target_id={target_id}: {detail}")

        if index < len(target_ids) - 1 and args.delay and not (
            args.fail_fast and failures
        ):
            time.sleep(args.delay)

    print(
        f"自动同意完成：成功 {len(successes)}，已是好友 {already_friend_count}，"
        f"失败 {len(failures)}，"
        f"总计 {len(target_ids)}"
    )
    if failures:
        print("自动同意失败目标：")
        for target_id, reason in failures:
            print(f"  - {target_id}: {reason}")
        return 1
    return 0


def main() -> int:
    args = parse_args()
    try:
        # Sending is opt-in. Without --yes, always stay in preview mode.
        if not args.yes:
            args.dry_run = True
        validate_args(args)
        target_ids = collect_target_ids(args)
        print(f"BASE_URL={args.base_url}")
        print(f"sender_id={args.sender_id}, targets={len(target_ids)}")
        print(f"target_ids={','.join(str(item) for item in target_ids)}")
        if args.dry_run:
            for target_id in target_ids:
                print(
                    f"[DRY-RUN] POST /api/friends/requests "
                    f"to_user_id={target_id}, message={args.message!r}"
                )
                if args.auto_accept:
                    print(
                        f"[DRY-RUN] POST /api/friends/requests/{{request_id}}/accept "
                        f"as target_id={target_id}"
                    )
            return 0

        users = load_users(args.users_json)
        token = with_retries(
            lambda: resolve_sender_token(args, users),
            retries=args.retries,
            retry_delay=args.retry_delay,
            label="登录",
        )
        send_status, request_ids, already_friends = send_requests(
            args, target_ids, token
        )
        if not args.auto_accept or not (request_ids or already_friends):
            return send_status

        accept_status = accept_requests(
            args,
            target_ids,
            request_ids,
            already_friends,
            users,
        )
        return 1 if send_status or accept_status else 0
    except (ApiError, ScriptError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
