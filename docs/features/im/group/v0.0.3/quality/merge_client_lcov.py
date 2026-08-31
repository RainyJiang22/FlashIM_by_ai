#!/usr/bin/env python3
"""Merge package-local Flutter LCOV reports into repository-relative paths."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
OUTPUT = Path(__file__).resolve().parent / "attempt-03" / "client.lcov"
REPORTS = (
    (ROOT / "client/modules/flash_im_core/coverage/lcov.info", "client/modules/flash_im_core"),
    (ROOT / "client/modules/flash_im_group/coverage/lcov.info", "client/modules/flash_im_group"),
    (ROOT / "client/modules/flash_im_friend/coverage/lcov.info", "client/modules/flash_im_friend"),
    (ROOT / "client/coverage/lcov.info", "client"),
)


def normalize(source: str, package_root: str) -> str:
    path = Path(source)
    if path.is_absolute():
        try:
            return path.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            return path.as_posix()
    value = source.removeprefix("./")
    if value.startswith(package_root + "/"):
        return value
    return f"{package_root}/{value}"


def main() -> None:
    merged: list[str] = []
    for report, package_root in REPORTS:
        if not report.exists():
            raise SystemExit(f"missing fresh LCOV report: {report}")
        for line in report.read_text(encoding="utf-8").splitlines():
            if line.startswith("SF:"):
                line = "SF:" + normalize(line[3:], package_root)
            merged.append(line)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(merged) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
