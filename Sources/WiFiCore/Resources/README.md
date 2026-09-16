# Generated manufacturer registry

Run `python3 scripts/update-vendors.py` from the repository root before running
tests. The app build script performs this setup automatically if the registry
is missing.

`manufacturers.json` is generated from IEEE's public MAC assignment listings
and is intentionally excluded from Git. It contains public address prefixes,
not observed device addresses. See the repository's `NOTICE.md`.
