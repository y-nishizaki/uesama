#!/bin/bash
# uesama 起動スクリプト
# tmux セッション作成 & エージェント（Claude Code / Codex）起動
set -e

UESAMA_HOME="${UESAMA_HOME:-$HOME/.uesama}"
ADMIN_BYPASS="${UESAMA_ADMIN_BYPASS:-false}"

# オプション解析
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --admin-bypass)
            ADMIN_BYPASS="true"
            shift
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

PROJECT_DIR="${POSITIONAL_ARGS[0]:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
KASHIN_COUNT="${UESAMA_KASHIN_COUNT:-9}"

# 言語設定を読み取り
LANG_SETTING="ja"
if [ -f "$PROJECT_DIR/.uesama/config/settings.yaml" ]; then
    export LANG_SETTING
    LANG_SETTING=$(grep "^language:" "$PROJECT_DIR/.uesama/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
elif [ -f "$UESAMA_HOME/config/settings.yaml" ]; then
    export LANG_SETTING
    LANG_SETTING=$(grep "^language:" "$UESAMA_HOME/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# エージェント設定読み取りヘルパー
# 設定ファイルから指定キーの値を取得する
read_setting() {
    local key="$1"
    local val=""
    if [ -f "$PROJECT_DIR/.uesama/config/settings.yaml" ]; then
        val=$(grep "^${key}:" "$PROJECT_DIR/.uesama/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "")
    fi
    if [ -z "$val" ] && [ -f "$UESAMA_HOME/config/settings.yaml" ]; then
        val=$(grep "^${key}:" "$UESAMA_HOME/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "")
    fi
    echo "$val"
}

# エージェント種別からコマンド情報を返すヘルパー
resolve_agent_cmd() {
    local agent_type="$1"
    case "$agent_type" in
        claude)
            echo "claude --dangerously-skip-permissions"
            ;;
        codex)
            echo "codex --full-auto"
            ;;
        *)
            echo "エラー: 未知のエージェント種別: $agent_type" >&2
            echo "  対応エージェント: claude, codex" >&2
            exit 1
            ;;
    esac
}

resolve_agent_display() {
    case "$1" in
        claude) echo "Claude Code" ;;
        codex)  echo "Codex" ;;
    esac
}

resolve_agent_ready_pattern() {
    case "$1" in
        claude) echo "bypass permissions" ;;
        codex)  echo '\$' ;;
    esac
}

# デフォルトエージェント（全ロール共通のフォールバック）
DEFAULT_AGENT="${UESAMA_AGENT:-$(read_setting agent)}"
DEFAULT_AGENT="${DEFAULT_AGENT:-claude}"

# ロール別エージェント設定
# 優先順: 環境変数 > settings.yaml の agent_<role> > デフォルト
AGENT_DAIMYO="${UESAMA_AGENT_DAIMYO:-$(read_setting agent_daimyo)}"
AGENT_DAIMYO="${AGENT_DAIMYO:-$DEFAULT_AGENT}"

AGENT_SANBO="${UESAMA_AGENT_SANBO:-$(read_setting agent_sanbo)}"
AGENT_SANBO="${AGENT_SANBO:-$DEFAULT_AGENT}"

AGENT_KASHIN="${UESAMA_AGENT_KASHIN:-$(read_setting agent_kashin)}"
AGENT_KASHIN="${AGENT_KASHIN:-$DEFAULT_AGENT}"

# 各ロールのコマンドを解決
DAIMYO_CMD=$(resolve_agent_cmd "$AGENT_DAIMYO")
SANBO_CMD=$(resolve_agent_cmd "$AGENT_SANBO")
KASHIN_CMD=$(resolve_agent_cmd "$AGENT_KASHIN")

DAIMYO_DISPLAY=$(resolve_agent_display "$AGENT_DAIMYO")
SANBO_DISPLAY=$(resolve_agent_display "$AGENT_SANBO")
KASHIN_DISPLAY=$(resolve_agent_display "$AGENT_KASHIN")

