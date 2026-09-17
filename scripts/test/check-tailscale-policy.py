#!/usr/bin/env python3
"""Check the offline guest draft and reviewed endpoint sources. Never calls Tailscale.

This is a narrow repository guard, not a Tailscale policy interpreter. It rejects
every policy shape except the reviewed guest-only draft. Full merged policy and
real share membership require Tailscale's validator and a scoped live test.
"""

import argparse
import configparser
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
POLICY = Path("packaging/host/linux/tailscale/guest-policy.example.json")
INVENTORY = Path("tests/tailscale/endpoint-inventory.json")
REVIEWED_FILES = {
    ".": {"packaging/host/linux/config/plank-host.conf",
          "packaging/host/linux/firewalld/plank.xml",
          "protocol/plank-transport/src/native.rs",
          "protocol/plank-transport/src/native_ffi.rs",
          "protocol/plank-transport/src/lib.rs"},
    "apps/client": {"app/backend/nvhttp.cpp", "app/backend/computermanager.cpp",
                    "app/backend/teraguchi/tailscaleworkstations.cpp",
                    "app/backend/teraguchi/hosttrust.h", "app/backend/teraguchi/studiosetup.h",
                    "app/backend/teraguchi/studiosetup.cpp",
                    "app/backend/teraguchi/supportdiagnostics.h", "app/backend/teraguchi/supportdiagnostics.cpp",
                    "app/gui/computermodel.cpp", "app/settings/plankclientpolicy.h",
                    "app/settings/plankclientpolicy.cpp", "app/streaming/session.cpp"},
    "apps/host/linux": {"src/nvhttp.cpp", "src/nvhttp.h", "src/config.cpp",
                        "src/network.cpp", "src/auth/pam_broker.cpp",
                        "src/session/host_supervisor.cpp"},
    "third_party/kyber-kymux": {"kynet/src/driver/quinn.rs"},
}


class CheckError(ValueError):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise CheckError("Duplicate JSON field")
        result[key] = value
    return result


def read_json(path):
    if path.stat().st_size > 65536:
        raise CheckError("JSON input exceeds the draft size limit")
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def validate_policy(policy, port):
    if type(port) is not int or not 1024 <= port <= 65535:
        raise CheckError("Invalid reviewed base port")
    if not isinstance(policy, dict) or set(policy) != {"acls", "grants", "ssh"}:
        raise CheckError("Expected the standalone guest draft, not a merged policy")
    if policy["acls"] != [] or policy["ssh"] != []:
        raise CheckError("Guest draft must not add ACL or Tailscale SSH access")
    grants = policy["grants"]
    if not isinstance(grants, list) or len(grants) != 1:
        raise CheckError("Guest draft must contain exactly one grant")
    grant = grants[0]
    if not isinstance(grant, dict) or set(grant) != {"src", "dst", "ip"}:
        raise CheckError("Unexpected guest grant fields")
    if grant["src"] != ["autogroup:shared"] or grant["dst"] != ["*"]:
        raise CheckError("Guest draft selectors changed; review sharing semantics")
    capabilities = grant["ip"]
    expected = {f"tcp:{port}", f"udp:{port}"}
    if (not isinstance(capabilities, list) or len(capabilities) != 2 or
            any(not isinstance(value, str) for value in capabilities) or
            set(capabilities) != expected):
        raise CheckError("Guest draft must allow only the reviewed TCP/UDP base port")
    return {("tcp", port), ("udp", port)}


def validate_package_ports(root, port):
    config = configparser.ConfigParser()
    config.read_string((root / "packaging/host/linux/config/plank-host.conf").read_text())
    if config.getint("network", "port") != port:
        raise CheckError("Packaged host base port differs from the guest draft")
    service = ET.parse(root / "packaging/host/linux/firewalld/plank.xml").getroot()
    ports = service.findall("port")
    if (len(ports) != 2 or
            {tuple(sorted(item.attrib.items())) for item in ports} !=
            {tuple(sorted({"protocol": proto, "port": str(port)}.items()))
             for proto in ("tcp", "udp")} or
            any(child.tag not in {"short", "description", "port"} for child in service)):
        raise CheckError("Packaged firewalld service differs from the guest draft")


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True).stdout.strip()


