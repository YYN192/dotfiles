# Modern CLI tools: zoxide, fzf, eza, bat, fd, ripgrep, yazi, lazygit, lazydocker, atuin.
# Rosé Pine colours follow macOS appearance: switch-theme.sh sets the universal
# variable rose_pine_mode, which every running fish picks up immediately.

status is-interactive; or return

# ---- theme --------------------------------------------------------------
if not set -q rose_pine_mode
    if defaults read -g AppleInterfaceStyle 2>/dev/null | string match -qi dark
        set -U rose_pine_mode dark
    else
        set -U rose_pine_mode light
    end
end

function __cli_tools_theme --on-variable rose_pine_mode
    set -l v rose-pine
    test "$rose_pine_mode" = light; and set v rose-pine-dawn

    set -gx BAT_THEME $v
    set -gx EZA_CONFIG_DIR ~/.config/eza/$v
    set -gx LG_CONFIG_FILE $HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/themes/$v.yml
    # fzf/<theme>.sh is upstream's file: one `export FZF_DEFAULT_OPTS="..."`.
    set -gx FZF_DEFAULT_OPTS (string match -r '"([^"]*)"' -- (string join ' ' < ~/.config/fzf/$v.sh))[2] \
        --layout=reverse --height=40% --border=rounded
end
__cli_tools_theme

# ---- fzf (Ctrl-T files, Alt-C dirs) --------------------------------------
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --level=2 --icons --color=always {}'"
fzf --fish | source

# ---- atuin (Ctrl-R; loaded after fzf so it owns Ctrl-R) -------------------
# Up arrow keeps fish's normal history.
atuin init fish --disable-up-arrow | source

# ---- zoxide: z <dir>, zi = interactive ------------------------------------
zoxide init fish | source

# ---- eza / bat ---------------------------------------------------------
alias ls 'eza --icons --group-directories-first'
alias ll 'eza -l --icons --git --group-directories-first'
alias la 'eza -la --icons --git --group-directories-first'
alias lt 'eza --tree --level=2 --icons --git-ignore'
alias cat 'bat --paging=never --style=plain'

# ---- lazygit / lazydocker --------------------------------------------
alias lg lazygit
alias lzd lazydocker

# ---- yazi: `y` opens it and cds to wherever you quit -------------------
function y
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
