#!/usr/bin/env bash
set -euo pipefail

CONTINUE=false
REPO="chmouel/lazyworktree"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="lazyworktree"

if command -v lazyworktree &>/dev/null || [[ -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
  echo "[WARNING] LazyWorktree is already installed."

  while true; do
    read -n 1 -r -p "Do you want to continue? (y/n): " yn
    echo ""

    case $yn in
      [Yy])
        CONTINUE=true
        break
        ;;
      [Nn])
        echo "Exiting."
        exit 0
        ;;
      *)
        echo "[ERROR] Invalid choice. Please answer 'y' or 'n'."
        ;;
    esac
  done
fi

TEMP_DIR=$(mktemp -d)

cleanup() {
    cd /
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Fetching latest release from $REPO"

# Get latest release info
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Latest version: $LATEST_TAG"

RELEASE_URL="https://github.com/$REPO/releases/download/$LATEST_TAG"

# Detect OS and architecture
case $(uname -s) in
    Linux*)   OS=Linux;;
    Darwin*)  OS=Darwin;;
    *)        echo "Unsupported OS: $(uname -s)"; exit 1;;
esac

case $(uname -m) in
    x86_64)   ARCH=x86_64;;
    arm64|aarch64) ARCH=arm64;;
    arm*)     ARCH=armhf;;
    *)        echo "Unsupported architecture: $(uname -m)"; exit 1;;
esac

echo "Detected: $OS $ARCH"

# Try common binary naming patterns for Go releases
for EXT in .tar.gz .zip; do
    BINARY="lazyworktree_${OS}_${ARCH}${EXT}"
    DOWNLOAD_URL="${RELEASE_URL}/${BINARY}"
    
    if curl -L -f -o /dev/null "$DOWNLOAD_URL" 2>/dev/null; then
        echo "Found binary: $BINARY"
        
        # Download
        curl -L -o "$TEMP_DIR/$BINARY" "$DOWNLOAD_URL"
        
        cd "$TEMP_DIR"
        
        # Extract
        if [[ $EXT == *.tar.gz ]]; then
            tar -xzf "$BINARY"
        else
            unzip -q "$BINARY"
        fi
        
        # Find the executable
        EXEC=$(find . -type f -name "lazyworktree*" -perm -111 | head -1)
        if [[ -z "$EXEC" ]]; then
            echo "No executable found after extraction"
            ls -la
            exit 1
        fi
        
        # Install
        mkdir -p "$INSTALL_DIR"
        mv "$EXEC" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
        
        echo "Installed latest lazyworktree v$LATEST_TAG to $INSTALL_DIR/$BINARY_NAME"
        
        # PATH setup
        if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
            echo ""
            echo "📝 Add to your ~/.bashrc, ~/.zshrc, or ~/.profile:"
            echo "   export PATH=\"\$HOME/bin:\$PATH\""
        fi
        
        echo ""
        echo "cd to a git repo and run 'lazyworktree'"
        exit 0
    fi
done

echo "No matching binary found for $OS/$ARCH in v$LATEST_TAG"
echo "Available assets:"
curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"name"' | sed 's/.*"name": "\([^"]*\)".*/  \1/'
exit 1
