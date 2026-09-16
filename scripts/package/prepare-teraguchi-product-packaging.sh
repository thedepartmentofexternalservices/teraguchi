#!/usr/bin/env bash
# Offline packaging checklist helper. Does not sign, notarize, or install.
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
profile=${1:?usage: prepare-teraguchi-product-packaging.sh PRIVATE_PRODUCT_IDENTITY.json}
[[ "$profile" == /* ]] || exit 2
[[ -f "$profile" ]] || exit 2
python3 - "$source_root" "$profile" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]) / 'scripts/package'))
import product_identity

profile_path = sys.argv[2]

profile = product_identity.load(profile_path)
block = product_identity.manifest_block(profile)
print("Product identity profile accepted for offline packaging prep.")
print("  display_name:", block["display_name"])
print("  bundle_id:", block["bundle_id"])
print("  minimum_os:", block["minimum_os"])
print("Next steps:")
print("  1. Build the Mac client DMG with the selected deployment target.")
print("  2. Collect with scripts/package/collect-package.py --product-identity", profile_path)
print("  3. Sign with scripts/package/sign-client-release.py using the same profile.")
print("  4. Verify with scripts/package/verify-client-release.py before any install test.")
PY
echo "Reference: docs/development/teraguchi-client-release.md"
echo "Reference: packaging/client/macos/product-identity.example.json"
echo "Source root: $source_root"
