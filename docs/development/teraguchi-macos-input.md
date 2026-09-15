# Teraguchi Mac pen input and Flame shortcut checkpoint

This candidate connects SDL's Cocoa pen events to PLANK's existing normalized
pen input. It changes the Mac client only. No host package, raw-HID bridge,
driver takeover, global event tap, new wire message or transport is introduced.
PLANK's Linux input implementation and protocol remain Alan Latteri's foundation.

## Client behavior

The pinned SDL 3.4.2 Cocoa backend already reads tablet-subtype `NSEvent`
pressure, tilt, eraser and barrel-button data. It splits one native sample into
touch, motion, buttons and axes bearing the same timestamp. The client now
assembles that sample before sending it, so contact uses the new coordinates
and pressure rather than the preceding hover position.

Samples go through the existing presentation-coordinate mapper, including
window points, canvas geometry and letterboxing. Pressure stays a normalized
float through the existing 32-byte pen encoder. Cocoa's tilt axes use the same
azimuth/magnitude conversion as PLANK's normalized Linux pen. Hover pressure is
zero; Cocoa does not supply physical hover distance. Barrel rotation and
tangential pressure are not mislabelled as the protocol's tilt azimuth.

Local toolbar routing also receives the completed sample. SDL's synthesized
mouse events are excluded from remote forwarding and immediate toolbar clicks;
otherwise a pen could both draw and click, or click a toolbar control at stale
coordinates. Mouse/pen/key events stay in SDL queue order on Mac. The common-C
worker retains its existing adjacent-motion batching.
While reconnecting, samples remain available to local controls with remote
capture disabled; live reconnect behavior still needs acceptance testing.

Focus loss, capture disable, layout change, proximity leave and tool changes
cancel owned remote pen state. Repeated cancellation does not send duplicate
releases. After interrupted contact or a held barrel button, forwarding waits
for release before accepting another press. Local toolbar drags retain local
ownership; focus loss also clears local button state. A failed pen enqueue,
including missing host pen capability, ends the session with a useful error
instead of substituting generic mouse input.

This is client implementation and offline validation, not a claim of working
Flame brush pressure, raw-HID parity, multi-display mapping or complete keyboard
capture.

## Mac pen cursor and Flame margins

A live single-output pilot exposed a pen-only click offset with the mouse
correct. The host stylus advertised axes `0..19200` / `0..10800`, but its active
Wacom Area was `960 540 18240 10260`. The operator's Flame preferences showed
5% margins on all four sides. Setting those margins to zero restored alignment.
The initial claim that the preceding day worked is retained; the exact change
that activated the mismatch has not been established.

The normalized client sends full-stream coordinates. Flame's Wacom driver maps
those coordinates through its configured tablet area before clicking. The Mac
client showed the locally positioned cursor, while Linux already used the host's
post-driver cursor position for tablet input. Zero margins are a temporary
workaround, not the intended product constraint.

The repair connects accepted Mac pen samples to that existing cursor-position
channel. An input-transparent Cocoa layer shows the host shape and hotspot on
the matching presentation output. It never warps the OS pointer, changes pen
packets, guesses a margin percentage, or edits Flame preferences. A newer host
position is required when switching to pen ownership. Mouse input, proximity
leave, local controls, mapping rejection, focus loss and capture cancellation
restore native pointer ownership. Renderer replacement recreates the overlays;
reconnect retains the existing sequence-epoch reset. Linux keeps its existing
Wayland implementation behind the shared cursor type.

Offline checks cover complete-sample ownership, held-contact suppression,
rejected sends and local routing. The native regression uses hidden windows to
check hotspot placement, alpha/color bytes, top-down coordinates, two-output
mapping, resize, input transparency and parent replacement. These tests do not
qualify physical pen alignment with nonzero margins or cursor latency over WAN.
Run the native check on an authorized GUI Mac:

```bash
bash scripts/test/check-macos-tablet-cursor.sh "$PLANK_WORK_ROOT/tablet-cursor"
```

