#!/usr/bin/env python3
"""Prepare a private P4 evidence manifest skeleton from repository provenance.

The output links a pilot run to exact candidate hashes, platform metadata, and
explicit incomplete gates. It does not collect live measurements, install
packages, or write into Git. Fill measurements in the private audit store only.
"""

import argparse
import json
import platform
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 1
INCOMPLETE = "incomplete"
NOT_RUN = "not-run"


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def gitlink(root: Path, commit: str, path: str) -> str:
    for line in git(root, "ls-tree", commit, path).splitlines():
        metadata, listed = line.split("\t", 1)
        if listed == path:
            return metadata.split()[2]
    raise ValueError("gitlink not found: " + path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--source-commit", default="HEAD")
    parser.add_argument("--branch", required=True, help="lowercase kebab-case feature branch or main")
    parser.add_argument("--output", type=Path, required=True, help="private manifest path; must not exist")
    parser.add_argument("--display-count", type=int, choices=(1, 2), required=True)
    parser.add_argument("--route-class", choices=("direct", "relay", "unknown"), default="unknown")
    parser.add_argument("--duration-minutes", type=int, default=30)
    parser.add_argument("--operator", default="", help="optional role label; never an account name")
    args = parser.parse_args()

    root = args.source_root.resolve()
    output = args.output.resolve()
    if output.exists():
        parser.error("output already exists")
    branch = args.branch.removeprefix("codex/")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", branch):
        parser.error("invalid branch qualifier")

    commit = git(root, "rev-parse", "--verify", args.source_commit + "^{commit}")
    version = git(root, "show", commit + ":packaging/VERSION")
    client = gitlink(root, commit, "apps/client")
    host = gitlink(root, commit, "apps/host/linux")
    kymux = gitlink(root, commit, "third_party/kyber-kymux")

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "prepared_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "status": INCOMPLETE,
        "run": {
            "branch": branch,
            "route_class": args.route_class,
            "display_count": args.display_count,
            "planned_duration_minutes": args.duration_minutes,
            "operator_role": args.operator or None,
        },
        "candidate": {
            "root_commit": commit,
            "package_version": version,
            "client_gitlink": client,
            "host_gitlink": host,
            "kymux_gitlink": kymux,
            "package_sha256": None,
            "package_path": None,
        },
        "environment": {
            "client_platform": "macos",
            "client_architecture": "arm64",
            "host_platform": "linux",
            "client_os": None,
            "host_os": None,
            "client_hardware_class": None,
            "host_hardware_class": None,
            "recorder": platform.platform(),
        },
        "measurements": {
            "network_rtt_ms_min": None,
            "network_rtt_ms_max": None,
            "network_rtt_ms_p95": None,
            "pre_fec_loss_percent_max": None,
            "post_fec_loss_percent_max": None,
            "incoming_video_mbps_peak": None,
            "quic_packets_lost_total": None,
            "video_receive_drops_total": None,
            "host_processing_latency_ms_p95": None,
            "decode_latency_ms_p95": None,
            "pen_to_picture_ms": None,
            "notes": "Counter sums and toolbar peaks are not pen-to-picture latency.",
        },
        "gates": {
            "Q1_exact_video": NOT_RUN,
            "Q2_input": NOT_RUN,
            "Q3_displays": NOT_RUN,
            "Q4_audio_playback": NOT_RUN,
            "Q5_recovery_ownership": NOT_RUN,
            "P3_access_controls": NOT_RUN,
            "P4_direct_path_load": NOT_RUN,
            "P4_impairment_recovery": NOT_RUN,
            "P4_revocation_seat_denial": NOT_RUN,
            "eight_hour_shift": NOT_RUN if args.duration_minutes < 480 else INCOMPLETE,
        },
        "artifacts": {
            "session_log_paths": [],
            "support_report_paths": [],
            "capture_paths": [],
        },
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    output.chmod(0o600)
    print(output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (subprocess.CalledProcessError, ValueError) as exc:
        print("Manifest preparation failed: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
