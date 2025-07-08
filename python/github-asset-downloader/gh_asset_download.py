#!/usr/bin/env python

"""Script to assist with downloading release assets from Github for pre-defined apps."""

import os
import sys
import platform
import urllib.request
import urllib.error
import json
import tempfile
import shutil
import re
import logging
from pathlib import Path
from dataclasses import dataclass, asdict, field
import argparse

log = logging.getLogger(__name__)

## File to load asset definitions from
ASSET_FILE: str = "assets.json"
## Const strings for Github URLs. Uses f-string templating, apply with GH_RELEASE_URL_FSTRING.format(username="user", repo="repo"), etc
GH_RELEASE_URL_FSTRING: str = (
    "https://api.github.com/repos/{username}/{repo}/releases/latest"
)
GH_RELEASE_DOWNLOAD_URL_FSTRING: str = (
    "https://github.com/{username}/{repo}/releases/download/{tag}/{asset}"
)

## Example asset JSON to dump to a file
EX_ASSET_JSON: str = json.dumps(
    [
        {
            "name": "example-app",
            "username": "githubUser",
            "repo": "repoName",
            "platforms": ["linux", "windows", "darwin"],
            "asset_strings": [
                {"os": "linux", "asset": "exampleapp-v{version}-{cpu_arch}.tar.gz"},
                {"os": "darwin", "asset": "exampleapp-v{version}-{cpu_arch}.zip"},
            ],
            "tag_transforms": [{"search": "^v", "replace": ""}],
        }
    ],
    indent=4,
    default=str,
)


def parse_args():
    parser = argparse.ArgumentParser(
        "gh_asset_download",
        description="Download release assets from Github. Loads asset release metadata from a JSON file.",
    )

    parser.add_argument(
        "--debug", "-D", action="store_true", help="Enable debug logging."
    )
    parser.add_argument(
        "--assets-file",
        "-f",
        type=str,
        default=ASSET_FILE,
        help="Path to a JSON file detailing Github assets.",
    )
    parser.add_argument("--output-dir", "-o", type=str, default=None, help="Path where downloads will be saved. Defaults to a temporary directory")

    args = parser.parse_args()

    return args


def github_api_request(url: str, token: str | None = None):
    """Send a request to the Github API and return the response body.

    Params:
        url: The URL to send the request to.
        token: The Github API token to use for authentication.

    Raises:
        urllib.error.HTTPError: If the request fails.
        urllib.error.URLError: If the request fails.

    Returns:
        The response body as a dictionary.
    """
    ## Build request
    req: urllib.request.Request = urllib.request.Request(url)

    ## Apply Github token header if present
    if token:
        log.info("Github API token detected. Rate limit will be increased.")
        req.add_header("Authorization", f"token {token}")

    ## Send the request
    log.debug(f"Sending request to {url}")
    try:
        with urllib.request.urlopen(req) as response:
            ## Extract response code, reason phrase.
            status_code = response.status
            reason = response.reason
            log.debug(f"[{status_code}: {reason}] URL: {url}")

            ## Extract body as dict
            body: dict = json.loads(response.read())

        return body

    except urllib.error.HTTPError as http_err:
        log.warning(f"({type(http_err)}) Error getting latest release: {http_err}")
        raise
    except urllib.error.URLError as url_err:
        log.warning(f"({type(url_err)}) Error getting latest release: {url_err}")
        raise
    except Exception as exc:
        log.warning(f"({type(exc)}) Failed getting latest release: {exc}")
        raise


def download_asset(url: str, output_filename: str, output_dir: str | None = None):
    if output_dir is None:
        output_dir = tempfile.mkdtemp()

    if not Path(output_dir).parent.exists():
        Path(output_dir).mkdir(parents=True, exist_ok=True)

    out_file: str = f"{output_dir}/{output_filename}"
    log.debug(f"Downloading {url} to {out_file}")

    try:
        with urllib.request.urlopen(url) as response, open(out_file, "wb") as f:
            shutil.copyfileobj(response, f)

    except urllib.error.HTTPError as http_err:
        log.warning(f"({type(http_err)}) Error downloading asset: {http_err}")
        raise
    except urllib.error.URLError as url_err:
        log.warning(f"({type(url_err)}) Error downloading asset: {url_err}")
        raise

    log.debug(f"Asset downloaded to {out_file}")

    return out_file