Local results: 16,439 pen assertions, 35 hidden native cursor checks (including
a Metal view), 18 presentation results and eight Quit scenarios pass.

Hosted CI builds this harness with `--build-only`; it does not claim a native
window-server or physical Wacom pass. The installed pilot must be recorded
separately from the source repair. Live acceptance: restore the preferred
margins, hover/click near the center and all edges, test a pressure stroke,
switch to a real mouse and back, visit local controls, refocus, then repeat
with paired outputs.

### Nonzero-margin live failure and diagnostic follow-up

The installed candidate at root `879e90c` / client `6267acf7` failed at 5%:
the operator sees one cursor which stays on target while the click lands
elsewhere. Zero margins remain the only confirmed workaround. Read-only host
samples confirm the X pointer tracks the configured Wacom crop, including edge
clamping. A private isolated cursor-consumer harness passed 21 checks, but uses
stubbed pen initialization and does not reproduce the live failure. The cause
is unresolved; the local-pointer explanation above was the repair hypothesis,
not an established complete diagnosis.

Set `PLANK_PEN_CURSOR_DIAGNOSTICS=1` during qmake/build only for a local diagnostic
candidate. The default build excludes this code. For each input-handler instance,
the first accepted pen packet starts a 15-second window, limited to ten numeric
coordinate records per second. Records include the latest normalized pen point,
action, real mouse event counts and point, host cursor point, mapped window point,
and ownership/visibility state. Pen-triggered records still appear if host cursor
updates are absent. Samples are asynchronous; timestamps do not imply individual
packet acknowledgement. The trace uses the existing private client log and does
not include keyboard text or artwork. Keep those logs outside Git.

This instrumentation changes no input routing or coordinate mapping. The
installed diagnostic captured valid host positions and window mapping while
native-cursor visibility was disabled during pen ownership. The operator reports
the cursor is visible outside the video area but disappears inside it. Hidden
layer-object checks did not cover this visible presentation failure. Reproduce
it with an isolated Metal window before another physical alignment test.

The operator also confirmed Flame's panel still showed 5% margins, while a
subsequent host read returned the full tablet area. Do not infer the preference
panel value from that property alone. Input endpoints may be retained across a
resumable session; reconnect-induced recreation or stale Flame device state is
a hypothesis, not an established cause. The diagnostic build is not a qualified
fix or an artist-distribution candidate.

### Cursor covered after Metal renderer reset

The live log showed cursor-parent refresh before the replacement Metal renderer
was created. SDL appends the new opaque Metal view above existing siblings;
`isAttachedTo()` still returned true because the content view did not change.
Thus cursor ownership correctly hid the Mac pointer while video covered the
replacement cursor. Earlier tests created Metal before the cursor and missed
this reset order.

`MacTabletCursor::dispatchPending()` now restores the cursor as the top sibling
only when another view was appended above it. It preserves image, hotspot,
position and visibility, without ordering or focusing the OS window. A regression
recreates Metal after the cursor, fails on the preceding source, and passes with
the fix. All 43 hidden checks pass. A separate visible local fixture renders a
red cursor square over continuously presented Metal video after this ordering;
visual inspection confirmed the square appears. This is local rendering evidence,
not physical Wacom, Flame margin, or WAN acceptance.

## Host pressure gate found during review

The reviewed Linux Host is
`9329784ac41f50cbec0c9d76badfd22227ec5e5f`, with libvirtualhid
`93d57db99a5bf4b1a9fbbc7ad1371671725b7e97`. Its normalized pen backend defines
`tablet_pressure_max = 4096` in `src/platform/linux/uhid_backend.cpp` and uses
that constant for both the advertised axis and pressure conversion.

That does not meet Teraguchi's PTH-660 `0...8191` target. The Mac client must
retain precision now; changing the host limit requires a separate dependency
change, Linux build and device/Flame acceptance. This review did not change or
test an installed host. Do not claim an end-to-end pressure pass from the
client's float tests.

