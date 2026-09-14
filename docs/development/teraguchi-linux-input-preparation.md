# Teraguchi Linux input preparation

This is an uninstalled dependency candidate and a static shortcut checker.
It builds on Alan Latteri's PLANK input implementation. The production host and
client gitlinks stay unchanged from the Mac keyboard candidate. New transport
work remains gated on host qualification.

## Dependency candidate

The separate `plank-libvirtualhid` branch `codex/linux-input-preparation` starts
at `93d57db99a5bf4b1a9fbbc7ad1371671725b7e97`, the dependency pinned by Host
`9329784ac41f50cbec0c9d76badfd22227ec5e5f`. Its local candidate commit is recorded
in HANDOFF. It is intentionally not promoted into the host gitlink until the
Linux build and integration checks pass.

| Area | Prepared behavior | Still required |
| --- | --- | --- |
| Normalized pen pressure | Advertise and quantize 0–8191 once; preserve the negative unchanged sentinel, release and hover behavior; reject non-finite pressure before emission. | Linux suite, recreated device axis inventory, application pressure measurement. |
| Keypad Enter | Honor the existing API's nonzero `scan_code` as an advertised evdev key, including `KEY_KPENTER`; zero keeps the existing VK map. | Linux suite and eventual negotiated client/host translation. Existing PLANK wire input still aliases Return and keypad Enter. |
| Key repeat | Retain each resolved native identity and the full event; serialize repeat emission with releases. | Linux backend and lifecycle tests, physical held-key interruption tests. |
| Unsupported native keys | Reject unadvertised power/pointer/out-of-range codes; XTest rejects explicit evdev codes. | Linux tests with XTest enabled on an isolated display. |

The library API layout, host adapter and packet schema are unchanged. No key
flag or spare VK value has been repurposed. The pressure change affects normalized
pen injection, not raw-HID forwarding or tablet USB identity. Existing devices
need recreation to obtain the new pressure range; this work does not perform it.
The portable test exercises production pressure/repeat helpers, not a mock copy
of their arithmetic or state logic.

## Modifier profile checker

`check-flame-modifier-profile.py` checks a **draft**, complete mapping of eight
side-specific modifiers. It only reads files and prints a proposed physical
sequence. It does not apply a profile, record keys, contact a host or install
anything. The default draft preserves physical identities: Command is Super,
Option is Alt, and both sides of each modifier stay distinct.

The nine draft shortcuts come from the saved Flame 2027.1 Smoke Classic bindings
collected during Phase 0. Only selected key sequences and action labels are
retained here; private source captures stay outside Git. Active bindings still
need confirmation in Flame, and the generic Shift binding is represented with
left Shift for now.

| Saved action | Required host identity | Remapping hazard |
| --- | --- | --- |
| Mark In | Right Alt | Collapsing Option sides loses this identity. |
| Mark Out | Right Control | Collapsing Control sides loses this identity. |
| Audio Monitoring | Shift + Left Control + Left Super + A | Mapping both Command keys to Control removes Super. |

Profiles must be permutations of all eight modifiers. A complete Control/Super
swap is statically reversible, but changes the physical Mark Out key to right
Command. It is tested as a possibility, not selected as a user preference.
Passing proves only reachability and preserved event order for these draft
sequences. It does not establish ergonomics, a full shortcut catalogue or real
Mac reserved-key delivery.

Before a runtime profile is introduced, it needs host-side, session-scoped
selection; one substitution only; press-time mapping retained through release;
release-all before a profile change; repeat and modifier-plus-pen ordering;
and compatibility with the host's synthesized modifier flags. The inherited
global keybinding map is not sufficient evidence for these properties.
Do not remap both the client and host. Identity remains the starting profile.

## Local validation

Test environment: Mac Studio with Apple M2 Ultra and 64 GB RAM, macOS 26.5.2
(25F84), Apple Clang with C++23. No Linux host or Flame instance participated.
Flame 2027.1 is the version of the saved shortcut fixture, not a tested runtime
for this candidate. Rocky Linux 9.7 remains the target for the pending builder
and hardware checks.

- 16,401 assertions pass against the production pressure/repeat helpers,
  including all 8,192 pressure codes and both Return/keypad release orders.
- Negative controls restoring the 4096 limit and dropping keypad scan-code
  identity are rejected by the portable test. The helper suite also passes
  AddressSanitizer and UndefinedBehaviorSanitizer.
- 14 modifier profile tests pass, including collision detection, simultaneous
  swaps, invalid draft data and ordered releases; all nine identity sequences
  pass the file-only checker.
- 12 existing CI policy/context tests pass after adding the modifier checks to
  the CI preflight. No workflow has been dispatched or published.
- Linux backend tests have been added for capability advertisement, native keys,
  pressure values, non-finite input, unchanged pressure and hover. They have
  **not run** on a Linux builder. CMake test integration is also unqualified.

From this root checkout, with the separate library candidate available:

```sh
bash scripts/test/check-linux-input-preparation.sh \
  "$LIBVIRTUALHID_CANDIDATE" "$PRIVATE_BUILD_OUTPUT"
```

This compiles device-free helpers and runs the profile checker. It does not
build or install a Host package. To inspect a different draft map:

```sh
python3 scripts/test/check-flame-modifier-profile.py --profile "$DRAFT_PROFILE"
```

## Qualification sequence

1. On the development Mac, run the prepared local pen monitor with the operator
   present and review Accessibility/Input Monitoring permissions. Physical
   reserved-chord delivery and capture-failure recovery need a later agreed
   client test; synthetic callback checks are not physical acceptance.
2. Confirm the active Flame shortcut preset. Keep identity mapping unless the
   operator chooses a different physical layout; rerun the static checker first.
3. Build/test the library candidate on the qualified Rocky Linux 9.7 builder,
   including the full Linux backend suite and isolated XTest checks. Retain the
   exact candidate commit, dependency pins, commands and results privately.
4. With verified recovery access and an agreed test window, build a separate
   host candidate and qualify its recreated uinput device on the authorized
   hardware test Host. Check pressure, repeat, disconnect cleanup, eraser/hover
   and Flame consumption. Do not use the workstation as a package builder.
5. After the host gates pass, negotiate distinct physical keypad identity through
   the existing PLANK client/host protocol. Test matched and mismatched versions
   before exposing it as supported. Windows remains behind the Mac production gate.

No host admission, native ten-bit capture, physical Wacom, cold-boot recovery,
WAN or production-release gate is closed by these static checks.
