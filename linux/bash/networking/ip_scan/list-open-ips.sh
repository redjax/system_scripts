#!/bin/bash

set -e

RANGE="192.168.1.1-100"

if ! command -v nmap >/dev/null 2>&1; then
  echo "nmap is not installed."
  exit 1
fi

function print_help() {
  echo "Usage: ./list-open-ips.sh [--range 0.0.0.1-100] [--output /path/to/file]"
  echo ""
  echo "Options:"
  echo "  -r, --range   IP range to scan (e.g. 192.168.1.1-100)"
  echo "  -o, --output  File path to write results (directories will be created if missing)"
  echo "  -h, --help    Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./list-open-ips.sh --range 192.168.1.1-100"
  echo "  ./list-open-ips.sh --range 192.168.1.1-50 --output /tmp/results/ips.txt"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--range)
      if [[ -z $2 ]] || [[ "$2" == "" ]]; then
        echo "[ERROR] --range provided, but no IP range given."
	
	print_help
	exit 1
      fi
      ;;
    -o|--output)
      if [[ -z $2 ]] || [[ "$2" == "" ]]; then
        echo "[ERROR] --output provided, but no file path given."

        print_help
        exit 1
      fi

      OUTPUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid arg: $1"

      print_help
      exit 1
      ;;
  esac
done

if [[ -z $RANGE ]] || [[ "$RANGE" == "" ]]; then
  echo "[ERROR] --range must not be empty/null. Pass a range with (example) --range 192.168.1.1-100"

  print_help
  exit 1
fi

echo "Scanning range: $RANGE ..."
RESULTS=$(sudo nmap -v -sn -n "$RANGE" -oG - | awk '/Status: Down/ {print $2}')
echo ""

if [[ $? -ne 0 ]]; then
  echo "Failed to scan range: $RANGE"
  exit $?
fi

echo "$RESULTS"

echo ""
echo "Scanned range: $RANGE"

if [[ -n $OUTPUT_FILE ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"

  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed saving results to file '$OUTPUT_FILE'"
    exit $?
  fi

  echo "$RESULTS" > "$OUTPUT_FILE"
  echo "Results written to $OUTPUT_FILE"
fi
