#!/usr/bin/env bash
#
# refresh-demo-env.sh — bring the demo org estate back to life so ALL of
# validate-pr.yml's gates (matrix validate + coverage + SCA + test-automation)
# can run green in CI.
#
# WHY YOU (a human) MUST RUN THIS, not the agent:
#   1. `sf org login web` needs an interactive browser OAuth callback.
#   2. The agent's environment REDACTS sfdx auth URLs (security policy), so it
#      cannot read the values needed to set the GitHub Actions secrets.
#   This script runs in YOUR shell where neither limitation applies.
#
# PREREQS:
#   - sf CLI v2 + gh CLI installed and on PATH
#   - gh authenticated as a user with push access to the repo below
#     (run: gh auth switch --user alansf   if needed)
#
# Run from the repo root:  bash scripts/refresh-demo-env.sh
set -euo pipefail

REPO="sfdc-alm-demo/salesforce-alm-demo-jh"
SCRATCH_DEF="config/project-scratch-def.json"
DURATION_DAYS=30

echo "==> 1/5  Re-authenticate the Dev Hub (browser will open)"
sf org login web --alias devhub --set-default-dev-hub

echo "==> 2/5  (Re)create the two demo scratch orgs + deploy source"
for alias in prod-demo sandbox-demo; do
  # Delete a stale/expired org of the same alias if present; ignore if gone.
  sf org delete scratch --target-org "$alias" --no-prompt >/dev/null 2>&1 || true
  sf org create scratch \
    --definition-file "$SCRATCH_DEF" \
    --alias "$alias" \
    --duration-days "$DURATION_DAYS" \
    --wait 20
  sf project deploy start --target-org "$alias" --source-dir force-app --wait 30
done

echo "==> 3/5  Extract auth URLs (stays local to this shell)"
DEVHUB_URL=$(sf org display --target-org devhub       --verbose --json | jq -r '.result.sfdxAuthUrl')
PROD_URL=$(sf org display   --target-org prod-demo     --verbose --json | jq -r '.result.sfdxAuthUrl')
SANDBOX_URL=$(sf org display --target-org sandbox-demo --verbose --json | jq -r '.result.sfdxAuthUrl')

for pair in "DEVHUB_URL:$DEVHUB_URL" "PROD_URL:$PROD_URL" "SANDBOX_URL:$SANDBOX_URL"; do
  name="${pair%%:*}"; val="${pair#*:}"
  if [[ -z "$val" || "$val" == "null" || "$val" != force://* ]]; then
    echo "ERROR: $name did not resolve to a valid force:// auth URL. Aborting." >&2
    exit 1
  fi
done

echo "==> 4/5  Set the three GitHub Actions secrets on $REPO"
printf '%s' "$DEVHUB_URL"  | gh secret set SFDX_AUTH_URL_DEVHUB  --repo "$REPO"
printf '%s' "$PROD_URL"    | gh secret set SFDX_AUTH_URL_PROD    --repo "$REPO"
printf '%s' "$SANDBOX_URL" | gh secret set SFDX_AUTH_URL_SANDBOX --repo "$REPO"
unset DEVHUB_URL PROD_URL SANDBOX_URL

echo "==> 5/5  Done. Re-run the verification PR's checks:"
echo "    gh pr checks 5 --repo $REPO --watch"
echo "    # or: gh workflow run validate-pr.yml  (then watch the run)"
