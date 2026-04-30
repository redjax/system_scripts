#!/usr/bin/env bash
set -euo pipefail

############################################
# Install Microsoft PowerShell from Github #
# https://github.com/PowerShell/PowerShell #
############################################

REPO_API_URL="https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
TMP_DIR=""

function log() {
	echo "[INFO] $*"
}

function warn() {
	echo "[WARN] $*" >&2
}

function error() {
	echo "[ERROR] $*" >&2
	exit 1
}

function require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		error "Required command not found: $1"
	fi
}

function cleanup_tmp_dir() {
	if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
		rm -rf "${TMP_DIR}"
	fi
}

function run_as_root() {
	if [[ "${EUID}" -eq 0 ]]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		error "This action requires root privileges. Install sudo or run as root."
	fi
}

function normalize_arch() {
	local arch
	arch="$(uname -m)"

	case "$arch" in
		x86_64|amd64)
			echo "amd64"
			;;
		aarch64|arm64)
			echo "arm64"
			;;
		armv7l|armv6l)
			echo "arm32"
			;;
		*)
			error "Unsupported architecture: $arch"
			;;
	esac
}

function is_musl() {
	if [[ -f /etc/alpine-release ]]; then
		return 0
	fi

	if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
		return 0
	fi

	return 1
}

function detect_distro_family() {
	local id=""
	local id_like=""

	if [[ -f /etc/os-release ]]; then
		# shellcheck disable=SC1091
		source /etc/os-release
		id="${ID:-}"
		id_like="${ID_LIKE:-}"
	else
		error "Could not detect distro (missing /etc/os-release)."
	fi

	local all_ids="${id} ${id_like}"

	if [[ "$all_ids" =~ (debian|ubuntu|linuxmint|pop|elementary|zorin|kali) ]]; then
		echo "deb"
		return
	fi

	if [[ "$all_ids" =~ (rhel|fedora|centos|rocky|almalinux|ol|amzn|sles|suse|opensuse) ]]; then
		echo "rpm"
		return
	fi

	if [[ "$all_ids" =~ (arch|manjaro|endeavouros|artix) ]]; then
		echo "tar"
		return
	fi

	warn "Unrecognized distro ID/ID_LIKE: '${all_ids}'. Falling back to tarball install."
	echo "tar"
}

function semver_only() {
	echo "$1" | sed -E 's/^v//; s/[^0-9.].*$//'
}

function is_update_needed() {
	local installed="$1"
	local latest="$2"

	if [[ -z "$installed" ]]; then
		return 0
	fi

	if [[ "$installed" == "$latest" ]]; then
		return 1
	fi

	local highest
	highest="$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n 1)"
    
	[[ "$highest" == "$latest" ]]
}

function current_pwsh_version() {
	if ! command -v pwsh >/dev/null 2>&1; then
		return 1
	fi

	pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null | tr -d '[:space:]'
}

function extract_latest_tag() {
	local release_json="$1"
	echo "$release_json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1
}

function extract_asset_urls() {
	local release_json="$1"
	echo "$release_json" | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p'
}

function pick_asset_url() {
	local all_urls="$1"
	local family="$2"
	local arch="$3"
	local prefer_rh="$4"
	local musl="$5"

	case "$family" in
		deb)
			if [[ "$arch" == "amd64" ]]; then
				echo "$all_urls" | grep -E '/powershell_[0-9].*-1\.deb_amd64\.deb$' | grep -vi 'lts' | head -n 1
				return
			fi
			;;
		rpm)
			case "$arch" in
				arm64)
					echo "$all_urls" | grep -E '/powershell-[0-9].*-1\.cm\.aarch64\.rpm$' | grep -vi 'lts' | head -n 1
					return
					;;
				amd64)
					if [[ "$prefer_rh" == "true" ]]; then
						local rh cm

						rh="$(echo "$all_urls" | grep -E '/powershell-[0-9].*-1\.rh\.x86_64\.rpm$' | grep -vi 'lts' | head -n 1 || true)"
						cm="$(echo "$all_urls" | grep -E '/powershell-[0-9].*-1\.cm\.x86_64\.rpm$' | grep -vi 'lts' | head -n 1 || true)"
						
                        if [[ -n "$rh" ]]; then
							echo "$rh"
						else
							echo "$cm"
						fi

						return
					fi

					echo "$all_urls" | grep -E '/powershell-[0-9].*-1\.cm\.x86_64\.rpm$' | grep -vi 'lts' | head -n 1
					return
					;;
			esac
			;;
		tar)
			case "$arch" in
				arm32)
					echo "$all_urls" | grep -E '/powershell-[0-9].*-linux-arm32\.tar\.gz$' | grep -vi 'lts' | head -n 1
					return
					;;
				arm64)
					echo "$all_urls" | grep -E '/powershell-[0-9].*-linux-arm64\.tar\.gz$' | grep -vi 'lts' | head -n 1
					return
					;;
				amd64)
					if [[ "$musl" == "true" ]]; then
						echo "$all_urls" | grep -E '/powershell-[0-9].*-linux-musl-x64\.tar\.gz$' | grep -vi 'lts' | head -n 1
						return
					fi

					echo "$all_urls" | grep -E '/powershell-[0-9].*-linux-x64\.tar\.gz$' | grep -vi 'fxdependent|musl|noopt|lts' | head -n 1
					return
					;;
			esac
			;;
	esac

	return 1
}

