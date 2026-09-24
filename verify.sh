#!/bin/bash
set -u

# ソフトウェアの存在とGoツール用のPATHブロックを確認する。
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

formulae=(git gh container jq ripgrep fd shellcheck go tmux)
for pkg in "${formulae[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    pass "formula: $pkg"
  else
    fail_msg "formulaが未導入: $pkg"
  fi
done

casks=(firefox visual-studio-code bitwarden signal discord tailscale-app google-drive chatgpt codex obsidian)
for app in "${casks[@]}"; do
  if brew list --cask "$app" >/dev/null 2>&1; then
    pass "cask: $app"
  else
    fail_msg "caskが未導入: $app"
  fi
done

if go_gopath=$(go env GOPATH) && [[ -n "$go_gopath" ]]; then
  go_bin_dir="${go_gopath%%:*}/bin"
  if [[ -f "$go_bin_dir/iro" && -x "$go_bin_dir/iro" ]]; then
    pass "iro: $go_bin_dir/iro"
  else
    fail_msg "iroが存在しないか実行できません: $go_bin_dir/iro"
  fi

  # .zshrcを実行せず、Ansibleのquoteフィルタと同じシェル引用を検証する。
  quoted_go_bin_dir="$go_bin_dir"
  if [[ "$go_bin_dir" == *[!a-zA-Z0-9_@%+=:,./-]* ]]; then
    escaped_quote="'\"'\"'"
    quoted_go_bin_dir="'${go_bin_dir//\'/$escaped_quote}'"
  fi
  expected_go_block=$(printf '%s\n' \
    '# BEGIN ANSIBLE MANAGED: Go tools' \
    "export PATH=$quoted_go_bin_dir:\"\$PATH\"" \
    '# END ANSIBLE MANAGED: Go tools')
  if [[ -f "$HOME/.zshrc" ]] && \
    actual_go_block=$(sed -n '/^# BEGIN ANSIBLE MANAGED: Go tools$/,/^# END ANSIBLE MANAGED: Go tools$/p' "$HOME/.zshrc") && \
    [[ "$actual_go_block" == "$expected_go_block" ]]; then
    pass "Goツール用PATHブロック"
  else
    fail_msg "$HOME/.zshrcのGoツール用PATHブロックが存在しないか一致しません"
  fi
else
  fail_msg "go env GOPATHを取得できません（iroとPATHブロックを検証できません）"
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  pass "Ansible"
else
  fail_msg "ansible-playbookが見つかりません"
fi

printf '\nSummary: FAIL=%d WARN=%d\n' "$fail" "$warn"
(( fail == 0 ))
