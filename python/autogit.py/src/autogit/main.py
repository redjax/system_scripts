import typing as t
from pathlib import Path

from core import PLATFORM

from git import Repo
import git


def validate_git_repo(repo: Repo = None) -> Repo:
    assert repo, ValueError("Missing a git.Repo() object")
    assert isinstance(repo, Repo), TypeError(
        f"repo must be of type git.Repo. Got type: ({type(repo)})"
    )
    assert Path(repo.working_tree_dir).exists(), Exception(
        f"Repo working directory is not a git repository. Repository: {repo.working_tree_dir}."
    )

    return repo


def load_repopath(repo_file: t.Union[str, Path] = Path("repo_path")) -> Path:
    assert repo_file, ValueError("Missing a repo path")
    assert isinstance(repo_file, str) or isinstance(repo_file, Path), ValueError(
        f"filename must be a string or Path. Got type: ({type(repo_file)})"
    )
    if isinstance(repo_file, str):
        if "~" in repo_file:
            repo_file: Path = Path(repo_file).expanduser()
        else:
            repo_file: Path = Path(repo_file)

    assert Path(repo_file).exists()

    try:
        with open(repo_file, "r") as f:
            f_data = f.read()
            assert f_data, ValueError(
                "repo_file must contain a path to a git repository."
            )

        return f_data

    except Exception as exc:
        msg = Exception(
            f"Unhandled exception loading repository path from file '{repo_file}'. Details:  {exc}"
        )

        raise msg


def load_git_repo(repo_path: t.Union[str, Path] = None) -> Repo:
    assert repo_path, ValueError("Missing a repo path")
    assert isinstance(repo_path, str) or isinstance(repo_path, Path), ValueError(
        f"repo_path must be a string or Path. Got type: ({type(repo_path)})"
    )
    if isinstance(repo_path, str):
        if "~" in repo_path:
            repo_path: Path = Path(repo_path).expanduser()
        else:
            repo_path: Path = Path(repo_path)

    assert Path(repo_path).exists()

    try:
        _repo: Repo = Repo(path=repo_path)

        return _repo

    except Exception as exc:
        msg = Exception(
            f"Unhandled exception loading git repository at path '{repo_path}'. Details: {exc}"
        )

        raise msg


def get_untracked(repo: Repo = None) -> list[str]:
    repo = validate_git_repo(repo)

    try:
        _untracked: list[str] = repo.untracked_files

        return _untracked

    except Exception as exc:
        msg = Exception(
            f"Unhandled exception getting untracked files in repository '{repo.working_tree_dir}'. Details: {exc}"
        )

        raise msg


def get_branchnames(repo: Repo = None) -> list[git.HEAD]:
    repo = validate_git_repo(repo)

    try:
        branches: list[git.HEAD] = repo.heads

        return branches

    except Exception as exc:
        msg = Exception(
            f"Unhandled exception getting branches from repo.heads. Details: {exc}"
        )

        raise msg


def main():
    GIT_REPO_PATH: Path = load_repopath()

    repo: Repo = load_git_repo(GIT_REPO_PATH)
    assert not repo.bare

    print(f"Found git repository at path '{GIT_REPO_PATH}'")
    print(f"Git remotes: {repo.remotes}")

    repo_config = repo.config_reader()

    untracked_files = get_untracked(repo=repo)
    if untracked_files:
        print(f"Untracked files ({type(untracked_files)}): {untracked_files}")

    print(f"Ref: {repo.head.ref}")

    branches = get_branchnames(repo=repo)
    print(f"Branches: {branches}")


if __name__ == "__main__":

    main()
