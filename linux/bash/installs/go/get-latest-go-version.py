#!/usr/bin/env python3

"""
Simple Go script to get the latest version of Go from https://go.dev/dl/?mode=json.

Parses the JSON data into readable terminal output. You can control the output with flags.
    --latest shows only the latest release
    --local shows only releases relevant to the current machine's platform
    --simple prints only the Go version number, i.e. 0.0.0
    
Run with -h/--help to print usage menu.
"""

import urllib.request
import json
import argparse
import platform

go_json_url: str = "https://go.dev/dl/?mode=json"

def fetch_go_versions():
    """Fetches the latest Go versions as a JSON object from https://go.dev/dl/?mode=json."""
    
    with urllib.request.urlopen(go_json_url) as response:
        if response.status != 200:
            raise Exception(f"Request to {go_json_url} failed with status {response.status}")
        
        return json.loads(response.read())

def filter_local_files(files):
    """Filters out files that are not relevant to the current machine's platform."""
    current_os = platform.system().lower()
    current_arch = platform.machine().lower()
    
    ## Map some common machine names to Go arch names
    arch_map = {"x86_64": "amd64", "aarch64": "arm64", "armv7l": "armv6l"}
    
    current_arch: str = arch_map.get(current_arch, current_arch)

    ## Return list of files that match the current OS and architecture
    return [f for f in files if f["os"] == current_os and f["arch"] == current_arch]

def main():
    ## Parse user args
    parser = argparse.ArgumentParser(description="List Go versions and downloads.")
    
    parser.add_argument("--latest", action="store_true", help="Show only the latest stable version")
    parser.add_argument("--local", action="store_true", help="Show only downloads for current platform")
    parser.add_argument("--simple", action="store_true", help="Print only version numbers")
    
    args = parser.parse_args()

    ## Fetch Go versions
    versions: list = fetch_go_versions()

    ## If --latest, keep only the first stable version
    if args.latest:
        latest_stable = next((v for v in versions if v.get("stable")), None)
        
        if not latest_stable:
            print("No stable Go version found.")
            return

        versions = [latest_stable]

    ## Iterate over versions & print
    for version in versions:
        if args.simple:
            ## remove 'go' prefix
            print(version['version'].lstrip('go'))
            continue

        print(f"Go version: {version['version']} (stable: {version.get('stable', False)})\n")
        print("Downloads:")

        files: list = version["files"]
        
        ## Filter downloads if --local provided
        if args.local:
            files = filter_local_files(files)

        ## Iterate over files and print
        for file in files:
            os_name = file.get("os", "source")
            arch = file.get("arch", "-")
            kind = file.get("kind")
            size_mb = file.get("size", 0) / 1024 / 1024
            
            print(f"- {file['filename']} | OS: {os_name} | Arch: {arch} | Kind: {kind} | Size: {size_mb:.1f} MB")

        print()

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[ERROR] ({exc.__class__.__name__}) Failed to get latest Go version from URL '{go_json_url}'. Details: {exc}")
