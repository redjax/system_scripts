#!/bin/bash

## Entrypoint function
main() {
  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 1
  fi

  for prog in "$@"; do
    echo "Killing processes matching: $prog"
    pkill -9 -f "$prog"
  done
}

## Help message function
show_help() {
  cat <<EOF
Usage: $(basename "$0") [PROGRAM_NAME]...

Kills all processes matching each PROGRAM_NAME argument.

Examples:
  $(basename "$0") firefox
  $(basename "$0") node python

Options:
  -h, --help    Show this help message and exit.
EOF
}

## Parse help flag
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      show_help
      exit 0
      ;;
  esac
done

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

