#!/usr/bin/env bash

set -euo pipefail

if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

for cmd in rustup rustc cargo; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    echo "Run this first:"
    echo "  bash scripts/setup/install-rust-macos.sh"
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/hello_rust"

echo "==> Creating a temporary Rust project"
cargo new --bin "$project_dir" --vcs none >/dev/null

echo "==> Replacing the sample program"
cat > "$project_dir/src/main.rs" <<'EOF'
fn main() {
    println!("hello, rust");
}
EOF

echo "==> Running rustfmt"
(
  cd "$project_dir"
  cargo fmt --check
)

echo "==> Running clippy"
(
  cd "$project_dir"
  cargo clippy --all-targets --all-features -- -D warnings
)

echo "==> Running the sample program"
(
  cd "$project_dir"
  cargo run --quiet
)

echo "==> Verification completed successfully"
