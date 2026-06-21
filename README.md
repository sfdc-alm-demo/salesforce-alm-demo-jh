# salesforce-alm-demo-jh

Live demo of GitHub Actions for Salesforce change management. A 20-minute walkthrough showing how a PR moves from "broken on a developer's laptop" to "deployed to production" with no manual deploys.

This repo is the *outcome* you can build using the [`salesforce-alm-github`](https://github.com/alansf/salesforce-alm-github) Claude Code skill.

## What it demonstrates

| Pattern | Where you see it | Why it matters |
|---|---|---|
| **Matrix Strategy** | `validate-pr.yml` — parallel validation against two scratch orgs | 3× faster than sequential |
| **JWT + Custom Properties governance** | `deploy-prod.yml` — `governance-gate` job reads repo properties via `gh api` before secrets are available | Compliance enforcement at the deploy gate, not a Slack message |
| **Quick Deploy with 4-day fallback** | `deploy-prod.yml` — Job ID artifact passed from PR validation, age-checked before reuse | 45-min deploys → 90 sec |
| **Custom Properties for conditional flows** | `validate-pr.yml` — different test thresholds per `compliance-tier` | Single workflow, many policies |
| **SCA gate** | `validate-pr.yml` — `sca` job runs Salesforce Code Analyzer (PMD + ESLint SAST, Retire.js SCA), blocks on Critical/High | Security + supply-chain evidence, no org access |
| **Test-automation gate** | `validate-pr.yml` — `test-automation` job runs the full suite on an isolated per-PR scratch org, emits JUnit | Standalone tests-passed evidence against the PR's actual code |

## Demo arc (20 min)

1. **Open dirty PR** with an Apex change → Pattern 1 matrix runs → coverage gate fails
2. **Fix the test gap live** → push → Job ID artifact captured
3. **Show governance gate** in `deploy-prod.yml` (`gh api` reading Custom Properties)
4. **Merge to main** → Quick Deploy uses validated Job ID → ~90 sec to "prod"
5. **Wrap**: `CHANGELOG.md` of the underlying skill, the Opus 4.7 review story

## Scratch orgs as stand-ins

Both target "orgs" in this demo are scratch orgs spun up from a Dev Hub:

| Demo role | Scratch alias |
|---|---|
| Production | `prod-demo` |
| Sandbox | `sandbox-demo` |

Every CLI command shown here is **identical** to what you'd run against a real production org or sandbox. Scratch orgs just give us an isolated, throwaway environment safe enough to demo on.

## Local setup (if you're rebuilding this)

```bash
# Auth Dev Hub once
sf org login web --alias devhub --set-default-dev-hub

# Create the two scratch orgs
sf org create scratch -f config/project-scratch-def.json -a prod-demo    -d 30
sf org create scratch -f config/project-scratch-def.json -a sandbox-demo -d 30

# Push source to both
sf project deploy start --target-org prod-demo
sf project deploy start --target-org sandbox-demo
```

GitHub Actions side requires:
- Connected App + JWT keypair in each scratch org (see `docs/setup.md`)
- GitHub Secrets: `SF_CONSUMER_KEY_PROD`, `SF_CONSUMER_KEY_SANDBOX`, `SF_JWT_KEY`, `SF_USERNAME_PROD`, `SF_USERNAME_SANDBOX`
- GitHub Secret for the test-automation gate: `SFDX_AUTH_URL_DEVHUB` (Dev Hub auth URL, used to spin up the ephemeral per-PR scratch org)
- GitHub Custom Properties: `compliance-tier` (SOX | HIPAA | PCI | Standard), `deployment-tier` (dev | qa | staging | production)
- GitHub Environments: `production`, `sandbox`

## Skill behind the demo

This repo's workflows were authored using the [`salesforce-alm-github`](https://github.com/alansf/salesforce-alm-github) Claude Code skill (v2.0.0). The skill itself was hardened via an Opus 4.7 review of the original Sonnet 4.5 draft — see [its CHANGELOG](https://github.com/alansf/salesforce-alm-github/blob/master/CHANGELOG.md).
