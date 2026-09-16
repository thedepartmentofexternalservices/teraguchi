# Native Mac two-output presentation

## Current boundary

The Metal renderer now accepts one or two presentation targets. It presents a
crop of the existing combined desktop on each target using PLANK's shared
presentation geometry. The transport and decoder still carry one canvas.

The explicit development picker now connects this renderer to native Mac window
creation. One output binds the launcher screen at Connect; two requires exactly
two independent, unrotated, horizontally arranged screens with qualified native
resolutions. The selected count and identities remain fixed through login and
reconnect. The supervised pilot has streamed two 3840x2160 outputs, but full
dual-display acceptance and P2/P4 hardware gates remain open.

## Display and window contract

The client records native display UUID/ID, configuration generation, logical
bounds, current mode/backing dimensions, refresh, rotation and native resolution.
These records exist only in memory. A random local handle crosses QML; physical
identities never enter settings, logs or a new service. The authentication request
is bound to that handle, and cancellation retires it.

Checks run before the credential dialog, before PAM, after PAM, at Session
initialization and reconnect, on display events and every two seconds while
streaming. Native reconfiguration callbacks record changes even if a monitor is
unplugged and restored between reads. SDL display IDs are resolved from unique
complete geometry after native identity verification; enumeration order cannot
select an output. Unsupported counts, mirroring, rotation, ambiguous identity or
geometry and unsupported native resolutions fail explicitly before login.

Assigned Mac outputs use borderless desktop windows sized to each selected
monitor. They stay in the current Space and do not enter SDL exclusive
fullscreen or a separate fullscreen Space. This works with unified Spaces
("Displays have separate Spaces" off): a one-output session can fill one Mac
monitor while the other stays available for local work. Two-output sessions use
the same borderless contract on both monitors. The session toolbar toggles
between that layout and separate windowed views; each output retains its canvas
crop. The native green button is disabled because it would move only one window
into its own fullscreen Space. No display mode is changed by assigned-session
startup. Session logs record whether separate Spaces is enabled.