DAIMYO_READY_PATTERN=$(resolve_agent_ready_pattern "$AGENT_DAIMYO")

# 表示用のエージェント名（全部同じならシンプルに、違うなら列挙）
if [ "$AGENT_DAIMYO" = "$AGENT_SANBO" ] && [ "$AGENT_SANBO" = "$AGENT_KASHIN" ]; then
    AGENT_DISPLAY_SUMMARY="$DAIMYO_DISPLAY"
else
    AGENT_DISPLAY_SUMMARY="大名:${DAIMYO_DISPLAY} / 参謀:${SANBO_DISPLAY} / 家臣:${KASHIN_DISPLAY}"
fi

# 色付きログ関数
log_info() { echo -e "\033[1;33m【報】\033[0m $1"; }
log_success() { echo -e "\033[1;32m【成】\033[0m $1"; }
log_war() { echo -e "\033[1;31m【戦】\033[0m $1"; }

# バナー表示
show_banner() {
    clear
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██╗   ██╗███████╗███████╗ █████╗ ███╗   ███╗ █████╗ \033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║██╔════╝██╔════╝██╔══██╗████╗ ████║██╔══██╗\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║█████╗  ███████╗███████║██╔████╔██║███████║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║██╔══╝  ╚════██║██╔══██║██║╚██╔╝██║██╔══██║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m╚██████╔╝███████╗███████║██║  ██║██║ ╚═╝ ██║██║  ██║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m    \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m              \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # 武士アスキーアート
    local BANNER_FILE="$UESAMA_HOME/scripts/banner_samurai.txt"
    if [ -f "$BANNER_FILE" ]; then
        echo -e "\033[1;37m"
        cat "$BANNER_FILE"
        echo -e "\033[0m"
    fi

    echo -e "\033[1;36m                   ╔═══════════════════════════════╗\033[0m"
    echo -e "\033[1;36m                   ║   家 臣 団 ・ \033[1;37m${KASHIN_COUNT}\033[1;36m 名 配 備      ║\033[0m"
    echo -e "\033[1;36m                   ╚═══════════════════════════════╝\033[0m"
    echo ""
    echo -e "              \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""
}

show_banner

echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m"
echo "  プロジェクト: $PROJECT_DIR"
echo "  エージェント: $AGENT_DISPLAY_SUMMARY"
if [ "$ADMIN_BYPASS" = "true" ]; then
    echo ""
    echo -e "  \033[1;31m⚠️  管理者バイパスモード: 有効\033[0m"
    echo -e "  \033[1;31m    上様の承認なしに大名が全権で判断いたす\033[0m"
fi
echo ""

# ═══════════════════════════════════════════════
# STEP 1: 既存セッションクリーンアップ
# ═══════════════════════════════════════════════
log_info "既存の陣を撤収中..."
tmux kill-session -t kashindan 2>/dev/null && log_info "  └─ kashindan陣、撤収完了" || true

# ═══════════════════════════════════════════════
# STEP 2: プロジェクトディレクトリに .uesama/ 初期化
# ═══════════════════════════════════════════════
log_info "プロジェクト陣地を構築中..."

PROJ_UESAMA="$PROJECT_DIR/.uesama"
mkdir -p "$PROJ_UESAMA/queue/tasks" "$PROJ_UESAMA/queue/reports" \
         "$PROJ_UESAMA/status" "$PROJ_UESAMA/config" "$PROJ_UESAMA/memory" \
         "$PROJ_UESAMA/logs"

# テンプレートからシンボリックリンク
for dir in instructions templates; do
    if [ ! -L "$PROJ_UESAMA/$dir" ]; then
        rm -rf "${PROJ_UESAMA:?}/$dir"
        ln -sf "$UESAMA_HOME/template/.uesama/$dir" "$PROJ_UESAMA/$dir"
    fi
