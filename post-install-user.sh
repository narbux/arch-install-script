#!/usr/bin/env bash

set -euxo pipefail

# User SSH setting
mkdir $HOME/.ssh
curl -SsL https://github.com/narbux.keys -o .ssh/authorized_keys

# Install PARU AUR helper
git clone --depth=1 https://aur.archlinux.org/paru-bin \
    && cd paru-bin \
    && makepkg -si --noconfirm \
    && cd ~ \
    && rm -rf paru-bin

# Install and configure zsh-antidote and zsh
paru -S --noconfirm zsh-antidote

cat <<'EOF' >> $HOME/.zsh_plugins.txt
mattmc3/ez-compinit
zsh-users/zsh-completions kind:fpath path=src

sindresorhus/pure kind:fpath

zsh-users/zsh-autosuggestions
zdharma-continuum/fast-syntax-highlighting kind:defer
EOF

cat <<'EOF' >> $HOME/.zshrc
EDITOR=nvim
VISUAL=nvim

source '/usr/share/zsh-antidote/antidote.zsh'
antidote load

chpwd() {
    exa
}

alias cat="bat -pp"
alias vim="nvim"
alias ls="exa"
alias ll="exa -lah"
alias tree="exa --tree"
alias ..="cd .."
alias cd="z"

autoload -Uz promptinit && promptinit && prompt pure

eval "$(zoxide init zsh)"
EOF

rm $HOME/.bash_logout $HOME/.bash_profile $HOME/.bashrc
