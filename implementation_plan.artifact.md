# STREAMZ Engineering Plan

This is the current documentation-level plan for keeping STREAMZ behavior stable across Android, Android TV, Windows, and Web. It does not claim the listed follow-up work has been implemented. The source-based architecture and detailed capability matrix are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Completed UI quality pass (29 October 2026)

- Centralized the app-wide Manrope roles and reused the existing blue-glow scaffold across routes; the animated launch overlay keeps the destination mounted.
- Reused focus-aware cards/buttons and responsive action grids, and corrected empty/search/error states, discovery retry behavior, player overlay hit testing, TV control contrast, and unknown storage reporting.
- Added widget regressions for splash continuity, text-scaled action grids, responsive file-grid columns, loading-button activation, and host-browser visual/control contracts.
- Completed the file-browser consistency follow-up: category and media grids use shared focus-aware cards and `DS.responsiveColumns`; metadata wraps and download actions retain separate accessible hit targets.
- Aligned both host-served HTML clients with the shared dark-blue glow, Manrope typography, responsive surfaces, focus-visible states, and reduced-motion preferences. Their JavaScript and playback flows remain independent.
- Added player error diagnosis and remote-stream recovery across Flutter mobile/desktop/Web and TV players, plus matching retry-and-resume handling in both host-served browser clients. Retries preserve position and use a delay capped at 30 seconds; codec/device/network categorization remains best-effort.
- Added a TV Recently played rail from the existing local history, while keeping in-progress items in Continue Watching and preserving D-pad playback/resume actions.
- Removed an unused technical component library and unused toggle widgets; renamed the downloads-sheet surface to `AppPanel` and updated the component guide.
- See [docs/UI_COMPONENTS.md](docs/UI_COMPONENTS.md) for the component API and [docs/UX_REVIEW.md](docs/UX_REVIEW.md) for the screen inventory, remaining constraints, and exact verification results.

The UI pass does not complete the outstanding native runtime checks below. Windows must be built on Windows, and Android TV still needs physical remote/focus and display-mode validation.

The previous UI pass passed all 47 Flutter tests; those results predate the playback-recovery and TV-home additions. Both host HTML scripts passed `node --check`. Flutter analysis/tests could not be rerun because the SDK wrapper could not write its protected cache and the direct Dart binary crashed during macOS CPU-info initialization. See the UX review for current platform limits.

## Current baseline

- Flutter app with Provider ViewModels and GetIt service composition.
- Native Android and Windows host/client flows; Android includes Leanback launch and remote-navigation support.
- Flutter Web and a separate host-served HTML browser client; both use browser media capabilities, and Web does not scan local files or use UDP discovery.
- MediaKit remains the Flutter player. A prior Android build failure was a timed-out native artifact download; this does not by itself establish a runtime player defect.
- Existing feature behavior, route/API contracts, pairing behavior, media IDs, and playback controls must be treated as compatibility requirements.

## Priority work

| Priority | Work | Completion evidence |
| --- | --- | --- |
| P0 | Confirm production Android package ID and release signing before store distribution. | Release build signed by the intended production key and package identity. |
| P0 | Verify LAN trust boundary and deployment guidance. Pairing gates WebSocket connections; HTTP media/API routes remain cleartext and do not inherit that gate. | Threat model and deployment guidance accurately describe current reachability and transport. |
| P1 | Record a behavior baseline on Android, Android TV, Windows, Flutter Web, and the host-served browser where each feature applies. | Matrix in `docs/ARCHITECTURE.md` has device/OS/browser and media sample results. |
| P1 | Measure scan time and memory with realistic large libraries before optimizing. | Reproducible baseline; any batching/pagination keeps media identity and existing API behavior compatible. |
| P1 | Compare the two browser HTML implementations for functional drift. Their shared visual treatment is aligned; behavior parity remains to be established. | Parity list for navigation, playback, pairing, WebSocket, and accessibility before any consolidation. |
| P2 | Refactor the HTTP/WebSocket service only around characterized responsibilities and tests. | Existing range, pairing, station, remote-control, and error semantics remain covered. |
| P2 | Re-evaluate MediaKit only through a focused playback/build spike. | Native and Web comparison includes tracks, screenshots/thumbnails, seek, format support, TV remote input, and clean build behavior. |

## Compatibility acceptance criteria

Before a refactor or package change is considered safe, compare old and new behavior for:

- Host start/stop, saved folders/settings, permission denial, and recovery after backgrounding or network changes.
- UDP discovery and manual connection, pairing-link behavior, metadata/browse results, thumbnails, file downloads, and HTTP byte-range seek.
- Playback controls, playlists, station join/pause/resume, sync role changes, queue, remote commands, progress/history persistence, audio/subtitle selection, and player teardown.
- Android TV D-pad focus order and activation; narrow through wide layouts; display modes at HD/1080p and 4K; browser codec and fullscreen/autoplay behavior.

Do not state that all features work identically on every target when the source uses platform-specific APIs or browser-controlled codecs. Mark a flow unsupported, limited, or unverified where appropriate.

## Routine verification

```sh
flutter analyze
flutter test
flutter build apk
flutter build web
```

Run `flutter build windows` on a Windows environment. For Android TV and browser media, automated build success is not a substitute for remote-input and representative-device playback checks. Capture the exact toolchain, OS/device, display mode, browser, network, and test media used.
