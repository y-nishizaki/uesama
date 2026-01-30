# コントリビューションガイド

## 開発環境セットアップ

### 前提条件

- **bash** (4.0+)
- **tmux** — `brew install tmux` / `sudo apt install tmux`
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
- **ShellCheck** — `brew install shellcheck` / `sudo apt install shellcheck`（推奨）

### 初期セットアップ

```bash
git clone https://github.com/y-nishizaki/uesama.git
cd uesama
bash scripts/setup-dev.sh
```

`setup-dev.sh` は以下を行います:

1. ShellCheck のインストール確認（未導入なら対話的にインストール）
2. pre-commit フックの有効化（`git config core.hooksPath .githooks`）

### pre-commit フック

コミット時にステージされたシェルスクリプトに対して自動実行されます:

- **ShellCheck** — 静的解析（warning レベル）
- **bash -n** — 構文チェック

スキップが必要な場合: `git commit --no-verify`

---

## プロジェクト構成

```
uesama/
├── bin/                        # CLI コマンド（uesama, uesama-daimyo, ...）
├── scripts/
│   ├── start.sh                # メイン起動スクリプト（tmux + Claude Code）
│   ├── setup.sh                # ユーザー向け依存チェック
│   └── setup-dev.sh            # 開発者向け環境セットアップ
├── template/
│   ├── instructions/           # 各エージェントのロール定義
│   │   ├── daimyo.md           #   大名（統括）
│   │   ├── sanbo.md            #   参謀（タスク管理）
│   │   └── kashin.md           #   家臣（実働）
│   ├── templates/              # dashboard.md, context.md のテンプレート
│   └── .claude/rules/          # Claude Code のルール設定
├── tests/
│   ├── run_tests.sh            # ユニットテスト
│   ├── test_tmux_integration.sh # tmux 統合テスト
│   └── test_template_consistency.sh
├── docs/
│   ├── workflow.md             # ワークフロー図（Mermaid）
│   ├── architecture.md         # アーキテクチャ解説
│   └── images/                 # SVG 画像（CI で自動生成）
├── .github/workflows/          # CI/CD
├── .githooks/pre-commit        # ローカルフック
├── install.sh                  # ユーザー向けインストーラ
└── uninstall.sh
```

---

## テストの実行

```bash
# ユニットテスト（ファイル存在、権限、構造チェック等）
bash tests/run_tests.sh

# tmux 統合テスト（tmux が必要）
bash tests/test_tmux_integration.sh

# テンプレート整合性チェック
bash tests/test_template_consistency.sh

# 全テストを一括実行
bash tests/run_tests.sh && bash tests/test_tmux_integration.sh && bash tests/test_template_consistency.sh
```

テストは CI でも自動実行されます（ShellCheck + actionlint + 全テスト）。

### テストの追加方法

`tests/run_tests.sh` に `pass` / `fail` ヘルパーを使って追加します:

```bash
if [ 条件 ]; then
    pass "テスト名"
else
    fail "テスト名" "エラー詳細"
fi
```

---

## ブランチ戦略

GitHub Flow を採用しています。

```
main ← develop ← feature/xxx
```

- `main`: 本番相当。ブランチ保護あり（PRレビュー1名必須、管理者にも適用）
- `develop`: 開発統合ブランチ。feature ブランチのマージ先
- feature ブランチは `develop` から切り、PRで `develop` にマージ
- リリース時に `develop` → `main` へPR

### ブランチ命名規則

| 種類 | 命名 | 例 |
|------|------|----|
| 機能追加 | `feature/xxx` | `feature/add-health-check` |
| バグ修正 | `fix/xxx` | `fix/yaml-parse-error` |
| リファクタ | `refactor/xxx` | `refactor/queue-system` |
| ドキュメント | `docs/xxx` | `docs/update-readme` |

---

## CI/CD

| ワークフロー | トリガー | 内容 |
|-------------|---------|------|
| `ci.yml` | push/PR to main | ShellCheck, actionlint, テスト |
| `ci-yaml-validate.yml` | push/PR to main | YAML lint |
| `ci-markdown-lint.yml` | push/PR to main | Markdown lint |
| `ci-security-check.yml` | push/PR to main | gitleaks（シークレット検出） |
| `ci-template-check.yml` | push/PR to main | テンプレート整合性 |
| `update-diagrams.yml` | push to main (docs/workflow.md) | SVG 画像自動再生成 |

---

## ワークフロー図の画像更新

README に埋め込んでいる SVG 画像は [kroki.io](https://kroki.io/) で Mermaid → SVG 変換しています。

`docs/workflow.md` を変更して main に push すると CI が自動で SVG を再生成します。

手動で再生成する場合:

```bash
# 全体フロー図
curl -s -o docs/images/workflow-overview.svg \
  -X POST "https://kroki.io/mermaid/svg" \
  -H "Content-Type: text/plain" \
  -d '@-' < <(sed -n '/^## 全体フロー/,/^## /{/^```mermaid$/,/^```$/{ /^```/d; p; }}' docs/workflow.md)

# 通信プロトコル図
curl -s -o docs/images/workflow-protocol.svg \
  -X POST "https://kroki.io/mermaid/svg" \
  -H "Content-Type: text/plain" \
  -d '@-' < <(sed -n '/^## 通信プロトコル/,/^## /{/^```mermaid$/,/^```$/{ /^```/d; p; }}' docs/workflow.md)
```

---

## リリース手順

1. `develop` ブランチで CHANGELOG.md を更新（`[Unreleased]` → バージョン番号）
2. `develop` → `main` へ PR 作成
3. レビュー後マージ
4. バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に従う

---

## コーディング規約

- シェルスクリプトは `#!/bin/bash` + `set -e` を必ず記述
- `eval` の使用禁止（インジェクション防止）
- 変数展開は `"${VAR}"` のようにダブルクォートで囲む
- ShellCheck の warning をすべて解消してからコミット
