#!/bin/sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # Get the directory of the script

nix build
docker load < result

# Run docker-compose
cd "$SCRIPT_DIR" && docker-compose up