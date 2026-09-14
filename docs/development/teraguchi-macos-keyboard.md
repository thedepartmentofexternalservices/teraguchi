# Teraguchi Mac keyboard candidate

This local candidate adds owned-key cleanup and reserved-chord capture to the
Mac client. It builds on the Mac pen and strict-video candidates. It does not
install a client, change a host or extend the transport. Alan Latteri's PLANK
keyboard map and existing native input messages remain the foundation.

## Behavior

| Case | Candidate behavior |
| --- | --- |
| Left/right Shift, Control, Option, Command | Distinct physical identities; Command remains Super and Option remains Alt. |
| Focus loss, capture change, reconnect or Quit | Cancel owned pen contact, invalidate queued captured keys, then release keys in reverse press order. |
| Key-up after modifiers/layout state changes | Release the identity and flags recorded at key-down. |
| Duplicate down or local OS repeat | No duplicate remote press; repeat remains host-generated. |
| Held key after interruption | Require physical release before accepting another press. |
| Client Ctrl+Alt+Shift shortcuts | Retain existing actions; consume the local key-up instead of sending an orphan release. |
| Return and keypad Enter together | Retain the shared host key until both physical keys release; they are still not distinguishable on the host. |
| Enqueue failure or loss of requested system-key capture | Stop the connection with a useful error and release owned input. |

The reserved-chord tap covers Command with Tab, Space, grave, Q, W, H, M or
Escape, and Control with the arrow keys. It runs only for a focused presentation
window with capture enabled. Ordinary keys and modifier events retain SDL's
Cocoa path. Media/Fn keys and Command+Option+Escape (Mac Force Quit) remain local.
Captured Command+Q is sent to the host; the Mac application's menu Quit and
the client's Ctrl+Alt+Shift+Q still disconnect. These distinctions require a
physical acceptance test before shipping.

The client checks Accessibility and Input Monitoring access without prompting
or changing settings. If requested capture cannot start, the connection closes
with directions to System Settings. Tap timeout/user disable is a failure; the
client does not silently continue without reserved chords or re-enable a tap
disabled by the OS. No key text, global trace or input log is recorded.

## Ordering and lifecycle

The earlier standalone tap patch called the input sender from the tap callback.
That can overtake pen/modifier events still awaiting Cocoa-to-SDL translation.
This implementation posts an inert AppKit marker at the back of the native
queue. A local monitor turns it into a separately allocated SDL event; only
the streaming loop resolves it and invokes normal keyboard handling. The loop
flushes the preceding pen sample first. No synthetic keyboard event is posted
to the operating system.

Pending markers are bounded to 128 entries, identified by numbers rather than
owning pointers, and invalidated on cancellation. Their SDL type explicitly
avoids `SDL_EVENT_USER`, which PLANK already uses for session control. A stale
marker cannot revive a cancelled press or become a pointer into a later session.
Mac state and callbacks remain on the main streaming thread.

The pinned SDL 3.4.2 Cocoa keyboard grab uses a private global-hotkey API. Mac
capture now uses the bounded public event tap instead. The extracted physical
key map retains existing values and non-normalized flags for other platforms;
their capture and key-state behavior is unchanged.

Relevant API contracts: Apple's [tail posting](https://developer.apple.com/documentation/appkit/nsapplication/postevent(_:atstart:))
and [local event monitor](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)),
and SDL's [custom event allocation](https://wiki.libsdl.org/SDL3/SDL_RegisterEvents).

## Validation

Test configuration: Mac Studio M2 Ultra, 64 GB, macOS 26.5.2 (25F84), SDK 26.5,
deployment target 26.0, Qt 6.10.2, Rust 1.89.0, SDL 3.4.2 and FFmpeg 9.0.1.
The arm64 client builds locally. The keyboard checks compile production sources:

```bash
bash scripts/test/check-macos-client-keyboard.sh "$PLANK_WORK_ROOT/keyboard-input"
```

- 75 key-map/state/pen-order assertions pass, including the saved Flame shortcut
  keys, side-specific modifiers, the Super-dependent audio chord, release flags,
  repeat suppression, held-key cancellation and the existing keypad alias.
- 61 reserved-key bridge assertions pass. They exercise the production callback
  with in-memory CGEvents and the real AppKit-to-SDL marker path, including prior
  native and SDL events, cancelled markers, bounded overflow and failure latches.
- Permission-denial and tap-creation-failure checks replace only the OS permission
  queries and creation call. They cannot create a live tap or request permission.
- The pen's 16,427 assertions, common-C modifier/stroke queue test and all eight
  native Quit scenarios pass. No host connection or system input injection occurs.
- The built app reports `PLANK 1.0.103-macos-keyboard-input` in an offscreen
  version-launch check; it was not installed or launched into a live session.

The test harness reads SDL's queue directly: `SDL_PollEvent` adds a poll-cycle
sentinel and is not an appropriate assertion that no queued marker remains.
Mac CI now invokes the keyboard script; a hosted run has not been performed for
this local candidate. Private logs and binary/source provenance stay outside Git.

## Remaining gates

**This is not a physical keyboard or Flame qualification pass.** Test the selected
chords on a stable, signed candidate with permissions granted, including ordinary
input before/after capture, focus loss, both displays, native menu Quit, Force Quit,
tap interruption, modifier-plus-pen and reconnect. Confirm the active Flame
shortcut preset and compare real host event traces and actions. Source tests
cannot establish system interception timing or behavior in the installed app.

The reviewed host `9329784ac41f50cbec0c9d76badfd22227ec5e5f` and libvirtualhid
`93d57db99a5bf4b1a9fbbc7ad1371671725b7e97` map `0x0D` to `KEY_ENTER` with no
distinct keypad-Enter route. Implementing that distinction needs an explicitly
negotiated client/host representation and Linux backend tests. Do not repurpose
an unrecognized VK or flag and claim success. Host-side modifier profiles also
remain open; a global Command-to-Control remap would lose the Super key required
by the saved audio chord unless the profile supplies a tested way to produce it.

The host pressure limit, native 10-bit capture and recovery gates remain open.
Live tests are limited to the authorized test workstation after verified recovery
access. This candidate inherits strict video admission and must not replace the
working client merely to bypass the existing capture gate.
