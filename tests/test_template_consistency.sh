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
