#!/bin/bash

if ! command -v docker &> /dev/null
then
    echo "docker could not be found"
    exit
fi

CONFIG_FILE="config.yml"
CONTAINER_NAME="branch-cleanup"
CONTAINER_IMG="branch-cleanup"

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-c|--config-file <config_file>] [-n|--name <container_name>] [-h|--help]"
            exit
            ;;
        *)
            echo "Unknown option $1"
            exit
            ;;
    esac
done

CONFIG_FILE=$(realpath "$CONFIG_FILE")

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file path '$CONFIG_FILE' is not a file"
    exit 1
fi

echo "Running container with config file $CONFIG_FILE and container name $CONTAINER_NAME"
docker run \
    --rm \
    --name $CONTAINER_NAME \
    -v $CONFIG_FILE:/app/config.yml \
    $CONTAINER_IMG --config-file config.yml

if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed running container"
    exit 1
else
    echo "$CONTAINER_NAME started successfully."
fi
