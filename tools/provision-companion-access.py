#!/usr/bin/env python3
"""Create a revocable pilot account token outside the repository; never print credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import time
from urllib.parse import urlsplit


def secure_write(path: Path, value: str) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(value)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--subject", required=True, help="Opaque account ID, not a name, email or phone number")
    parser.add_argument("--directory", type=Path, required=True, help="Private directory OUTSIDE the repository")
    parser.add_argument("--existing-chat-link-file", type=Path, help="Private file OUTSIDE the repository containing this verified account owner's existing signed Rumi chat URL")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", args.subject):
        parser.error("Subject must be 1–80 letters, numbers, underscores or hyphens.")
    repository = Path(__file__).resolve().parents[1]
    destination = args.directory.expanduser().resolve()
    if destination == repository or repository in destination.parents:
        parser.error("Credential output must be outside this repository.")
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    if destination.stat().st_mode & 0o077:
        parser.error("Output directory must be private (permissions 700).")
    account_file = destination / f"{args.subject}.account-token"
    registry_file = destination / f"{args.subject}.server-registry.json"
    if account_file.exists() or registry_file.exists():
        parser.error("Refusing to overwrite an existing credential file.")
    api_file = destination / f"{args.subject}.existing-api-secrets.json"
    api_config = None
    if args.existing_chat_link_file:
        link_path = args.existing_chat_link_file.expanduser().resolve()
        if link_path == repository or repository in link_path.parents:
            parser.error("The private chat link must be outside this repository.")
        if not link_path.is_file() or link_path.stat().st_size > 4096 or link_path.stat().st_mode & 0o077:
            parser.error("Use a private link file (permissions 600), no larger than 4 KB.")
        link = urlsplit(link_path.read_text().strip())
        match = re.fullmatch(r"/chat/(\d{8,15}\.\d{1,12}\.[a-f0-9]{32})/?", link.path)
        if link.scheme != "https" or not link.hostname or link.username or link.password or link.query or link.fragment or not match:
            parser.error("The file must contain the existing service's HTTPS private chat link.")
        chat_token = match.group(1)
        if int(chat_token.split(".")[1]) <= time.time():
            parser.error("The existing chat link has expired; obtain a fresh one.")
        if api_file.exists():
            parser.error("Refusing to overwrite existing API provisioning.")
        api_config = {"RUMI_API_ORIGIN": f"https://{link.netloc}", "RUMI_API_CHAT_LINKS": json.dumps({args.subject: chat_token})}
    token = secrets.token_urlsafe(48)
    mapping = {hashlib.sha256(token.encode()).hexdigest(): args.subject}
    secure_write(account_file, token + "\n")
    secure_write(registry_file, json.dumps(mapping) + "\n")
    if api_config:
        secure_write(api_file, json.dumps(api_config) + "\n")
    print(f"Created private credential files in {destination}")
    print("Merge the server registry into RUMI_ACCESS_TOKENS using server secret settings.")
    print("Use only the account token in the iPhone Account screen; never paste either file into chat.")
    print("To revoke access, remove its hash from the server registry. Do not reuse a subject for another person.")
    if api_config:
        print("Install the existing API settings through server secret management; merge account mappings, do not replace other accounts.")
        print("Provision only after verifying that the Rumi chat link belongs to this account owner. Links expire after 24 hours; renew privately.")
        print("Shared-memory calls also require the existing ELEVEN_INIT_SECRET as RUMI_API_INIT_SECRET and the same ElevenLabs agent/number.")


if __name__ == "__main__":
    main()
