# Architecture

## Purpose

This repository hosts the static source for `mwieland.com`.

The deployed artifact is the contents of `public/` only. The site is a lightweight static landing page with legal/privacy content and no current server-side application code.

## Repository Layout

- `public/` deployable web root
- `private/` non-deployable local/runtime files only
- `scripts/` validation, deploy, and smoke-test tooling
- `docs/` architecture and operational documentation

## Deployment Model

Local production deploys run through `./deploy.sh`.

Expected flow:

1. `./scripts/prod-gate.sh`
2. `./scripts/predeploy-guard.sh`
3. mirror-upload `public/` to the configured SFTP target
4. post-deploy remote health checks

CI is validation-only and must not deploy.

## Validation Model

- `scripts/prod-gate.sh` checks local deploy readiness and required tooling
- `scripts/predeploy-guard.sh` validates deploy-relevant git state, public artifact safety, dependency audit status, and local smoke tests
- `scripts/smoke-test.sh` serves `public/` locally and checks core pages/assets
- `scripts/check-remote-health.sh` validates the live site after deploy

## Security Boundaries

- Secrets belong only in `.env.local`
- `.env.example` contains placeholders only
- `private/` is never deployed
- Any future server-side code must live only under `public/api/`
