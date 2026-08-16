#!/bin/bash
set -euo pipefail

# 初期化直後のMacで、Ansibleを実行できるところまで準備する。
# macOSの細かな設定やアプリのログイン状態は、このスクリプトでは管理しない。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS専用です。" >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: Apple Silicon (arm64) を前提としています。" >&2
  exit 1
fi

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
if (( MACOS_MAJOR < 26 )); then
  echo "ERROR: macOS 26以降を前提としています。現在: ${MACOS_VERSION}" >&2
  exit 1
fi

echo "==> 対象: macOS ${MACOS_VERSION} / $(uname -m)"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Xcode Command Line Toolsを要求します。"
  xcode-select --install || true
  cat <<'MSG'
Command Line Toolsのインストール完了後、もう一度 ./bootstrap.sh を実行してください。
MSG
  exit 2
fi

echo "==> Xcode Command Line Tools: OK"

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Homebrewを公式インストーラで導入します。"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Siliconの標準prefixをPATHへ反映する。
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(brew shellenv)"
fi

echo "==> Homebrew: $(brew --version | /usr/bin/sed -n '1p')"

# arm64だけならRosettaは必須ではないが、amd64-onlyの開発物に備えて標準導入する。
if /usr/sbin/pkgutil --pkgs | /usr/bin/grep -E '^com\.apple\.pkg\.Rosetta' >/dev/null; then
  echo "==> Rosetta 2: already installed"
else
  echo "==> Rosetta 2を導入します。sudo認証が必要です。"
  sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "==> AnsibleをHomebrewで導入します。"
  brew install ansible
else
  echo "==> Ansible: already installed"
fi

echo "==> Ansible collectionを準備します。"
ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml"

cat <<'MSG'

bootstrap完了。
次に以下を実行してください。

  ansible-playbook --ask-become-pass playbook.yml
  ./verify.sh

MSG
