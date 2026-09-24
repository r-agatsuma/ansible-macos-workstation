# ansible-macos-workstation

Apple Silicon Macを初期化したあと、個人用ワークステーションとして必要なCLIツールとGUIアプリを短時間で戻すための小さなAnsible Cookbookです。

目的はmacOSを完全に宣言的管理することではありません。**ソフトウェアだけをだいたい同じ状態に戻し、それ以外はmacOSと人間に任せる**方針です。

## 対象

- Apple Silicon (`arm64`)
- macOS 26以降
- 個人用の開発ワークステーション
- Homebrew + Ansibleによるローカル構成管理

Mac固有の細かな設定差は許容します。2台のMacを完全なクローンにはしません。

## 管理するもの

### Homebrew Formula

| パッケージ | 用途 |
| --- | --- |
| `git` | Git |
| `gh` | GitHub CLI |
| `container` | AppleのLinux container実行環境 |
| `jq` | JSON処理 |
| `ripgrep` | 高速な全文検索 (`rg`) |
| `fd` | ファイル検索 |
| `shellcheck` | shell scriptの静的解析 |
| `go` | Go toolchain |
| `tmux` | ターミナル多重化 |

`awk`、`sed`、`grep`、`find`、`curl`、`ssh`、`rsync`などはmacOS標準のものを使います。GNU版への依存を標準環境へ持ち込まない方針です。

### Homebrew Cask

| Cask | アプリ |
| --- | --- |
| `firefox` | Firefox |
| `visual-studio-code` | Visual Studio Code |
| `bitwarden` | Bitwarden |
| `signal` | Signal |
| `discord` | Discord |
| `tailscale-app` | Tailscale |
| `google-drive` | Google Drive |
| `chatgpt` | ChatGPTデスクトップアプリ |
| `codex` | Codex CLI |
| `obsidian` | Obsidian |

CodexはCLIですが、Homebrew Caskの`codex`で配布されています。ChatGPTデスクトップアプリの`chatgpt` Caskも引き続き導入します。

### Go-installed tools

| ツール | インストール元 |
| --- | --- |
| `iro` | `github.com/r-agatsuma/iro/cmd/iro@latest` |

`go env GOPATH`で実効GOPATHを取得し、複数のエントリがある場合は先頭の`bin`ディレクトリに`iro`を導入します。インストール時の`GOBIN`をこのディレクトリに指定するため、既存の`GOBIN`設定には依存しません。システムやHomebrewのバイナリディレクトリへは移動しません。期待する場所に`iro`が無い場合だけ`go install github.com/r-agatsuma/iro/cmd/iro@latest`を実行し、既存のバイナリは毎回更新しません。

Ansibleは`~/.zshrc`の以下の専用ブロックだけを管理し、その他の既存内容を保持します。ファイルが無ければ作成します。PATHには実際に解決したGoバイナリディレクトリをシェル用に引用して設定します。

```sh
# BEGIN ANSIBLE MANAGED: Go tools
export PATH="<resolved GOPATH bin>:$PATH"
# END ANSIBLE MANAGED: Go tools
```

再適用してもブロックは重複しません。PATHの反映には新しい対話的zshセッションを開いてください。既に実行中のシェルへの即時反映は不要です。

## 管理しないもの

以下は意図的にAnsibleの責務外です。

- Apple Account
- Touch ID
- FileVaultとrecovery key
- Dock、Finder、壁紙、キーボード等のmacOS設定
- TCC / Privacy & Securityの承認
- TailscaleのログインとVPN/System Extensionの承認
- Google DriveのログインとOS側の権限承認
- Bitwarden / Signal / Discord / ChatGPTのログイン
- VS Codeの設定・Extension・Settings Sync
- Obsidian VaultとVault内の設定 (`.obsidian`)
- SSH秘密鍵や開発データ
- Git repositoryのrestore
- `.zshrc`全体や汎用dotfiles管理
- tmuxの設定
- Codexのログイン・設定
- iroのプロジェクト設定

