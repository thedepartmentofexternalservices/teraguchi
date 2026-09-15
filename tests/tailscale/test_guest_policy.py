"""Offline draft regressions, not a replacement for Tailscale's policy compiler."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "guest_policy", ROOT / "scripts/test/check-tailscale-policy.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
PORT = 28989


class GuestPolicyTests(unittest.TestCase):
    def setUp(self):
        self.policy = guard.read_json(ROOT / guard.POLICY)

    def rejects(self, policy):
        with self.assertRaises(guard.CheckError):
            guard.validate_policy(policy, PORT)

    def test_only_expected_transport_endpoints(self):
        allowed = guard.validate_policy(self.policy, PORT)
        for proto in ("tcp", "udp"):
            self.assertEqual([PORT], [port for port in range(1, 65536)
                                     if (proto, port) in allowed])
        for proto in ("icmp", "icmpv6", "sctp", "gre"):
            self.assertNotIn((proto, PORT), allowed)

    def test_native_policy_cases_keep_both_protocols_and_denied_services(self):
        fragment = guard.read_json(ROOT / "packaging/host/linux/tailscale/guest-tests.example.json")
        self.assertEqual({"shared-workstation": "192.0.2.10"}, fragment["hosts"])
        allowed = guard.validate_policy(self.policy, PORT)
        cases = fragment["tests"]
        self.assertEqual(["tcp", "udp"], [case["proto"] for case in cases])
        sentinels = {
            "tcp": {22, 80, 443, 445, 2049, 3389, 5900, 28988, 28990, 47984, 47989, 47990, 48010},
            "udp": {53, 111, 2049, 5353, 28988, 28990, 47998, 47999, 48000, 48010},
        }
        for case in cases:
            self.assertEqual("artist@example.com", case["src"])
            self.assertEqual([f"shared-workstation:{PORT}"], case["accept"])
            self.assertEqual({f"shared-workstation:{port}" for port in sentinels[case["proto"]]},
                             set(case["deny"]))
            for action in ("accept", "deny"):
                for target in case[action]:
                    endpoint = (case["proto"], int(target.rsplit(":", 1)[1]))
                    self.assertEqual(action == "accept", endpoint in allowed)

    def test_wildcard_member_or_named_sources_rejected(self):
        for src in (["*"], ["autogroup:member"], ["artist@example.com"],
                    ["autogroup:shared", "*"]):
            with self.subTest(src=src):
                candidate = copy.deepcopy(self.policy)
                candidate["grants"][0]["src"] = src
                self.rejects(candidate)

    def test_merged_allow_rules_rejected(self):
        for rule in ({"src": ["*"], "dst": ["*"], "ip": ["*"]},
                     {"src": ["autogroup:shared"], "dst": ["*"], "ip": ["tcp:22"]}):
            candidate = copy.deepcopy(self.policy)
            candidate["grants"].append(rule)
            self.rejects(candidate)

    def test_old_acl_cannot_broaden_draft(self):
        self.policy["acls"] = [{"action": "accept", "src": ["*"], "dst": ["*:*"]}]
        self.rejects(self.policy)

    def test_ssh_access_rejected(self):
        self.policy["ssh"] = [{"action": "accept", "src": ["autogroup:shared"],
                              "dst": ["*"], "users": ["autogroup:nonroot"]}]
        self.rejects(self.policy)

    def test_expanded_missing_duplicate_and_legacy_ports_rejected(self):
        for capabilities in (["*"], ["28989"], ["tcp:*", "udp:*"],
                             ["tcp:28989-28990", "udp:28989"], ["tcp:28989"],
                             ["tcp:28989", "tcp:28989"], ["tcp:28989", "udp:48010"],
                             ["tcp:28989", "udp:28989", "icmp:*"], [None, {}]):
            with self.subTest(capabilities=capabilities):
                candidate = copy.deepcopy(self.policy)
                candidate["grants"][0]["ip"] = capabilities
                self.rejects(candidate)

    def test_unknown_capabilities_and_policy_sections_rejected(self):
        for key in ("app", "via", "srcPosture"):
            candidate = copy.deepcopy(self.policy)
            candidate["grants"][0][key] = []
            self.rejects(candidate)
        self.policy["autoApprovers"] = {}
        self.rejects(self.policy)

    def test_changed_destination_requires_review(self):
        self.policy["grants"][0]["dst"] = ["autogroup:internet"]
        self.rejects(self.policy)

    def test_malformed_or_empty_policy_rejected(self):
        for candidate in (None, [], {}, {"grants": []},
                          dict(self.policy, grants=[]), dict(self.policy, grants=[None])):
            self.rejects(candidate)

    def test_duplicate_json_rejected(self):
        with self.assertRaises(guard.CheckError):
            json.loads('{"grants":[],"grants":[{}]}', object_pairs_hook=guard.unique_object)

    def test_port_change_requires_coordinated_policy_update(self):
        for port in (28990, True, 0, 65536, "28989"):
            with self.assertRaises(guard.CheckError):
                guard.validate_policy(self.policy, port)

    def test_package_ports_match(self):
        guard.validate_package_ports(ROOT, PORT)
        with self.assertRaises(guard.CheckError):
            guard.validate_package_ports(ROOT, PORT + 1)

    def test_changed_package_firewall_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = Path("packaging/host/linux/config/plank-host.conf")
            service = Path("packaging/host/linux/firewalld/plank.xml")
            for path in (config, service):
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_bytes((ROOT / path).read_bytes())
            original = (root / service).read_text()
            for extra in ('<port protocol="tcp" port="22"/>', '<protocol value="icmp"/>'):
                (root / service).write_text(original.replace("</service>", extra + "</service>"))
                with self.assertRaises(guard.CheckError):
                    guard.validate_package_ports(root, PORT)

    def test_source_drift_requires_reinventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "endpoint.cpp").write_bytes(b"reviewed")
            inventory = {"sources": [{"path": ".", "sha256": {
                "endpoint.cpp": hashlib.sha256(b"reviewed").hexdigest()}}]}
            self.assertEqual(1, guard.verify_sources(root, root, inventory))
            (root / "endpoint.cpp").write_bytes(b"another listener")
            with self.assertRaises(guard.CheckError):
                guard.verify_sources(root, root, inventory)

    def test_inventory_is_complete(self):
        inventory = guard.read_json(ROOT / guard.INVENTORY)
        guard.validate_inventory(inventory)
        self.assertEqual(PORT, inventory["base_port"])
        self.assertEqual(19, sum(len(entry["sha256"]) for entry in inventory["sources"]))

    def test_inventory_cannot_omit_or_redirect_sources(self):
        inventory = guard.read_json(ROOT / guard.INVENTORY)
        candidates = [dict(inventory, sources=[]), dict(inventory, version=True)]
        missing = copy.deepcopy(inventory)
        missing["sources"][0]["sha256"].pop("protocol/plank-transport/src/native.rs")
        candidates.append(missing)
        redirected = copy.deepcopy(inventory)
        redirected["sources"][0]["path"] = "../another-checkout"
        candidates.append(redirected)
        duplicate = copy.deepcopy(inventory)
        duplicate["sources"][1] = duplicate["sources"][0]
        candidates.append(duplicate)
        for candidate in candidates:
            with self.assertRaises(guard.CheckError):
                guard.validate_inventory(candidate)

    def test_different_gitlink_and_unpopulated_host_rejected(self):
        commit = "a" * 40
        inventory = {"sources": [{"path": "apps/host/linux", "commit": commit, "sha256": {}}]}
        with patch.object(guard, "git", return_value=f"160000 commit {'b' * 40}\tapps/host/linux"):
            with self.assertRaises(guard.CheckError):
                guard.verify_sources(ROOT, ROOT / "apps/host/linux", inventory)
        with patch.object(guard, "git", side_effect=[
                f"160000 commit {commit}\tapps/host/linux", str(ROOT)]):
            with self.assertRaises(guard.CheckError):
                guard.verify_sources(ROOT, ROOT / "apps/host/linux", inventory)


if __name__ == "__main__":
    unittest.main()
