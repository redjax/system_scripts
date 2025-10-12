#!/usr/bin/env bash

set -uo pipefail

declare -a PLUGINS=(
    ## Open files/dirs with Enter
    yazi-rs/plugins:smart-enter
    ## Paste file into hovered dir
    yazi-rs/plugins:smart-paste
    ## Mount (mount/eject paths)
    yazi-rs/plugins:mount
    ## VSC files (show git changes)
    yazi-rs/plugins:vcs-files
    ## Smart filter
    yazi-rs/plugins:smart-filter
    ## Chmod
    yazi-rs/plugins:chmod
    ## mime-ext (faster MIME types, at the expense of accuracy. Uses file extensions)
    yazi-rs/plugins:mime-ext
    ## Diff
    yazi-rs/plugins:diff
)

if ! command -v ya &>/dev/null; then
    if command -v yazi &>/dev/null; then
        echo "[ERROR] yazi is installed, but 'ya' command not found."
    else
        echo "[ERROR] ya command not found."
    fi
    exit 1
fi

# Parse YA version, e.g. output: "Ya 25.4.8 (ea90b047 2025-05-11)"
YA_VERSION_RAW=$(ya --version | head -n1)
YA_VERSION=$(echo "$YA_VERSION_RAW" | grep -oP '\d+\.\d+\.\d+')
MIN_VERSION="25.5.28"

version_ge() {
    # returns 0 (true) if $1 >= $2 else 1
    # Sort two versions and check if first version is second line
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Main install loop
declare -a _errs=()

echo "Installing Yazi plugins"
for plugin in "${PLUGINS[@]}"; do
    echo ""
    echo "Installing plugin: ${plugin}"

    if version_ge "$YA_VERSION" "$MIN_VERSION"; then
        ## Newer ya with 'pkg' subcommand
        if output=$(ya pkg add "$plugin" 2>&1); then
            echo "Plugin '${plugin}' installed."
        else
            if echo "$output" | grep -q "already exists"; then
                echo "Plugin '${plugin}' already installed, skipping."
            else
                echo "[ERROR] Failed to install plugin '${plugin}':"
                echo "$output"
                _errs+=("$plugin")
            fi
        fi
    else
        ## Older ya with legacy 'pack -a' subcommand
        if output=$(ya pack -a "$plugin" 2>&1); then
            echo "Plugin '${plugin}' installed."
        else
            if echo "$output" | grep -q "already exists"; then
                echo "Plugin '${plugin}' already installed, skipping."
            else
                echo "[ERROR] Failed to install plugin '${plugin}':"
                echo "$output"
                _errs+=("$plugin")
            fi
        fi
    fi
done

echo ""
echo "Finished installing Yazi plugins."
echo ""

if [[ "${#_errs[@]}" -gt 0 ]]; then
    echo "Failed on ${#_errs[@]} plugin install(s):"
    for e in "${_errs[@]}"; do
        echo "  [FAILURE] $e"
    done
fi

exit 0
