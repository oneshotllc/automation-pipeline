#!/usr/bin/env bash
# Abstraction check. Exit 0 = PASS. Workflow exports must not contain the configured org, repos, approvers,
# any ticket reference, host name, calendar date, or person: those belong in the configuration file only.
set -uo pipefail
cd "$(dirname "$0")/.."
CFG=$(redis-cli --raw GET cfg:pipeline)
vals=$(printf '%s' "$CFG" | python3 -c '
import json,sys; d=json.load(sys.stdin); out=set()
out.add(d["org"]); out.update(d.get("approvers",[])); out.update(d.get("bots",[]))
for k in ("evidence","monitor","config_source"):
    for v in (d.get(k) or {}).values():
        if isinstance(v,dict): out.update(str(x) for x in v.values() if isinstance(x,str))
        elif isinstance(v,str): out.add(v)
print("\n".join(sorted(x for x in out if len(x)>3)))')
fail=0
for f in workflows/*.json; do
  # strip version metadata (history names are not runtime config)
  # The config loader is the one place a config location is written down; it is the bootstrap and is exempt.
  case "$f" in *config-loader.json) echo "skip $f (bootstrap pointer to the config file)"; continue;; esac
  body=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d=d[0] if isinstance(d,list) else d; [d.pop(k,None) for k in ("versionMetadata","shared","activeVersion")]; print(json.dumps(d))' "$f" | sed -E 's/"X-GitHub-Api-Version", *"value": *"[0-9-]+"/"X-GitHub-Api-Version","value":"api-version"/g; s/X-GitHub-Api-Version","value":"[0-9-]+"/X-GitHub-Api-Version","value":"api-version"/g')
  hits=""
  while IFS= read -r v; do [ -n "$v" ] && printf '%s' "$body" | grep -q -F -- "$v" && hits="$hits [$v]"; done <<< "$vals"
  printf '%s' "$body" | grep -q -E '(^|[^0-9A-Za-z])#[0-9]{2,}([^0-9]|$)' && hits="$hits [ticket-ref]"
  printf '%s' "$body" | grep -q -E '\.ts\.net|studio\.local|[0-9]{4}-[0-9]{2}-[0-9]{2}' && hits="$hits [host-or-date]"
  if [ -n "$hits" ]; then echo "FAIL $f:$hits"; fail=1; else echo "ok   $f"; fi
done
[ $fail -eq 0 ] && echo PASS || echo FAIL; exit $fail
