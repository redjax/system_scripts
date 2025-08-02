#!/bin/bash

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

## Standardize architecture names for Terraform downloads, if needed
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

if command -v terraform &>/dev/null; then
  echo "Terraform is already installed."
  exit 0
fi

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

if ! command -v unzip &>/dev/null; then
  echo "unzip is not installed."
  exit 1
fi

## mac OS install
if [ "$OS" = "Darwin" ]; then
  echo "Detected OS: $OS"

  ## On macOS, prefer Homebrew if available
  if command -v brew >/dev/null 2>&1; then
    echo "Installing Terraform via Homebrew"
    brew install terraform
  else
    ## Manual install: Download and unzip
    echo "Installing Terraform via zip"

    VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | grep -o '"current_version":"[^"]*' | head -1 | cut -d'"' -f4)
    URL="https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_darwin_${ARCH}.zip"
    TMP_DIR=$(mktemp -d)
    
    ## Download terraform archive
    echo "Downloading Terraform from $URL"
    curl -Lo "$TMP_DIR/terraform.zip" "$URL"
    if [ $? -ne 0 ]; then
      echo "Failed to download Terraform from $URL"
      exit 1
    fi
    
    ## Extract terraform archive
    echo "Extracting $TMP_DIR/terraform.zip"
    unzip "$TMP_DIR/terraform.zip" -d "$TMP_DIR"
    if [ $? -ne 0 ]; then
      echo "Failed to extract Terraform from $TMP_DIR/terraform.zip"
      exit 1
    fi
    
    ## Move terraform to /usr/local/bin
    echo "Moving Terraform to /usr/local/bin/"
    sudo mv "$TMP_DIR/terraform" /usr/local/bin/
    if [ $? -ne 0 ]; then
      echo "Failed to move Terraform to /usr/local/bin/"
      rm -rf "$TMP_DIR"

      exit 1
    fi

    rm -rf "$TMP_DIR"
    
    echo "Terraform $VERSION installed in /usr/local/bin/"
  fi

## Linux install
elif [ "$OS" = "Linux" ]; then
  ## Find Linux distribution
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID,,}"
  else
    echo "Cannot determine Linux distribution."
    exit 1
  fi

  echo "Detected Linux distribution: $NAME ($ID)"

  case "$DISTRO_ID" in
    ubuntu|debian)
      echo "Installing Terraform via apt-get"

      ## Install prerequisites
      sudo apt-get update
      sudo apt-get install -y software-properties-common gnupg2 curl
      
      ## Add HashiCorp GPG key
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      
      ## Add HashiCorp repo
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

      ## Install
      sudo apt-get update
      sudo apt-get install -y terraform
      ;;
    fedora)
      echo "Installing Terraform via dnf"

      ## Install prerequisites
      sudo dnf install -y dnf-plugins-core
      ## Add HashiCorp repo
      sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

      ## Install
      sudo dnf -y install terraform
      ;;
    centos|rhel)
      echo "Installing Terraform via yum"

      ## Add HashiCorp repo
      sudo yum install -y yum-utils

      ## Add HashiCorp repo
      sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

      ## Install
      sudo yum -y install terraform
      ;;
    opensuse*|suse)
      echo "Installing Terraform via manual archive extract"

      ## Get latest terraform version
      VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | grep -o '"current_version":"[^"]*' | head -1 | cut -d'"' -f4)
      ## Build URL
      URL="https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_${ARCH}.zip"

      TMP_DIR=$(mktemp -d)
      
      ## Download terraform archive
      curl -Lo "$TMP_DIR/terraform.zip" "$URL"
      if [ $? -ne 0 ]; then
        echo "Failed to download Terraform from $URL"
        exit 1
      fi

      ## Extract terraform archive
      unzip "$TMP_DIR/terraform.zip" -d "$TMP_DIR"
      if [ $? -ne 0 ]; then
        echo "Failed to extract Terraform from $TMP_DIR/terraform.zip"
        exit 1  
      fi

      ## Move terraform to /usr/local/bin
      sudo mv "$TMP_DIR/terraform" /usr/local/bin/

      rm -rf "$TMP_DIR"
      ;;
    arch)
      echo "Installing Terraform via pacman"
      
      ## On Arch Linux, use pacman or AUR
      if command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm terraform
      else
        echo "Pacman not found. Please install terraform manually or via AUR."
      fi
      ;;
    *)
      echo "Unsupported or unrecognized Linux distribution: $DISTRO_ID"
      exit 1
      ;;
  esac
else
  echo "Unsupported OS: $OS"
  exit 1
fi

## Verify installation
if command -v terraform &>/dev/null; then
  echo "Installed Terraform version: $(terraform version)"
  terraform version
else
  if [[ -f /usr/local/bin/terraform ]]; then
    echo "Installed Terraform version: $(terraform version)"
    terraform version
  else
    echo "Terraform installation failed"
    exit 1
  fi
fi
