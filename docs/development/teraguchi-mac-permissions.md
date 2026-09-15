# Mac permission onboarding

The `--workstations` development picker now checks Accessibility and Input
Monitoring for the running client. A status panel explains what is missing;
Review permissions opens a dialog with separate statuses, explicit System
Settings actions, a manual navigation route, and Check again. Closing the dialog
preserves the workstation and selected display count. Granting access never
starts a connection automatically.

## Native checks and cancellation

`MacInputAccess::query()` reads `AXIsProcessTrusted()` and
`CGPreflightListenEventAccess()`. The real reserved-key event tap uses this same
check. These reads do not request access, install a tap, record input, or open
System Settings. Only an explicit click opens one of two fixed Settings URLs.
Opening Settings never changes the reported permission state.

The UI refreshes on startup, return to the window, explicit retry and every two
seconds while the window is active. A denied check cancels pending login or
requests cleanup of a retained session. Late authentication results cannot
complete that cancelled attempt. Selection survives cancellation.

The native boundary independently checks current permissions before PAM,
Session creation, initialization and assigned-endpoint validation, including
reconnect. The assigned Session also checks every two seconds in its SDL loop,
where Qt timers cannot provide this guarantee. A denied check exits through the
existing held-input/session cleanup path. A cached UI status cannot authorize
capture. Real OS revocation timing and active-session cleanup remain live gates.

## App identity and repair

The dialog names the running bundle using `CFBundleDisplayName`. The development
build still uses PLANK's existing product bundle identity; its separate
`Teraguchi Development` settings namespace is not a new macOS permission
identity. Another app copy or a diagnostic tool may have different grants.

Users return from Privacy & Security and check again, or quit and reopen if
macOS requires it. The client does not edit the TCC database, request a blanket
grant, or infer access from a saved setting. Stable Teraguchi bundle identity,
signing, permission persistence across updates, and clean-Mac repair still need
distribution work and qualification with the exact candidate.

## Local validation

With the retained Qt 6.10.2 toolchain:

```sh
bash scripts/test/check-macos-input-permissions.sh "$PRIVATE_PERMISSIONS_OUTPUT"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
bash scripts/test/check-macos-client-keyboard.sh "$PRIVATE_KEYBOARD_OUTPUT"
PLANK_CLIENT_EXECUTABLE="$BUILT_CLIENT_EXECUTABLE" \
  bash scripts/test/check-workstation-client.sh "$PRIVATE_CLIENT_SMOKE_OUTPUT"
```

- Native permission tests: five QtTest results pass using injected permission
  readers and Settings openers. Cases cover both required grants, unsupported
  platforms, revocation, unchanged reads, fixed URLs and Settings failure.
- UI tests: 135 results pass, including missing permissions before host
  preparation, loss before/during PAM, cancellation, retry and no automatic
  connection. Thirty-eight simulated screens render with network access denied.
- Keyboard tests: 75 mapping assertions and 61 Cocoa/SDL bridge assertions pass.
  The bridge fixture now runs inside a non-activating AppKit application loop;
  local event monitors did not run reliably before `NSApp run`. The committed
  baseline reproduced that failure, and the same loop correction passed it.
  These tests post only process-local synthetic events and install no live tap.
- The complete arm64/macOS 26 client builds. Its uninstalled smoke test passes
  blank-settings startup, malformed-configuration rejection and idle Quit with
  no unexpected QML warning. Strict-video and native Quit regression checks pass.

Offscreen captures verify layout, not native control painting, physical video or
live permissions. No Settings action, permission grant, host connection, app
installation or Tailscale change occurred. Private logs retain failed harness
and native-control checks alongside their successful corrected runs. Hosted CI
and clean-Mac/live-session qualification have not run for this slice.

See the [P3/P4 checklist](teraguchi-p3-p4.md) and
[shared-workstation integration](teraguchi-tailscale-workstations.md).
