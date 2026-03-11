#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-$(cd "$(dirname "$0")/../terraform" && pwd)}"
SERVICE_URL="$(terraform -chdir="$TF_DIR" output -raw service_url)"
TABLE_NAME="${1:-kek}"

echo "Service URL: $SERVICE_URL"
echo
echo "== healthcheck =="
curl -fsS "$SERVICE_URL/healthcheck" -o /dev/null -w 'HTTP %{http_code}\n'
echo
echo "== show_create_table =="
curl -fsS "$SERVICE_URL/show_create_table?table_name=$TABLE_NAME"
echo
echo "== write_log =="
curl -fsS "$SERVICE_URL/write_log" \
  -H 'Content-Type: application/json' \
  -d '[{"table_name":"kek","rows":[{"a":1,"b":"hello from demo script"},{"a":2}],"format":"json"},{"table_name":"kek","rows":[[3,"row from list"]],"format":"list"}]'
echo
