#!/bin/bash
# uesama 起動スクリプト
# tmux セッション作成 & エージェント（Claude Code / Codex）起動
set -e

UESAMA_HOME="${UESAMA_HOME:-$HOME/.uesama}"
PROJECT_DIR="${1:-.}"
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

# エージェント設定を読み取り（claude or codex）
AGENT_TYPE="${UESAMA_AGENT:-}"
if [ -z "$AGENT_TYPE" ]; then
    if [ -f "$PROJECT_DIR/.uesama/config/settings.yaml" ]; then
        AGENT_TYPE=$(grep "^agent:" "$PROJECT_DIR/.uesama/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "")
    fi
    if [ -z "$AGENT_TYPE" ] && [ -f "$UESAMA_HOME/config/settings.yaml" ]; then
        AGENT_TYPE=$(grep "^agent:" "$UESAMA_HOME/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "")
    fi
    AGENT_TYPE="${AGENT_TYPE:-claude}"
fi

# エージェント起動コマンドの決定
case "$AGENT_TYPE" in
    claude)
        AGENT_CMD="claude --dangerously-skip-permissions"
        AGENT_DISPLAY_NAME="Claude Code"
        AGENT_READY_PATTERN="bypass permissions"
        ;;
    codex)
        AGENT_CMD="codex --full-auto"
        AGENT_DISPLAY_NAME="Codex"
        AGENT_READY_PATTERN='\$'
        ;;
    *)
        echo "エラー: 未知のエージェント種別: $AGENT_TYPE"
        echo "  対応エージェント: claude, codex"
        exit 1
        ;;
esac

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
echo "  エージェント: $AGENT_DISPLAY_NAME"
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
         "$PROJ_UESAMA/status" "$PROJ_UESAMA/config" "$PROJ_UESAMA/memory"

# テンプレートからシンボリックリンク
for dir in instructions templates; do
    if [ ! -L "$PROJ_UESAMA/$dir" ]; then
        rm -rf "${PROJ_UESAMA:?}/$dir"
        ln -sf "$UESAMA_HOME/template/.uesama/$dir" "$PROJ_UESAMA/$dir"
    fi
done

# エージェントルールの配置
if [ "$AGENT_TYPE" = "codex" ]; then
    # Codex: UESAMA.md をfallbackファイルとして配置（既存 AGENTS.md を壊さない）
    if [ ! -L "$PROJECT_DIR/UESAMA.md" ]; then
        rm -f "$PROJECT_DIR/UESAMA.md"
        ln -sf "$UESAMA_HOME/template/.claude/rules/uesama.md" "$PROJECT_DIR/UESAMA.md"
    fi
    # ~/.codex/config.toml に fallback 設定を追加
    CODEX_CONFIG_DIR="$HOME/.codex"
    CODEX_CONFIG="$CODEX_CONFIG_DIR/config.toml"
    mkdir -p "$CODEX_CONFIG_DIR"
    if [ ! -f "$CODEX_CONFIG" ]; then
        cat > "$CODEX_CONFIG" << 'TOML'
project_doc_fallback_filenames = ["UESAMA.md"]
TOML
        log_info "  └─ ~/.codex/config.toml を作成（UESAMA.md fallback設定）"
    elif ! grep -q 'UESAMA.md' "$CODEX_CONFIG" 2>/dev/null; then
        # 既存の fallback 設定があるか確認
        if grep -q 'project_doc_fallback_filenames' "$CODEX_CONFIG" 2>/dev/null; then
            # 既存リストに UESAMA.md を追加
            sed -i 's/project_doc_fallback_filenames *= *\[/project_doc_fallback_filenames = ["UESAMA.md", /' "$CODEX_CONFIG"
        else
            echo '' >> "$CODEX_CONFIG"
            echo 'project_doc_fallback_filenames = ["UESAMA.md"]' >> "$CODEX_CONFIG"
        fi
        log_info "  └─ ~/.codex/config.toml に UESAMA.md fallback設定を追加"
    fi
else
    # Claude Code: .claude/rules/ にルールをシンボリックリンク
    mkdir -p "$PROJECT_DIR/.claude/rules"
    if [ ! -L "$PROJECT_DIR/.claude/rules/uesama.md" ]; then
        rm -f "$PROJECT_DIR/.claude/rules/uesama.md"
        ln -sf "$UESAMA_HOME/template/.claude/rules/uesama.md" "$PROJECT_DIR/.claude/rules/uesama.md"
    fi
fi

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
agent: $AGENT_TYPE
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
echo ""

# ═══════════════════════════════════════════════
# STEP 7: エージェント起動（Claude Code / Codex）
# ═══════════════════════════════════════════════
log_war "👑 全軍に ${AGENT_DISPLAY_NAME} を召喚中..."

# 大名
tmux send-keys -t "$DAIMYO_ID" "$AGENT_CMD"
tmux send-keys -t "$DAIMYO_ID" Enter
log_info "  └─ 大名、召喚完了"

sleep 1

# 参謀
tmux send-keys -t "$SANBO_ID" "$AGENT_CMD"
tmux send-keys -t "$SANBO_ID" Enter

# 家臣
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    tmux send-keys -t "${KASHIN_IDS[$i]}" "$AGENT_CMD"
    tmux send-keys -t "${KASHIN_IDS[$i]}" Enter
done
log_info "  └─ 参謀・家臣、召喚完了"

log_success "✅ 全軍 ${AGENT_DISPLAY_NAME} 起動完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 8: 指示書読み込み
# ═══════════════════════════════════════════════
log_war "📜 各エージェントに指示書を読み込ませ中..."

echo "  ${AGENT_DISPLAY_NAME} の起動を待機中（最大30秒）..."
for i in {1..30}; do
    if tmux capture-pane -t "$DAIMYO_ID" -p | grep -q "$AGENT_READY_PATTERN"; then
        echo "  └─ 大名の ${AGENT_DISPLAY_NAME} 起動確認完了（${i}秒）"
        break
    fi
    sleep 1
done

# 大名に指示書
log_info "  └─ 大名に指示書を伝達中..."
tmux send-keys -t "$DAIMYO_ID" ".uesama/instructions/daimyo.md を読んで役割を理解せよ。"
sleep 0.5
tmux send-keys -t "$DAIMYO_ID" Enter

# 参謀に指示書
sleep 2
log_info "  └─ 参謀に指示書を伝達中..."
tmux send-keys -t "$SANBO_ID" ".uesama/instructions/sanbo.md を読んで役割を理解せよ。"
sleep 0.5
tmux send-keys -t "$SANBO_ID" Enter

# 家臣に指示書
sleep 2
log_info "  └─ 家臣に指示書を伝達中..."
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    num=$((i + 1))
    tmux send-keys -t "${KASHIN_IDS[$i]}" ".uesama/instructions/kashin.md を読んで役割を理解せよ。汝は家臣${num}号である。"
    sleep 0.3
    tmux send-keys -t "${KASHIN_IDS[$i]}" Enter
    sleep 0.5
done

log_success "✅ 全軍に指示書伝達完了"
echo ""

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
echo "  │  uesama-daimyo    セッションに再接続                     │"
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