@dataclass
class GithubReleaseAssetDefinitionBase:
    """Base class for GithubReleaseAssetDefinition.

    Attributes:
        name (str): The name of the program/asset to download from Github.
        username (str): The username of the Github repository owner.
        repo (str): The name of the Github repository.
        platforms (list[str]): A list of platforms to download assets for.
        asset_strings (list[dict]): A list of asset strings to download.
        tag_transforms (list[dict]): A list of tag transforms to apply (i.e. replace/remove characters, add prefix/suffix, etc).

    Properties:
        gh_api_release_url (str): The Github API URL for the latest release.
        repo_str (str): The string representation of the repository (i.e. "username/repo").

    Methods:
        get_latest_release_tag: Get the latest release tag from the Github API.
        return_asset_strings: Return a list of asset strings for the given platform.
        return_asset_urls: Return a list of asset URLs for the given platform.
        dump: Return a dictionary representation of the object.

    Example:
        repo = GithubReleaseAssetDefinition(
            username="veeso",
            repo="termscp",
            platforms=["linux", "windows"],
            asset_strings=[
                {"os": "linux", "asset": "termscp-v{version}-{cpu_arch}-unknown-linux-gnu.tar.gz"},
                {"os": "darwin", "asset": "termscp-v{version}-{cpu_arch}-apple-darwin.tar.gz"}
            ],
            tag_transforms=[
                {"search": "^v", "replace": ""},
            ]
        )

    """

    name: str = field(
        default="",
        metadata={"help": "The name of the program/asset to download from Github."},
    )
    username: str = field(
        default="", metadata={"help": "The username of the Github repository owner."}
    )
    repo: str = field(
        default="", metadata={"help": "The name of the Github repository."}
    )
    platforms: list[str] = field(
        default_factory=list,
        metadata={"help": "A list of platforms to download assets for."},
    )
    asset_strings: list[dict[str, str]] = field(
        default_factory=list, metadata={"help": "A list of asset strings to download."}
    )
    tag_transforms: list[dict[str, str]] = field(
        default_factory=list,
        metadata={
            "help": "A list of tag transforms to apply (i.e. replace/remove characters, add prefix/suffix, etc)."
        },
    )

    def dump(self) -> dict:
        """Dump model class to dict.

        Returns:
            (dict): A dictionary representation of the object.
        """
        data = asdict(self)
        data["gh_api_release_url"] = self.gh_api_release_url

        return data

    @property
    def gh_api_release_url(self) -> str:
        """Get the Github API URL for the latest release."""
        return GH_RELEASE_URL_FSTRING.format(username=self.username, repo=self.repo)

    @property
    def repo_str(self) -> str:
        """Get the string representation of the repository (i.e. "username/repo")."""
        return f"{self.username}/{self.repo}"

    def get_latest_release_tag(self, token: str | None = None) -> str:
        """Get the latest release tag from the Github API.

        Params:
            token (str | None): The Github API token to use for authentication.

        Returns:
            (str): The latest release tag from the Github API.
        """
        log.debug(f"Getting latest release from {self.gh_api_release_url}")
        if token:
            log.debug("Detected Github token, rate limit will be increased.")

        try:
            ## Get the release data
            release_data: dict = github_api_request(url=self.gh_api_release_url)

            ## Extract tag name
            tag_name: str = release_data["tag_name"]

            return tag_name

        except Exception as exc:
            log.error(f"({type(exc)}) Failed getting latest release: {exc}")
            raise

    def return_asset_strings(self, os: str, *args, **kwargs):
        """Return a list of asset strings for the given platform.

        Params:
            os (str): The platform to return asset strings for.

        Returns:
            (list[str]): A list of asset strings for the given platform.
        """
        ## Empty list to store rendered asset strings
        rendered_asset_strings: list[str] = []

        ## Iterate over asset string dicts
        for asset_string_dict in self.asset_strings:
            ## Match asset string to OS
            if asset_string_dict["os"].lower() == os.lower():
                log.debug(f"Match asset string: {asset_string_dict}")

                ## Extract string from dict
                asset_str = asset_string_dict["asset"]
                log.debug(f"Raw asset string: {asset_str}")
                log.debug(f"Will use format values: {kwargs}")

                try:
                    ## Format the asset string using the provided kwargs
                    rendered = asset_str.format(**kwargs)

                    ## Add to list
                    rendered_asset_strings.append(rendered)
                except KeyError as e:
                    log.error(
                        f"Missing key {e} for formatting asset string: {asset_str}"
                    )
                    raise

        return rendered_asset_strings

    def return_asset_download_url(self, release_tag: str, file_name: str) -> str:
        """Return a download URL for the given release tag and file name.

        Params:
            release_tag (str): The release tag to download the asset from.
            file_name (str): The name of the file to download.

        Returns:
            (str): The download URL for the given release tag and file name.
        """
        ## Format download URL string
        download_url: str = GH_RELEASE_DOWNLOAD_URL_FSTRING.format(
            username=self.username, repo=self.repo, tag=release_tag, asset=file_name
        )
        log.debug(f"Asset download URL: {download_url}")

        return download_url


