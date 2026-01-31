#!/bin/bash
set -e

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 テンプレート整合性チェック                ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ==================================================================
# 1. template/instructions/ 内の全.mdファイルが template/ 配下に存在するか
# ==================================================================
echo "  [instructions ファイル]"
for f in "$PROJECT_ROOT"/template/instructions/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if [ -f "$PROJECT_ROOT/template/instructions/$name" ]; then
        pass "template/instructions/$name exists"
    else
        fail "template/instructions/$name exists" "file not found"
    fi
done

# ==================================================================
# 2. template/templates/ 内の全ファイルが template/ 配下に存在するか
# ==================================================================
echo ""
echo "  [templates ファイル]"
for f in "$PROJECT_ROOT"/template/templates/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if [ -f "$PROJECT_ROOT/template/templates/$name" ]; then
        pass "template/templates/$name exists"
    else
        fail "template/templates/$name exists" "file not found"
    fi
done

# ==================================================================
# 3. dashboard.md テンプレートの必須セクション
# ==================================================================
echo ""
echo "  [dashboard.md 必須セクション]"
DASHBOARD="$PROJECT_ROOT/template/templates/dashboard.md"

if [ ! -f "$DASHBOARD" ]; then
    fail "dashboard.md exists" "file not found"
else
    pass "dashboard.md exists"

    for section in "🚨 要対応" "📋 進行中" "✅ 完了" "📊 家臣団状態"; do
        if grep -q "$section" "$DASHBOARD"; then
            pass "dashboard.md contains '$section'"
        else
            fail "dashboard.md contains '$section'" "section not found"
        fi
    done
fi

# ==================================================================
# 4. ペイン参照の整合性チェック（kashindan:0.X ハードコード禁止）
# ==================================================================
echo ""
echo "  [ペイン参照の整合性]"

DAIMYO_MD="$PROJECT_ROOT/template/instructions/daimyo.md"
SANBO_MD="$PROJECT_ROOT/template/instructions/sanbo.md"

# daimyo.md の panes: セクションで sanbo がペイン名参照になっていること
if grep -A2 '^panes:' "$DAIMYO_MD" | grep -q 'sanbo: sanbo'; then
    pass "daimyo.md panes: sanbo uses pane name reference"
else
    fail "daimyo.md panes: sanbo uses pane name reference" "expected 'sanbo: sanbo'"
fi

# daimyo.md の send-keys 正しい例が -t sanbo を使っていること
if grep 'tmux send-keys -t sanbo' "$DAIMYO_MD" | grep -qv '^\s*#'; then
    pass "daimyo.md send-keys examples use '-t sanbo'"
else
    fail "daimyo.md send-keys examples use '-t sanbo'" "no '-t sanbo' found in send-keys"
fi

# sanbo.md の send-keys 例が -t daimyo を使っていること
if grep -q 'tmux send-keys -t daimyo' "$SANBO_MD"; then
    pass "sanbo.md send-keys examples use '-t daimyo'"
else
    fail "sanbo.md send-keys examples use '-t daimyo'" "no '-t daimyo' found"
fi

# 全 instructions/*.md で kashindan:0.0 がハードコードされていないこと
# （参謀ペインへの参照は sanbo を使うべき）
HARDCODE_FILES=""
for f in "$PROJECT_ROOT"/template/instructions/*.md; do
    if grep -q 'kashindan:0\.0' "$f"; then
        HARDCODE_FILES="$HARDCODE_FILES $(basename "$f")"
    fi
done
if [ -z "$HARDCODE_FILES" ]; then
    pass "no instructions/*.md contains hardcoded 'kashindan:0.0'"
else
    fail "no instructions/*.md contains hardcoded 'kashindan:0.0'" "found in:$HARDCODE_FILES"
fi

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
