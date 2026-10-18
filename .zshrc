# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # prompt custom di bawah
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

setopt prompt_subst

# git info (branch + dirty) — truecolor, palette Minimal Neutral
ZSH_THEME_GIT_PROMPT_PREFIX="%F{#a1a1a1}("
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{#a1a1a1})"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{#ff6467}*"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_BRANCH="%F{#91c5ff}"

PROMPT='%F{#fafafa}%n@%m:%~$(git_prompt_info)%(!.#.$)%f '

RPROMPT='%(?..%F{#ff6467}[%?]%f )%F{#a1a1a1}%*%f'

# Aliases
alias ll="ls -lah"
alias humble="python3 $HOME/tools/humble/humble.py"
alias testssl.sh="bash $HOME/tools/testssl.sh/testssl.sh"
alias webroot="cd /var/www/html"
alias vim="$HOME/apps/nvim/bin/nvim"

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias reload="exec ${SHELL} -l"

# Functions
function mkdir() {
    if [[ $# -eq 1 ]]; then
        command mkdir -p "$1" && builtin cd "$1"
    else
        command mkdir -p "$@"
    fi
}

extract() {
    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.tar.xz)  tar xJf "$1" ;;
        *.zip)     unzip "$1" ;;
        *.7z)      7z x "$1" ;;
        *)         echo "unknown format: $1" ;;
    esac
}

path() { echo -e ${PATH//:/\\n}; }

cekip() { curl -s ipinfo.io/ip; echo; }

# PATH
export PATH="$HOME/development/dotfiles/bin:$HOME/.local/bin:$PATH"
export PATH="/usr/local/go/bin:$HOME/go/bin:$HOME/.pdtm/go/bin:$PATH"
export PATH="$HOME/.gems/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"

# Environment
export GEM_HOME="$HOME/.gems"
export NVM_DIR="$HOME/nvm"
export TERM=xterm-256color
export PYTHONWARNINGS="ignore"
export PYTHONIOENCODING='UTF-8'
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export EDITOR='nvim'

# NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Cargo
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# bun completions
[ -s "/home/abay/.bun/_bun" ] && source "/home/abay/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

export PATH="$HOME/apps/macchina/target/release:$PATH"
