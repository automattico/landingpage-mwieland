# SFTP Deploy

Deploy target is the **contents of `public/`**.

## One-Time Setup

1. Create `.env.local` in the repo root.
2. Fill in these values in `.env.local`:
   - `SFTP_HOST`
   - `SFTP_PORT`
   - `SFTP_USER`
   - `SFTP_REMOTE_DIR`
   - either `SFTP_PASSWORD` or `SFTP_KEY_PATH`
3. Install `lftp`.
   - macOS with Homebrew: `brew install lftp`

`.env.local` is ignored by Git. Keep real credentials there, not in tracked files.
Prefer `SFTP_KEY_PATH` over `SFTP_PASSWORD` if your host supports SSH keys.

Example `.env.local`:

```bash
SFTP_HOST=example.com
SFTP_PORT=22
SFTP_USER=your-sftp-username
SFTP_REMOTE_DIR=/public_html/landingpage
SFTP_PASSWORD=your-sftp-password
# SFTP_KEY_PATH=/Users/your-user/.ssh/your-host-key
```

The remote directory from your FileZilla screenshot is:

```bash
SFTP_REMOTE_DIR=/public_html/landingpage
```

## Deploy

Run:

```bash
./deploy.sh
```

The script:

1. Loads `.env.local` automatically if present.
2. Verifies the required SFTP variables exist.
3. Connects over SFTP only.
4. Uploads the contents of `public/` to the configured remote directory.
5. Deletes remote files that no longer exist locally.

The repository stays safe because:

1. `.env.local` is ignored by Git.
2. No credentials are written into tracked files.
3. Transport is SFTP, not plain FTP.

If you use an SSH key, keep the key outside the repository, for example in `~/.ssh/`.

## First-Time Local Setup

Create this file:

- [`.env.local`](/Users/mwieland/dev/landingpage-mwieland/.env.local)

Place it in the repo root, next to:

- [`deploy.sh`](/Users/mwieland/dev/landingpage-mwieland/deploy.sh)

Then paste your real SFTP values there.

Password-based example:

```bash
SFTP_HOST=example.com
SFTP_PORT=22
SFTP_USER=your-sftp-username
SFTP_REMOTE_DIR=/public_html/landingpage
SFTP_PASSWORD=your-sftp-password
```

SSH-key example:

```bash
SFTP_HOST=example.com
SFTP_PORT=22
SFTP_USER=your-sftp-username
SFTP_REMOTE_DIR=/public_html/landingpage
SFTP_KEY_PATH=/Users/your-user/.ssh/your-host-key
```

## Manual Fallback

If you need to upload manually, connect with SFTP and upload everything inside `public/` to the same remote directory.

Upload these paths:

- `public/index.html`
- `public/legal-notice.html`
- `public/legal-notice/`
- `public/site.webmanifest`
- `public/robots.txt`
- `public/sitemap.xml`
- `public/favicon.ico`
- `public/css/`
- `public/images/`

Do not upload:

- `archive/`
- `work/`
- `.github/`
- project docs (`DEPLOY.md`, `README*`, etc.)

## Post-Deploy Verification

Open and hard-refresh these URLs:

1. `https://mwieland.com/`
2. `https://mwieland.com/legal-notice.html`
3. `https://mwieland.com/site.webmanifest`
4. `https://mwieland.com/images/avatar-320.jpg`
5. `https://mwieland.com/images/favicon-32x32.png`
6. `https://mwieland.com/robots.txt`
7. `https://mwieland.com/sitemap.xml`
8. `https://mwieland.com/legal-notice/`

Check:

1. Hero page renders correctly and language switching works.
2. Social icons open the expected links.
3. Avatar loads and is sharp.
4. Favicon appears in the browser tab.
5. Legal page link works from the homepage.

You can also point it at a different env file:

```bash
ENV_FILE=/path/to/custom.env ./deploy.sh
```
