# Demo Speaker Notes (20 min)

## Pre-flight (do 30 min before the demo)

Run the smoke check below. If anything fails, you have time to recover.

```bash
# 1. Scratch orgs alive?
sf org list | grep -E "prod-demo|sandbox-demo"
# Both should show Status: Active and an expiry date in the future

# 2. Auth URLs still valid?
sf data query --target-org prod-demo --query "SELECT Id FROM User LIMIT 1" --json | jq -r '.status'
sf data query --target-org sandbox-demo --query "SELECT Id FROM User LIMIT 1" --json | jq -r '.status'
# Both should print 0 (success)

# 3. Last workflow run green?
gh run list --repo sfdc-alm-demo/salesforce-alm-demo-jh --limit 1 --json conclusion -q '.[].conclusion'
# Should print "success"

# 4. Reset the demo state — close any open PRs, get back on a clean main
cd ~/Development/salesforce-alm-demo-jh
git checkout main
git pull
gh pr list --repo sfdc-alm-demo/salesforce-alm-demo-jh --state open
# Should be empty
```

If any check fails, see the **Recovery** section at the bottom.

---

## The arc (20 minutes)

### Opening — 2 min

Two browser tabs ready: GitHub repo, and one scratch org's setup tree.

> **Say**: "Most Salesforce teams I talk to are deploying with a person clicking buttons in Workbench or a vendor tool. That works at small scale, but it doesn't compose with the kind of speed Agentforce demands. Today I'll show you a 20-minute walkthrough of a PR's life — broken on a developer's laptop, validated against two orgs in parallel, deployed to production with reused validation results. Total wall-clock time from merge to production: under a minute."

> **Caveat to volunteer**: "These two orgs are scratch orgs — Salesforce-issued throwaway environments. The CLI commands you see, the GitHub Actions, the security patterns are **identical** to what runs against a real production org or sandbox. Scratch orgs just keep me from breaking anything real while I demo."

Show the repo's README on GitHub. Highlight the 4 patterns table.

---

### Act 1: Open a dirty PR — 5 min

Switch to terminal in `~/Development/salesforce-alm-demo-jh`.

```bash
git checkout -b feature/add-rush-discount
```

Open `force-app/main/default/classes/BookingService.cls` in editor. Add this method (paste — don't type live, you'll fat-finger):

```apex
public static Decimal applyLoyaltyDiscount(Decimal basePrice, Integer yearsAsCustomer) {
    if (yearsAsCustomer == null || yearsAsCustomer < 1) {
        return basePrice;
    }
    Decimal discountRate = Math.min(yearsAsCustomer * 0.02, 0.20);
    return basePrice * (1 - discountRate);
}
```

> **Say**: "I added a loyalty discount calculation. I deliberately forgot to write a test. Watch what happens."

```bash
git add . && git commit -m "Add loyalty discount" && git push -u origin feature/add-rush-discount
gh pr create --base main --title "Add loyalty discount" --body "Adds a loyalty discount."
```

Switch to the PR in browser. Refresh. The two **Validate against prod** and **Validate against sandbox** checks should appear within 10 seconds.

> **Say**: "Two things just kicked off. Both are validating the same change — one against my prod-demo org, one against my sandbox-demo. **In parallel.** This is GitHub Actions Matrix Strategy. In your real shop this would be FSC sandbox, Health Cloud sandbox, and Industries sandbox. Three minutes of clock time instead of nine."

Wait ~30 seconds. Both checks fail. Bot leaves two ❌ comments on the PR.

> **Say**: "Two gates fired. First, Salesforce's own platform gate enforces org-wide 75% coverage during validation — that's non-negotiable. On top of that, our workflow adds a per-class coverage floor so individual classes can't hide behind a passing average. I haven't tested my new method, so both gates tripped. **The platform fired before any of my custom logic — that's the right order.** Instant feedback to the developer."

Open the failing run, scroll to "Run validation deploy with tests". Show the rendered error message: `Salesforce validation failed: ... 57%, pelo menos 75%...`

---

### Act 2: Fix the bug live — 3 min

Back in the editor. Open `BookingServiceTest.cls`. Find the commented-out section near the bottom and uncomment / paste:

