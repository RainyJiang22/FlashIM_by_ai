#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
OUTPUT = ROOT / "docs/features/im/group/v0.0.2/quality/client-attempt-1/lcov.info"
INPUTS = (
    (
        ROOT / "client/modules/flash_im_conversation/coverage/lcov.info",
        "client/modules/flash_im_conversation",
    ),
    (
        ROOT / "client/modules/flash_im_group/coverage/lcov.info",
        "client/modules/flash_im_group",
    ),
    (
        ROOT / "client/modules/flash_im_chat/coverage/lcov.info",
        "client/modules/flash_im_chat",
    ),
    (ROOT / "client/coverage/lcov.info", "client"),
)


def rebase(line: str, base: str) -> str:
    if not line.startswith("SF:"):
        return line
    value = Path(line[3:])
    if value.is_absolute():
        try:
            return f"SF:{value.resolve().relative_to(ROOT).as_posix()}"
        except ValueError:
            return line
    return f"SF:{base}/{value.as_posix()}"


OUTPUT.parent.mkdir(parents=True, exist_ok=True)
records = []
for path, base in INPUTS:
    if not path.exists():
        raise SystemExit(f"missing coverage input: {path}")
    records.extend(rebase(line, base) for line in path.read_text().splitlines())
OUTPUT.write_text("\n".join(records) + "\n")
