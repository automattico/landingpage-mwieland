# Production Deploy

Deploy target is the contents of `public/`.

## Production Gate

Before any production deploy, run the local production gate:

```bash
./scripts/prod-gate.sh
```

It blocks deploys when any of these checks fail:

1. Deploy-relevant git state is dirty (`public/`, `scripts/`, `deploy.sh`, `.github/workflows/`).
2. Required production files are missing or local asset references are broken.
3. Potential secrets, credentials, debug/dev markers, or unsafe deploy artifacts are present.
4. Supported dependency audits report `high` or `critical` vulnerabilities.
5. Local smoke tests fail against a temporary preview server for `public/`.

Current safeguard intentionally skipped: a registry-backed dependency vulnerability scan is not applicable right now because this repo has no tracked application dependency lockfile. The gate detects that and reports it explicitly. If a supported lockfile is added later, the audit becomes blocking automatically.

## Local Setup

Create `.env.local` in the repo root:

```bash
SFTP_HOST=example.com
SFTP_PORT=22
SFTP_USER=your-sftp-username
SFTP_REMOTE_DIR=/public_html/landingpage
SFTP_PASSWORD=your-sftp-password
# Or use this instead of SFTP_PASSWORD:
# SFTP_KEY_PATH=/Users/your-user/.ssh/your-host-key
```

Install `lftp` locally:

```bash
brew install lftp
```

Keep credentials only in `.env.local` or your shell environment. Do not put deploy secrets in GitHub for this repo.

## Local Deploy Flow

Run the gate and deploy:

```bash
./scripts/prod-gate.sh
./deploy.sh
```

`./deploy.sh` also runs the production gate by default, so this shorter form is enough:

```bash
./deploy.sh
```

Optional overrides:

```bash
SITE_URL=https://mwieland.com ./deploy.sh
PREVIEW_SITE_URL=https://preview.example.com ./deploy.sh
RUN_POST_DEPLOY_HEALTHCHECK=0 ./deploy.sh
ENV_FILE=/path/to/custom.env ./deploy.sh
```

If `PREVIEW_SITE_URL` is set, deploy will first verify that preview/staging URL before touching production. If you do not have a preview environment, that step is skipped.

## CI

GitHub Actions is now validation-only. The workflow in [.github/workflows/validate-public.yml](/Users/mwieland/dev/landingpage-mwieland/.github/workflows/validate-public.yml#L1) runs `./scripts/prod-gate.sh` on push and pull request, but it does not deploy and does not require secrets.

## Post-Deploy Health Check

After upload, `./deploy.sh` verifies:

1. `/`
2. `/legal-notice.html`
3. `/site.webmanifest`
4. `/robots.txt`
5. `/sitemap.xml`
6. `/images/avatar-320.jpg`
7. `/images/favicon-32x32.png`

The deploy fails hard if any of those checks fail.

## Rollback Guidance

This deploy is a mirror upload with delete enabled. Roll back by redeploying the last known-good commit locally:

```bash
git checkout <known-good-commit>
./scripts/prod-gate.sh
./deploy.sh
```

If you need to keep working on current changes, do the rollback from a temporary branch instead of your main working tree.
