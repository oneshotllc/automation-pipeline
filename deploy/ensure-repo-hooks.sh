#!/usr/bin/env bash
# Ensure every active repo the App is installed on has one webhook to the pipeline ingress, subscribed to the
# configured events. Everything comes from the pipeline configuration file; the only inputs are the config
# location and the public ingress base URL. Idempotent.
#   usage: ensure-repo-hooks.sh <ingress-base-url>      e.g. https://<public-host>/webhook
set -euo pipefail
BASE=${1:?ingress base url, e.g. https://host/webhook}
GH="$HOME/bin/oneshot-pr exec gh"
CFG_REPO=${CONFIG_REPO:-oneshotllc/.github}; CFG_PATH=${CONFIG_PATH:-automation/pipeline.json}
CFG=$($GH api "repos/$CFG_REPO/contents/$CFG_PATH" --jq .content | base64 -d)
PATH_=$(printf '%s' "$CFG" | python3 -c 'import json,sys;print(json.load(sys.stdin)["ingress"]["path"])')
EVENTS=$(printf '%s' "$CFG" | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin)["ingress"]["events"]))')
SECRET_KEY=$(printf '%s' "$CFG" | python3 -c 'import json,sys;print(json.load(sys.stdin)["keys"]["webhook_secret"])')
SECRET=$(redis-cli --raw GET "$SECRET_KEY")
URL="$BASE/$PATH_"
for r in $($GH api "installation/repositories?per_page=100" --jq '.repositories[] | select(.archived==false) | .full_name'); do
  id=$($GH api "repos/$r/hooks" --jq ".[] | select(.config.url==\"$URL\") | .id" 2>/dev/null | head -1 || true)
  body=$(printf '{"active":true,"events":%s,"config":{"url":"%s","content_type":"json","secret":"%s","insecure_ssl":"0"}}' "$EVENTS" "$URL" "$SECRET")
  if [ -n "$id" ]; then printf '%s' "$body" | $GH api -X PATCH "repos/$r/hooks/$id" --input - >/dev/null; echo "updated  $r hook $id"
  else id=$(printf '{"name":"web",%s' "${body#\{}" | $GH api -X POST "repos/$r/hooks" --input - --jq .id); echo "created  $r hook $id"; fi
done
