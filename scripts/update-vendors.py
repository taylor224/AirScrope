#!/usr/bin/env python3
"""Refresh the bundled IEEE public MAC assignment registry. No device data is sent."""
import argparse
import csv
import datetime
import io
import json
from pathlib import Path
import subprocess

SOURCES = {
    "oui": "https://standards-oui.ieee.org/oui/oui.csv",
    "mam": "https://standards-oui.ieee.org/oui28/mam.csv",
    "mas": "https://standards-oui.ieee.org/oui36/oui36.csv",
    "iab": "https://standards-oui.ieee.org/iab/iab.csv",
}
parser = argparse.ArgumentParser()
parser.add_argument("--from-dir", type=Path, help="Use previously downloaded ieee-{oui,mam,mas,iab}.csv files")
args = parser.parse_args()
entries = {}
for key, url in SOURCES.items():
    if args.from_dir:
        raw = (args.from_dir / f"ieee-{key}.csv").read_bytes()
    else:
        # Use macOS's curl and system certificate store. IEEE may reject the
        # default Python urllib client even for these public download URLs.
        raw = subprocess.run([
            "curl", "--fail", "--location", "--silent", "--show-error",
            "--retry", "3", "--connect-timeout", "15", "--max-time", "120", url,
        ], check=True, stdout=subprocess.PIPE).stdout
    count = 0
    for row in csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))):
        prefix = row["Assignment"].strip().upper()
        name = row["Organization Name"].strip()
        if len(prefix) not in (6, 7, 9) or not all(c in "0123456789ABCDEF" for c in prefix):
            raise ValueError(f"Invalid assignment in {key}")
        if name:
            entries[prefix] = {"organization": name, "registry": row["Registry"]}
            count += 1
    if count <= 1000:
        raise ValueError(f"Incomplete registry: {key}")
    print(f"{key}: {count} assignments", flush=True)
payload = {"updatedAt": datetime.date.today().isoformat(), "sources": list(SOURCES.values()), "entries": entries}
output = Path(__file__).resolve().parent.parent / "Sources/WiFiCore/Resources/manufacturers.json"
output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_suffix(".json.tmp")
temporary.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
temporary.replace(output)
print(f"Wrote {len(entries)} assignments")
