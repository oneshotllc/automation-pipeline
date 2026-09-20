#!/usr/bin/env bash
# Apply the configured branch protection to every active repository's default branch. Idempotent; run after
# adding a repository. Everything comes from the pipeline configuration; nothing here names a repository.
set -uo pipefail
GH="$HOME/bin/oneshot-pr exec gh"
CFG_REPO=${CONFIG_REPO:-oneshotllc/.github}; CFG_PATH=${CONFIG_PATH:-automation/pipeline.json}
CFG=$($GH api "repos/$CFG_REPO/contents/$CFG_PATH" --jq .content | base64 -d)
cfg(){ printf '%s' "$CFG" | python3 -c "import json,sys;d=json.load(sys.stdin);v=eval('d'+sys.argv[1]);print(json.dumps(v) if isinstance(v,(dict,list)) else (str(v).lower() if isinstance(v,bool) else v))" "$1"; }
CHECKS=$(cfg "['ci']['checks']"); REVIEWS=$(cfg "['branch_protection']['required_reviews']"); DISMISS=$(cfg "['branch_protection']['dismiss_stale_reviews']"); ADMINS=$(cfg "['branch_protection']['enforce_admins']"); CONV=$(cfg "['branch_protection']['require_conversation_resolution']"); FORCE=$(cfg "['branch_protection']['allow_force_pushes']"); DEL=$(cfg "['branch_protection']['allow_deletions']")
for r in $($GH api "installation/repositories?per_page=100" --jq '.repositories[] | select(.archived==false) | .full_name'); do
  def=$($GH api "repos/$r" --jq .default_branch)
  # Require only check contexts this repository produces on pull requests: a workflow triggered on pull_request
  # (not merely reusable via workflow_call) with a job named like the context. Requiring anything else blocks forever.
  produced="[]"
  for f in $($GH api "repos/$r/contents/.github/workflows" --jq '.[].path' 2>/dev/null); do
    body=$($GH api "repos/$r/contents/$f" --jq .content 2>/dev/null | base64 -d 2>/dev/null)
    produced=$(python3 - "$body" "$produced" "$CHECKS" <<'PY'
import json,sys,re
body,have,want=sys.argv[1],json.loads(sys.argv[2]),json.loads(sys.argv[3])
on_pr=bool(re.search(r'^\s*on:\s*$.*?^\S', body, re.M|re.S) and re.search(r'^\s+pull_request(_target)?\s*:', body, re.M)) or bool(re.search(r'^on:\s*\[?[^\n]*pull_request', body, re.M))
jobs={c for c in want if re.search(r'^\s{2}'+re.escape(c)+r':\s*$', body, re.M)}
print(json.dumps(sorted(set(have)|(jobs if on_pr else set()))))
PY
)
  done
  payload=$(python3 -c "import json,sys; ctx=json.loads(sys.argv[1]); print(json.dumps({'required_status_checks': ({'strict': True, 'contexts': ctx} if ctx else None), 'enforce_admins': sys.argv[2]=='true', 'required_pull_request_reviews': {'required_approving_review_count': int(sys.argv[3]), 'dismiss_stale_reviews': sys.argv[4]=='true'}, 'restrictions': None, 'required_conversation_resolution': sys.argv[5]=='true', 'allow_force_pushes': sys.argv[6]=='true', 'allow_deletions': sys.argv[7]=='true'}))" "$produced" "$ADMINS" "$REVIEWS" "$DISMISS" "$CONV" "$FORCE" "$DEL")
  if printf '%s' "$payload" | $GH api -X PUT "repos/$r/branches/$def/protection" --input - >/dev/null 2>&1; then echo "protected $r ($def): reviews=$REVIEWS contexts=$produced"; else echo "FAILED   $r ($def)"; fi
done
