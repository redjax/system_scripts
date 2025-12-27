#!/usr/bin/env bash
set -euo pipefail

## Default version
TEMURIN_VERSION="${1:-25}"

## Detect OS and arch
OS="$(. /etc/os-release && echo "$ID")"
VERSION_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}")"
ARCH="$(uname -m)"

echo "Installing Temurin JDK $TEMURIN_VERSION on $OS/$ARCH"

## Debian / Ubuntu
if [[ "$OS" =~ (debian|ubuntu|linuxmint) ]]; then
    sudo apt update
    sudo apt install -y wget apt-transport-https gnupg

    ## Import GPG key
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg >/dev/null

    ## Add repo
    REPO_CODENAME="$VERSION_CODENAME"
    echo "deb https://packages.adoptium.net/artifactory/deb $REPO_CODENAME main" | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null

    ## Install
    sudo apt update
    sudo apt install -y "temurin-$TEMURIN_VERSION-jdk"

## RHEL / CentOS / Fedora
elif [[ "$OS" =~ (rhel|centos|fedora) ]]; then
    DISTRIBUTION_NAME="${OS}"
    sudo tee /etc/yum.repos.d/adoptium.repo >/dev/null <<EOF
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/$DISTRIBUTION_NAME/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
EOF

    if command -v dnf >/dev/null; then
        sudo dnf install -y "temurin-$TEMURIN_VERSION-jdk"
    else
        sudo yum install -y "temurin-$TEMURIN_VERSION-jdk"
    fi

## openSUSE / SLES
elif [[ "$OS" =~ (opensuse|sles) ]]; then
    sudo zypper ar -f "https://packages.adoptium.net/artifactory/rpm/opensuse/$(. /etc/os-release; echo $VERSION_ID)/$ARCH" adoptium
    sudo zypper refresh
    sudo zypper install -y "temurin-$TEMURIN_VERSION-jdk"

## Alpine Linux
elif [[ "$OS" == "alpine" ]]; then
    sudo wget -O /etc/apk/keys/adoptium.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk
    echo 'https://packages.adoptium.net/artifactory/apk/alpine/main' | sudo tee -a /etc/apk/repositories
    sudo apk update
    sudo apk add "temurin-$TEMURIN_VERSION-jdk"

else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "Temurin JDK $TEMURIN_VERSION installed successfully!"
java -version
