# コントリビューションガイド

## ブランチ戦略

シンプルなGitHub Flowを採用。

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

## ワークフロー図の画像更新

README に埋め込んでいる SVG 画像は [kroki.io](https://kroki.io/) を使って Mermaid コードから生成しています。

`docs/workflow.md` の Mermaid 図を変更した場合は、以下の手順で SVG を再生成してください。

```bash
# 全体フロー図
curl -s -o docs/images/workflow-overview.svg \
  -X POST "https://kroki.io/mermaid/svg" \
  -H "Content-Type: text/plain" \
  -d '@-' < <(sed -n '/^## 全体フロー/,/^```$/{/^```mermaid$/,/^```$/{ /^```/d; p; }}' docs/workflow.md)

# 通信プロトコル図
curl -s -o docs/images/workflow-protocol.svg \
  -X POST "https://kroki.io/mermaid/svg" \
  -H "Content-Type: text/plain" \
  -d '@-' < <(sed -n '/^## 通信プロトコル/,/^```$/{/^```mermaid$/,/^```$/{ /^```/d; p; }}' docs/workflow.md)
```

任意の Mermaid コードから直接生成する場合:

```bash
curl -s -o output.svg \
  -X POST "https://kroki.io/mermaid/svg" \
  -H "Content-Type: text/plain" \
  -d 'flowchart TD
    A-->B'
```

生成した SVG は `docs/images/` に配置し、README では `<img>` タグで参照しています。