function install_deb() {
	local pkg_file="$1"

	run_as_root dpkg -i "$pkg_file" || true
	run_as_root apt-get update
	run_as_root apt-get install -f -y
}

function install_rpm() {
	local pkg_file="$1"

	if command -v dnf >/dev/null 2>&1; then
		run_as_root dnf install -y "$pkg_file"
		return
	fi

	if command -v yum >/dev/null 2>&1; then
		run_as_root yum localinstall -y "$pkg_file"
		return
	fi

	if command -v zypper >/dev/null 2>&1; then
		run_as_root zypper --non-interactive install "$pkg_file"
		return
	fi

	run_as_root rpm -Uvh "$pkg_file"
}

function install_tarball() {
	local tar_file="$1"
	local version="$2"
	local extract_dir="$3"
	local install_root="/opt/microsoft/powershell"
	local install_dir="${install_root}/${version}"

	mkdir -p "$extract_dir"
	tar -xzf "$tar_file" -C "$extract_dir"

	run_as_root mkdir -p "$install_root"
	run_as_root rm -rf "$install_dir"
	run_as_root mkdir -p "$install_dir"
	run_as_root cp -a "$extract_dir"/. "$install_dir"/
	run_as_root chmod +x "${install_dir}/pwsh"
	run_as_root ln -sfn "${install_dir}/pwsh" /usr/bin/pwsh
}

function main() {
	require_cmd curl
	require_cmd grep
	require_cmd sed
	require_cmd sort
	require_cmd tar
	require_cmd uname
	require_cmd mktemp

	log "Detecting OS and architecture"

	local distro_family arch release_json latest_tag latest_version installed_version
	local all_urls download_url archive_path prefer_rh=false musl=false
	local os_id=""

	arch="$(normalize_arch)"
	distro_family="$(detect_distro_family)"

	if [[ -f /etc/os-release ]]; then
		# shellcheck disable=SC1091
		source /etc/os-release
		os_id="${ID:-}"
	fi

	if [[ "$distro_family" == "rpm" ]] && [[ "$os_id" =~ (rhel|centos|rocky|almalinux|ol|amzn|fedora) ]]; then
		prefer_rh=true
	fi

	if is_musl; then
		musl=true
	fi

	log "Fetching latest stable (mainline) PowerShell release"
	release_json="$(curl -fsSL "$REPO_API_URL")"

	latest_tag="$(extract_latest_tag "$release_json")"
	if [[ -z "$latest_tag" ]]; then
		error "Could not determine latest PowerShell release tag from GitHub."
	fi

	latest_version="$(semver_only "$latest_tag")"
	if [[ -z "$latest_version" ]]; then
		error "Could not parse latest PowerShell version from tag: $latest_tag"
	fi

	installed_version="$(current_pwsh_version || true)"
	installed_version="$(semver_only "$installed_version")"

	if [[ -n "$installed_version" ]]; then
		log "Installed PowerShell version: $installed_version"
	else
		log "PowerShell is not currently installed."
	fi

	log "Latest stable PowerShell version: $latest_version"

	if ! is_update_needed "$installed_version" "$latest_version"; then
		log "PowerShell is already up to date. No action needed."
		exit 0
	fi

	all_urls="$(extract_asset_urls "$release_json")"
	download_url="$(pick_asset_url "$all_urls" "$distro_family" "$arch" "$prefer_rh" "$musl" || true)"

	## Fall back to generic tarball if distro package is unavailable for this architecture.
	if [[ -z "$download_url" ]]; then
		warn "No distro package found for family='$distro_family' arch='$arch'. Falling back to tarball."
		distro_family="tar"
		download_url="$(pick_asset_url "$all_urls" "tar" "$arch" "$prefer_rh" "$musl" || true)"
	fi

	if [[ -z "$download_url" ]]; then
		error "Could not find a compatible PowerShell release asset for this system."
	fi

	TMP_DIR="$(mktemp -d -t pwsh-install-XXXXXX)"
	trap cleanup_tmp_dir EXIT

	archive_path="${TMP_DIR}/$(basename "$download_url")"

	log "Using temporary directory: $TMP_DIR"
	log "Downloading asset: $(basename "$download_url")"
	curl -fL "$download_url" -o "$archive_path"

	case "$download_url" in
		*.deb)
			log "Installing DEB package"
			install_deb "$archive_path"
			;;
		*.rpm)
			log "Installing RPM package"
			install_rpm "$archive_path"
			;;
		*.tar.gz)
			log "Installing tarball build"
			install_tarball "$archive_path" "$latest_version" "${TMP_DIR}/extract"
			;;
		*)
			error "Unsupported asset type selected: $download_url"
			;;
	esac

	local final_version
	final_version="$(current_pwsh_version || true)"

	if [[ -n "$final_version" ]]; then
		log "PowerShell install complete. Current version: $final_version"
	else
		error "Installation finished, but 'pwsh' was not found on PATH."
	fi
}

main "$@"


