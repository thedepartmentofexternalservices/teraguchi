#!/usr/bin/env bash
# Offline packaging checklist helper. Does not sign, notarize, or install.
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
profile=${1:?usage: prepare-teraguchi-product-packaging.sh PRIVATE_PRODUCT_IDENTITY.json}
[[ "$profile" == /* ]] || exit 2
[[ -f "$profile" ]] || exit 2
python3 - <<'PY' "$profile"
import json
import sys
from pathlib import Path

required = {
    "schema_version", "product", "platform", "architecture", "bundle_id",
    "team_id", "minimum_os", "display_name", "channel",
}
profile = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
missing = required - set(profile)
if missing:
    raise SystemExit("missing fields: " + ", ".join(sorted(missing)))
if profile.get("status") == "example-only":
    raise SystemExit("replace example-only product identity before packaging")
if "example" in profile["bundle_id"]:
    raise SystemExit("bundle_id still contains example placeholder")
print("Product identity profile accepted for offline packaging prep.")
print("Next steps:")
print("  1. Build the Mac client DMG with the selected deployment target.")
print("  2. Collect the exact package with scripts/package/collect-package.py.")
print("  3. Sign with scripts/package/sign-client-release.py using this profile.")
print("  4. Verify with scripts/package/verify-client-release.py before any install test.")
PY
echo "Reference: docs/development/teraguchi-client-release.md"
echo "Reference: packaging/client/macos/product-identity.example.json"
echo "Source root: $source_root"
