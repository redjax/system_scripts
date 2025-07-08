# Github Asset Downloader <!-- omit in toc -->

Attempt to download a Github asset from a release tag. Script uses [a JSON file to define assets](./example.assets.json). The JSON accepts multiple parameters, including a formatted asset string to assist the script with different kinds of releases.

## Table of Contents <!-- omit in toc -->

- [Usage](#usage)
- [Example asset JSON](#example-asset-json)

## Usage

Run `python gh_asset_download.py --help` to see usage.

## Example asset JSON

The example below defines a release asset for the [termscp program](https://github.com/veeso/termscp).

```json
[
    {
        "name": "termscp",
        "username": "veeso",
        "repo": "termscp",
        "platforms": [
            "linux",
            "windows"
        ],
        "asset_strings": [
            {
                "os": "linux",
                "asset": "termscp-v{version}-{cpu_arch}-unknown-linux-gnu.tar.gz"
            },
            {
                "os": "darwin",
                "asset": "termscp-v{version}-{cpu_arch}-apple-darwin.tar.gz"
            }
        ],
        "tag_transforms": [
            {
                "search": "^v",
                "replace": ""
            }
        ]
    }
]
```
