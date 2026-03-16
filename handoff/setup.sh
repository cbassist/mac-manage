#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────
# Fresh Mac Setup Script
# Run once on a new macOS user account.
#
# Prerequisites:
#   1. Open Terminal
#   2. xcode-select --install   (gets git + build tools)
#   3. Clone this repo or copy this directory
#   4. Edit credentials.env with your actual values
#   5. Run: ./setup.sh
# ─────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ──────────────────────────────────────
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1"; }

# ── Step 1: Install Homebrew ────────────────────
if command -v brew &>/dev/null; then
    green "✓ Homebrew already installed"
else
    yellow "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session (Apple Silicon vs Intel)
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    green "✓ Homebrew installed"
fi

# ── Step 2: Install from Brewfile ───────────────
yellow "Installing packages from Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile" --no-lock
green "✓ Packages installed"

# ── Step 3: Git config ─────────────────────────
if [[ -f "$SCRIPT_DIR/credentials.env" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/credentials.env"

    git config --global credential.helper osxkeychain
    git config --global user.name "${GIT_USER_NAME:-}"
    git config --global user.email "${GIT_USER_EMAIL:-}"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    green "✓ Git configured for ${GIT_USER_NAME:-unknown}"
else
    yellow "⚠ No credentials.env found — skipping git config"
    yellow "  Copy credentials.env.example to credentials.env and fill in values"
fi

# ── Step 4: Store credentials in Keychain ───────
if [[ -n "${GITHUB_USERNAME:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
    security add-generic-password -a "$GITHUB_USERNAME" -s "GitHub" -w "$GITHUB_TOKEN" -U
    green "✓ GitHub credentials stored in Keychain"
else
    yellow "⚠ Skipping GitHub keychain — set GITHUB_USERNAME and GITHUB_TOKEN in credentials.env"
fi

if [[ -n "${SUPABASE_EMAIL:-}" && -n "${SUPABASE_PASSWORD:-}" ]]; then
    security add-generic-password -a "$SUPABASE_EMAIL" -s "Supabase" -w "$SUPABASE_PASSWORD" -U
    green "✓ Supabase credentials stored in Keychain"
else
    yellow "⚠ Skipping Supabase keychain — set SUPABASE_EMAIL and SUPABASE_PASSWORD in credentials.env"
fi

# ── Step 5: Node.js via fnm ────────────────────
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
    fnm install --lts
    green "✓ Node.js LTS installed via fnm"
else
    yellow "⚠ fnm not found — skipping Node.js install"
fi

# ── Step 6: Shell setup ────────────────────────
# Ensure fnm loads in new shells
ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]] || ! grep -q 'fnm env' "$ZSHRC" 2>/dev/null; then
    cat >> "$ZSHRC" << 'ZSHRC_BLOCK'

# ── Added by setup.sh ──────────────────────────
# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# fnm (Node version manager)
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
fi
ZSHRC_BLOCK
    green "✓ Shell config updated (~/.zshrc)"
else
    green "✓ Shell config already has fnm setup"
fi

# ── Done ────────────────────────────────────────
echo ""
green "══════════════════════════════════════════"
green "  Setup complete!"
green "══════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Open a NEW terminal window (to pick up PATH changes)"
echo "  2. Run: gh auth login     (to authenticate GitHub CLI)"
echo "  3. Open VS Code — extensions will be ready"
echo ""
yellow "Remember to delete credentials.env after setup!"
