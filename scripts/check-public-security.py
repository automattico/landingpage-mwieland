#!/usr/bin/env python3

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "public"
REQUIRED_FILES = [
    PUBLIC / "index.html",
    PUBLIC / "legal-notice.html",
    PUBLIC / "site.webmanifest",
    PUBLIC / "css" / "styles.css",
    PUBLIC / "images" / "bg2022.jpg",
    PUBLIC / "images" / "avatar-320.jpg",
    PUBLIC / "images" / "favicon-32x32.png",
]
HTML_FILES = [
    PUBLIC / "index.html",
    PUBLIC / "legal-notice.html",
    PUBLIC / "legal-notice" / "index.html",
]
TEXT_EXTENSIONS = {
    ".css",
    ".env",
    ".html",
    ".js",
    ".json",
    ".md",
    ".svg",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
    ".sh",
    ".py",
}
SECRET_RULES = [
    ("private key", re.compile(r"-----BEGIN (?:OPENSSH|RSA|EC|DSA|PGP) PRIVATE KEY-----")),
    ("aws access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("github token", re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b")),
    ("github fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    ("slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("sftp password assignment", re.compile(r"^\s*SFTP_PASSWORD\s*=\s*(.+?)\s*$", re.MULTILINE)),
]
SECRET_ALLOWLIST = {
    "your-sftp-password",
    '"your-sftp-password"',
    "'your-sftp-password'",
}
DISALLOWED_PUBLIC_NAMES = {
    ".env",
    ".env.local",
    ".env.production",
    ".git",
    ".gitignore",
    ".htpasswd",
    "phpinfo.php",
    "info.php",
}
DISALLOWED_PUBLIC_SUFFIXES = (
    ".bak",
    ".crt",
    ".env",
    ".key",
    ".kdbx",
    ".log",
    ".map",
    ".old",
    ".orig",
    ".pem",
    ".pfx",
    ".p12",
    ".sql",
    ".swp",
    ".tmp",
)
DEV_MARKERS = [
    "localhost",
    "127.0.0.1",
    "0.0.0.0",
    "__vite_ping",
    "@vite/client",
    "webpack://",
]
ATTR_RE = re.compile(r'(?:href|src)="([^"]+)"')
CSS_RE = re.compile(r'url\((?:\"|\')?([^"\')]+)')


def is_text_file(path: pathlib.Path) -> bool:
    return path.suffix.lower() in TEXT_EXTENSIONS


def check_ref(base: pathlib.Path, ref: str, missing: list[str]) -> None:
    if ref.startswith(("http://", "https://", "mailto:", "data:", "#", "tel:")):
        return
    normalized = ref.split("?", 1)[0].split("#", 1)[0]
    if normalized.startswith("/"):
        target = (PUBLIC / normalized.lstrip("/")).resolve()
    else:
        target = (base / normalized).resolve()
    if not target.exists():
        missing.append(f"{base.relative_to(ROOT)} -> {ref}")


def load_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def scan_refs(issues: list[str]) -> None:
    missing: list[str] = []
    for html in HTML_FILES:
        text = load_text(html)
        for ref in ATTR_RE.findall(text):
            check_ref(html.parent, ref, missing)

    css_text = load_text(PUBLIC / "css" / "styles.css")
    for ref in CSS_RE.findall(css_text):
        check_ref((PUBLIC / "css"), ref, missing)

    manifest = json.loads(load_text(PUBLIC / "site.webmanifest"))
    for icon in manifest.get("icons", []):
        src = icon.get("src")
        if src:
            check_ref(PUBLIC, src, missing)

    if missing:
        issues.append("Missing local references:\n" + "\n".join(sorted(missing)))


def scan_required_files(issues: list[str]) -> None:
    missing = [str(path.relative_to(ROOT)) for path in REQUIRED_FILES if not path.exists()]
    if missing:
        issues.append("Missing required deploy files:\n" + "\n".join(missing))


def scan_public_file_names(issues: list[str]) -> None:
    bad_paths: list[str] = []
    for path in PUBLIC.rglob("*"):
        if not path.is_file():
            continue
        lower_name = path.name.lower()
        if lower_name in DISALLOWED_PUBLIC_NAMES or lower_name.endswith(DISALLOWED_PUBLIC_SUFFIXES):
            bad_paths.append(str(path.relative_to(ROOT)))
    if bad_paths:
        issues.append("Disallowed files present in deploy artifact:\n" + "\n".join(sorted(bad_paths)))


def scan_dev_markers(issues: list[str]) -> None:
    hits: list[str] = []
    for path in PUBLIC.rglob("*"):
        if not path.is_file() or not is_text_file(path):
            continue
        text = load_text(path).lower()
        for marker in DEV_MARKERS:
            if marker in text:
                hits.append(f"{path.relative_to(ROOT)} contains {marker}")
    if hits:
        issues.append("Public artifact contains development-only markers:\n" + "\n".join(sorted(hits)))


def scan_secrets(issues: list[str]) -> None:
    hits: list[str] = []
    tracked_paths: set[pathlib.Path] = set()
    git_ls = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    for entry in git_ls.stdout.splitlines():
        path = ROOT / entry
        if path.is_file():
            tracked_paths.add(path)

    for path in PUBLIC.rglob("*"):
        if path.is_file():
            tracked_paths.add(path)

    for path in sorted(tracked_paths):
        if not is_text_file(path):
            continue
        text = load_text(path)
        for label, pattern in SECRET_RULES:
            for match in pattern.finditer(text):
                if label == "sftp password assignment":
                    value = match.group(1).strip()
                    if (
                        value in SECRET_ALLOWLIST
                        or value.startswith("${")
                        or "$" in value
                        or value in {'""', "''"}
                    ):
                        continue
                hits.append(f"{path.relative_to(ROOT)}: possible {label}")
                break
    if hits:
        issues.append("Potential secrets detected:\n" + "\n".join(sorted(hits)))


def main() -> int:
    issues: list[str] = []
    if not PUBLIC.is_dir():
        print(f"Missing public directory: {PUBLIC}", file=sys.stderr)
        return 1

    scan_required_files(issues)
    scan_refs(issues)
    scan_public_file_names(issues)
    scan_dev_markers(issues)
    scan_secrets(issues)

    if issues:
        print("\n\n".join(issues), file=sys.stderr)
        return 1

    print("Public artifact, reference, and secret/config checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