## Flame shortcut baseline

The earlier Phase 0 inventory recorded these selected Flame 2027.1 Smoke
Classic bindings. They are a saved baseline, not confirmation of the currently
active profile or a complete shortcut catalogue:

| Action | Saved host binding |
| --- | --- |
| Mark In | Right Alt |
| Mark Out | Right Ctrl |
| Play | V |
| Stop Play/Render | Space |
| Toggle Node Schematic View | Grave/backtick, user override |
| Toggle Batch/MK Schematic View | Escape, user override |
| Next / previous version | Left Alt + Up / Down, user overrides |
| Toggle audio monitoring | Shift + Left Ctrl + Left Super + A, user override |

Source review of the current keyboard handler confirms distinct left/right
Ctrl and Alt virtual keys, physical scancode lookup and repeat suppression.
The follow-on [Mac keyboard candidate](teraguchi-macos-keyboard.md) adds owned-key
cleanup and a reserved-key bridge; physical capture and the host-side Mac modifier
profile remain unqualified. Command-to-Control remapping must not silently remove the
Super key needed by the audio chord. Right Option must remain available as
Right Alt for Mark In. The handler currently maps keypad Enter and Return to
the same virtual key; separate keypad Enter remains a requirement gap.

Keep normal Mac Quit behavior intact while designing reserved-chord capture.
The older Phase 0 event-tap patch cannot be declared integrated merely because
its isolated callback tests passed. The follow-on candidate replaces its direct
sending path with ordered markers and tests; physical permissions/capture checks
are still required.

## Reproduce local checks

After building the client with the pinned Mac dependencies:

```bash
bash scripts/test/check-macos-client-pen.sh \
  "$PLANK_WORK_ROOT/pen-input" \
  "$PLANK_WORK_ROOT/client-build/moonlight-common-c/libmoonlight-common-c.a"
```

The tests compile the product sample assembler, use recording callbacks, and
exercise the actual common-C input worker with an in-memory native sender.
They open no host connection and inject no input. Hosted Mac CI runs both.

Results on the Mac Studio M2 Ultra, 64 GB, macOS 26.5.2 (25F84), SDK 26.5:

- Arm64 client build passes with Qt 6.10.2, Rust 1.89.0, pinned SDL 3.4.2 and
  FFmpeg 9.0.1. Deployment target is 26.0.
- All 8,191 nonzero synthetic pressure values remain unchanged through the
  assembler and packet encoder. The test has 16,427 assertions in total.
- State tests cover sample ordering, eraser/tool changes, buttons, tilt,
  proximity, invalid values, failed sends, focus/capture suspension, local
  control coordinates and held-press suppression.
- The common-C queue preserves a Ctrl/Shift-plus-stroke sequence across
  pressure changes, tip release, modifier releases and cancel-all.
- The strict-video policy/metadata tests and all eight native Quit regression
  scenarios pass. The client also passes an offscreen version-launch check.

These checks do not exercise a physical Wacom, a global key tap, real host
injection, Flame actions or application reconnection. Synthetic pressure values
do not establish the resolution supplied by a physical driver.

## Operator's next test

The test script also builds `macos-pen-monitor`. Run it locally when the pen is
available. It uses the same assembler, shows pressure/tilt/tool/buttons, and
closes after two minutes or Escape. It has no network or host input code.
Use the normal Wacom driver; do not uninstall it or alter macOS privacy settings
to bypass a failed test. A physical check must confirm hover, light/firm
pressure, eraser, both buttons and release after leaving/refocusing the window.

Then address the host pressure limit in an isolated Linux candidate. Live Flame
testing remains restricted to the authorized test workstation with verified
recovery access. The strict-video parent candidate also requires native 10-bit
capture; do not replace the working client to bypass that gate. Active shortcut
confirmation, reserved chords, actual host event traces, local toolbar behavior
and Wacom strokes in Flame remain acceptance work.
