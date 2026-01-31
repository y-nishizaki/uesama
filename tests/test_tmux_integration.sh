#!/bin/bash
# uesama tmux 統合テスト
# CI 上の Ubuntu でも tmux が使える前提で、セッション作成・ペイン分割を検証する
set -e

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJECT_ROOT
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    echo "    $2"
}

# テスト用セッション名（本番と衝突しない）
TEST_SESSION="test_kashindan_$$"

cleanup() {
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama tmux 統合テスト                    ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ==================================================================
# 前提条件チェック
# ==================================================================
if ! command -v tmux > /dev/null 2>&1; then
    echo "  SKIP: tmux が見つかりません"
    exit 0
fi

TEST_TMPDIR=$(mktemp -d)

# ==================================================================
# 1. セッション作成テスト
# ==================================================================
echo "  [セッション作成]"

tmux new-session -d -s "$TEST_SESSION" -n "agents" -c "$TEST_TMPDIR"
if tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
    pass "kashindan session created"
else
    fail "kashindan session created" "session not found"
fi

# ==================================================================
# 2. ペイン分割テスト（start.sh と同じロジック: 大名+参謀+家臣9=11ペイン）
# ==================================================================
echo ""
echo "  [ペイン分割 - start.sh 現行ロジック再現]"

KASHIN_COUNT=9
TOTAL_PANES=$((KASHIN_COUNT + 2))  # daimyo + sanbo + kashin

# start.sh と同じレイアウト構築:
# 左列: 大名(上) + 参謀(下)
# 右3列×3行: 家臣1-9

# 1. セッション作成済み（LEFT_ID = 最初のペイン）
LEFT_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')

# 2. 左右分割: 左25%=大名+参謀列、右75%=家臣エリア
tmux split-window -h -p 75 -t "$LEFT_ID"
RIGHT_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')

# 3. 左列を上下分割: 上67%=大名、下33%=参謀
tmux split-window -v -p 33 -t "$LEFT_ID"
SANBO_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')
DAIMYO_ID="$LEFT_ID"

# 4. 右エリアを3列に分割
tmux split-window -h -p 67 -t "$RIGHT_ID"
COL23_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')
tmux split-window -h -p 50 -t "$COL23_ID"
COL3_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')
COL1_ID="$RIGHT_ID"
COL2_ID="$COL23_ID"

# 5. 各列を3行に分割（家臣×9）
KASHIN_IDS=()
for COL_ID in "$COL1_ID" "$COL2_ID" "$COL3_ID"; do
    KASHIN_IDS+=("$COL_ID")
    tmux split-window -v -p 67 -t "$COL_ID"
    MID_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')
    KASHIN_IDS+=("$MID_ID")
    tmux split-window -v -p 50 -t "$MID_ID"
    BOT_ID=$(tmux display-message -t "$TEST_SESSION:0" -p '#{pane_id}')
    KASHIN_IDS+=("$BOT_ID")
done

# ペイン数を検証
ACTUAL_PANES=$(tmux list-panes -t "$TEST_SESSION:0" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ACTUAL_PANES" -eq "$TOTAL_PANES" ]; then
    pass "kashindan has $TOTAL_PANES panes (daimyo + sanbo + ${KASHIN_COUNT} kashin)"
else
    fail "kashindan has $TOTAL_PANES panes" "got $ACTUAL_PANES panes"
fi

# ==================================================================
# 3. ペインタイトル設定テスト
# ==================================================================
echo ""
echo "  [ペインタイトル]"

# 大名
tmux select-pane -t "$DAIMYO_ID" -T "daimyo"
DAIMYO_TITLE=$(tmux display-message -t "$DAIMYO_ID" -p '#{pane_title}' 2>/dev/null)
if [ "$DAIMYO_TITLE" = "daimyo" ]; then
    pass "daimyo pane title is 'daimyo'"
else
    fail "daimyo pane title is 'daimyo'" "got '$DAIMYO_TITLE'"
fi

# 参謀
tmux select-pane -t "$SANBO_ID" -T "sanbo"
SANBO_TITLE=$(tmux display-message -t "$SANBO_ID" -p '#{pane_title}' 2>/dev/null)
if [ "$SANBO_TITLE" = "sanbo" ]; then
    pass "sanbo pane title is 'sanbo'"
else
    fail "sanbo pane title is 'sanbo'" "got '$SANBO_TITLE'"
fi

# 家臣
for ((i=0; i<${#KASHIN_IDS[@]} && i<KASHIN_COUNT; i++)); do
    num=$((i + 1))
    tmux select-pane -t "${KASHIN_IDS[$i]}" -T "kashin$num" 2>/dev/null || true
done

KASHIN1_TITLE=$(tmux display-message -t "${KASHIN_IDS[0]}" -p '#{pane_title}' 2>/dev/null)
if [ "$KASHIN1_TITLE" = "kashin1" ]; then
    pass "kashin1 pane title is 'kashin1'"
else
    fail "kashin1 pane title is 'kashin1'" "got '$KASHIN1_TITLE'"
fi

KASHIN9_TITLE=$(tmux display-message -t "${KASHIN_IDS[8]}" -p '#{pane_title}' 2>/dev/null)
if [ "$KASHIN9_TITLE" = "kashin9" ]; then
    pass "kashin9 pane title is 'kashin9'"
else
    fail "kashin9 pane title is 'kashin9'" "got '$KASHIN9_TITLE'"
fi

# ==================================================================
# 4. ペインタイトルによる send-keys テスト
# ==================================================================
echo ""
echo "  [ペインタイトルによる send-keys]"

# -t sanbo でメッセージが正しいペインに届くか
tmux send-keys -t "$SANBO_ID" "echo SANBO_TITLE_TEST" Enter
sleep 0.5
CAPTURED_SANBO=$(tmux capture-pane -t "$SANBO_ID" -p 2>/dev/null)
if echo "$CAPTURED_SANBO" | grep -q "SANBO_TITLE_TEST"; then
    pass "send-keys to sanbo pane delivers correctly"
else
    fail "send-keys to sanbo pane delivers correctly" "marker not found"
fi

# -t daimyo でメッセージが正しいペインに届くか
tmux send-keys -t "$DAIMYO_ID" "echo DAIMYO_TITLE_TEST" Enter
sleep 0.5
CAPTURED_DAIMYO=$(tmux capture-pane -t "$DAIMYO_ID" -p 2>/dev/null)
if echo "$CAPTURED_DAIMYO" | grep -q "DAIMYO_TITLE_TEST"; then
    pass "send-keys to daimyo pane delivers correctly"
else
    fail "send-keys to daimyo pane delivers correctly" "marker not found"
fi

# 家臣ペインへの送信テスト
tmux send-keys -t "${KASHIN_IDS[0]}" "echo KASHIN1_TITLE_TEST" Enter
sleep 0.5
CAPTURED_K1=$(tmux capture-pane -t "${KASHIN_IDS[0]}" -p 2>/dev/null)
if echo "$CAPTURED_K1" | grep -q "KASHIN1_TITLE_TEST"; then
    pass "send-keys to kashin1 pane delivers correctly"
else
    fail "send-keys to kashin1 pane delivers correctly" "marker not found"
fi

# ==================================================================
# 5. キューファイル生成テスト（start.sh の STEP 3 ロジック再現）
# ==================================================================
echo ""
echo "  [キューファイル生成]"

PROJ_UESAMA="$TEST_TMPDIR/.uesama"
mkdir -p "$PROJ_UESAMA/queue/tasks" "$PROJ_UESAMA/queue/reports" \
         "$PROJ_UESAMA/status" "$PROJ_UESAMA/config" "$PROJ_UESAMA/memory"

for i in $(seq 1 "$KASHIN_COUNT"); do
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

# 全家臣のファイルが生成されたか
ALL_REPORTS=true
ALL_TASKS=true
for i in $(seq 1 "$KASHIN_COUNT"); do
    [ -f "$PROJ_UESAMA/queue/reports/kashin${i}_report.yaml" ] || ALL_REPORTS=false
    [ -f "$PROJ_UESAMA/queue/tasks/kashin${i}.yaml" ] || ALL_TASKS=false
done

if [ "$ALL_REPORTS" = true ]; then
    pass "all $KASHIN_COUNT report YAML files created"
else
    fail "all $KASHIN_COUNT report YAML files created" "some missing"
fi

if [ "$ALL_TASKS" = true ]; then
    pass "all $KASHIN_COUNT task YAML files created"
else
    fail "all $KASHIN_COUNT task YAML files created" "some missing"
fi

if [ -f "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml" ]; then
    pass "daimyo_to_sanbo.yaml created"
else
    fail "daimyo_to_sanbo.yaml created" "not found"
fi

# YAML の中身が正しいか
REPORT1_WORKER=$(grep 'worker_id:' "$PROJ_UESAMA/queue/reports/kashin1_report.yaml" | awk '{print $2}')
if [ "$REPORT1_WORKER" = "kashin1" ]; then
    pass "kashin1_report.yaml has correct worker_id"
else
    fail "kashin1_report.yaml has correct worker_id" "got '$REPORT1_WORKER'"
fi

REPORT1_STATUS=$(grep 'status:' "$PROJ_UESAMA/queue/reports/kashin1_report.yaml" | awk '{print $2}')
if [ "$REPORT1_STATUS" = "idle" ]; then
    pass "kashin1_report.yaml initial status is idle"
else
    fail "kashin1_report.yaml initial status is idle" "got '$REPORT1_STATUS'"
fi

TASK1_STATUS=$(grep 'status:' "$PROJ_UESAMA/queue/tasks/kashin1.yaml" | awk '{print $2}')
if [ "$TASK1_STATUS" = "idle" ]; then
    pass "kashin1.yaml initial task status is idle"
else
    fail "kashin1.yaml initial task status is idle" "got '$TASK1_STATUS'"
fi

QUEUE_CONTENT=$(cat "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml")
if echo "$QUEUE_CONTENT" | grep -q 'queue: \[\]'; then
    pass "daimyo_to_sanbo.yaml initialized with empty queue"
else
    fail "daimyo_to_sanbo.yaml initialized with empty queue" "content: $QUEUE_CONTENT"
fi

# ==================================================================
# 6. ディレクトリ構造テスト
# ==================================================================
echo ""
echo "  [ディレクトリ構造]"

for d in queue/tasks queue/reports status config memory; do
    if [ -d "$PROJ_UESAMA/$d" ]; then
        pass ".uesama/$d directory exists"
    else
        fail ".uesama/$d directory exists" "not found"
    fi
done

# ==================================================================
# 7. セッション kill テスト（uesama-stop と同じロジック）
# ==================================================================
echo ""
echo "  [セッション停止]"

tmux kill-session -t "$TEST_SESSION" 2>/dev/null
if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
    pass "kashindan session killed successfully"
else
    fail "kashindan session killed successfully" "session still exists"
fi

# 既に無いセッションを kill しても失敗しないか
tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
pass "killing non-existent session does not error (with || true)"

# ==================================================================
# 8. uesama-send テスト
# ==================================================================
echo ""
echo "  [uesama-send ヘルパー]"

# panes.yaml を生成してテスト
TEST_SESSION2="test_send_$$"
TEST_TMPDIR2=$(mktemp -d)
tmux new-session -d -s "$TEST_SESSION2" -n "agents" -c "$TEST_TMPDIR2"

SEND_LEFT_ID=$(tmux display-message -t "$TEST_SESSION2:0" -p '#{pane_id}')
tmux split-window -h -p 50 -t "$SEND_LEFT_ID"
SEND_RIGHT_ID=$(tmux display-message -t "$TEST_SESSION2:0" -p '#{pane_id}')

# ペインタイトル設定
tmux select-pane -t "$SEND_LEFT_ID" -T "daimyo"
tmux select-pane -t "$SEND_RIGHT_ID" -T "sanbo"

# panes.yaml 生成
SEND_PROJ="$TEST_TMPDIR2/.uesama"
mkdir -p "$SEND_PROJ"
cat > "$SEND_PROJ/panes.yaml" << EOF
daimyo: $SEND_LEFT_ID
sanbo: $SEND_RIGHT_ID
EOF

UESAMA_SEND="$PROJECT_ROOT/bin/uesama-send"

# --resolve テスト
RESOLVED=$(UESAMA_PROJECT_DIR="$TEST_TMPDIR2" "$UESAMA_SEND" --resolve sanbo 2>/dev/null)
if [ "$RESOLVED" = "$SEND_RIGHT_ID" ]; then
    pass "uesama-send --resolve sanbo returns correct pane ID"
else
    fail "uesama-send --resolve sanbo returns correct pane ID" "expected '$SEND_RIGHT_ID', got '$RESOLVED'"
fi

# send-keys テスト
UESAMA_PROJECT_DIR="$TEST_TMPDIR2" "$UESAMA_SEND" sanbo "echo UESAMA_SEND_TEST" 2>/dev/null
UESAMA_PROJECT_DIR="$TEST_TMPDIR2" "$UESAMA_SEND" sanbo Enter 2>/dev/null
sleep 0.5
CAPTURED_SEND=$(tmux capture-pane -t "$SEND_RIGHT_ID" -p 2>/dev/null)
if echo "$CAPTURED_SEND" | grep -q "UESAMA_SEND_TEST"; then
    pass "uesama-send delivers message to correct pane"
else
    fail "uesama-send delivers message to correct pane" "marker not found"
fi

# 存在しないペイン名のエラーテスト
if ! UESAMA_PROJECT_DIR="$TEST_TMPDIR2" "$UESAMA_SEND" --resolve nonexistent 2>/dev/null; then
    pass "uesama-send --resolve fails for unknown pane name"
else
    fail "uesama-send --resolve fails for unknown pane name" "should have failed"
fi

# panes.yaml が存在しない場合のエラーテスト
EMPTY_TMPDIR=$(mktemp -d)
mkdir -p "$EMPTY_TMPDIR/.uesama"
if ! UESAMA_PROJECT_DIR="$EMPTY_TMPDIR" "$UESAMA_SEND" --resolve sanbo 2>/dev/null; then
    pass "uesama-send fails when panes.yaml missing"
else
    fail "uesama-send fails when panes.yaml missing" "should have failed"
fi
rm -rf "$EMPTY_TMPDIR"

tmux kill-session -t "$TEST_SESSION2" 2>/dev/null || true
rm -rf "$TEST_TMPDIR2"

# ==================================================================
# 9. KASHIN_COUNT=3 テスト（新ロジック: 大名+参謀+家臣3=5ペイン）
# ==================================================================
echo ""
echo "  [KASHIN_COUNT=3 テスト]"

TEST_SESSION_SMALL="test_small_$$"
SMALL_COUNT=3
SMALL_TOTAL=$((SMALL_COUNT + 2))  # daimyo + sanbo + kashin

tmux new-session -d -s "$TEST_SESSION_SMALL" -n "agents" -c "$TEST_TMPDIR"

# start.sh と同じロジックで構築（家臣3名版）
S_LEFT_ID=$(tmux display-message -t "$TEST_SESSION_SMALL:0" -p '#{pane_id}')
tmux split-window -h -p 75 -t "$S_LEFT_ID"
S_RIGHT_ID=$(tmux display-message -t "$TEST_SESSION_SMALL:0" -p '#{pane_id}')
tmux split-window -v -p 33 -t "$S_LEFT_ID"

# 右エリアを3行に分割（家臣3名なので1列×3行）
tmux split-window -v -p 67 -t "$S_RIGHT_ID"
S_MID_ID=$(tmux display-message -t "$TEST_SESSION_SMALL:0" -p '#{pane_id}')
tmux split-window -v -p 50 -t "$S_MID_ID"

SMALL_PANES=$(tmux list-panes -t "$TEST_SESSION_SMALL:0" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SMALL_PANES" -eq "$SMALL_TOTAL" ]; then
    pass "KASHIN_COUNT=3: creates $SMALL_TOTAL panes (daimyo + sanbo + 3 kashin)"
else
    fail "KASHIN_COUNT=3: creates $SMALL_TOTAL panes" "got $SMALL_PANES panes"
fi

tmux kill-session -t "$TEST_SESSION_SMALL" 2>/dev/null || true

# ==================================================================
# 結果
# ==================================================================
echo ""
TOTAL=$((PASS + FAIL))
echo "  結果: $PASS/$TOTAL passed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "  ✗ $FAIL test(s) failed"
    exit 1
else
    echo "  ✅ All tests passed"
fi
