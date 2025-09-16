#!/usr/bin/env bash
set -euo pipefail

## Find a Python interpreter for pip installs
PYTHON_BIN=""
for bin in python3 python py py3 python; do
    if command -v "$bin" >/dev/null 2>&1; then
        PYTHON_BIN=$bin
        break
    fi
done

## Ensure git-filter-repo is installed (try uv first, then pip)
if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "git-filter-repo not found."

    ## Install with uv, if available
    if command -v uv >/dev/null 2>&1; then
        echo "uv found. Installing git-filter-repo as a tool..."
        uv tool install git-filter-repo
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if [[ -z "$PYTHON_BIN" ]]; then
        echo "No Python interpreter found. Please install Python or uv."
        exit 1
    fi

    ## Fallback to Python
    echo "Using $PYTHON_BIN to install git-filter-repo via pip..."
    "$PYTHON_BIN" -m pip install --user git-filter-repo
    export PATH="$HOME/.local/bin:$PATH"
fi

## Test git-filter-repo was installed correctly
if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "git-filter-repo still not found after installation attempts."
    exit 1
fi

## Function to print help menu/usage
usage() {
    echo ""
    echo "Usage: $0 [--force] \\"
    echo "          --repo-url git@github.com:user/repo.git \\"
    echo "          --source-email 'old.email@example.com' \\"
    echo "          --target-email 'new.email@example.com' \\"
    echo "          [--source-name 'Old Name'] \\"
    echo "          [--target-name 'New Name']"
    echo ""

    exit 1
}

## Default vars
REPO_URL=""
SRC_EMAIL=""
TGT_EMAIL=""
SRC_NAME=""
TGT_NAME=""
FORCE_PUSH=""

## Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --repo-url)
        REPO_URL="$2"
        shift 2
        ;;
    --source-email)
        SRC_EMAIL="$2"
        shift 2
        ;;
    --target-email)
        TGT_EMAIL="$2"
        shift 2
        ;;
    --source-name)
        SRC_NAME="$2"
        shift 2
        ;;
    --target-name)
        TGT_NAME="$2"
        shift 2
        ;;
    --force)
        FORCE_PUSH=1
        shift
        ;;
    -h | --help)
        usage
        ;;
    *)
        echo "Invalid argument: $1"
        usage
        ;;
    esac
done

if [[ -z "$REPO_URL" || -z "$SRC_EMAIL" || -z "$TGT_EMAIL" ]]; then
    echo "Missing required arguments."
    usage
fi

echo "Repo URL: $REPO_URL"
echo "Replacing source email <$SRC_EMAIL> with target email <$TGT_EMAIL>"

if [[ -n "$SRC_NAME" ]]; then
    echo "Source name: $SRC_NAME"
fi
if [[ -n "$TGT_NAME" ]]; then
    echo "Target name: $TGT_NAME"
fi

## Create temporary directory to clone repo into
TMP_DIR=$(mktemp -d)
echo "Mirror cloning repository into temporary directory: $TMP_DIR"
git clone --mirror "$REPO_URL" "$TMP_DIR/repo"
cd "$TMP_DIR/repo"

echo "Rewriting commit history emails with git-filter-repo..."
## Read history with source username/email, replace with target
read -r -d '' COMMIT_CALLBACK <<EOF || true
if commit.author_email.decode('utf-8') == '$SRC_EMAIL':
    commit.author_email = b'$TGT_EMAIL'
$([[ -n "$TGT_NAME" ]] && echo "    commit.author_name = b'$TGT_NAME'")
if commit.committer_email.decode('utf-8') == '$SRC_EMAIL':
    commit.committer_email = b'$TGT_EMAIL'
$([[ -n "$TGT_NAME" ]] && echo "    commit.committer_name = b'$TGT_NAME'")
EOF

## Rewrite history
git filter-repo --force --commit-callback "$COMMIT_CALLBACK"

## Exit early if no history was rewritten
COMMIT_MAP_FILE=".git/filter-repo/commit-map"
if [[ ! -f "$COMMIT_MAP_FILE" || ! -s "$COMMIT_MAP_FILE" ]]; then
    echo ""
    echo "No commits were rewritten (commit-map is empty). Exiting without pushing."
    echo ""

    exit 0
fi

echo "Removing backup refs..."
##  Remove all refs with old data
git for-each-ref --format='%(refname)' refs/original | xargs -r git update-ref -d
git for-each-ref --format='%(refname)' refs/backup | xargs -r git update-ref -d

echo "Expiring reflogs and pruning unreachable objects..."
## Expire old data locally before pushing
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "Verifying no lingering commits with source email anywhere..."

## Get list of commits with source email
SOURCE_COMMITS=$(git for-each-ref --format='%(refname)' | while read -r ref; do
    git log "$ref" --pretty=format:"%H%x09%ad%x09%an%x09%ae%x09%cN%x09%cE" --date=iso |
        awk -v src_email="$SRC_EMAIL" '
        $4 == src_email || $6 == src_email {
            print FILENAME "\t" $0
        }' FILENAME="$ref"
done)

## If any commits remain with source email, exit
if [[ -n "$SOURCE_COMMITS" ]]; then
    echo ""
    echo "[ERROR] Some commits still contain the source email <$SRC_EMAIL>:"
    echo ""
    echo -e "Ref\tCommit\tDate\tAuthorName\tAuthorEmail\tCommitterName\tCommitterEmail"
    echo "$SOURCE_COMMITS"
    echo ""
    echo "Aborting push."

    exit 2
fi

echo "Removing local refs under refs/merge-requests/ to avoid push errors..."
## Remove all refs under refs/merge-requests/
git for-each-ref --format='%(refname)' refs/merge-requests | xargs -r -n 1 git update-ref -d || true

echo "Adding remote origin after filter-repo cleanup..."
## Re-add origin (git-filter-repo removes it)
git remote add origin "$REPO_URL"

echo "Pushing all branches and tags to origin forcibly..."
## Push rewritten histories back up
if [[ -n "${FORCE_PUSH:-}" ]]; then
    if ! git push origin --force --all; then
        echo ""
        echo "[ERROR] Failed to push rewritten commits to origin."

        exit 1
    fi

    if ! git push origin --force --tags; then
        echo ""
        echo "[ERROR] Failed to push rewritten commits to origin."

        exit 1
    fi

else
    if ! git push origin --all; then
        echo ""
        echo "[ERROR] Failed to push rewritten commits to origin."

        exit 1
    fi

    if ! git push origin --tags; then
        echo ""
        echo "[ERROR] Failed to push rewritten commits to origin."

        exit 1
    fi

fi

echo "Successfully rewritten all commits and pushed to remote."
echo "Temporary repo location: $TMP_DIR/repo"

exit 0
