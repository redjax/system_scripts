# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "asyncio",
#     "httpx",
#     "loguru",
#     "pyyaml",
# ]
# ///


import sys
from pathlib import Path
from urllib.parse import quote

from loguru import logger as log
import asyncio
import yaml
import httpx
import argparse


CONFIG_FILE = "config.yml"


DEFAULT_CONFIG = {
    "github": {
        "token": "ghp_yourgithubtokenhere",
        "user": "github_username",
    },
    "codeberg": {
        "token": "codeberg_api_token_here",
        "user": "codeberg_username",
    },
    "repositories": [
        {"github": "repo1", "codeberg": "repo1"},
        {"github": "repo2", "codeberg": "repo2"},
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        "branch-clean", description="Clean up branches in mirrored git repositories."
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Dry run mode. Will not delete branches, just print what would be deleted.",
    )

    parser.add_argument(
        "-f",
        "--config-file",
        type=str,
        default=CONFIG_FILE,
        help="Path to config file. Defaults to 'config.yml'.",
    )

    parser.add_argument("--debug", action="store_true", help="Enable debug logging.")

    parser.add_argument(
        "--log-file", type=str, help="Path to log file.", default=None
    )

    parser.add_argument(
        "--generate-config",
        action="store_true",
        help="Generate default config file and exit.",
    )

    return parser.parse_args()


def configure_logging(log_level: str = "INFO", log_file: str = None):
    ## Clear default loguru handlers
    log.remove()

    ## Format with timestamp, level, clickable file:line for VSCode
    log_format = (
        "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | "
        "<level>{level: <8}</level> | "
        "<cyan>{file}:{line}</cyan> - "
        "<level>{message}</level>"
    )

    # Console sink (with async safe enqueue)
    log.add(
        sys.stderr,
        level=log_level,
        format=log_format,
        backtrace=True,
        diagnose=True,
        enqueue=True,
    )

    # Optional file sink always DEBUG level if provided
    if log_file:
        log.add(
            log_file,
            level="DEBUG",
            rotation="10 MB",
            retention="7 days",
            enqueue=True,
            backtrace=True,
            diagnose=True,
            format=log_format,
        )


def write_default_config(path):
    with open(path, "w") as f:
        yaml.safe_dump(DEFAULT_CONFIG, f, sort_keys=False)
    log.info(f"Default config wrote to {path}")


def load_config(file_path):
    try:
        with open(file_path, "r") as f:
            return yaml.safe_load(f)
    except Exception as exc:
        log.error(f"Failed to load config: {exc}")
        sys.exit(1)


async def get_github_branches(client, username, repo, token):
    url = f"https://api.github.com/repos/{username}/{repo}/branches"
    headers = {"Authorization": f"token {token}"}
    branches = []
    page = 1

    log.info(f"Getting branches from {url}")

    while True:
        params = {"per_page": 100, "page": page}
        resp = await client.get(url, headers=headers, params=params)
        resp.raise_for_status()

        data = resp.json()

        if not data:
            break

        branches.extend(b["name"] for b in data)
        page += 1

    return branches


async def get_codeberg_branches(client, username, repo, token):
    url = f"https://codeberg.org/api/v1/repos/{username}/{repo}/branches"
    headers = {"Authorization": f"token {token}"}
    branches = []
    page = 1

    log.info(f"Getting branches from {url}")

    while True:
        params = {"page": page, "limit": 100}
        resp = await client.get(url, headers=headers, params=params)
        resp.raise_for_status()

        data = resp.json()

        if not data:
            break

        branches.extend(b["name"] for b in data)
        page += 1

    return branches


async def delete_codeberg_branch(client, repo_full_name, branch_name, token):
    encoded_branch = quote(branch_name, safe="")
    url = f"https://codeberg.org/api/v1/repos/{repo_full_name}/branches/{encoded_branch}"
    headers = {"Authorization": f"token {token}"}

    resp = await client.delete(url, headers=headers)

    if resp.status_code == 204:
        log.info(f"Deleted branch '{branch_name}' from Codeberg repo '{repo_full_name}'")
    else:
        log.error(
            f"Failed to delete branch '{branch_name}' from Codeberg: "
            f"{resp.status_code} {resp.text}"
        )


async def process_repo(
    client, gh_user, gh_token, cb_user, cb_token, repos, dry_run
):
    for repo in repos:
        github_repo = repo["github"]
        codeberg_repo = repo["codeberg"]

        log.info(
            f"Processing repository pair: GitHub {gh_user}/{github_repo} <-> Codeberg {cb_user}/{codeberg_repo}"
        )

        gh_branches = set(
            await get_github_branches(client, gh_user, github_repo, gh_token)
        )
        cb_branches = set(
            await get_codeberg_branches(client, cb_user, codeberg_repo, cb_token)
        )

        to_delete = cb_branches - gh_branches

        if not to_delete:
            log.warning("No branches to delete.")
            continue

        for branch in to_delete:
            if dry_run:
                log.info(
                    f"[DRY RUN] Would delete branch '{branch}' from Codeberg repo '{cb_user}/{codeberg_repo}'"
                )
            else:
                await delete_codeberg_branch(client, f"{cb_user}/{codeberg_repo}", branch, cb_token)


async def main():
    args = parse_args()
    configure_logging(
        log_level="DEBUG" if args.debug else "INFO", log_file=args.log_file
    )

    # Handle generate config flag
    if args.generate_config:
        if Path(args.config_file).exists():
            log.warning(
                f"Config file already exists at '{args.config_file}', skipping generation."
            )
        else:
            write_default_config(args.config_file)
        sys.exit(0)

    # Validate config exists unless generate-config
    if not Path(args.config_file).exists():
        log.error(
            f"Config file not found at path '{args.config_file}'. Use --generate-config to create it."
        )
        sys.exit(1)

    # Load config
    log.debug(f"Loading config from path: {args.config_file}")
    config = load_config(args.config_file)

    github_token = config["github"]["token"]
    github_user = config["github"]["user"]
    codeberg_token = config["codeberg"]["token"]
    codeberg_user = config["codeberg"]["user"]
    repos = config["repositories"]

    log.debug(
        f"""
 == Configuration ==

GitHub user: {github_user}
GitHub token: <redacted>

Codeberg user: {codeberg_user}
Codeberg token: <redacted>

Repositories:
{yaml.dump(repos, default_flow_style=False)}
"""
    )

    if args.dry_run:
        log.info("DRY_RUN mode enabled, no changes will be made.")

    log.info("Synchronizing branches")

    try:
        async with httpx.AsyncClient() as client:
            await process_repo(
                client,
                github_user,
                github_token,
                codeberg_user,
                codeberg_token,
                repos,
                args.dry_run,
            )
        log.info("Done synchronizing branches.")
    except Exception as exc:
        log.exception(exc)
        sys.exit(1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(f"[ERROR] Failed synchronizing branches. Details: {exc}")
        sys.exit(1)