```apex
@IsTest
static void applyRushFee_adds25Percent() {
    System.assertEquals(125.00, BookingService.applyRushFee(100.00));
}

@IsTest
static void applyLoyaltyDiscount_appliesPerYearWithCap() {
    System.assertEquals(90.00, BookingService.applyLoyaltyDiscount(100.00, 5));
    System.assertEquals(80.00, BookingService.applyLoyaltyDiscount(100.00, 15));
    System.assertEquals(100.00, BookingService.applyLoyaltyDiscount(100.00, 0));
    System.assertEquals(100.00, BookingService.applyLoyaltyDiscount(100.00, null));
}
```

```bash
git add . && git commit -m "Add tests" && git push
```

> **Say**: "Same workflow re-runs automatically. While we wait, let me show you what's *actually* happening in the workflow file."

Open `.github/workflows/validate-pr.yml` in the repo browser. Walk through:
- The `matrix.org_alias: [prod, sandbox]` block (~line 28)
- The `sf org login sfdx-url --sfdx-url-file <(printf '%s' "${{ secrets... }}")` line (~line 50). Pause here:

> **Say**: "Look closely at this line. We're not writing the auth URL to a file. We're piping it through process substitution — a transient file descriptor the kernel destroys the moment the command exits. The naive approach is to echo the secret into a file and `rm` it afterwards, but that secret can still leak through workflow logs, runner caches, and post-job hooks. Process substitution avoids the disk entirely. The secret never lands anywhere it can be recovered."

Refresh the PR. Both checks now ✅. Bot leaves two ✅ comments.

---

### Act 3: Show the governance gate — 3 min

Open `.github/workflows/deploy-prod.yml` in the repo browser.

> **Say**: "Now let me show you what runs *after* this PR merges. The deploy workflow has two jobs. The **first** is a governance gate that runs *before* secrets are accessible."

Walk through `governance-gate` (lines 18–55). Pause on the `gh api` call (line 32):

> **Say**: "Custom Properties on the GitHub repo — like compliance-tier and deployment-tier — are read at workflow runtime via the REST API. **They're not exposed as workflow variables**, which is a thing the Sonnet-authored version of this skill got wrong. If this repo isn't tagged compliance-tier=SOX, the gate fails and the deploy job never starts. Compliance enforcement at the gate, not in a Slack message after-the-fact."

Show the repo's Custom Properties: GitHub → repo → Settings → Custom properties. Point out `compliance-tier: SOX`, `deployment-tier: production`.

Walk through the `deploy` job. Highlight:
- `environment: production` (line 63) — GitHub Environment with reviewer protection
- The `Decide quick vs full deploy` step (line 90): age check against 72-hour buffer
- The `Quick Deploy` step (line 113): `sf project deploy quick --job-id`

> **Say**: "Here's the magic. We don't redeploy the whole project. We tell Salesforce: 'Use the validation result from the PR — the one that passed all the tests two minutes ago.' This collapses an 8-minute full deploy down to under a minute. **Salesforce-side**, those validation results expire in 4 calendar days. We added a 72-hour age check so we never get bitten by an expired validation."

---

### Act 4: Merge and watch the deploy — 5 min

Back in terminal:

```bash
gh pr merge --squash --delete-branch
```

Switch to GitHub Actions tab. The Deploy to Production workflow should fire within 10 seconds.

> **Say**: "Watch the timing. Governance gate runs first — it'll be done in ~3 seconds. Then the deploy job kicks off."

Click into the running workflow. Watch:
1. **Governance gate** — green in 3 sec. Show the log: "✅ Compliance gate passed: SOX + production"
2. **Deploy** — show the steps as they tick green:
   - Authenticate to production (~5 sec)
   - Download validation Job ID artifact (~2 sec)
   - Decide quick vs full deploy → "Within Quick Deploy window" (~1 sec)
   - **Quick Deploy** (~15 sec)

Total wall-clock: ~30 seconds.

> **Say**: "30 seconds. From PR merge to production deployed. With test results that we trust because they came from the validate step on the PR — not re-running the same tests we already ran."

Open the Deploy summary. Point out the metadata table at the bottom:
> Mode: quick · Compliance tier: SOX · Deployment tier: production

---

### Closing — 2 min

> **Say**: "30 seconds from merge to production. Parallel validation across orgs. Compliance enforced at the gate, not after the fact. Secrets that never touch disk. Quick Deploy reusing test results we already trust. That's not seven tools stitched together — it's one opinionated pattern, encoded once, and every team that adopts it gets the same hardened result."

> "Your team can have this running in an afternoon. The reference implementation is public at github.com/sfdc-alm-demo — point it at your repo and you're off."

