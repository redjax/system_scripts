#!/usr/bin/env bash
set -euo pipefail

## Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        else
            OS="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi

    echo "$OS"
}

## Detect architecture
detect_arch() {
    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

## Check if lnav is already installed
check_installed() {
    if command -v lnav &> /dev/null; then
        INSTALLED_VERSION=$(lnav -V 2>&1 | head -n1 | grep -oP 'lnav \K[0-9.]+' || echo "unknown")
        return 0
    else
        return 1
    fi
}

## Get latest version from GitHub
get_latest_version() {
    echo "Fetching latest version from GitHub"

    LATEST_VERSION=$(curl -s https://api.github.com/repos/tstack/lnav/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/^v//')
    if [ -z "$LATEST_VERSION" ]; then
        echo "ERROR: Failed to fetch latest version"
        return 1
    fi

    echo "$LATEST_VERSION"
}

## Install via package manager
install_via_package_manager() {
    local os=$1
    
    case "$os" in
        ubuntu|debian)
            echo "Installing lnav via apt"

            sudo apt-get update
            sudo apt-get install -y lnav
            ;;
        fedora|rhel|rocky|almalinux)
            echo "Installing lnav via dnf"

            sudo dnf install -y lnav
            ;;
        centos)
            if [ "${OS_VERSION%%.*}" -ge 8 ]; then
                echo "Installing lnav via dnf"

                sudo dnf install -y lnav
            else
                echo "Installing lnav via yum"

                sudo yum install -y lnav
            fi
            ;;
        arch|manjaro)
            echo "Installing lnav via pacman"

            sudo pacman -S --noconfirm lnav
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            echo "Installing lnav via zypper"

            sudo zypper install -y lnav
            ;;
        macos)
            if command -v brew &> /dev/null; then
                echo "Installing lnav via Homebrew"

                brew install lnav
            else
                echo "ERROR: Homebrew not found. Please install Homebrew first."

                return 1
            fi
            ;;
        *)
            echo "WARNING: No package manager support for $os, will try GitHub release"

            return 1
            ;;
    esac
}

## Download and install from GitHub
install_from_github() {
    local version=$1
    local arch=$2
    local os=$3
    
    echo "Installing lnav v${version} from GitHub"
    
    ## Determine the correct binary name based on OS and architecture
    local binary_name=""
    
    if [[ "$os" == "macos" ]]; then
        if [[ "$arch" == "aarch64" ]]; then
            binary_name="lnav-${version}-arm64-macos.zip"
        else
            binary_name="lnav-${version}-x86_64-macos.zip"
        fi

    else
        ## Linux
        if [[ "$arch" == "x86_64" ]]; then
            binary_name="lnav-${version}-x86_64-linux-musl.zip"
        elif [[ "$arch" == "aarch64" ]]; then
            ## Try to find ARM64 binary, might not always be available
            binary_name="lnav-${version}-aarch64-linux-musl.zip"
        else
            echo "ERROR: No pre-built binary available for architecture: $arch"

            return 1
        fi
    fi
    
    local download_url="https://github.com/tstack/lnav/releases/download/v${version}/${binary_name}"
    local temp_dir=$(mktemp -d)
    
    echo "Downloading from: $download_url"
    
    if curl -L -f -o "${temp_dir}/${binary_name}" "$download_url"; then
        echo "Download successful, extracting"

        cd "$temp_dir"
        unzip -q "${binary_name}"
        
        ## Find the lnav binary in the extracted files
        local lnav_binary=$(find . -name "lnav" -type f -executable | head -n1)
        
        if [ -n "$lnav_binary" ]; then
            echo "Installing lnav to /usr/local/bin"
            sudo install -m 755 "$lnav_binary" /usr/local/bin/lnav

            cd - > /dev/null
            rm -rf "$temp_dir"

            echo "lnav installed successfully"

            return 0
        else
            echo "ERROR: Could not find lnav binary in extracted files"

            cd - > /dev/null
            rm -rf "$temp_dir"

            return 1
        fi
    else
        echo "ERROR: Failed to download lnav binary"
        echo "WARNING: The binary $binary_name might not exist for this platform"
        echo "You may need to build from source: https://docs.lnav.org/en/latest/intro.html#installation"

        rm -rf "$temp_dir"

        return 1
    fi
}

## Update lnav
update_lnav() {
    local current_version=$1
    local latest_version=$2
    
    echo "Current version: $current_version"
    echo "Latest version: $latest_version"
    
    if [ "$current_version" = "$latest_version" ]; then
        echo "lnav is already up to date (v${current_version})"

        return 0
    fi
    
    echo "Updating lnav from v${current_version} to v${latest_version}"
    
    ## Try to detect how it was installed
    local lnav_path=$(which lnav)
    
    if [[ "$lnav_path" == *"/usr/local/bin"* ]]; then
        ## Likely installed from GitHub, update via GitHub
        echo "Detected manual installation, updating via GitHub"

        install_from_github "$latest_version" "$(detect_arch)" "$(detect_os)"
    else
        ## Likely installed via package manager
        echo "Updating via package manager"

        install_via_package_manager "$(detect_os)"
    fi
}

## Main installation logic
main() {
    echo "Starting lnav installation/update process"
    
    ## Detect platform
    OS=$(detect_os)
    ARCH=$(detect_arch)
    
    echo "Detected OS: $OS"
    echo "Detected Architecture: $ARCH"
    
    ## Check if already installed
    if check_installed; then
        echo "lnav is already installed (v${INSTALLED_VERSION})"
        
        LATEST_VERSION=$(get_latest_version)
        if [ $? -eq 0 ]; then
            update_lnav "$INSTALLED_VERSION" "$LATEST_VERSION"
        else
            echo "WARNING: Could not check for updates"
        fi

    else
        echo "lnav is not installed"
        
        ## Try package manager first for better integration
        if install_via_package_manager "$OS"; then
            echo "lnav installed successfully via package manager"
        else
            ## Fall back to GitHub release
            LATEST_VERSION=$(get_latest_version)

            if [ $? -eq 0 ]; then
                if install_from_github "$LATEST_VERSION" "$ARCH" "$OS"; then
                    echo "lnav installed successfully from GitHub"
                else
                    echo "ERROR: Failed to install lnav from GitHub"
                    exit 1
                fi

            else
                echo "ERROR: Failed to determine latest version"
                exit 1
            fi
        fi

    fi
    
    ## Verify installation
    if command -v lnav &> /dev/null; then
        FINAL_VERSION=$(lnav -V 2>&1 | head -n1)
        
        echo "Installation complete!"
        echo "Installed version: $FINAL_VERSION"
        echo "Run 'lnav' to start the log navigator"
    else
        echo "ERROR: Installation verification failed"
        exit 1
    fi
}

main "$@"
