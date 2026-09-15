# Native Mac two-output presentation

## Current boundary

The Metal renderer now accepts one or two presentation targets. It presents a
crop of the existing combined desktop on each target using PLANK's shared
presentation geometry. The transport and decoder still carry one canvas.

This completes the renderer portion of the Mac two-output work. **The development
picker still rejects a two-display session.** Session window creation and
placement remain Wayland-only. Native Mac window placement, display loss,
fullscreen transitions and exact-candidate qualification are the next slice.
The renderer tests do not enable an incomplete session path.

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

## Next integration work

1. Bind the explicitly selected two displays to stable native display IDs before
   login, and revalidate both before startup/reconnect. Reject unsupported display
   counts or arrangements explicitly.
2. Create and place native Mac presentation windows on those exact outputs.
   Handle Spaces/fullscreen transitions, focus, toolbar ownership and close/Quit
   for both; never hide one output while claiming a two-output session.
3. Recheck both display bindings during streaming and clean up held input on
   removal, replacement or incompatible mode changes. Verify pointer, pen and
   reserved-key routing across the output seam.
4. Qualify the combined 7680-wide decode path, both physical ten-bit surfaces,
   4K60 throughput, color, output timing and real input using the exact candidate.

See the [P3/P4 checklist](teraguchi-p3-p4.md). Physical testing and the deferred
operator session remain separate from this local renderer checkpoint.
