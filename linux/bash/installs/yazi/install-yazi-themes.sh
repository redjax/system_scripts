#!/usr/bin/env bash

set -uo pipefail

declare -a THEMES=(
    ## Dark
    dangooddd/kanagawa                   # dark = "kanagawa"
    yazi-rs/flavors:catppuccin-macchiato # dark = "catppuccin-macchiato"
    yazi-rs/flavors:catppuccin-frappe    # dark = "catppuccin-frappe"
    yazi-rs/flavors:dracula              # dark = "dracula"
    bennyyip/gruvbox-dark                # dark = "gruvbox-dark"
    kmlupreti/ayu-dark                   # dark = "ayu-dark"
    gosxrgxx/flexoki-dark                # dark = "flexoki-dark"
    956MB/vscode-dark-modern             # dark = "vscode-dark-modern"
    956MB/vscode-dark-plus               # dark = "vscode-dark-plus"
    Mintass/rose-pine                    # dark = "rose-pine"
    Mintass/rose-pine-moon               # dark = "rose-pine-moon"

    ## Light
    yazi-rs/flavors:catppuccin-latte     # light = "catppuccin-latte"
    muratoffalex/kanagawa-lotus          # light = "kanagawa-lotus"
    gosxrgxx/flexoki-light               # light = "flexoki-light"
    956MB/vscode-light-modern            # light = "vscode-light-modern"
    956MB/vscode-light-plus              # light = "vscode-light-plus"
    Mintass/rose-pine-dawn               # light = "rose-pine-dawn"
)

if ! command -v ya &>/dev/null; then
    if command -v yazi &>/dev/null; then
        echo "[ERROR] yazi is installed, but 'ya' command not found."
    else
        echo "[ERROR] ya command not found."
    fi
    exit 1
fi

YA_VERSION_RAW=$(ya --version | head -n1)
YA_VERSION=$(echo "$YA_VERSION_RAW" | grep -oP '\d+\.\d+\.\d+')
MIN_VERSION="25.5.28"

version_ge() {
    # return 0 if $1 >= $2 else 1
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

declare -a _errs=()

echo "Installing Yazi themes"
for theme in "${THEMES[@]}"; do
    echo ""
    echo "Installing theme: ${theme}"

    if version_ge "$YA_VERSION" "$MIN_VERSION"; then
        if output=$(ya pkg add "$theme" 2>&1); then
            echo "Theme '${theme}' installed."
        else
            if echo "$output" | grep -q "already exists"; then
                echo "Theme '${theme}' already installed, skipping."
            else
                echo "[ERROR] Failed to install theme '${theme}':"
                echo "$output"
                _errs+=("$theme")
            fi
        fi
    else
        if output=$(ya pack -a "$theme" 2>&1); then
            echo "Theme '${theme}' installed."
        else
            if echo "$output" | grep -q "already exists"; then
                echo "Theme '${theme}' already installed, skipping."
            else
                echo "[ERROR] Failed to install theme '${theme}':"
                echo "$output"
                _errs+=("$theme")
            fi
        fi
    fi
done

echo ""
echo "Finished installing Yazi themes."
echo ""

if [[ "${#_errs[@]}" -gt 0 ]]; then
    echo "Failed on ${#_errs[@]} theme install(s):"
    for e in "${_errs[@]}"; do
        echo "  [FAILURE] $e"
    done
fi

exit 0
