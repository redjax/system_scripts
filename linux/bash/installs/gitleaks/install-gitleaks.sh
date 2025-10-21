#!/usr/bin/env bash

set -e

if command -v gitleaks &>/dev/null; then
    echo "Gitleaks is already installed."
    exit 1
fi

# Detect OS and architecture for asset name suffix
case "$(uname -s)" in
    Linux*)
        case "$(uname -m)" in
            x86_64) suffix="linux_x64.tar.gz" ;;
            arm64|aarch64) suffix="linux_arm64.tar.gz" ;;
            armv6l) suffix="linux_armv6.tar.gz" ;;
            armv7l) suffix="linux_armv7.tar.gz" ;;
            i?86) suffix="linux_x32.tar.gz" ;;
            *) echo "Unsupported Linux architecture: $(uname -m)"; exit 1 ;;
        esac
        ;;
    Darwin*)
        case "$(uname -m)" in
            arm64) suffix="darwin_arm64.tar.gz" ;;
            x86_64) suffix="darwin_x64.tar.gz" ;;
            *) echo "Unsupported macOS architecture: $(uname -m)"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

echo "Fetching latest gitleaks release version..."
release_api="https://api.github.com/repos/gitleaks/gitleaks/releases/latest"
latest_version=$(curl -s "$release_api" | jq -r '.tag_name')

if [[ -z "$latest_version" ]]; then
    echo "Could not detect latest version"
    exit 1
fi

# Strip leading 'v' if present
version="${latest_version#v}"

asset="gitleaks_${version}_${suffix}"

echo "Latest version: $version"
echo "Looking for asset: $asset"

download_url=$(curl -s "$release_api" | jq -r ".assets[] | select(.name==\"$asset\") | .browser_download_url")

if [[ -z "$download_url" ]]; then
    echo "Could not find asset: $asset"
    exit 1
fi

# Create a temporary directory
temp_dir=$(mktemp -d)
echo "Created temporary directory $temp_dir"

# Download the asset to the temp directory
temp_archive="$temp_dir/$asset"
echo "Downloading $asset ..."
curl -L -o "$temp_archive" "$download_url"

# Extract inside the temporary directory
echo "Extracting $asset ..."
tar -xzf "$temp_archive" -C "$temp_dir"

# Confirm binary exists
if [[ ! -f "$temp_dir/gitleaks" ]]; then
    echo "Failed to find gitleaks binary after extraction"
    exit 1
fi

echo "Installing gitleaks to /usr/local/bin (requires sudo)..."
chmod +x "$temp_dir/gitleaks"
sudo mv "$temp_dir/gitleaks" /usr/local/bin/

# Cleanup
echo "Cleaning up temporary directory ..."
rm -rf "$temp_dir"

echo "Installation complete. Installed gitleaks version:"
gitleaks version

