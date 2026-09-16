# Help and private support reports

The development workstation picker has a Help button for display, tablet,
shortcut, access and picture-requirement problems. It opens without starting a
connection, changing the display count, opening Settings or writing a report.
Known failure categories select the relevant help topic. Free-form failure
messages never become report content.

## Repair guidance

Display help follows the current candidate's binding rules: one screen uses the
launcher window's display; two requires exactly two independent, unrotated screens
arranged side by side with vertical overlap. A display or mode change requires a
new connection. Choosing one display remains an explicit artist action. The
System Settings route and extended/mirrored desktop distinction follow
[Apple's display guide](https://support.apple.com/guide/mac-help/mchlb5f905a1/mac).
These candidate restrictions come from the native binding code, not an Apple
hardware-limit claim.

Tablet help starts with a local pen check and Wacom settings, then separates Mac
permission repair from end-to-end Flame testing. Wacom documents a device/pen
diagnostic path in [Test the pen](https://101.wacom.com/UserHelp/en/TestingPen_Full.htm).
The client neither runs that diagnostic nor imports its device data. Review
permissions opens the existing client permission dialog; opening Help itself
never requests access or captures input. Permission status cannot prove pressure,
tilt, eraser, hover, buttons, shortcuts or cross-display mapping.

Access help distinguishes the Tailscale guest account, signed studio/workstation
trust, studio workstation login and an occupied seat. Certificate changes still
require administrator review. Picture help retains the strict native ten-bit,
HEVC 4:4:4 ten-bit and hardware-decoding requirements. Help does not authorize a
fallback, force a seat takeover or change any connection-admission check.

## Report boundary

Support report is a separate help topic. Prepare report snapshots launcher status
and displays the complete serialized JSON. Save report writes those same bytes;
Show folder is another explicit action. There is no upload, clipboard copy,
external support URL or automatic collection. An artist can review the saved file
and choose whether to share it through the studio's support process.

The native `SupportDiagnostics` object has no reference to logs, saved settings,
workstations, credentials, network providers, input samples or captured frames.
QML passes thirteen named scalar status inputs. The serializer emits a fixed
schema, accepting only known enum strings, typed booleans and a display count of
one or two. Unknown or malformed values produce `unknown`/null. Extra fields and
nested data are discarded; arbitrary text is never redacted and copied through.

The report is at most 4 KiB. It includes:

- Numeric client, Qt and OS versions, plus coarse platform. Client branch labels
  are omitted; this is not an exact-build provenance receipt.
- Studio setup and Tailscale status categories; phase and known issue category.
- Assignment-cache freshness/refresh state and session-resource retention.
- Selected display count and selected workstation's availability category.
- Accessibility and Input Monitoring status, with unchecked/unsupported states.
- Explicit `not-tested` values for physical displays, tablet and video paths.

It excludes names, studio labels, account/node/host identifiers, addresses,
certificate fingerprints, keys, tokens, passwords, logs, file paths, device
serials, artwork, timestamps, keystrokes, pen coordinates and pressure samples.
Status is a snapshot of launcher presentation, not proof of access, a free seat,
live performance or hardware qualification. Exact candidate hashes and private P4 measurements use
`scripts/test/prepare-p4-evidence-manifest.py`; see
[teraguchi-transport-counters.md](teraguchi-transport-counters.md).

Reports are saved under the running app's application-data location in
`support-reports`, with random filenames and no overwrite. The report directory
must be owner-only (`0700`); new files are `0600`. Save checks for symlink paths
and Git ancestors, then uses a held directory descriptor and exclusive file
creation. A nonprivate existing report directory is rejected, not silently
changed. Partial writes are removed. Error messages contain no paths or input
values. A prepared snapshot can be saved once; Prepare report allows a new one.
Local account compromise and concurrent hostile changes to ancestor directories
are outside this export boundary.

Reports remain until the artist removes them. There is no background retention
service. The UI preview disables saving and folder opening entirely. Native unit
tests use private temporary directories and injected folder openers.

## Checks and remaining gates

The focused native suite exercises the real QML-to-C++ conversion, fixed schema,
private-data canaries, oversized/nested inputs, type confusion, version text,
unchecked permissions, reviewed-byte equality, private file modes, no overwrite,
explicit save/folder actions, failure behavior and symlink/Git rejection.
Sixteen native QtTest results and 156 QML results pass. Forty-nine network-denied
screens render; seven new help/report screens were also captured with native Mac
controls and visually checked, including compact and dark layouts. The complete
arm64/macOS 26 client build and blank-settings startup/idle Quit smoke pass.
Twelve CI policy/context tests pass locally; hosted CI has not run.

```bash
bash "$PLANK_SOURCE_ROOT/scripts/test/check-support-diagnostics.sh" \
  "$PRIVATE_AUDIT/support-diagnostics"
bash "$PLANK_SOURCE_ROOT/scripts/test/check-workstation-ui.sh" \
  "$PRIVATE_AUDIT/workstation-ui"
```

QML tests cover topic selection, preserved workstation/display choice, manual
permission review, the exact snapshot input fields, explicit save/reveal and
failure-code clearing. New light/dark and compact preview cases cover the help
and report panels. These checks do not grant OS permissions or connect a host.
Clean-Mac usability, permission persistence and artist troubleshooting remain
live acceptance work. This slice does not complete P3 or enter P4.