done

# .gitignore に .uesama/ 追加
if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q "^\.uesama/" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# uesama multi-agent system" >> "$PROJECT_DIR/.gitignore"
        echo ".uesama/" >> "$PROJECT_DIR/.gitignore"
    fi
else
    echo "# uesama multi-agent system" > "$PROJECT_DIR/.gitignore"
    echo ".uesama/" >> "$PROJECT_DIR/.gitignore"
fi

log_success "  └─ プロジェクト陣地構築完了"

# ═══════════════════════════════════════════════
# STEP 3: キューファイルリセット
# ═══════════════════════════════════════════════
log_info "軍議記録を初期化中..."

for i in $(seq 1 $KASHIN_COUNT); do
    cat > "$PROJ_UESAMA/queue/reports/kashin${i}_report.yaml" << EOF
worker_id: kashin${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    cat > "$PROJ_UESAMA/queue/tasks/kashin${i}.yaml" << EOF
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
done

cat > "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml" << 'EOF'
queue: []
EOF

# ═══════════════════════════════════════════════
# STEP 4: ダッシュボード初期化
# ═══════════════════════════════════════════════
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
sed "s/{{TIMESTAMP}}/$TIMESTAMP/" "$UESAMA_HOME/template/.uesama/templates/dashboard.md" > "$PROJ_UESAMA/dashboard.md"

# context.md（なければテンプレートからコピー）
if [ ! -f "$PROJ_UESAMA/context.md" ]; then
    cp "$UESAMA_HOME/template/.uesama/templates/context.md" "$PROJ_UESAMA/context.md"
fi

# config/settings.yaml（なければ作成）
if [ ! -f "$PROJ_UESAMA/config/settings.yaml" ]; then
    cat > "$PROJ_UESAMA/config/settings.yaml" << EOF
language: ja
kashin_count: $KASHIN_COUNT
agent: $DEFAULT_AGENT
agent_daimyo: $AGENT_DAIMYO
agent_sanbo: $AGENT_SANBO
agent_kashin: $AGENT_KASHIN

# 管理者バイパスモード
# true にすると上様（人間）の承認待ちをスキップし、大名が全権委任で判断する
# 起動オプション: uesama --admin-bypass
# 環境変数: UESAMA_ADMIN_BYPASS=true
admin_bypass: $ADMIN_BYPASS

# ═══════════════════════════════════════════════
# セキュリティポリシー（エンタープライズ向け）
# ═══════════════════════════════════════════════
security:
  # 家臣が実行を禁止されるコマンドパターン
  # マッチした場合、家臣は status: blocked で参謀に報告する義務がある
  blocked_commands:
    - "rm -rf /"
    - "git push --force"
    - "git push -f"
    - "git reset --hard"
    - "chmod 777"
    - "DROP TABLE"
    - "DROP DATABASE"
    - "TRUNCATE"

  # 読み書き禁止のファイルパターン（glob形式）
  # 家臣はこれらのファイルにアクセスしてはならない
  protected_paths:
    - ".env"
    - ".env.*"
    - "**/*.pem"
    - "**/*.key"
    - "**/credentials*"
    - "**/secrets*"
    - "**/.aws/*"
    - "**/.ssh/*"

  # 書き込み許可スコープ（設定時、この範囲外への書き込みを禁止）
  # 空またはコメントアウトで制限なし
  # writable_scope:
  #   - "src/**"
  #   - "docs/**"
  #   - "tests/**"
  #   - "package.json"
  #   - "tsconfig.json"

  # 家臣が参謀の承認なしに実行できない操作カテゴリ
  requires_approval:
    - "file_delete"        # ファイル・ディレクトリの削除
    - "git_push"           # git push（通常pushも含む）
    - "package_install"    # npm install, pip install 等
    - "external_request"   # curl, wget 等の外部通信
    - "config_change"      # 設定ファイルの変更
    - "schema_change"      # DBスキーマ変更
EOF
fi

log_success "  └─ 初期化完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 5: kashindanセッション作成（大名 + 参謀 + 家臣×N）
# ═══════════════════════════════════════════════
TOTAL_PANES=$((KASHIN_COUNT + 2))  # daimyo + sanbo + kashin
log_war "⚔️ 全軍の陣を構築中（${TOTAL_PANES}名配備）..."

# レイアウト:
# ┌──────────┬──────────┬──────────┬──────────┐
# │          │ kashin1  │ kashin4  │ kashin7  │
# │  大名    ├──────────┼──────────┼──────────┤
# │          │ kashin2  │ kashin5  │ kashin8  │
# ├──────────┼──────────┼──────────┼──────────┤
# │  参謀    │ kashin3  │ kashin6  │ kashin9  │
# └──────────┴──────────┴──────────┴──────────┘

# 1. セッション作成（左列全体 → 大名+参謀になる）
tmux new-session -d -s kashindan -n "agents" -c "$PROJECT_DIR"
LEFT_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')

# 2. 左右分割: 左25%=大名+参謀列、右75%=家臣エリア
tmux split-window -h -p 75 -t "$LEFT_ID"
RIGHT_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')

# 3. 左列を上下分割: 上67%=大名、下33%=参謀
tmux split-window -v -p 33 -t "$LEFT_ID"
SANBO_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')
DAIMYO_ID="$LEFT_ID"

# 4. 右エリアを3列に分割
tmux split-window -h -p 67 -t "$RIGHT_ID"
COL23_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')
tmux split-window -h -p 50 -t "$COL23_ID"
COL3_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')
COL1_ID="$RIGHT_ID"
COL2_ID="$COL23_ID"

# 5. 各列を3行に分割（家臣×9）
KASHIN_IDS=()
for COL_ID in "$COL1_ID" "$COL2_ID" "$COL3_ID"; do
    KASHIN_IDS+=("$COL_ID")
    tmux split-window -v -p 67 -t "$COL_ID"
    MID_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')
    KASHIN_IDS+=("$MID_ID")
    tmux split-window -v -p 50 -t "$MID_ID"
    BOT_ID=$(tmux display-message -t "kashindan:0" -p '#{pane_id}')
    KASHIN_IDS+=("$BOT_ID")
done

# ペインタイトル・PS1設定
# 大名（ダークネイビー背景）
tmux select-pane -t "$DAIMYO_ID" -T "daimyo" -P 'bg=colour17'
tmux send-keys -t "$DAIMYO_ID" "cd '$PROJECT_DIR' && export PS1='(\[\033[1;35m\]大名\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter

# 参謀
tmux select-pane -t "$SANBO_ID" -T "sanbo"
tmux send-keys -t "$SANBO_ID" "cd '$PROJECT_DIR' && export PS1='(\[\033[1;31m\]sanbo\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter

# 家臣1-9
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    kid="${KASHIN_IDS[$i]}"
    num=$((i + 1))
    tmux select-pane -t "$kid" -T "kashin$num" 2>/dev/null || true
    tmux send-keys -t "$kid" "cd '$PROJECT_DIR' && export PS1='(\[\033[1;34m\]kashin$num\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter 2>/dev/null || true
done

log_success "  └─ 全軍の陣、構築完了"

# ペインIDマッピングを panes.yaml に書き出し（uesama-send 用）
log_info "  └─ ペインIDマッピングを生成中..."
{
    echo "# uesama pane ID mapping (auto-generated)"
    echo "daimyo: $DAIMYO_ID"
    echo "sanbo: $SANBO_ID"
    for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
        num=$((i + 1))
        echo "kashin${num}: ${KASHIN_IDS[$i]}"
    done
} > "$PROJ_UESAMA/panes.yaml"
log_success "  └─ panes.yaml 生成完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 7: エージェント起動（Claude Code / Codex）
# ═══════════════════════════════════════════════
log_war "👑 全軍にエージェントを召喚中..."

# 大名
tmux send-keys -t "$DAIMYO_ID" "$DAIMYO_CMD"
tmux send-keys -t "$DAIMYO_ID" Enter
log_info "  └─ 大名（${DAIMYO_DISPLAY}）、召喚完了"

sleep 1

# 参謀
tmux send-keys -t "$SANBO_ID" "$SANBO_CMD"
tmux send-keys -t "$SANBO_ID" Enter

# 家臣
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    tmux send-keys -t "${KASHIN_IDS[$i]}" "$KASHIN_CMD"
    tmux send-keys -t "${KASHIN_IDS[$i]}" Enter
done
log_info "  └─ 参謀（${SANBO_DISPLAY}）・家臣（${KASHIN_DISPLAY}）、召喚完了"

log_success "✅ 全軍エージェント起動完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 8: 指示書読み込み
# ═══════════════════════════════════════════════
log_war "📜 各エージェントに指示書を読み込ませ中..."

echo "  ${DAIMYO_DISPLAY} の起動を待機中（最大30秒）..."
for i in {1..30}; do
    if tmux capture-pane -t "$DAIMYO_ID" -p | grep -q "$DAIMYO_READY_PATTERN"; then
        echo "  └─ 大名の ${DAIMYO_DISPLAY} 起動確認完了（${i}秒）"
        break
    fi
    sleep 1
done

# 大名に指示書
log_info "  └─ 大名に指示書を伝達中..."
UESAMA_PROJECT_DIR="$PROJECT_DIR" "$UESAMA_HOME/bin/uesama-send" daimyo ".uesama/instructions/daimyo.md を読んで役割を理解せよ。"

# 参謀に指示書
sleep 2
log_info "  └─ 参謀に指示書を伝達中..."
UESAMA_PROJECT_DIR="$PROJECT_DIR" "$UESAMA_HOME/bin/uesama-send" sanbo ".uesama/instructions/sanbo.md を読んで役割を理解せよ。"

# 家臣に指示書
sleep 2
log_info "  └─ 家臣に指示書を伝達中..."
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    num=$((i + 1))
    UESAMA_PROJECT_DIR="$PROJECT_DIR" "$UESAMA_HOME/bin/uesama-send" "kashin${num}" ".uesama/instructions/kashin.md を読んで役割を理解せよ。汝は家臣${num}号である。"
    sleep 0.5
done

log_success "✅ 全軍に指示書伝達完了"
echo ""

# 大名ペインをアクティブに設定（attach時に大名ペインにフォーカスが当たるようにする）
tmux select-pane -t "$DAIMYO_ID"

# ═══════════════════════════════════════════════
# 完了メッセージ
# ═══════════════════════════════════════════════
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  コマンド一覧:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  uesama-stop      全セッション停止（撤収）               │"
echo "  │  uesama-session   セッションに再接続                     │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════
# STEP 9: ターミナルウィンドウ自動起動（macOS）
# ═══════════════════════════════════════════════
if [ "$(uname)" = "Darwin" ]; then
    log_info "ターミナルウィンドウを起動中..."

    open_terminal_with_command() {
        local cmd="$1"
        # shellcheck disable=SC2034
        local title="$2"
        if [ -d "/Applications/iTerm.app" ]; then
            osascript -e "
                tell application \"iTerm\"
                    activate
                    set newWindow to (create window with default profile)
                    tell current session of newWindow
                        write text \"exec $cmd\"
                    end tell
                end tell
            " 2>/dev/null
        else
            osascript -e "
                tell application \"Terminal\"
                    activate
                    do script \"exec $cmd\"
                end tell
            " 2>/dev/null
        fi
    }

    open_terminal_with_command "tmux attach -t kashindan" "kashindan"

    log_success "  └─ ターミナルウィンドウ起動完了"
    echo ""
fi
