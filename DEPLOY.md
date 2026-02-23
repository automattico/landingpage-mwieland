# FTP Deploy

Deploy target is the **contents of `public/`**.

## Upload

1. Connect to FTP.
2. Open local folder: `public/`
3. Upload everything inside `public/` to the FTP web root (document root).
   - Upload these paths:
     - `public/index.html`
     - `public/legal-notice.html`
     - `public/legal-notice/`
     - `public/site.webmanifest`
     - `public/robots.txt`
     - `public/sitemap.xml`
     - `public/favicon.ico`
     - `public/css/`
     - `public/images/`
4. Confirm overwrites for changed files.
5. Remove remote files that were deleted locally (if any).

## Do Not Upload

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
2. Social icons (including GitHub) open expected links.
3. Avatar loads and is sharp.
4. Favicon appears in browser tab.
5. Legal page link works from homepage.
