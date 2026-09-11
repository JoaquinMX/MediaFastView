# Maximum-precision lookup

Maximum-precision lookup indexes every decoded presentation frame, then uses
compact descriptors to select frames for Apple Vision verification. It does not
run Vision on every indexed frame, so completion does not guarantee exhaustive
scene recall.

## Search behavior

- Search only completed, current indexes from the active profile.
- Validate each video's index during the descriptor scan, before publishing any
  candidate from that video. Invalid indexes are reported separately.
- Preserve the best window selected by the original full/full and center/center
  hash comparison. Add up to three windows using all four descriptor pairings,
  with at least 250 ms between selected windows.
- Verify actual adjacent presentation frames as well as the selected frame.
- Check the most promising videos first and publish verified results while the
  search continues through selected windows in every eligible video.
- Start with one window in each query's first 16 ranked videos. Then verify the
  remaining selected windows and videos in batches of at most eight videos.
  Multiple queries share a native session; each finished video can publish an
  update without waiting for the rest of its batch.
- Apply Strict/Balanced/Loose only to Vision acceptance scores. Candidate
  selection must not change when sensitivity changes.
- Keep one best result per video/query, ordered by Vision distance and path.

The initial pass is intended to provide useful results quickly. The broader
pass has no global video cutoff and can take longer to finish on large libraries.
Skipping preparation starts a search of completed indexes; it does not skip the
descriptor scan or Vision verification, so it cannot promise instant results.
Stop & Keep Results saves an explicitly incomplete verification snapshot;
Cancel discards the active operation. Skipping index preparation and stopping
verification are separate forms of incomplete work.

## Resource and compatibility constraints

The existing binary descriptor recipe and Vision revision 1 remain unchanged.
Changes must retain exact requested times, actual returned presentation times,
orientation handling, and existing feature-print preprocessing. Standard lookup
and video-to-video lookup retain their behavior.

Descriptor scanning must not materialize all indexed frames. Native work keeps
one active video generator and at most 128 cached candidate feature-print pairs
per session, never a cache of decoded frame images. Cancellation must stop new
work, cancel active native operations, and balance security-scoped access.

Only a complete, unchanged current search can serve a sensitivity-only rematch
from cached scores. Changes to the profile, queries, source/index fingerprints,
index generation, or matching policy invalidate that reuse.

## Validation record

The first independent review identified four accepted defects: cross-phase
failure accounting, query-scoped candidate cache keys, missing live video
validation before score-cache reuse, and timestamp tie ordering. All four were
repaired with regression tests. A fresh independent review found no actionable
defects and confirmed those repairs. The duplicate empty-phase publication was
removed. The legacy non-session matcher still carries an unused query-based
candidate fingerprint; this was accepted as optional cleanup because that path
does not use the shared frame-print cache.

The integrated Flutter suite has passed 771
tests, and the full analyzer reports the same 114 existing findings recorded
before this implementation. Lookup-specific analysis and formatting checks are
clean. Isar bindings were regenerated successfully. Final native tests and the
macOS debug build passed: all 14 Runner tests succeeded with zero failures, and
`flutter build macos --debug` produced the debug app. Native tests emitted Apple
performance diagnostics during synchronous fixture/AVFoundation calls; those
warnings are not an end-to-end responsiveness benchmark.

An isolated native-Isar fixture contains 4,760,064 descriptors in 2,688 videos.
Local single-run measurements (milliseconds; not universal latency guarantees):

| Work measured | Time |
| --- | ---: |
| Original descriptor decoding/hash scan before storage edits | 2,888 |
| Descriptor decoding/hash scan with improved pagination | 2,304 |
| Packed record/hash scan with improved pagination | 1,880 |
| Cache-size metadata lookup | 6 |
| Repository first result, with fake Vision | 2,808 |
| Repository all-video completion, with fake Vision | 4,681 |

The packed and decoded scans produced identical checksums. The repository
benchmark returned all 2,688 fixture videos and found no invalid indexes. Native
Vision is deliberately faked in the repository benchmark; its times do not
include video decoding or Vision computation. Peak process RSS was 635,781,120
bytes including the Flutter test runtime and memory-mapped Isar database.

The native same-workload fixture measured 77.4 ms without candidate-print reuse
and 36.0 ms with reuse. Candidate feature-print generation fell from eight to
four, with identical selected presentation times and scores equal within
0.0001. The separate real two-query session test generated four query prints
and just two shared candidate prints, returned both query matches, and reported
no video failure. These are small generated fixtures, not guarantees for a
real library, codec, disk, or video length.

Run the large fixture with:

```sh
flutter test test/features/duplicates/data/maximum_frame_storage_performance_test.dart --dart-define=MAXIMUM_FRAME_BENCHMARK=true
```

Without the flag, the same test uses a small fixture suitable for the normal
suite. The bundled macOS Isar core is used without downloading dependencies.
The test also opens a copy made with the pre-metadata schema and verifies that
backfill preserves descriptor bytes. A concurrent clear/backfill test verifies
that cleared chunks are not resurrected. Hosted Runner tests skip Flutter
startup to avoid opening the application database.

Required checks include selection equivalence, more than 16 matching videos,
multiple temporal windows, sensitivity monotonicity, stale/corrupt chunk
rejection, clear/cancel races, progressive UI and history compatibility, native
score equivalence, resource bounds, and cancellation. The full Flutter and macOS
test suites, code generation, analyzer comparison, whitespace check, and macOS
debug build are release gates.
