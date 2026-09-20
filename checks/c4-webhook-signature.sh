#!/usr/bin/env bash
# C4 webhook check (oneshotllc/.github#31). Exit 0 = PASS.
# 1) bad signature -> 401; 2) good signature on a synthetic issues.opened -> 202 and the item lands in queue:intake.
set -uo pipefail
URL=${1:-${TRIAGE_WEBHOOK_URL:?pass the webhook URL as $1 or set TRIAGE_WEBHOOK_URL}}
SECRET=$(cat "$HOME/.config/oneshot-pr/webhook-secret")
N=$((RANDOM+100000))
BODY=$(printf '{"action":"opened","issue":{"number":%d,"title":"C4 signature check","body":"synthetic","labels":[],"state":"open","user":{"login":"bwoestman"},"html_url":"https://github.com/oneshotllc/template-smoke/issues/%d"},"repository":{"name":"template-smoke","full_name":"oneshotllc/template-smoke","owner":{"login":"oneshotllc"}},"sender":{"login":"bwoestman","type":"User"}}' $N $N)
SIG="sha256=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')"
bad=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' -H 'X-GitHub-Event: issues' -H "X-GitHub-Delivery: c4-bad-$N" -H 'X-Hub-Signature-256: sha256=0000' --data-binary "$BODY")
good=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' -H 'X-GitHub-Event: issues' -H "X-GitHub-Delivery: c4-good-$N" -H "X-Hub-Signature-256: $SIG" --data-binary "$BODY")
sleep 3
inq=$(redis-cli --raw LRANGE queue:intake 0 -1 | grep -c "\"issue_number\":$N,")
# the sorter may already have moved it on; count the stream queue too and the seen key
ins=$(redis-cli --raw LRANGE queue:oneshotllc 0 -1 | grep -c "\"issue_number\":$N,")
echo "bad-signature -> $bad (want 401); good-signature -> $good (want 202); item in intake=$inq stream=$ins"
# clean up the synthetic item so the consumer never comments on a non-existent issue
redis-cli --raw LRANGE queue:intake 0 -1 | grep "\"issue_number\":$N," | while read -r l; do redis-cli LREM queue:intake 0 "$l" >/dev/null; done
redis-cli --raw LRANGE queue:oneshotllc 0 -1 | grep "\"issue_number\":$N," | while read -r l; do redis-cli LREM queue:oneshotllc 0 "$l" >/dev/null; done
[ "$bad" = "401" ] && [ "$good" = "202" ] && [ $((inq+ins)) -ge 1 ] && { echo PASS; exit 0; }
echo FAIL; exit 1