@dataclass
class GithubReleaseAssetDefinition(GithubReleaseAssetDefinitionBase):
    """Class to represent a Github release asset definition.

    Params:
        name (str): The name of the program/asset to download from Github.
        username (str): The username of the Github repository owner.
        repo (str): The name of the Github repository.
        platforms (list[str]): A list of platforms to download assets for.
        asset_strings (list[dict]): A list of asset strings to download.
        tag_transforms (list[dict]): A list of tag transforms to apply (i.e. replace/remove characters, add prefix/suffix, etc).

    Properties:
        gh_api_release_url (str): The Github API URL for the latest release.
        repo_str (str): The string representation of the repository (i.e. "username/repo").

    Methods:
        get_latest_release_tag: Get the latest release tag from the Github API.
        return_asset_strings: Return a list of asset strings for the given platform.
        return_asset_urls: Return a list of asset URLs for the given platform.
        dump: Return a dictionary representation of the object.

    Example:
        repo = GithubReleaseAssetDefinition(
            username="veeso",
            repo="termscp",
            platforms=["linux", "windows"],
            asset_strings=[
                {"os": "linux", "asset": "termscp-v{version}-{cpu_arch}-unknown-linux-gnu.tar.gz"},
                {"os": "darwin", "asset": "termscp-v{version}-{cpu_arch}-apple-darwin.tar.gz"}
            ],
            tag_transforms=[
                {"search": "^v", "replace": ""},
            ]
    """

    pass


def load_github_api_token() -> str:
    """Load the Github API token from the environment variable GH_API_TOKEN."""
    ## Load token from env
    token = os.environ.get("GH_API_TOKEN", None)

    if token is None:
        raise ValueError("Missing GH_API_TOKEN env var")

    return token


def get_platform() -> dict:
    """Get the platform information.

    Returns:
        (dict): A dictionary containing the platform information.
    """
    ## Build platform info dict
    _platform = {
        "os": platform.system(),
        "arch": platform.machine(),
        "version": platform.version(),
    }

    return _platform


def get_linux_distro_id(os_name: str) -> dict:
    """Get the Linux distro ID.

    Params:
        os_name (str): The name of the OS.

    Returns:
        (str): The Linux distro ID, i.e. "ubuntu," "debian," etc.
    """
    ## Detect Linux distro
    if os_name == "Linux":
        distro_id = None

        ## Try to get freedesktop_os_release
        try:
            ## Check if freedesktop_os_release exists in platform module
            if hasattr(platform, "freedesktop_os_release"):
                ## Extract distro ID dict
                info: dict = platform.freedesktop_os_release()
                ## Extract dostrp_id str
                distro_id = info.get("ID")
            else:
                ## Fallback, parse /etc/os-release
                if not Path("/etc/os-release").exists():
                    raise FileNotFoundError(
                        "Could not set distro ID. No freedesktop_os_release detected, and /etc/os-release does not exist."
                    )

        except Exception:
            log.warning(f"Error getting distro ID: {sys.exc_info()[0]}")
            pass

        return distro_id

    return None


def apply_tag_transform(tag: str, tag_transform: dict):
    """Apply a regex-based search/replace to the tag.

    Params:
        tag (str): The tag to apply the transform to.
        tag_transform (dict): A dictionary containing the search and replace strings.

    Returns:
        (str): The transformed tag.
    """
    ## Check if both a search and replace rule are supplied
    if tag_transform and "search" in tag_transform and "replace" in tag_transform:
        ## Apply transformation
        try:
            return re.sub(tag_transform["search"], tag_transform["replace"], tag)
        except Exception as exc:
            log.error(f"({type(exc)}) Failed applying tag transform: {exc}")
            raise

    return tag