秘密情報をこのrepositoryへ保存しないでください。

## 初期構築

macOS初期化後、このrepositoryを取得してTerminalを開きます。

### 1. bootstrap

```bash
./bootstrap.sh
```

`bootstrap.sh`は以下を準備します。

1. Apple Silicon / macOS 26以降であることを確認
2. Xcode Command Line Toolsを確認
3. Homebrewを確認し、無ければ公式installerで導入
4. Rosetta 2を確認し、無ければ導入
5. AnsibleをHomebrewで導入
6. `community.general` collectionを導入

Command Line Toolsが無い場合はAppleのinstallerを起動して終了します。インストール完了後に`./bootstrap.sh`をもう一度実行してください。

Homebrewの標準prefixはApple Siliconでは`/opt/homebrew`です。

### 2. Playbookを実行

```bash
ansible-playbook playbook.yml
```

不足しているHomebrew Formula / CaskとGo経由のiroを導入し、Goツール用のPATHブロックを設定します。実行時に`pkg型Cask導入用のmacOS管理者パスワード`を非表示で入力します。このpasswordは、Google DriveやTailscaleなどpkg型Caskのinstallerがsudoを必要とする場合にだけ`homebrew_cask`へ渡します。Homebrew自体をrootで実行するためのものではありません。

このPlaybookは`state: present`を使います。既に入っているソフトウェアを毎回強制upgradeしたり、versionを固定したりしません。

### 3. 確認

```bash
./verify.sh
```

Homebrew Formula / CaskとAnsibleの存在、動的に解決したGOPATHの先頭の`bin/iro`の存在と実行権限、`~/.zshrc`のGoツール用PATHブロックを確認します。現在のシェルのPATHが未反映でもiroを検証できます。ログイン状態やmacOSの権限状態は検査対象外です。

## 初回だけ人間が行う作業

Ansible完了後、必要なアプリを起動して初回設定を行います。

### Apple container

通常のarm64 containerを使うだけならRosetta 2は必須ではありません。このCookbookでは、将来`linux/amd64`のimageやbinaryが必要になった場合に備えてRosetta 2を標準導入します。

必要になった時点でcontainer systemを起動します。

```bash
container system start
```

kernel等の初回準備が発生する場合があります。

### Tailscale

Tailscaleを起動してログインします。macOSからVPN/System ExtensionやPrivacy & Securityの承認を要求された場合は、人間が内容を確認して許可します。

### Google Drive

Google Driveを起動してGoogle Accountへログインします。File Providerやフォルダアクセス等をmacOSから求められた場合は手動で許可します。

### その他

Bitwarden、Signal、Discord、ChatGPT、VS Codeも必要に応じてログイン・同期します。ObsidianはGoogle Drive上の既存Vaultを手動で開きます。

## 日常の再適用

software listを変更した場合や、状態を確認したい場合は再度実行できます。

```bash
./bootstrap.sh
ansible-playbook playbook.yml
./verify.sh
```

基本的には不足しているsoftwareだけが追加されます。

## 初期化テストの想定

最初は現在使っていないMacをReference Implementation兼テスト機として使います。

```text
必要データを退避
  ↓
macOSを初期化
  ↓
macOSの初期設定
  ↓
このrepositoryを取得
  ↓
./bootstrap.sh
  ↓
ansible-playbook playbook.yml
  ↓
./verify.sh
  ↓
各GUIアプリのlogin / OS権限承認
  ↓
開発データをrestore
  ↓
実運用して不足softwareだけCookbookへ追加
```

この流れが安定したら、もう1台のMacにも同じCookbookを適用します。

## 設計方針

このrepositoryは「Macそのものを再現する」ためのものではありません。

再現したいのは、初期化後に必要なsoftwareが揃い、Git・editor・container・VPN・cloud storage・messaging・password manager・AI開発環境をすぐ使い始められる状態です。

macOSの個人設定まで管理対象を広げると保守コストが上がるため、必要性が出るまでは追加しません。
