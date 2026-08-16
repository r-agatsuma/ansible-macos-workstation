#!/bin/bash
set -u

# Playbookの責務である「ソフトウェアが存在すること」だけを確認する。
# アプリのログイン状態やmacOSの権限設定は検査しない。

fail=0
warn=0

pass() { printf 'PASS: %s\n' "$1"; }
fail_msg() { printf 'FAIL: %s\n' "$1" >&2; fail=$((fail + 1)); }
warn_msg() { printf 'WARN: %s\n' "$1" >&2; warn=$((warn + 1)); }

if [[ "$(uname -s)" == "Darwin" ]]; then
  pass "macOS"
else
  fail_msg "macOSではありません"
fi

if [[ "$(uname -m)" == "arm64" ]]; then
  pass "Apple Silicon (arm64)"
else
  fail_msg "arm64ではありません"
fi

if command -v brew >/dev/null 2>&1; then
  pass "Homebrew"
else
  fail_msg "Homebrewが見つかりません"
fi

if /usr/sbin/pkgutil --pkgs | /usr/bin/grep -E '^com\.apple\.pkg\.Rosetta' >/dev/null; then
  pass "Rosetta 2"
else
  warn_msg "Rosetta 2が見つかりません（arm64-only運用ならcontainer自体は利用可能）"
fi

formulae=(git gh container jq ripgrep fd shellcheck)
for pkg in "${formulae[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    pass "formula: $pkg"
  else
    fail_msg "formulaが未導入: $pkg"
  fi
done

casks=(firefox visual-studio-code bitwarden signal discord tailscale-app google-drive chatgpt)
for app in "${casks[@]}"; do
  if brew list --cask "$app" >/dev/null 2>&1; then
    pass "cask: $app"
  else
    fail_msg "caskが未導入: $app"
  fi
done

if command -v ansible-playbook >/dev/null 2>&1; then
  pass "Ansible"
else
  fail_msg "ansible-playbookが見つかりません"
fi

printf '\nSummary: FAIL=%d WARN=%d\n' "$fail" "$warn"
(( fail == 0 ))