def main(assets_json_file: str, output_dir: str| None = None):
    ## Check if assets file exists, dump if not & exit
    if not Path(assets_json_file).exists():
        log.warning(f"Assets JSON file not found at path: {assets_json_file}. Creating default file, make sure to edit it before re-running.")
        with open(assets_json_file, "w") as f:
            f.write(EX_ASSET_JSON)
        exit(1)
        
    if output_dir is None or output_dir == "":
        log.warning("No asset directory detected, will use a temporary directory.")

    ## Set distro_id to None for error handling
    distro_id = None

    ## Get platform info, Github token
    platform = get_platform()
    gh_token = load_github_api_token()
    log.debug(f"Github API token: {gh_token}")

    ## Get distro ID for Linux
    if platform.get("os") == "Linux":
        distro_id = get_linux_distro_id(os_name=platform.get("os"))

    log.debug(json.dumps(platform, indent=4))
    log.debug(json.dumps(distro_id, indent=4))

    ## Load assets JSON
    log.info(f"Loading assets from file: {assets_json_file}")
    with open(assets_json_file, "r") as f:
        assets_raw = json.load(f)

    ## Build list of GithubReleaseAssetDefinition objects
    try:
        assets: list[GithubReleaseAssetDefinition] = [
            GithubReleaseAssetDefinition(**asset) for asset in assets_raw
        ]
    except Exception as exc:
        log.error(
            f"({type(exc)}) Failed converting asset dicts to GithubReleaseAssetDefinition objects: {exc}"
        )
        raise

    for asset in assets:
        log.debug(f"Asset: {asset}")

        ## Request latest release tag
        latest_release = asset.get_latest_release_tag()
        log.info(f"Latest release for {asset.repo_str}: {latest_release}")
        ## Set raw tag for Github URL
        raw_tag = latest_release

        ## Apply tag transforms
        if len(asset.tag_transforms) > 0:
            log.warning("Applying tag transforms")
            for tag_transform in asset.tag_transforms:
                try:
                    ## Create temporary var with new value
                    latest_release_transformed: str = apply_tag_transform(
                        tag=latest_release, tag_transform=tag_transform
                    )
                    log.debug(f"Transformed_tag: {latest_release_transformed}")

                    ## Reset latest_release to transformed value
                    latest_release: str = latest_release_transformed
                except Exception as exc:
                    log.error(f"({type(exc)}) Failed applying tag transform: {exc}")
                    raise

        ## Get asset strings
        log.info(f"Latest release for {asset.repo_str}: {latest_release}")
        asset_strs = asset.return_asset_strings(
            os=platform.get("os"),
            **{"version": latest_release, "cpu_arch": platform.get("arch")},
        )
        log.debug(f"Asset strings: {asset_strs}")

        ## Download assets
        for asset_str in asset_strs:
            log.info(f"Downloading asset: {asset_str}")
            asset_url = asset.return_asset_download_url(
                release_tag=raw_tag, file_name=asset_str
            )

            try:
                download_path: str = download_asset(
                    url=asset_url,
                    output_filename=asset_str,
                    output_dir=output_dir,
                )
                
                log.info(f"Asset downloaded to path: {download_path}")
            except Exception as exc:
                log.error(f"({type(exc)}) Failed downloading asset: {exc}")
                raise


def run():
    """Default entrypoint.
    
    Description:
        Parse CLI args, set up logging, & call main function.
    """
    args = parse_args()
    log_level = "DEBUG" if args.debug else "INFO"
    log_fmt = "%(asctime)s | %(levelname)s | %(name)s.%(funcName)s:%(lineno)s :: %(message)s" if args.debug else "%(asctime)s | %(levelname)s :: %(message)s"
    
    logging.basicConfig(
        level=log_level,
        format=log_fmt,
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    log.debug("DEBUG logging enabled")

    try:
        main(assets_json_file=args.assets_file)
    except Exception as exc:
        log.error(f"({type(exc)}) Failed downloading assets: {exc}")
        raise


if __name__ == "__main__":
    run()
