#!/bin/bash

## Generate a secure key/password for use with restic repository.

set -euo pipefail

KEY_LENGTH=2048
OUTPUT_FILE=""

if ! command -v resticprofile; then
    echo "resticprofile is not installed. Please install resticprofile & try again."
    exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -k|--key-length)
      KEY_LENGTH="$2"
      shift 2
      ;;
    -o|--output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$KEY_LENGTH" ]] || [[ "$KEY_LENGTH" -lt 512 ]] || [[ "$KEY_LENGTH" == "" ]]; then
  echo "Key length must be at least 512 bits."
  exit 1
fi

if [[ ! "$OUTPUT_FILE" == "" ]]; then
  if [[ -f "$OUTPUT_FILE" ]]; then
  echo "Restic password file '$OUTPUT_FILE' already exists."
  read -p "Do you want to overwrite it? (y/n) " overwrite_response
  case $overwrite_response in
    [yY])
    ;;
    *)
      echo "Cancelling."
      exit 1
    ;;
  esac
  fi
fi

echo "Generating a secure key/password for use with restic repository."

key=$(resticprofile generate --random-key $KEY_LENGTH)
if [[ $? -ne 0 ]]; then
  echo "Failed generating key/password."
  exit $?
else

  if [[ -z "$key" ]] || [[ "$key" == "" ]]; then
    echo "Failed generating key/password."
    exit 1
  fi

  echo "Key/password generated successfully."
  exit 0
fi
