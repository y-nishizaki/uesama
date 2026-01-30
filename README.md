# uesama

<div align="center">

<!-- markdownlint-disable MD036 -->
**AI コーディングエージェント マルチ統率システム**

*コマンド1つで、最大11体のAIエージェントが並列稼働*
<!-- markdownlint-enable MD036 -->

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![Codex](https://img.shields.io/badge/OpenAI-Codex-blue)](https://github.com/openai/codex)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

</div>

---

## これは何？

**uesama** は、複数の AI コーディングエージェント（Claude Code / Codex）を戦国時代の軍制のように統率するCLIツールです。

一度インストールすれば、任意のプロジェクトディレクトリで使用できます。

```text
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   DAIMYO    │  ← 命令を受け取り、即座に委譲
    │   (大名)    │
    └──────┬──────┘
           │ YAMLファイル + tmux send-keys
    ┌──────▼──────┐
    │    SANBO    │  ← タスクを分解し家臣に分配
    │   (参謀)    │
    └──────┬──────┘
           │
  ┌─┬─┬─┬─┴─┬─┬─┬─┬─┐
  │1│2│3│4│5│6│7│8│9│  ← 最大9体の家臣が並列実行
  └─┴─┴─┴─┴─┴─┴─┴─┴─┘
      KASHIN (家臣)
```

---

## クイックスタート

### 必要環境

- **tmux** — `brew install tmux` (macOS) / `sudo apt install tmux` (Linux)
- **AI コーディングエージェント**（いずれか1つ）:
  - Claude Code CLI — `npm install -g @anthropic-ai/claude-code`
  - Codex CLI — `npm install -g @openai/codex`

### インストール

```bash
curl -fsSL https://raw.githubusercontent.com/y-nishizaki/uesama/main/install.sh | sh
source ~/.zshrc  # または ~/.bashrc
```

### 使い方

```bash
cd /your/project
uesama              # 全エージェント起動
uesama-session      # セッションに接続
uesama-stop         # 全セッション終了
uesama-update       # uesama を最新版に更新
```

### アンインストール

```bash
cd uesama
./uninstall.sh
```

---

## 仕組み

1. `uesama` がプロジェクトに `.uesama/` ディレクトリを作成
2. tmux セッション `kashindan` を起動（大名+参謀+家臣のペインを配置）
3. 全エージェントで AI コーディングエージェント（Claude Code or Codex）を起動
4. エージェント間は YAML ファイル + tmux send-keys で通信（イベント駆動、ポーリングなし）
5. 進捗は `.uesama/dashboard.md` で確認

---

## アーキテクチャ

| エージェント | 役割 | 数 |
| ----------- | ---- | --- |
| 大名 (Daimyo) | 総大将 — あなたの命令を受け、参謀に委譲 | 1 |
| 参謀 (Sanbo) | 軍師 — タスクを分解し、家臣に割り当て | 1 |
| 家臣 (Kashin) | 実働部隊 — タスクを並列実行 | 9（デフォルト） |

家臣の数は環境変数 `UESAMA_KASHIN_COUNT` で変更できます。

### エージェント設定

`~/.uesama/config/settings.yaml` またはプロジェクトの `.uesama/config/settings.yaml` で設定:

```yaml
agent: claude              # 全ロール共通のデフォルト
agent_daimyo: claude       # 大名のみ指定
agent_sanbo: codex         # 参謀のみ指定
agent_kashin: claude       # 家臣のみ指定
```

環境変数でも上書き可能:

```bash
UESAMA_AGENT=claude                  # 全ロール共通
UESAMA_AGENT_DAIMYO=claude           # 大名のみ
UESAMA_AGENT_SANBO=codex             # 参謀のみ
UESAMA_AGENT_KASHIN=claude           # 家臣のみ
```

### tmux レイアウト

```text
┌──────────┬──────────┬──────────┬──────────┐
│          │ kashin1  │ kashin4  │ kashin7  │
│  大名    ├──────────┼──────────┼──────────┤
│          │ kashin2  │ kashin5  │ kashin8  │
├──────────┼──────────┼──────────┼──────────┤
│  参謀    │ kashin3  │ kashin6  │ kashin9  │
└──────────┴──────────┴──────────┴──────────┘
```

---

## ワークフロー図

### 全体フロー

<img src="docs/images/workflow-overview.svg" alt="全体ワークフロー" width="100%">

### 通信プロトコル

<img src="docs/images/workflow-protocol.svg" alt="通信プロトコル" width="100%">

詳細は [docs/workflow.md](docs/workflow.md) を参照。

---

## 使用例: 指示から完了報告までの流れ

上様が指示を1つ出すだけで、エージェント同士が自律的にやりとりしながらタスクを完了します。

```
上様 → 大名: "Stripe決済APIを実装せよ。エンドポイント、テスト、ドキュメントも揃えること"

  大名 → 参謀: "新しい指示がある。確認して実行せよ。"
                                        ── 上様はここで手が空く。次の指示を出してもよい ──

  参謀: (コードベースを読み、タスクを分解)
  参謀 → 大名: "計画案を提出する。4家臣に分配したい。承認を仰ぎたし。
    - 家臣1: POST /api/payments エンドポイント実装
    - 家臣2: Stripeサービス層の実装
    - 家臣3: 単体テスト・統合テスト作成
    - 家臣4: ドキュメント作成"

  大名: (計画をレビュー)
  大名 → 参謀: "家臣1と家臣2は同じファイルに触る可能性がある。
    エンドポイントとサービス層は1名にまとめよ。3家臣で再計画せよ。"

  参謀: (計画を修正し再提出)
  参謀 → 大名: "修正した。3家臣に再編。ファイル競合なし。
    - 家臣1: エンドポイント + サービス層
    - 家臣2: テスト作成
    - 家臣3: ドキュメント作成"

  大名: "よし、承認する。実行せよ。"
                                        ── 3名が同時に作業開始 ──

  家臣3 → 参謀: "任務完了でござる。docs/api/payments.md を作成した。"
  家臣1 → 参謀: "任務完了でござる。src/api/payments.ts, src/services/stripe.ts を作成した。"

  参謀: (家臣2がまだ作業中。家臣1,3の成果物を確認しながら待機)

  家臣2 → 参謀: "任務完了でござる。tests/api/payments.test.ts を作成した。"

  参謀: (全員完了。成果物を確認し、ダッシュボードを更新)
  参謀 → 大名: "全3タスク完了。dashboard.md を更新した。確認されたし。"

  大名: (ダッシュボードと成果物を確認)
  大名 → 上様: "Stripe決済API実装、完了いたしました。
    - エンドポイント + サービス層 (家臣1)
    - テスト作成 (家臣2)
    - ドキュメント作成 (家臣3)"
```

> 上様が操作するのは最初の指示だけです。計画のレビュー・差し戻し・承認・実行・集約・報告は
> すべてエージェント間で自律的に行われます。

---

## 主な特徴

- **並列実行**: 最大9タスクを同時実行
- **ノンブロッキング**: 命令後すぐ次の命令を出せる
- **イベント駆動**: ポーリングなしでAPI代金を節約
- **CLIインストール**: 一度入れればどのプロジェクトでも使える

---

## クレジット

[multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun)（yohey-w）をベースに開発。原型は [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication)（Akira-Papa）。

## 設定リファレンス

### 環境変数一覧

| 環境変数 | 説明 | デフォルト |
| -------- | ---- | ---------- |
| `UESAMA_HOME` | インストールディレクトリ | `$HOME/.uesama` |
| `UESAMA_KASHIN_COUNT` | 家臣（ワーカー）の数 | `9` |
| `UESAMA_AGENT` | 全ロール共通のエージェント (`claude` / `codex`) | `claude` |
| `UESAMA_AGENT_DAIMYO` | 大名のエージェント | `UESAMA_AGENT` に従う |
| `UESAMA_AGENT_SANBO` | 参謀のエージェント | `UESAMA_AGENT` に従う |
| `UESAMA_AGENT_KASHIN` | 家臣のエージェント | `UESAMA_AGENT` に従う |
| `UESAMA_ADMIN_BYPASS` | 承認フローをスキップ | `false` |

### 設定ファイル

`settings.yaml` は以下の順で読み込まれます（上が優先）:

1. プロジェクト: `.uesama/config/settings.yaml`
2. ユーザー: `~/.uesama/config/settings.yaml`

環境変数は設定ファイルより優先されます。

---

## トラブルシューティング

### tmux セッションが残ってしまった

```bash
uesama-stop                          # 通常の停止
tmux kill-session -t kashindan       # 手動で強制終了
```

### `uesama-session` で「セッションが見つかりません」と表示される

`uesama` で先にエージェントを起動してください。

### エージェントが応答しない・フリーズした

1. `uesama-session` でセッションに接続し、該当ペインを確認
2. 必要なら `uesama-stop` で全体を停止し、再度 `uesama` で起動

### ログの確認

各セッションのログは `.uesama/logs/<タイムスタンプ>/` に保存されます。

```bash
ls .uesama/logs/                     # セッション一覧
cat .uesama/logs/latest/sanbo.log    # 参謀のログを確認
```

---

## ⚠️ 利用上の注意

uesama は複数のAIエージェントを**許可確認なしの自動実行モード**（`--dangerously-skip-permissions`等）で起動します。これにより以下のリスクがあります。

- **ファイルの自動変更・削除**: エージェントはユーザーの確認なしにファイルを作成・編集・削除します。意図しない変更が発生する可能性があるため、**Git管理下のプロジェクトで使用すること**を強く推奨します。
- **禁止コマンドはプロンプトベースの制御**: `rm -rf /` などの危険なコマンドの抑止はシステムプロンプトによる指示に依存しており、技術的な強制力はありません。プロンプトインジェクション等により回避される可能性があります。
- **並列実行による影響範囲の拡大**: 最大11体のエージェントが同時に動作するため、問題が発生した場合の影響範囲が単体利用時より大きくなります。
- **トークン消費量の増大**: 複数エージェントが並列で動作するため、トークン消費量が急速に増加する場合があります。利用状況を定期的に確認してください。

本ツールは**自己責任**でご利用ください。重要なプロジェクトでは、使い捨てのブランチで試すなどの対策を推奨します。

---

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照。
