#!/usr/bin/env bash
set -euo pipefail

install_pre_commit() {
    ## Attempt to install pre-commit using pip (possibly via python -m pip)
    if command -v pip &>/dev/null; then
        if pip install --user pre-commit; then
            return 0
        fi
    fi
    
    if command -v pip3 &>/dev/null; then
        if pip3 install --user pre-commit; then
            return 0
        fi
    fi
    
    if command -v python &>/dev/null; then
        if python -m pip install --user pre-commit; then
            return 0
        fi
    fi
    
    if command -v python3 &>/dev/null; then
        if python3 -m pip install --user pre-commit; then
            return 0
        fi
    fi
    
    if command -v py3 &>/dev/null; then
        if py3 -m pip install --user pre-commit; then
            return 0
        fi
    fi

    return 1
}

main() {
    ## Check if uv is installed
    if command -v uv &>/dev/null; then
        echo "Installing pre-commit using uv tool..."
        if uv tool install pre-commit --with pre-commit-uv --force-reinstall; then
            echo "pre-commit installed successfully with uv."
            exit 0
        else
            echo "Failed to install pre-commit with uv."
        fi
    fi

    echo "uv tool not found or installation failed, falling back to pip/python..."
    
    if install_pre_commit; then
        echo "pre-commit installed successfully with pip/python."
        exit 0
    else
        echo "Failed to install pre-commit via pip and python commands."
        exit 1
    fi
}

main
