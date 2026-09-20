#!/usr/bin/env bash
# Webhook signature check. Exit 0 = PASS.
# 1) bad signature -> 401; 2) good signature on a synthetic issues.opened -> 202 and the item lands in queue:intake.
set -uo pipefail
URL=${1:-${TRIAGE_WEBHOOK_URL:?pass the webhook URL as $1 or set TRIAGE_WEBHOOK_URL}}
CFG=$(redis-cli --raw GET cfg:pipeline)
SECRET=$(redis-cli --raw GET "$(printf "%s" "$CFG" | python3 -c "import json,sys;print(json.load(sys.stdin)['keys']['webhook_secret'])")")
SMOKE=${SMOKE_REPO:?set SMOKE_REPO=<owner>/<repo>}
APPROVER=$(printf "%s" "$CFG" | python3 -c "import json,sys;print(json.load(sys.stdin)['approvers'][0])")
STREAMQ=$(printf "%s" "$CFG" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['queues']['stream_prefix']+d['streams']['default'])")
SEEN_PREFIX=$(printf "%s" "$CFG" | python3 -c "import json,sys;print(json.load(sys.stdin)['keys']['seen_prefix'])")
INTAKE=$(printf "%s" "$CFG" | python3 -c "import json,sys;print(json.load(sys.stdin)['queues']['intake'])")
N=$((RANDOM+100000))
BODY=$(printf '{"action":"opened","issue":{"number":%d,"title":"C4 signature check","body":"synthetic","labels":[],"state":"open","user":{"login":"%s"},"html_url":"https://github.com/%s/issues/%d"},"repository":{"name":"%s","full_name":"%s","owner":{"login":"%s"}},"sender":{"login":"%s","type":"User"}}' $N "$APPROVER" "$SMOKE" $N "${SMOKE##*/}" "$SMOKE" "${SMOKE%%/*}" "$APPROVER")
# Pre-claim the synthetic key so the sorter drops it: the consumer must never try to comment on an issue that does not exist.
redis-cli SET "${SEEN_PREFIX}${SMOKE}#$N" c4-check EX 3600 >/dev/null
SIG="sha256=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')"
bad=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' -H 'X-GitHub-Event: issues' -H "X-GitHub-Delivery: c4-bad-$N" -H 'X-Hub-Signature-256: sha256=0000' --data-binary "$BODY")
good=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' -H 'X-GitHub-Event: issues' -H "X-GitHub-Delivery: c4-good-$N" -H "X-Hub-Signature-256: $SIG" --data-binary "$BODY")
sleep 3
inq=$(redis-cli --raw LRANGE "$INTAKE" 0 -1 | grep -c "\"issue_number\":$N,")
# the sorter may already have moved it on; count the stream queue too and the seen key
ins=$(redis-cli --raw LRANGE "$STREAMQ" 0 -1 | grep -c "\"issue_number\":$N,")
echo "bad-signature -> $bad (want 401); good-signature -> $good (want 202); item in intake=$inq stream=$ins"
# clean up the synthetic item so the consumer never comments on a non-existent issue
redis-cli --raw LRANGE "$INTAKE" 0 -1 | grep "\"issue_number\":$N," | while read -r l; do redis-cli LREM "$INTAKE" 0 "$l" >/dev/null; done
redis-cli --raw LRANGE "$STREAMQ" 0 -1 | grep "\"issue_number\":$N," | while read -r l; do redis-cli LREM "$STREAMQ" 0 "$l" >/dev/null; done
redis-cli DEL "${SEEN_PREFIX}${SMOKE}#$N" >/dev/null
[ "$bad" = "401" ] && [ "$good" = "202" ] && [ $((inq+ins)) -ge 1 ] && { echo PASS; exit 0; }
echo FAIL; exit 1
