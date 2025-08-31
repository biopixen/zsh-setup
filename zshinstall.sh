#!/usr/bin/env bash
set -euo pipefail

echo "==> Zsh + Oh My Zsh + Powerlevel10k setup starting for user: $USER (home: $HOME)"

# Always start with a clean slate so we don't inherit another user's $ZSH
unset ZSH || true

# --- Vars (scoped to *current* user)
HOME_DIR="$HOME"
ZSH_DIR="$HOME_DIR/.oh-my-zsh"
export ZSH="$ZSH_DIR"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
PLUG_AUTOSUG="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
PLUG_SYNTAX="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
THEME_P10K="$ZSH_CUSTOM/themes/powerlevel10k"

# sudo helper
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# --- 0) Packages
echo "==> Installing required packages..."
if command -v apt >/dev/null 2>&1; then
  $SUDO apt update
  $SUDO apt install -y zsh git curl fonts-powerline
else
  echo "!! apt not found. Install zsh, git, curl, fonts-powerline manually." >&2
fi

# --- 1) Oh My Zsh (per-user install)
if [ -d "$ZSH_DIR" ]; then
  echo "==> Oh My Zsh already present at $ZSH_DIR (skipping install)."
else
  echo "==> Installing Oh My Zsh into $ZSH_DIR ..."
  RUNZSH="no" CHSH="no" KEEP_ZSHRC="yes" sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# --- 2) Plugins (per-user)
echo "==> Ensuring plugins exist for $USER ..."
if [ -d "$PLUG_AUTOSUG" ]; then
  echo "   - zsh-autosuggestions already installed."
else
  git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUG_AUTOSUG"
fi

if [ -d "$PLUG_SYNTAX" ]; then
  echo "   - zsh-syntax-highlighting already installed."
else
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUG_SYNTAX"
fi

# --- 3) Theme: Powerlevel10k (per-user)
echo "==> Ensuring Powerlevel10k theme exists for $USER ..."
if [ -d "$THEME_P10K" ]; then
  echo "   - powerlevel10k already installed."
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_P10K"
fi

# --- 4) Write ~/.zshrc (per-user)
ZSHRC_PATH="$HOME_DIR/.zshrc"
echo "==> Writing $ZSHRC_PATH ..."
cat > "$ZSHRC_PATH" <<'EOF'
# ~/.zshrc — Optimized for speed and usability (based on Scott Spence 2025)

# Disable unwanted behaviors
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"

# Oh My Zsh settings
export ZSH="$HOME/.oh-my-zsh"

# Theme (Powerlevel10k). To switch to agnoster later, change to: ZSH_THEME="agnoster"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Source Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# Performance: smarter completion caching
autoload -Uz compinit
if [ -f ~/.zcompdump ]; then
  compinit -C
else
  compinit
fi

# (Kept from your snippet) Spaceship-related vars (harmless if not used)
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="⚡"
SPACESHIP_PROMPT_ORDER=(time user dir git line_sep char)

# zsh-autosuggestions tuning
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#663399,standout"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

# Load Powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

# --- 5) Default ~/.p10k.zsh if missing (per-user)
P10K_PATH="$HOME_DIR/.p10k.zsh"
if [ ! -f "$P10K_PATH" ]; then
  echo "==> Writing default $P10K_PATH ..."
  cat > "$P10K_PATH" <<'EOF'
# Minimal, single-line Powerlevel10k prompt preset
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)

typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS='➜'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS='✗'

typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique

typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
EOF
fi

# --- 6) Make zsh default shell for current user
if [ -x /usr/bin/zsh ]; then
  current_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  if [ "$current_shell" != "/usr/bin/zsh" ]; then
    echo "==> Setting default shell to zsh for $USER ..."
    chsh -s /usr/bin/zsh || echo "   (Could not chsh automatically; run: chsh -s /usr/bin/zsh)"
  fi
fi

# --- 7) Optional: mirror sebastian's setup to root in one pass
# Run like: SETUP_ROOT_FROM="/home/sebastian" ./zshinstall.sh
if [ "${SETUP_ROOT_FROM:-}" != "" ] && [ "$EUID" -ne 0 ]; then
  echo "==> Mirroring config to root from ${SETUP_ROOT_FROM} ..."
  $SUDO cp -f "${SETUP_ROOT_FROM}/.zshrc" /root/.zshrc
  if [ -f "${SETUP_ROOT_FROM}/.p10k.zsh" ]; then
    $SUDO cp -f "${SETUP_ROOT_FROM}/.p10k.zsh" /root/.p10k.zsh
  fi
  # ensure root has its own OMZ + theme + plugins (no cross-user repos)
  $SUDO -H -u root bash -lc 'unset ZSH; export HOME=/root; export ZSH="$HOME/.oh-my-zsh";
    if [ ! -d "$ZSH" ]; then RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; fi
    ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}";
    [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k";
    [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions";
    [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting";
  '
  if [ "$(getent passwd root | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    echo "==> Setting default shell to zsh for root ..."
    $SUDO chsh -s /usr/bin/zsh root || true
  fi
fi

# --- X) Disable Ubuntu MOTD
echo "==> Disabling Ubuntu MOTD..."
if [ -d /etc/update-motd.d ]; then
  $SUDO chmod -x /etc/update-motd.d/* || true
fi
if grep -q '^PrintMotd' /etc/ssh/sshd_config 2>/dev/null; then
  $SUDO sed -i 's/^PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config
else
  echo "PrintMotd no" | $SUDO tee -a /etc/ssh/sshd_config
fi
$SUDO systemctl restart ssh || true



echo "==> Setup complete. Pro tip: when switching to root, use 'su -' or 'sudo -i' for a clean login shell."
echo "==> Launching zsh..."
exec zsh
