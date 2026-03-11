#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-$(cd "$(dirname "$0")/../terraform" && pwd)}"
SSH_KEY="${SSH_KEY:?Set SSH_KEY to the private key path used for the VMs}"
SSH_USER="$(terraform -chdir="$TF_DIR" output -raw ssh_user)"
NGINX_IP="$(terraform -chdir="$TF_DIR" output -raw nginx_public_ip)"
BACKENDS_JSON="$(terraform -chdir="$TF_DIR" output -json backend_private_ips)"

TMP_CONFIG="$(mktemp)"
trap 'rm -f "$TMP_CONFIG"' EXIT

python3 - <<'PY' "$BACKENDS_JSON" > "$TMP_CONFIG"
import json
import sys

backend_ips = json.loads(sys.argv[1])
print("log_format upstreamlog '$remote_addr - $remote_user [$time_local] '")
print("                      '\"$request\" $status $body_bytes_sent '")
print("                      '\"$http_referer\" \"$http_user_agent\" '")
print("                      'upstream=$upstream_addr request_time=$request_time upstream_time=$upstream_response_time';")
print()
print("upstream logbroker_backend {")
for ip in backend_ips:
    print(f"    server {ip}:80 max_fails=1 fail_timeout=5s;")
print("    keepalive 16;")
print("}")
print()
print("server {")
print("    listen 80 default_server;")
print("    server_name _;")
print()
print("    access_log /var/log/nginx/logbroker_access.log upstreamlog;")
print("    error_log  /var/log/nginx/logbroker_error.log warn;")
print()
print("    location / {")
print("        proxy_http_version 1.1;")
print("        proxy_set_header Host $host;")
print("        proxy_set_header X-Real-IP $remote_addr;")
print("        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;")
print("        proxy_set_header Connection \"\";")
print("        proxy_next_upstream error timeout http_502 http_503 http_504;")
print("        proxy_pass http://logbroker_backend;")
print("    }")
print("}")
PY

scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$TMP_CONFIG" "$SSH_USER@$NGINX_IP:/tmp/logbroker.conf"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SSH_USER@$NGINX_IP" \
  'sudo mv /tmp/logbroker.conf /etc/nginx/conf.d/logbroker.conf && sudo nginx -t && sudo systemctl reload nginx'

echo "nginx reloaded on $NGINX_IP"
