fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
fish_add_path $HOME/.spicetify
# Machine-specific paths and aliases go in conf.d/local.fish (untracked).

alias neofetch='fastfetch -c neofetch'
alias burp='brew update && brew upgrade --greedy'

if status is-interactive
    if test "$TERM_PROGRAM" != "vscode" -a "$TERMINAL_EMULATOR" != "JetBrains-JediTerm" -a -z "$INSIDE_EMACS"
        neofetch
    end
end

set -U fish_greeting

starship init fish | source