While the fullscreen pair is visible and either window has input focus, the
session hides the macOS menu bar and Dock completely so Linux receives the
screen edges. Auto-hide would still reveal macOS controls on hover. The
[AppKit presentation options](https://developer.apple.com/documentation/appkit/nsapplication/presentationoptions-swift.struct)
are scoped to the client process; app switching and Force Quit remain available.
Focus loss, either window minimizing/hiding, windowed mode and session cleanup
restore the previous options. No global Dock or menu-bar preference changes.

Both windows are placed before either is shown. Either window's close request
ends the session, including during reconnect. Minimize/restore applies to both;
a failed grouped operation ends the session. Display removal, replacement, mode
change or a window moving to another output uses the existing input/transport
cleanup path. Scale/size changes on either surface recreate the Metal renderer.
The primary owns the toolbar, while mouse, pen and reserved-key routing use the
shared two-output layout. Real Spaces, focus, minimize/restore and input behavior
still require attended qualification.

## Renderer behavior

`vt_presentation.h` validates target identity, primary-window ownership and
non-overlapping, contiguous horizontal output rectangles. Either output can be
primary. Unequal widths/heights are supported with top-aligned output canvases.
Missing/duplicate targets, gaps, overlaps and unsupported output counts fail
before Metal views are allocated.

The production vertex builder uses `PlankPresentation::sliceForOutput`, the same
canvas geometry used by mouse and pen mapping. Each target gets source UVs for
its slice, preserving letterboxing, orientation and display seams. Drawable
pixel density affects rasterization without changing the source region.
An output outside the visible video region is cleared to black.

`VTMetalRenderer` owns a Metal view, texture cache, command queue and color
pipeline per output. It creates one decoder device context. The secondary
renderer consumes the same decoded frame and never starts a second decoder.
The existing profile checks and hardware-only Teraguchi admission still apply.
Toolbar and status overlays stay on the primary output.

Both outputs must have usable drawables and encoded commands before either
command is submitted. Failed preparation or encoding requests the existing
renderer-reset path. Missing drawables drop the frame for both targets rather
than submitting only one crop. Separate Metal submissions do not establish
synchronized physical scanout; cross-display timing remains a live gate.

Frame textures use shared ownership across completion handlers, including
discarded commands. Presented callbacks own their synchronization state instead
of referencing the renderer after destruction. Partial initialization and normal
teardown release both output views. Window changes require recreation of both
views from Session's current layout. The resource ownership changes also cover
the single-output renderer path.

## Local checks

Use the retained Qt 6.10.2 and Mac dependency roots. Store output outside Git.

```sh
# CPU-only geometry and existing pointer/cursor mapping tests; also wired to CI.
bash scripts/test/check-macos-presentation.sh "$PRIVATE_OUTPUT"

# Adds offscreen ten-bit GPU textures with production vertices/shader/uniforms.
bash scripts/test/check-macos-presentation.sh "$PRIVATE_GPU_OUTPUT" --gpu

# Adds production-renderer setup/cleanup on hidden, non-activating Cocoa windows.
bash scripts/test/check-macos-presentation.sh "$PRIVATE_NATIVE_OUTPUT" --native
```

Local results on the development Mac:

- Nine renderer-geometry QtTest results and nine existing presentation/input
  mapping results pass. Invalid targets, primary on either side, seams,
  letterboxing, unequal outputs and different pixel densities are covered.
- The GPU check renders 52 offscreen BGR10A2 targets and verifies 31,680 RGB
  channel values. Maximum error is half a ten-bit code value. It covers two- and
  three-plane input, horizontal/vertical letterboxing and invisible crops.
  A deliberate uncropped-frame negative control must fail the same check.
- The production renderer passes 71 lifecycle checks with hidden Cocoa windows.
  Tests reject a missing target before allocation, inject a second-output shader
  failure, verify both ten-bit layers, and repeat setup/render/cleanup three times.
  Synthetic software frames exercise Metal resources; this is not hardware
  decode or physical display evidence. Overlay/session actions abort if called.
- The complete arm64/macOS 26 client builds. Strict-video admission/frame checks
  and the uninstalled blank-settings startup/idle-Quit smoke test pass.

No host connection, input capture, permission change or installation is part of
these tests. Hosted CI has not run for this slice. Local compile and GPU checks
cannot pass the one/two-display hardware gates or the sustained WAN workload.

## Window and binding checks

```sh
# Synthetic selection, identity/mode change and SDL mapping tests; also in CI.
bash scripts/test/check-macos-display-binding.sh "$PRIVATE_OUTPUT"

# Adds actual native identity reads and hidden, non-activating window placement.
bash scripts/test/check-macos-display-binding.sh "$PRIVATE_NATIVE_OUTPUT" --native
```

The window slice passes 21 QtTest results for selection, replacement, mode,
rotation, mirror, layout, reordered/ambiguous SDL mapping and system-UI handling
for either focused output, focus loss, hidden/minimized outputs and windowed mode.
The native fixture passes 142 checks for exact frame placement, repeated
borderless/windowed transitions and prevention of independent fullscreen Spaces.
It also exercises actual AppKit option changes, repeated entry/exit and scope
cleanup from both normal and auto-hidden baselines in a background process.
Its windows remain hidden
on the available display: it is not a physical two-display or active-session test.
139 QML results include display loss before credentials, before submission and
during PAM, plus retained two-output selection through successful preparation.

The first live dual-output pilot exposed the missing menu-bar/Dock suppression.
That repair passes these local checks; top-edge access and restoring the Mac UI
still need verification in the updated installed candidate.

## Next qualification work

1. Exercise the exact candidate on two physical displays: both primary choices,
   unequal scaling, fullscreen/windowed, Spaces, focus, minimize/restore, close,
   startup cancellation, display removal/replacement and reconnect.
2. Verify pointer, pen and reserved-key routing across the output seam and held
   input cleanup on each failure. Native fixtures do not inject real input.
3. Qualify the combined 7680-wide decode path, both physical ten-bit surfaces,
   4K60 throughput, color, output timing and real editing workloads.

Trusted studio setup and product distribution remain independent coding work.
See the [P3/P4 checklist](teraguchi-p3-p4.md). Physical testing and the deferred
operator session remain separate from this local window checkpoint.