Q&A.


OPTIONAL! 
Open Claude Code on screen.
 - Run one prompt against the salesforce-alm-github skill: "Add a delta-deployment workflow to this repo using sfdx-git-delta."

---

## Recovery scripts

### "The PR validation is taking forever"

If validate-pr exceeds ~3 min, something's wrong with the scratch org. Skip the live demo of validation and pre-show the previous successful run:

```bash
gh run view 25936694521 --repo sfdc-alm-demo/salesforce-alm-demo-jh --web
```

### "The Auth URL secret expired"

Refresh both:

```bash
PROD=$(sf org display --target-org prod-demo --verbose --json | jq -r '.result.sfdxAuthUrl')
SANDBOX=$(sf org display --target-org sandbox-demo --verbose --json | jq -r '.result.sfdxAuthUrl')
echo -n "$PROD" | gh secret set SFDX_AUTH_URL_PROD --repo sfdc-alm-demo/salesforce-alm-demo-jh
echo -n "$SANDBOX" | gh secret set SFDX_AUTH_URL_SANDBOX --repo sfdc-alm-demo/salesforce-alm-demo-jh
```

### "A scratch org expired"

```bash
sf org create scratch -f config/project-scratch-def.json -a prod-demo --duration-days 30 --wait 10
sf project deploy start --target-org prod-demo --source-dir force-app
# Then re-extract Auth URL as above
```

### "I need to reset to a clean state for a re-demo" (pre-loyalty state)

The demo depends on `applyLoyaltyDiscount` NOT existing yet on main (you add it live in Act 1). Reset to the pre-loyalty state:

```bash
cd ~/Development/salesforce-alm-demo-jh
# Close any open PRs and clean branches
gh pr list --json number -q '.[].number' | xargs -I {} gh pr close {} --delete-branch
git checkout main && git pull
git branch | grep -v 'main' | xargs git branch -D 2>/dev/null

# Reset main to the pre-loyalty baseline and force-push.
# NOTE: use the `demo-baseline` tag, NOT the old 5da4a6e commit — 5da4a6e
# predates the SCA + test-automation gates and would wipe them off main.
git fetch origin --tags
git reset --hard demo-baseline   # pre-loyalty state WITH the new gates
git push --force-with-lease origin main

# Verify: applyLoyaltyDiscount should NOT appear in BookingService...
grep -c 'applyLoyaltyDiscount' force-app/main/default/classes/BookingService.cls && echo "ERROR: loyalty method still present" || echo "✅ pre-loyalty state OK"
# ...and the two new gates SHOULD be present in the workflow
grep -qE '^  sca:' .github/workflows/validate-pr.yml && grep -qE '^  test-automation:' .github/workflows/validate-pr.yml && echo "✅ SCA + test-automation gates present" || echo "ERROR: new gates missing — you reset too far back"
```

**After the demo**: the merge in Act 4 will push the loyalty code back to main, returning the repo to its normal state.

### "Quick Deploy fell back to Full Deploy unexpectedly"

This is a feature, not a bug — but if you want to demonstrate Quick Deploy working, the prereq is a successful validate-pr run with an artifact within the last 7 days. Check:

```bash
gh api repos/sfdc-alm-demo/salesforce-alm-demo-jh/actions/runs/$(gh run list --repo sfdc-alm-demo/salesforce-alm-demo-jh --workflow validate-pr.yml --status success --limit 1 --json databaseId -q '.[].databaseId')/artifacts
```

If empty, run a successful validate-pr first by re-opening a PR.

---

## What to NOT demo (off-screen)

- The Connected App / JWT setup (we use SFDX Auth URL because trial Dev Hubs can't deploy ConnectedApp metadata to scratch orgs — this is a real, documented limitation, but mentioning it pulls focus)
- The full breakdown of all 7 patterns from the skill (point at the README, don't recite)
- The Identity Broker tier of Pattern 2 (Vault/AWS STS) — too much for 20 min

---

## Backup talking points if a demo step fails

| Failure | What to say |
|---|---|
| Network drops | "While we wait, let me walk you through what *should* be happening here..." then narrate from the workflow YAML |
| Workflow doesn't fire | Open the previous successful run on a different PR, narrate that one |
| `sf` CLI version mismatch | "These commands work against `sf` CLI 2.x. Updates released this week may behave differently — let me show you the patterns instead." |
