# アーキテクチャ

## 概要

uesama は tmux + AI コーディングエージェント（Claude Code / Codex）でマルチエージェント協調を実現するシステムです。エージェント間の通信はすべて YAML ファイル + `tmux send-keys` によるイベント駆動で行われ、ポーリングは一切行いません。

## エージェント構成

| エージェント | 数 | tmux ペイン | 役割 |
| ----------- | --- | ---------- | ---- |
| 大名 (Daimyo) | 1 | `kashindan:0`（左上） | ユーザーの命令を受け、参謀に委譲。計画の承認/修正判断 |
| 参謀 (Sanbo) | 1 | `kashindan:0.0`（左下） | タスク分解、家臣への割当、dashboard.md の更新 |
| 家臣 (Kashin) | 最大9 | `kashindan:0.1`〜 | タスクの実行と結果報告 |

家臣数はデフォルト9、環境変数 `UESAMA_KASHIN_COUNT` で変更可能。

## tmux レイアウト

すべてのエージェントは単一の tmux セッション `kashindan` 内に配置されます。

```text
┌──────────┬──────────┬──────────┬──────────┐
│          │ kashin1  │ kashin4  │ kashin7  │
│  大名    ├──────────┼──────────┼──────────┤
│          │ kashin2  │ kashin5  │ kashin8  │
├──────────┼──────────┼──────────┼──────────┤
│  参謀    │ kashin3  │ kashin6  │ kashin9  │
└──────────┴──────────┴──────────┴──────────┘
  左 25%          右 75%（3列）
```

## 通信プロトコル

### 原則

- **イベント駆動**: エージェントは通知されるまで停止状態。ポーリング禁止（API代金節約）
- **YAML ファイル**: 構造化データの受け渡し
- **send-keys**: tmux の `send-keys` で相手ペインにコマンドを送り「起こす」
- **2回の bash 呼び出し**: send-keys はメッセージ送信と Enter キー送信を別々に実行（1回だと確実に届かない）

### 通信フロー

```text
ユーザー → 大名: 直接入力
大名 → 参謀: .uesama/queue/daimyo_to_sanbo.yaml + send-keys
参謀 → 大名: .uesama/queue/sanbo_plan.yaml + send-keys（計画承認依頼）
参謀 → 家臣: .uesama/queue/tasks/kashin{N}.yaml + send-keys
家臣 → 参謀: .uesama/queue/reports/kashin{N}_report.yaml + send-keys
参謀 → 大名: dashboard.md 更新 + send-keys（完了通知）
大名 → ユーザー: 結果報告
```

## ファイル構成（プロジェクト側）

`uesama` を実行すると、対象プロジェクトに以下が作成されます:

```text
.uesama/
├── config/
│   └── settings.yaml           # 言語、家臣数、エージェント設定
├── queue/
│   ├── daimyo_to_sanbo.yaml    # 大名→参謀 指示
│   ├── sanbo_plan.yaml         # 参謀→大名 計画承認依頼
│   ├── tasks/
│   │   └── kashin{N}.yaml      # 参謀→家臣 タスク指示
│   └── reports/
│       └── kashin{N}_report.yaml # 家臣→参謀 結果報告
├── dashboard.md                # 進捗状況（参謀のみ更新）
├── instructions/ → symlink     # エージェントロール定義
└── templates/ → symlink        # テンプレートファイル
```

## エージェントのロール定義

各エージェントの振る舞いは `template/instructions/` 内の Markdown ファイルで定義されています。YAML Front Matter にワークフローと禁止事項が構造化されています。

### 禁止事項（共通）

すべてのエージェントに共通する禁止事項:

| ID | 内容 |
| -- | ---- |
| F003/F004 | Task agents の使用禁止（send-keys を使う） |
| F004 | ポーリング禁止 |
| F005 | コンテキストを読まずに作業開始禁止 |

### エージェント固有の制約

| エージェント | 禁止事項 |
| ----------- | ------- |
| 大名 | 自分でタスク実行しない。家臣に直接指示しない |
| 参謀 | 自分でタスク実行しない。ユーザーに直接報告しない |
| 家臣 | 大名に直接報告しない。ユーザーに直接連絡しない。指示外の作業禁止 |

## 計画承認フロー

参謀は以下の条件でタスク実行前に大名の承認を求めます:

- 大規模な変更
- 家臣3人以上を動員
- 破壊的変更
- コンテキスト不足

承認不要の場合（新規ファイルのみ、家臣1〜2人、具体的な指示）は直接実行に移ります。

## 並列実行ルール

- 異なるファイルを扱う家臣は並列実行可能
- 同一ファイルへの書き込みは禁止（RACE-001）
- 依存関係がある場合は逐次実行

## エスカレーション

大名が自律判断する範囲:

- タスクの承認/否認、次のタスク指示、軽微な方針調整、品質チェック

上様（ユーザー）に判断を仰ぐケース:

- セキュリティ問題、大規模方針変更、コスト影響、要件の根本的変更

## 拡張ポイント

### 新しいエージェントロールの追加

1. `template/instructions/` に新ロールの `.md` ファイルを作成
2. `scripts/start.sh` にペイン作成と指示送信のロジックを追加
3. 通信用 YAML ファイルのパスを定義

### 家臣数の変更

環境変数で制御:

```bash
export UESAMA_KASHIN_COUNT=4
uesama
```

または `~/.uesama/config/settings.yaml`:

```yaml
kashin_count: 4
```

### ロール別エージェント設定

大名・参謀・家臣それぞれに異なる AI エージェントを指定できます。

`~/.uesama/config/settings.yaml`（またはプロジェクト `.uesama/config/settings.yaml`）:

```yaml
agent: claude              # 全ロール共通のデフォルト
agent_daimyo: claude       # 大名のみ上書き
agent_sanbo: codex         # 参謀のみ上書き
agent_kashin: claude       # 家臣のみ上書き
```

環境変数でも制御可能（settings.yaml より優先）:

| 環境変数 | 対象 |
| -------- | ---- |
| `UESAMA_AGENT` | 全ロール共通のデフォルト |
| `UESAMA_AGENT_DAIMYO` | 大名のみ |
| `UESAMA_AGENT_SANBO` | 参謀のみ |
| `UESAMA_AGENT_KASHIN` | 家臣のみ |

優先順位: 環境変数 `UESAMA_AGENT_<ROLE>` > settings.yaml `agent_<role>` > `UESAMA_AGENT` > settings.yaml `agent` > デフォルト（claude）
