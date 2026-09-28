clear

# ── Oh My Posh prompt ──────────────────────────────────────
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/powerlevel10k_rainbow.omp.json)"

# ── Aliases ────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias proj='cd ~/Projects'

# ── Colored man pages ─────────────────────────────────────
export LESS_TERMCAP_mb=$'\e[1;34m'
export LESS_TERMCAP_md=$'\e[1;34m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;36m'

# ── Fortune + random Pokémon cowsay ───────────────────────
pokecow() {
    local _pokemon_cows=(~/.config/cowsay/pokemons/*.cow)
    local _cow
    if [ -e "${_pokemon_cows[0]}" ]; then
        _cow="${_pokemon_cows[RANDOM % ${#_pokemon_cows[@]}]}"
    else
        _cow="moose"
    fi
    fortune -s -n 120 definitions humorists fortunes riddles work wisdom | ~/.config/cowsay/pokesay.sh -f "$_cow" -W 50
}

clear() {
    command clear
    pokecow
}

pokecow