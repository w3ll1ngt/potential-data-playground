#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <backend-private-ip> [ssh-key-path]" >&2
  exit 1
fi

BACKEND_IP="$1"
SSH_KEY="${2:-${SSH_KEY:-}}"
TF_DIR="${TF_DIR:-$(cd "$(dirname "$0")/../terraform" && pwd)}"
SSH_USER="$(terraform -chdir="$TF_DIR" output -raw ssh_user)"
NAT_IP="$(terraform -chdir="$TF_DIR" output -raw nat_public_ip)"

SSH_ARGS=( -J "$SSH_USER@$NAT_IP" )
if [[ -n "$SSH_KEY" ]]; then
  SSH_ARGS+=( -i "$SSH_KEY" )
fi
SSH_ARGS+=( -o StrictHostKeyChecking=accept-new )

ssh "${SSH_ARGS[@]}" "$SSH_USER@$BACKEND_IP" 'sudo journalctl -u logbroker -f'