def validate_inventory(inventory):
    if (not isinstance(inventory, dict) or
            set(inventory) != {"version", "base_port", "scope", "sources"} or
            type(inventory["version"]) is not int or inventory["version"] != 1):
        raise CheckError("Invalid endpoint inventory schema")
    sources = inventory["sources"]
    if not isinstance(sources, list) or len(sources) != len(REVIEWED_FILES):
        raise CheckError("Incomplete endpoint inventory")
    seen = set()
    for entry in sources:
        if not isinstance(entry, dict) or set(entry) != {"path", "commit", "sha256"}:
            raise CheckError("Invalid endpoint inventory entry")
        name = entry["path"]
        if not isinstance(name, str) or name not in REVIEWED_FILES or name in seen:
            raise CheckError("Unexpected or duplicate inventory source")
        seen.add(name)
        if (not isinstance(entry["commit"], str) or
                not re.fullmatch(r"[0-9a-f]{40}", entry["commit"]) or
                not isinstance(entry["sha256"], dict) or
                set(entry["sha256"]) != REVIEWED_FILES[name] or
                any(not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)
                    for value in entry["sha256"].values())):
            raise CheckError("Reviewed pins, paths or digests are incomplete")


def verify_sources(root, host_source, inventory):
    # Review full pins as well as selected working files. No network/fetch/init.
    count = 0
    for entry in inventory["sources"]:
        relative = entry["path"]
        repo = root if relative == "." else root / relative
        if relative != ".":
            tree = git(root, "ls-tree", "HEAD", "--", relative).split()
            if len(tree) != 4 or tree[:3] != ["160000", "commit", entry["commit"]]:
                raise CheckError("A reviewed product gitlink changed")
            if relative == "apps/host/linux":
                repo = host_source
            # rev-parse HEAD alone can accidentally resolve an empty submodule's parent.
            if Path(git(repo, "rev-parse", "--show-toplevel")).resolve() != repo.resolve():
                raise CheckError("A reviewed source repository is not populated")
            if git(repo, "rev-parse", "HEAD") != entry["commit"]:
                raise CheckError("A source checkout differs from its reviewed gitlink")
        for name, expected in entry["sha256"].items():
            if not re.fullmatch(r"[0-9a-f]{64}", expected):
                raise CheckError("Invalid source digest in inventory")
            actual = hashlib.sha256((repo / name).read_bytes()).hexdigest()
            if actual != expected:
                raise CheckError("Reviewed endpoint source changed; repeat the inventory")
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host-source", type=Path, default=ROOT / "apps/host/linux",
                        help="Local checkout at the reviewed host gitlink; never fetched")
    args = parser.parse_args()
    try:
        inventory = read_json(ROOT / INVENTORY)
        validate_inventory(inventory)
        port = inventory["base_port"]
        validate_policy(read_json(ROOT / POLICY), port)
        validate_package_ports(ROOT, port)
        count = verify_sources(ROOT, args.host_source, inventory)
    except (OSError, ValueError, KeyError, TypeError, configparser.Error,
            ET.ParseError, subprocess.CalledProcessError) as error:
        # Never echo file contents, private paths or subprocess output.
        message = str(error) if isinstance(error, CheckError) else "Required local input is unavailable or invalid"
        print(f"FAIL: {message}", file=sys.stderr)
        return 1
    print(f"PASS: guest-only TCP/UDP draft; package ports; {count} reviewed source files")
    print("OFFLINE ONLY: merged Tailscale policy, share membership and live enforcement remain untested")
    return 0


if __name__ == "__main__":
    sys.exit(main())
