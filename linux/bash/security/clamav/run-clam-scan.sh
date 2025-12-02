#!/usr/bin/env bash
set -uo pipefail

if ! command -v clamscan >/dev/null 2>&1; then
    echo "Error: clamscan not found. Install ClamAV first." >&2
    exit 1
fi

function usage() {
    echo ""
    echo "Usage: $0 -t|--target <path> [options]"
    echo ""
    echo "Options:"
    echo "  -t, --target <path>          File or directory to scan (required)"
    echo "  -o, --results-output <file>  Write full clamscan output to this file"
    echo "  -r, --recursive              Scan directories recursively"
    echo "  -i, --infected-only          Only print infected files (--infected --no-summary)"
    echo "  -s, --summary-only           Only print scan summary"
    echo "  -e, --exclude <pattern>      Exclude path or glob (can be repeated)"
    echo "  -v, --verbose                Enable verbose output"
    echo "  -l, --log-file <path>        Path to ClamAV log file (default: /var/log/clamav/system-scan.log)"
    echo "  --max-filesize <size>        Max file size to scan (e.g. 50M)"
    echo "  -h, --help                   Show this help menu"
    echo ""
    echo "Examples:"
    echo " $0 -t /home -r -i"
    echo " $0 -t /var/www -r -o /tmp/clamav.log --max-filesize 100M"
    echo ""
}

## Defaults
TARGET="$(pwd -P)"
OUTPUT="/tmp/$(date +%Y%m%d-%H%M%S).clamav.log"
RECURSIVE=0
INFECTED_ONLY=0
SUMMARY_ONLY=0
EXCLUDES=()
MAX_FILESIZE=""
VERBOSE="false"
LOG_FILE="/var/log/clamav/system-scan.log"

# Simple arg parser
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target)
            TARGET="${2:-}"
            shift 2
            ;;
        -o|--results-output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE=1
            shift
            ;;
        -i|--infected-only)
            INFECTED_ONLY=1
            shift
            ;;
        -s|--summary-only)
            SUMMARY_ONLY=1
            shift
            ;;
        -e|--exclude)
            EXCLUDES+=("$2")
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="${2:-}"
            shift 2
            ;;
        --max-filesize)
            MAX_FILESIZE="${2:-}"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

## Validate inputs
if [[ -z "$TARGET" ]]; then
    echo "Error: --target is required." >&2
    usage
    exit 1
fi

## Build array to hold clam scan options
CLAMSCAN_OPTS=("--stdout")

## Recursive
if [[ "$RECURSIVE" -eq 1 ]]; then
    CLAMSCAN_OPTS+=("-r")
fi

## Infected / summary control
if [[ "$INFECTED_ONLY" -eq 1 ]]; then
    CLAMSCAN_OPTS+=("--infected" "--no-summary")
elif [[ "$SUMMARY_ONLY" -eq 1 ]]; then
    CLAMSCAN_OPTS+=("--summary")
fi

## Excludes
for pat in "${EXCLUDES[@]}"; do
    CLAMSCAN_OPTS+=("--exclude-dir=$pat" "--exclude=$pat")
done

## Max filesize
if [[ -n "$MAX_FILESIZE" ]]; then
    CLAMSCAN_OPTS+=("--max-filesize=$MAX_FILESIZE")
fi

## Verbose logging
if [[ "$VERBOSE" == "true" ]]; then
    CLAMSCAN_OPTS+=("--verbose")
fi

## Log file
if [[ -n "$LOG_FILE" ]]; then
    CLAMSCAN_OPTS+=("--log=$LOG_FILE")
fi

## Always exit with nonzero on virus found, but not on minor errors
#  clamscan default exit codes:
#    0: no virus, 1: virus found, >1: error

echo "Running: clamscan ${CLAMSCAN_OPTS[*]} \"$TARGET\""

if [[ -n "$OUTPUT" ]]; then
    ## tee output to file
    clamscan "${CLAMSCAN_OPTS[@]}" "$TARGET" | tee "$OUTPUT"

    EXIT_CODE=${PIPESTATUS[0]}
else
    clamscan "${CLAMSCAN_OPTS[@]}" "$TARGET"
    EXIT_CODE=$?
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "ClamAV scan completed: no malware found."
elif [[ $EXIT_CODE -eq 1 ]]; then
    echo "ClamAV scan completed: malware FOUND. Check $OUTPUT for details."
else
    echo "ClamAV scan encountered an error (exit code: $EXIT_CODE)." >&2
    echo "Try re-running the script with sudo:"
    echo "  sudo $0 $*"
fi

exit "$EXIT_CODE"
