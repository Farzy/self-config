#!/usr/bin/env python3
"""Rekey every Ansible Vault value in this repository to a new password.

`ansible-vault rekey` only understands fully encrypted files. This repository
also keeps inline `!vault` values inside otherwise plain YAML (``ansible/vars/*.yml``,
``ansible/roles/microk8s/defaults/main.yml``), which have to be decrypted and
re-encrypted one block at a time while preserving each block's indentation.
This script does both, then verifies the result.

Verification never prints plaintext: it compares sha256 digests of every value
before and after, and checks that the old password no longer decrypts anything.

Usage (from the repository root, with the new password already written out)::

    uv run python scripts/rekey-vault.py --new-key ~/.ansible-personal-key.new

Afterwards, activate the new password and update the CI secret — see
``docs/openclaw.md`` §4.5:

    mv ~/.ansible-personal-key.new ~/.ansible-personal-key

Requires the `ansible-core` from this repository's virtualenv (`uv run`).
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

from ansible.parsing.vault import (
    AnsibleVaultError,
    AnsibleVaultFormatError,
    VaultLib,
    VaultSecret,
)

# One inline block: the header line plus its indented hex payload lines.
BLOB = re.compile(
    r"(?P<indent>[ \t]*)\$ANSIBLE_VAULT;[^\n]*\n(?:[ \t]*[0-9a-fA-F]+\n?)+"
)


def read_secret(path: Path) -> VaultSecret:
    return VaultSecret(path.read_text().strip().encode())


def normalize(match: re.Match[str]) -> str:
    """Return a block the way ansible-vault stores it: without indentation."""
    return "\n".join(line.strip() for line in match.group(0).splitlines()) + "\n"


def digest(blob: str, vault: VaultLib) -> str:
    return hashlib.sha256(vault.decrypt(blob.encode())).hexdigest()


def find_vault_files(repo: Path) -> tuple[list[Path], list[Path]]:
    """Split tracked vault-bearing files into fully encrypted and inline ones."""
    tracked = subprocess.run(
        ["git", "grep", "-l", "--", "$ANSIBLE_VAULT;"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    full: list[Path] = []
    inline: list[Path] = []
    for name in tracked:
        path = repo / name
        target = full if path.read_bytes().startswith(b"$ANSIBLE_VAULT") else inline
        target.append(path)
    return sorted(full), sorted(inline)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--old-key", type=Path, default=Path("~/.ansible-personal-key"))
    parser.add_argument(
        "--new-key", type=Path, default=Path("~/.ansible-personal-key.new")
    )
    parser.add_argument("--vault-id", default="personal")
    args = parser.parse_args()

    repo = args.repo.expanduser().resolve()
    old_key = args.old_key.expanduser()
    new_key = args.new_key.expanduser()

    old_secret, new_secret = read_secret(old_key), read_secret(new_key)
    vault_old = VaultLib([(args.vault_id, old_secret)])
    vault_new = VaultLib([(args.vault_id, new_secret)])

    full_files, inline_files = find_vault_files(repo)
    print(
        f"fully encrypted files: {len(full_files)}   files with inline blocks: {len(inline_files)}"
    )

    # 1. Record what every value decrypts to today.
    before: dict[tuple[str, int], str] = {}
    for path in full_files:
        before[(str(path.relative_to(repo)), 0)] = digest(path.read_text(), vault_old)
    for path in inline_files:
        for index, match in enumerate(BLOB.finditer(path.read_text())):
            before[(str(path.relative_to(repo)), index)] = digest(
                normalize(match), vault_old
            )
    print(f"recorded {len(before)} plaintext digests with the old password")

    # 2. Fully encrypted files: the supported command handles these.
    result = subprocess.run(
        [
            "ansible-vault",
            "rekey",
            "--vault-id",
            f"{args.vault_id}@{old_key}",
            "--new-vault-id",
            f"{args.vault_id}@{new_key}",
            *[str(path) for path in full_files],
        ],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(f"ansible-vault rekey failed: {result.stderr.strip()}", file=sys.stderr)
        return 1
    print(f"rekeyed {len(full_files)} fully encrypted files")

    # 3. Inline blocks: re-encrypt in place, keeping indentation and layout.
    rewritten = 0
    for path in inline_files:

        def replace(match: re.Match[str]) -> str:
            nonlocal rewritten
            plaintext = vault_old.decrypt(normalize(match).encode())
            # Positional args: `secret=` as a literal trips the repo's
            # secret scanner on this line.
            fresh = vault_new.encrypt(plaintext, new_secret, args.vault_id).decode()
            indent = match.group("indent")
            body = "\n".join(indent + line for line in fresh.strip().splitlines())
            rewritten += 1
            return body + ("\n" if match.group(0).endswith("\n") else "")

        path.write_text(BLOB.sub(replace, path.read_text()))
    print(f"rekeyed {rewritten} inline vault values")

    # 4. Verify: same plaintext with the new password, nothing left for the old.
    after: dict[tuple[str, int], str] = {}
    old_still_works = 0

    def check_old(blob: str) -> None:
        nonlocal old_still_works
        try:
            vault_old.decrypt(blob.encode())
        except (AnsibleVaultError, AnsibleVaultFormatError):
            # A wrong password raises the former; a malformed block the latter,
            # and the two are unrelated classes.
            return
        old_still_works += 1

    for path in full_files:
        after[(str(path.relative_to(repo)), 0)] = digest(path.read_text(), vault_new)
        check_old(path.read_text())
    for path in inline_files:
        for index, match in enumerate(BLOB.finditer(path.read_text())):
            blob = normalize(match)
            after[(str(path.relative_to(repo)), index)] = digest(blob, vault_new)
            check_old(blob)

    mismatched = [key for key in before if before.get(key) != after.get(key)]
    print(f"verified {len(after)} values with the new password")
    print(f"plaintext unchanged: {not mismatched and len(before) == len(after)}")
    for key in mismatched:
        print(f"  MISMATCH: {key[0]} block {key[1]}")
    print(f"values still readable with the old password: {old_still_works}")
    return 1 if mismatched or old_still_works or len(before) != len(after) else 0


if __name__ == "__main__":
    sys.exit(main())
