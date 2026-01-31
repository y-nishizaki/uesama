# AGENT.md

AIコーディングエージェントがこのリポジトリで作業する際のガイドライン。

## プロジェクト概要

uesama（上様）は、最大11のAIコーディングエージェント（Claude Code / Codex）を並列管理するBashベースのマルチエージェントオーケストレーションシステム。封建制の階層メタファーを採用：

- **大名（Daimyo）** × 1：プロジェクトリーダー。ユーザーから指示を受け参謀に委任
- **参謀（Sanbo）** × 1：タスク分解・家臣への割り当て・ダッシュボード管理
- **家臣（Kashin）** × 最大9：タスクを並列実行するワーカー

通信はすべて **YAMLファイル + tmux send-keys** で行われる（ポーリングなし）。

## コマンド

```bash
# 開発環境セットアップ
bash scripts/setup-dev.sh

# テスト実行
bash tests/run_tests.sh                    # ユニットテスト (69+チェック)
bash tests/test_tmux_integration.sh        # tmux統合テスト (25+チェック)
bash tests/test_template_consistency.sh    # テンプレート整合性

# 起動・停止
uesama [--admin-bypass]    # マルチエージェントシステム起動
uesama-session             # 実行中のtmuxセッションにアタッチ
uesama-stop                # 全セッション終了
```

## CI で実行されるリンター

ShellCheck（警告レベル）、`bash -n`構文検証、actionlint、yamllint、markdownlint、gitleaks。pre-commitフックでもShellCheckと構文検証が走る。

## アーキテクチャ

### 通信フロー

```
User → Daimyo → Sanbo → Kashin(1-9) 並列実行
                Sanbo ← Kashin(報告)
       Daimyo ← Sanbo(ダッシュボード更新)
User ← Daimyo(結果報告)
```

参謀が承認要否を判断し、大規模変更・3人以上のワーカー・破壊的操作の場合は大名に承認を求める。`admin_bypass: true` で承認フローをスキップ可能。

### 主要ファイル

- `bin/uesama` — CLIエントリポイント（ラッパー）
- `scripts/start.sh` — メインオーケストレーションロジック（~500行）
- `scripts/setup.sh` — 依存関係チェック（tmux, エージェント）
- `template/instructions/{daimyo,sanbo,kashin}.md` — 各ロールの定義（YAML Front Matter付き）
- `template/templates/{context,dashboard}.md` — プロジェクトコンテキスト・進捗テンプレート

### 実行時に生成されるファイル（.uesama/）

```
.uesama/
├── config/settings.yaml       # 言語、ワーカー数、エージェント設定
├── queue/
│   ├── daimyo_to_sanbo.yaml   # 大名→参謀コマンド
│   ├── sanbo_plan.yaml        # 参謀→大名承認リクエスト
│   ├── tasks/kashin{N}.yaml   # 参謀→家臣タスク割当
│   └── reports/kashin{N}_report.yaml  # 家臣→参謀結果報告
├── dashboard.md               # 進捗管理（参謀が更新）
└── memory/global_context.md   # 永続的プロジェクト知識
```

### tmuxレイアウト

左25%に大名・参謀、右75%に家臣9人（3列×3行）。起動時に大名ペインがアクティブ。

### 並行性ルール

- 異なるワーカーが異なるファイルを操作：OK
- 複数ワーカーが同一ファイルを操作（RACE-001）：禁止
- 依存関係がある場合は逐次実行にフォールバック

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `UESAMA_HOME` | `$HOME/.uesama` | インストールディレクトリ |
| `UESAMA_KASHIN_COUNT` | `9` | ワーカー数 |
| `UESAMA_AGENT` | `claude` | デフォルトエージェント種別 |
| `UESAMA_AGENT_DAIMYO/SANBO/KASHIN` | `UESAMA_AGENT`継承 | ロール別エージェント |
| `UESAMA_ADMIN_BYPASS` | `false` | 承認フロースキップ |
