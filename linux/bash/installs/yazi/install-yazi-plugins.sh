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

if ! command -v ya; then
    if command -v yazi; then
        echo "[ERROR] yazi is installed, but 'ya' command not found."
    fi
fi

declare -a _errs=()

echo "Installing Yazi plugins"
for plugin in "${PLUGINS[@]}"; do
    echo ""
    echo "Installing plugin: ${plugin}"

    if output=$(ya pkg add $plugin 2>&1); then
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
