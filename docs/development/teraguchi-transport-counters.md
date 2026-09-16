# Native transport counter inventory

Updated 2026-09-15. This inventories counters already exposed by the pinned
native transport and the Client session layer before P4 adds more telemetry.
Counter sums do not prove physical input-to-display latency, WAN quality on
their own, or production qualification.

## Toolbar and session sampling

| Measurement | Source | Update cadence | Toolbar label | Proves | Does not prove |
| --- | --- | --- | --- | --- | --- |
| Rendered FPS | Client render loop (`m_CurrentRenderedFps`) | Per frame loop | FPS | Presented frame rate on the Client | Host capture rate, encode rate, or network delivery |
| Incoming video bitrate | Client receive/decode path (`m_CurrentVideoMbps`) | Per frame loop | Video Mbps | Observed incoming media rate | Encoder target, wire bitrate including FEC repair, or sustained WAN capacity |
| Pre-FEC video loss | `PlankTransportNativeStats` FEC counters via `VideoPacketLossInterval` | 1 s deltas, 10 s peak | Loss % | Largest finalized RaptorQ source-symbol loss interval | IP/QUIC packet loss totals, frame gaps, decode errors, or post-decode drops |
| Network RTT | `PlankTransportNativeStats.quic_rtt_us` rounded to ms | 1 s | RTT | QUIC round-trip time for the native endpoint | Pen-to-picture latency, host processing time, decode time, presentation delay, or audio sync |

Network RTT uses zero as unavailable until the first valid native stats sample.
See [video FEC telemetry](../architecture/video-fec-telemetry.md) for the loss
column semantics.

## `PlankTransportNativeStats` (client data plane)

Sampled from `Session::plankTransportVideoReceiveLoop()` through
`plank_transport_native_endpoint_stats()`. Published in session teardown logs
and used for toolbar RTT and FEC loss.

| Field | Meaning | P4 use |
| --- | --- | --- |
| `video_frames_sent` / `video_frames_received` | Complete video frame count | Throughput sanity |
| `video_bytes_sent` / `video_bytes_received` | Video payload bytes | Bitrate cross-check |
| `video_send_drops` / `video_receive_drops` | Endpoint queue drops | Backpressure evidence |
| `audio_packets_*` / `audio_bytes_*` | Audio transport counters | A/V stability |
| `audio_send_drops` / `audio_receive_drops` | Audio queue drops | Audio stall diagnosis |
| `input_packets_sent` / `input_packets_received` | Input channel packets | Input path activity only |
| `data_packets_sent` / `data_packets_received` | Auxiliary data channel | Reserved for future use |
| `quic_rtt_us` | Media-path QUIC RTT | Direct-path observation, toolbar RTT |
| `quic_packets_lost` | QUIC lost-packet counter | Loss drill correlation |
| `kyproto_packets_dropped` | KyProto layer drops before FEC accounting | Transport health |
| `video_fec_source_symbols` | Finalized FEC source-symbol denominator | Toolbar loss % |
| `video_fec_source_symbols_missing` | Missing originals at object finalize | Toolbar loss % (before FEC) |
| `video_fec_source_symbols_unrecovered` | Missing originals in expired unreconstructed objects | Toolbar loss % (after FEC) |

## `PlankTransportStats` (library/control plane)

Available through the broader transport library for probes and future diagnostics.
The assigned Mac client session uses the native FFI stats above for live toolbar
values. Keep both structures aligned when adding telemetry.

| Field group | Examples | Notes |
| --- | --- | --- |
| Video packet/byte counters | `video_packets_sent`, `video_receive_queue_high_water` | Separate send/receive queues |
| Audio packet/byte counters | `audio_packets_received`, `audio_transport_send_drops` | Distinct from video |
| Media QUIC | `media_quic_rtt_us`, `media_quic_packets_lost` | Media connection |
| Control QUIC | `control_packets_*`, `control_send_queue_full` | Setup/control path |
| Interaction QUIC | `interaction_quic_rtt_us`, `interaction_quic_packets_lost` | Input/control latency path |

## Per-frame and decode-path timings (not in toolbar)

| Measurement | Source | Notes |
| --- | --- | --- |
| `host_processing_latency` | `PlankTransportNativeVideoFrameInfo` per frame | Host-side processing hint in microseconds; logged in decode stats, not toolbar |
| Host processing histogram | FFmpeg renderer session stats | p95 host processing from decoded frames |
| Decode completion histogram | FFmpeg renderer | Client decode stage only |
| Client pacer queue / renderer call latency | Pacer | Presentation pacing, separate from network RTT |

Do not relabel any of these as total session latency without an external
end-to-end measurement method.

## Gaps before P4 live entry

- No toolbar field for post-FEC loss peak (only pre-FEC is shown today).
- No direct/relay path label in the toolbar; derive from Tailscale separately.
- No exported stage-timing bundle tied to the P4 evidence manifest yet.
- No automatic pen-to-picture or audio-offset measurement in product UI.

Use `scripts/test/prepare-p4-evidence-manifest.py` to start a run record that
links candidate provenance to these counters and explicit pass/fail gates.
