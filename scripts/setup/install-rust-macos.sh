#!/usr/bin/env bash

set -euo pipefail

: "${RUSTUP_DOWNLOAD_TIMEOUT:=600}"
: "${RUSTUP_CONCURRENT_DOWNLOADS:=1}"

cleanup_partial_downloads() {
  local downloads_dir="$HOME/.rustup/downloads"

  if [[ -d "$downloads_dir" ]]; then
    find "$downloads_dir" -type f -name '*.partial' -delete
  fi
}

verify_toolchain_binaries() {
  rustup run stable rustc -V >/dev/null 2>&1 && rustup run stable cargo -V >/dev/null 2>&1
}

run_rustup_with_retry() {
  local description="$1"
  shift

  echo "==> $description"
  if "$@"; then
    return 0
  fi

  echo "Primary download failed. Retrying with curl backend and conservative network settings..."
  cleanup_partial_downloads

  env \
    RUSTUP_USE_CURL=1 \
    RUSTUP_CONCURRENT_DOWNLOADS=1 \
    RUSTUP_DOWNLOAD_TIMEOUT="$RUSTUP_DOWNLOAD_TIMEOUT" \
    RUSTUP_IO_THREADS=1 \
    "$@"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only."
  exit 1
fi

echo "==> Checking Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found."
  echo "Opening the system installer now..."
  xcode-select --install || true
  echo
  echo "Finish the installation, then rerun:"
  echo "  bash scripts/setup/install-rust-macos.sh"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but was not found."
  exit 1
fi

if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
  echo "==> Installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none
else
  echo "==> rustup is already installed"
fi

if [[ -f "$HOME/.cargo/env" ]]; then
  # Load cargo/rustup into the current shell so the rest of the script can use them.
  source "$HOME/.cargo/env"
fi

run_rustup_with_retry "Installing or updating the stable toolchain" \
  rustup toolchain install stable --profile minimal

if ! verify_toolchain_binaries; then
  echo "Installed toolchain is incomplete. Reinstalling stable from scratch..."
  rustup toolchain uninstall stable >/dev/null 2>&1 || true
  cleanup_partial_downloads
  run_rustup_with_retry "Reinstalling the stable toolchain" \
    rustup toolchain install stable --profile minimal
fi

rustup default stable

run_rustup_with_retry "Installing common components" \
  rustup component add rustfmt clippy rust-analyzer

echo "==> Rust environment is ready"
rustc -V
cargo -V
rustup show active-toolchain
