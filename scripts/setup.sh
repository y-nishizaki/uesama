#!/bin/bash
# uesama 依存チェックスクリプト
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HAS_ERROR=false

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama 依存チェック                       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# tmux チェック & 自動インストール
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION)"
else
    echo -e "  ${YELLOW}!${NC} tmux が見つかりません"
    TMUX_INSTALL_SUCCESS=false

    # 利用可能なインストール方法を検出
    TMUX_OPTIONS=()
    TMUX_CMDS=()
    if command -v brew &> /dev/null; then
        TMUX_OPTIONS+=("brew (brew install tmux)")
        TMUX_CMDS+=("brew install tmux")
    fi
    if command -v port &> /dev/null; then
        TMUX_OPTIONS+=("MacPorts (sudo port install tmux)")
        TMUX_CMDS+=("sudo port install tmux")
    fi
    if command -v apt-get &> /dev/null; then
        TMUX_OPTIONS+=("apt-get (sudo apt-get install tmux)")
        TMUX_CMDS+=("sudo apt-get update -qq && sudo apt-get install -y -qq tmux")
    fi
    if command -v dnf &> /dev/null; then
        TMUX_OPTIONS+=("dnf (sudo dnf install tmux)")
        TMUX_CMDS+=("sudo dnf install -y tmux")
    fi
    if command -v yum &> /dev/null; then
        TMUX_OPTIONS+=("yum (sudo yum install tmux)")
        TMUX_CMDS+=("sudo yum install -y tmux")
    fi
    if command -v pacman &> /dev/null; then
        TMUX_OPTIONS+=("pacman (sudo pacman -S tmux)")
        TMUX_CMDS+=("sudo pacman -S --noconfirm tmux")
    fi
    if command -v apk &> /dev/null; then
        TMUX_OPTIONS+=("apk (sudo apk add tmux)")
        TMUX_CMDS+=("sudo apk add tmux")
    fi
    if command -v zypper &> /dev/null; then
        TMUX_OPTIONS+=("zypper (sudo zypper install tmux)")
        TMUX_CMDS+=("sudo zypper install -y tmux")
    fi

    if [ ${#TMUX_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "    インストール方法を選択してください:"
        for i in "${!TMUX_OPTIONS[@]}"; do
            echo "      $((i + 1))) ${TMUX_OPTIONS[$i]}"
        done
        echo "      0) スキップ"
        echo ""
        read -r -p "    番号を入力 [0]: " choice
        choice="${choice:-0}"

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#TMUX_OPTIONS[@]} ]; then
            idx=$((choice - 1))
            echo "    インストール中..."
            bash -c "${TMUX_CMDS[$idx]}" && TMUX_INSTALL_SUCCESS=true
        else
            echo "    スキップしました"
        fi
    else
        echo -e "  ${RED}✗${NC} サポートされるパッケージマネージャが見つかりません"
        echo "    手動でインストールしてください: https://github.com/tmux/tmux/wiki/Installing"
    fi

    if [ "$TMUX_INSTALL_SUCCESS" = true ] && command -v tmux &> /dev/null; then
        TMUX_VERSION=$(tmux -V | awk '{print $2}')
        echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION) をインストールしました"
    elif [ "$TMUX_INSTALL_SUCCESS" != true ]; then
        HAS_ERROR=true
    else
        echo -e "  ${RED}✗${NC} tmux のインストールに失敗しました"
        HAS_ERROR=true
    fi
fi

# エージェント設定を読み取り（ロール別対応）
UESAMA_HOME="${UESAMA_HOME:-$HOME/.uesama}"

read_setup_setting() {
    local key="$1"
    local val=""
    for cfg in ".uesama/config/settings.yaml" "$UESAMA_HOME/config/settings.yaml"; do
        if [ -f "$cfg" ]; then
            val=$(grep "^${key}:" "$cfg" 2>/dev/null | awk '{print $2}' || echo "")
            [ -n "$val" ] && break
        fi
    done
    echo "$val"
}

DEFAULT_AGENT="${UESAMA_AGENT:-$(read_setup_setting agent)}"
DEFAULT_AGENT="${DEFAULT_AGENT:-claude}"

AGENT_DAIMYO="${UESAMA_AGENT_DAIMYO:-$(read_setup_setting agent_daimyo)}"
AGENT_DAIMYO="${AGENT_DAIMYO:-$DEFAULT_AGENT}"
AGENT_SANBO="${UESAMA_AGENT_SANBO:-$(read_setup_setting agent_sanbo)}"
AGENT_SANBO="${AGENT_SANBO:-$DEFAULT_AGENT}"
AGENT_KASHIN="${UESAMA_AGENT_KASHIN:-$(read_setup_setting agent_kashin)}"
AGENT_KASHIN="${AGENT_KASHIN:-$DEFAULT_AGENT}"

# 必要なエージェントの一覧（重複除去）
REQUIRED_AGENTS=()
for a in "$AGENT_DAIMYO" "$AGENT_SANBO" "$AGENT_KASHIN"; do
    already=false
    for existing in "${REQUIRED_AGENTS[@]}"; do
        [ "$existing" = "$a" ] && already=true && break
    done
    [ "$already" = false ] && REQUIRED_AGENTS+=("$a")
done

# エージェント CLI チェック & 自動インストール（必要なもの全て）
check_and_install_agent() {
    local agent_type="$1"
    local cli_name="" display=""

    case "$agent_type" in
        claude) cli_name="claude"; display="Claude Code CLI" ;;
        codex)  cli_name="codex";  display="Codex CLI" ;;
        *)
            echo -e "  ${RED}✗${NC} 未知のエージェント種別: $agent_type"
            HAS_ERROR=true
            return
            ;;
    esac

    if command -v "$cli_name" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $display"
        return
    fi

    echo -e "  ${YELLOW}!${NC} $display が見つかりません"
    local install_success=false

    INSTALL_OPTIONS=()
    INSTALL_CMDS=()
    if [ "$agent_type" = "claude" ]; then
        if command -v curl &> /dev/null; then
            INSTALL_OPTIONS+=("curl (curl -fsSL https://claude.ai/install.sh | sh)")
            INSTALL_CMDS+=("curl -fsSL https://claude.ai/install.sh | sh")
        fi
        if command -v yarn &> /dev/null; then
            INSTALL_OPTIONS+=("yarn (yarn global add @anthropic-ai/claude-code)")
            INSTALL_CMDS+=("yarn global add @anthropic-ai/claude-code")
        fi
        if command -v pnpm &> /dev/null; then
            INSTALL_OPTIONS+=("pnpm (pnpm add -g @anthropic-ai/claude-code)")
            INSTALL_CMDS+=("pnpm add -g @anthropic-ai/claude-code")
        fi
        if command -v brew &> /dev/null; then
            INSTALL_OPTIONS+=("brew (brew install claude-code)")
            INSTALL_CMDS+=("brew install claude-code")
        fi
        if command -v npm &> /dev/null; then
            INSTALL_OPTIONS+=("npm (npm install -g @anthropic-ai/claude-code)")
            INSTALL_CMDS+=("npm install -g @anthropic-ai/claude-code")
        fi
    elif [ "$agent_type" = "codex" ]; then
        if command -v npm &> /dev/null; then
            INSTALL_OPTIONS+=("npm (npm install -g @openai/codex)")
            INSTALL_CMDS+=("npm install -g @openai/codex")
        fi
        if command -v brew &> /dev/null; then
            INSTALL_OPTIONS+=("brew (brew install --cask codex)")
            INSTALL_CMDS+=("brew install --cask codex")
        fi
        if command -v yarn &> /dev/null; then
            INSTALL_OPTIONS+=("yarn (yarn global add @openai/codex)")
            INSTALL_CMDS+=("yarn global add @openai/codex")
        fi
        if command -v pnpm &> /dev/null; then
            INSTALL_OPTIONS+=("pnpm (pnpm add -g @openai/codex)")
            INSTALL_CMDS+=("pnpm add -g @openai/codex")
        fi
    fi

    if [ ${#INSTALL_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "    インストール方法を選択してください:"
        for i in "${!INSTALL_OPTIONS[@]}"; do
            echo "      $((i + 1))) ${INSTALL_OPTIONS[$i]}"
        done
        echo "      0) スキップ"
        echo ""
        read -r -p "    番号を入力 [0]: " choice
        choice="${choice:-0}"

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#INSTALL_OPTIONS[@]} ]; then
            idx=$((choice - 1))
            echo "    インストール中..."
            bash -c "${INSTALL_CMDS[$idx]}" && install_success=true
        else
            echo "    スキップしました"
        fi
    else
        echo -e "  ${RED}✗${NC} npm/yarn/pnpm/brew/curl が見つかりません"
        if [ "$agent_type" = "claude" ]; then
            echo "    手動でインストールしてください: https://docs.anthropic.com/en/docs/claude-code"
        else
            echo "    手動でインストールしてください: https://github.com/openai/codex"
        fi
    fi

    if [ "$install_success" = true ] && command -v "$cli_name" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $display をインストールしました"
    elif [ "$install_success" != true ]; then
        HAS_ERROR=true
    else
        echo -e "  ${RED}✗${NC} $display のインストールに失敗しました"
        HAS_ERROR=true
    fi
}

for agent in "${REQUIRED_AGENTS[@]}"; do
    check_and_install_agent "$agent"
done

echo ""

if [ "$HAS_ERROR" = true ]; then
    echo -e "  ${YELLOW}⚠ 不足している依存関係があります${NC}"
    exit 1
else
    echo -e "  ${GREEN}✅ 全ての依存関係が揃っています${NC}"
fi
