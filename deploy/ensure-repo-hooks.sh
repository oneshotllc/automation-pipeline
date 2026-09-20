#!/usr/bin/env bash
# Ensure every repo the App is installed on has ONE webhook to the NodeMation ingress, subscribed to the
# events the pipeline consumes. Idempotent. The App itself is subscribed to these events but GitHub is not
# delivering them through the App hook (only check_suite/ping arrive), so repo hooks are the reliable path.
set -euo pipefail
URL=https://macstudio.tailcb79bc.ts.net:10000/webhook/github-issue-triage
SECRET=$(cat "$HOME/.config/oneshot-pr/webhook-secret")
GH="$HOME/bin/oneshot-pr exec gh"
EVENTS='["issues","issue_comment","pull_request","pull_request_review"]'
for r in $($GH api "installation/repositories?per_page=100" --jq '.repositories[] | select(.archived==false) | .full_name'); do
  id=$($GH api "repos/$r/hooks" --jq ".[] | select(.config.url==\"$URL\") | .id" 2>/dev/null | head -1 || true)
  if [ -n "$id" ]; then
    $GH api -X PATCH "repos/$r/hooks/$id" --input - >/dev/null <<JSON
{"active":true,"events":$EVENTS,"config":{"url":"$URL","content_type":"json","secret":"$SECRET","insecure_ssl":"0"}}
JSON
    echo "updated  $r hook $id"
  else
    id=$($GH api -X POST "repos/$r/hooks" --input - --jq .id <<JSON
{"name":"web","active":true,"events":$EVENTS,"config":{"url":"$URL","content_type":"json","secret":"$SECRET","insecure_ssl":"0"}}
JSON
)
    echo "created  $r hook $id"
  fi
done
