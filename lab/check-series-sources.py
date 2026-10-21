#!/usr/bin/env python3
"""Inventory the pinned terminal release of each PHP 5/7 series; no code is run."""

import hashlib
import sys
import tarfile
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


repo_root = Path(__file__).resolve().parent.parent
source_dir = Path(sys.argv[1]) if len(sys.argv) == 2 else Path("/private/tmp/php-backport-sources")
if len(sys.argv) > 2:
    raise SystemExit("usage: check-series-sources.py [source-directory]")

rows = []
for line in (repo_root / "lab/source-hashes.tsv").read_text().splitlines():
    version, expected = line.split("\t")
    archive = source_dir / f"php-{version}.tar.gz"
    if sha256(archive) != expected:
        raise SystemExit(f"source hash mismatch: {version}")
    with tarfile.open(archive, "r:gz") as source:
        session = source.extractfile(f"php-{version}/ext/session/session.c")
        if session is None:
            raise SystemExit(f"missing session source: {version}")
        progress = b"upload_progress" in session.read()
    rows.append((version, "present" if progress else "absent"))

for version, progress in rows:
    print(f"{version}\tarchive_sha256_ok\tupload_progress_symbol_{progress}")
print("Source inventory only; neither CVE remediation nor runtime behavior is verified.")
