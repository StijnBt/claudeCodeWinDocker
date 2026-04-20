#!/bin/bash
# Usage: configure-git.sh [name] [email]
set -e

NAME="$1"
EMAIL="$2"

if ! command -v git >/dev/null 2>&1; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi
if [ -n "$NAME" ]; then
    git config --global user.name "$NAME"
fi
if [ -n "$EMAIL" ]; then
    git config --global user.email "$EMAIL"
fi
