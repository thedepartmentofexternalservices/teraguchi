# Native Mac Quit regression

The native application Quit event reached Qt while SDL owned the streaming loop,
leaving the session window open. The Mac-only client event filter also queues
SDL Quit; normal Qt shutdown and deferred session cleanup remain in place.
Ordinary SDL Disconnect still returns to the host list. Client source changes
are extracted unchanged from `2f0e0dbf`; the product keeps its existing macOS 27
baseline and decoder policy. PLANK and Alan Latteri retain attribution.

## Reproduce and verify

Before the fix, choose Quit plank-client from the Mac application menu during a
stream: the session remains open. With the installed fix, the operator confirmed
disconnect and logs/process inspection verified application exit. The Host and
remote desktop survived. This closes that reported case only.

With the pinned Qt and SDL dependency paths from the build runbook exported:

```bash
bash scripts/test/check-macos-quit-bridge.sh "$PLANK_WORK_ROOT/quit-regression"
```

The runner compiles the production bridge and a negative control without it.
The negative control must exit 12 for the missing event handoff. Eight scenarios
pass: idle, active loop, ordinary disconnect, unrelated event, queued Qt Quit,
duplicate Quit, Quit after SDL shutdown, and 25 disconnect/reinitialize cycles.
These are Qt/SDL event-lifecycle tests with bounded failure exits. They do not
simulate authentication, network transport, input release, or renderer teardown.
The CI Mac client job runs them after its normal build. The CI fixture explicitly
isolates its synthetic expected source SHA from the workflow environment.

Local headless tests used `MACOSX_DEPLOYMENT_TARGET=26.0` to match the prepared
Qt/SDL libraries. That test setting does not alter this branch's product target.
Live Quit during connection setup, after network loss, and repeated artist
sessions still need acceptance testing. Retain the original picture-freeze issue
separately. Rolling back the installed fix means restoring the retained earlier
client app; this patch makes no Host or desktop configuration change.

## Tested configuration

Test environment: Mac Studio M2 Ultra, 64 GB, macOS 26.5.2 (25F84), SDK 26.5,
Qt 6.10.2, and the pinned private FFmpeg 9.0.1 dependency tree. Earlier live
checks used Rocky Linux 9.7, Autodesk Flame 2027.1 (application package
2027.1.0-249), RTX PRO 6000 Blackwell Max-Q, NVIDIA 580.126.18, and upstream
PLANK Host v1.0.103. The installed development app remains the combined root
`22bcfec9531ab1243c615a441713d450366c9a11` / client
`2f0e0dbf9c10bb6f382150f6ec6ee3d9b657ac8d` build. No new app or Host package was
installed during this split. Live evidence from that app must not be relabeled
as a standalone build of this branch. Hostnames, raw logs, and fixtures stay private.
