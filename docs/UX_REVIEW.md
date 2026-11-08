# Premium UI review — status 29 October 2026

## Scope and flow

Reviewed route definitions, all presentation screen families and their reusable widgets, Provider/GetIt composition, client/server ViewModels, HTTP client/server contracts, media scanning, downloads, queues, playback, and platform shells. The app has a native host, native/Flutter Web clients, and one host-served modern HTML client. Preserve these boundaries and the existing routes, pairing, media models, station commands, and MediaKit integration.

## Current status

The shared Flutter visual language is implemented across the routed app: near-black scaffold with configurable blue glow, Manrope-led type roles, transparent app bars with scroll-under blur, shared spacing/radius tokens, responsive grids, and focus-aware reusable controls. The Appearance screen applies saved device-local preferences app-wide. The host-served HTML client's switch changes its appearance while retaining the same browser/player implementation.

The latest UI follow-up found no routed Flutter screen roots bypassing `AppScaffold`. The player now surfaces likely connection/codec/device failures, preserves playback position during automatic remote-stream retries, and gives Retry/Back actions. The TV home now adds a Recently played rail sourced from local history next to Continue Watching; the current progress and shelf indicator refresh from the local store when playback closes. The host-served browser client has network/codec/device diagnostics and resume-aware retries.

Verification update (31 October 2026): all 73 Flutter tests pass, including the splash, responsive-grid, loading-button, TV viewport, host-loss reconnect, WebSocket client-cap, file-stream cap, LAN browse, and media recovery checks. The current Android debug APK builds successfully, and the Web release build succeeded in the previous verification. Full analysis reports five existing info-level findings outside the LAN scanner and integration-test files; those changed files analyze cleanly. Windows build plus physical Android/Android TV display, remote, playback, and Wi-Fi interruption checks remain necessary on matching hardware/toolchains.

## Initial review priorities

1. **Correctness and access:** fix launch overlay coverage/state continuity, keep navigation available in library states, guard delayed UI callbacks, preserve hidden-player hit testing, and make primary controls readable.
2. **Shared design system:** centralize Manrope type roles and readable captions; reuse native Material buttons and one focusable action-card/grid implementation. Keep the existing transparent bars and blue-glow backdrop.
3. **Screen usability:** adapt action grids to width/text scale; improve manual connect keyboard handling; clarify search states; give remote controls readable labels and bounded content; present unknown storage honestly.
4. **Validation:** run the existing behavior suite and focused widget regressions covering splash lifetime, keyboard activation, loading buttons, contrast, and representative mobile/TV viewports with larger text.

## Baseline findings before the UI follow-ups

The findings below describe the state at the start of the review; they are not a current to-do list. Implemented changes are summarized in the next section.

| Screen family | Purpose / preserved actions | Findings and improvement direction |
| --- | --- | --- |
| Launch | Initialize app and reveal routed destination | Transparent splash content exposes home; changing child hierarchy can remount state. Keep one stable child subtree and an opaque, noninteractive splash layer. |
| Home, mobile and TV | Host or join, permission routing | Brand direction is established. Reuse typography and improve action semantics without changing entry routes. |
| Permissions | Media/audio/background requests and continue | Dense captions and long uppercase messages. Use shared typography, clear feedback, and guard deferred initialization. |
| Connect, mobile and TV | Discovery, manual address/code, QR, history | Duplicated action cards; fixed grid cells; manual sheet is not scrollable; discovery retry drops its callback. |
| Interface/mobile/TV gateways, including TV variants | Select browser/file view, join station, disconnect | Repeated action widgets and type styles; dense TV technical copy. Preserve each destination and station payload. |
| Mobile and TV media libraries | Featured media, category rails, queue, station playback | Empty/loading view replaces navigation; repeated featured items; fixed rail heights and limited search feedback. |
| Mobile and TV search | Query and play matching media | Initial state and no-match state look identical; missing TV back control; mobile results expose thumbnails without titles. |
| Mobile and TV file managers | Browse, sort, filter, search, play, download | Tiny metadata; home branch masks browse errors; generic TV empty states; deferred initialization needs mounted guards. |
| Downloads sheet | Progress, filter, cancel/delete, clear completed | Fabricated storage fallback; empty filtered list has no explanation; dense header can overflow. |
| Mobile and TV player + track/sync dialogs | Playback, seek, tracks, fit, speed, sleep, sync, remote input | White primary icon on white TV button; invisible OSD remains hit-testable; several icon controls lack readable labels. |
| Server dashboard and subpages | Host lifecycle, folders/filters, stations, traffic/logs/history, QR, preview, remote commands | Fourteen fixed square action cells dominate layout; hardcoded running status; repeated tiny typography. |
| Remote relay | Trackpad, navigation, text/intercom | Unbounded desktop width; controller not disposed; small uppercase labels and missing tooltips. |
| Shared states, cards, buttons, progress | Consistent feedback and input | Two duplicate button implementations; nested focus targets; progress renders nonzero for zero and rejects nonfinite input. |
| Appearance settings | Global font, title weight, glow, and radius controls | Preferences must flow through shared theme tokens and remain persisted locally. The settings route now updates the app-wide appearance. |

## Existing architectural limits

HTTP media endpoints remain unauthenticated LAN endpoints; browser codecs and native scanning/discovery differ. Downloads use native files, so Flutter Web download parity needs a separate implementation. The host-served HTML client remains separate from Flutter Web and uses browser media playback. This review does not change server contracts, release signing, or codecs. See [ARCHITECTURE.md](ARCHITECTURE.md) for those boundaries.

## Implemented in this review

- Centralized the Manrope scale in `AppTextStyles`, raised the smallest shared role to 12 logical pixels, and moved screen-level styles onto the shared roles.
- Kept the blue-glow scaffold at the app root and made the launch overlay preserve the mounted route. The splash absorbs input until it exits and respects reduced-motion settings.
- Consolidated the repeated action-grid/card patterns, made columns and tile height respond to viewport width and text scaling, and routed compact buttons through the shared button.
- Replaced the mobile and TV interface-selection station rows, plus mobile history rows, with the shared rounded `AppListTileCard`; station joining and history playback callbacks are unchanged.
- Standardized live station presentation across mobile and TV home rails, interface selection, browse-media gateways, and file managers. TV browse grids now use landscape station cards; the player station picker uses the same station rows, current-station indicator, and empty state. Station join/switch payloads and route behavior are unchanged.
- Restyled the mobile shared-queue rail with the library's heading scale, aligned content inset, card-based queue and empty states, and accessible vote controls. The existing queue vote command and delta values are preserved.
- Standardized app-bar back actions on the shared `AppBackButton`; route-specific back behavior and TV focus handling remain in their screens.
- Extended the premium server styling to network traffic, live logs, both connection/viewing history surfaces, remote relay, QR pairing/scanning, station management, sharing controls, and shared-folder browsing. Reused the common card, heading, row, button, and loading/empty/error components while preserving existing route, pairing, station, and server commands.
- Replaced the server's old no-device panel and legacy telemetry actions with the shared visual language; aligned cards to the same content inset and retained drag-to-transfer and remote-control behavior.
- Made remote navigation columns adapt to the available width and text scale. Moved shared-folder item counting off the UI isolate, kept counts visible, and surfaced directory access failures instead of reporting a false empty folder.
- Standardized modal sheets on `showAppBottomSheet`, `AppSheetHeader`, and `AppSheetOption`: matching dark surfaces and rounded corners, consistent headings and spacing, focusable actions, and no decorative horizontal rules. Downloads, remote control/media, pairing, interface preview, media actions, and manual connection retain their existing behaviors.
- Kept shared app bars fully transparent at scroll position zero, then enabled a clipped backdrop blur and subtle tint only when content overlaps the toolbar.
- Kept search and relay actions available when the client library is empty; distinguished an untouched search from a no-match result and showed media titles in mobile search results.
- Fixed manual discovery retries to reuse the real discovery callback, made the manual-IP sheet scroll around the keyboard, prevented hidden player OSD controls from taking pointer input, and corrected TV primary-control contrast.
- Removed fabricated disk-capacity defaults, gave filtered downloads an explicit empty state, bounded remote-relay content on wide displays, and disposed its text controller.
- Fixed mobile file-manager error precedence so a failed browse is shown instead of the home summary.
- Replaced the mobile file-manager's custom tap-only category and file cards with shared focusable cards. Its category grid and file grid now share `DS.responsiveColumns` and adapt to viewport width and text scale; list metadata wraps, and download controls have separate, labeled tap targets.
- Standardized download-sheet panels on `AppPanel`, removed the unreferenced technical-card component library and unused toggle widgets, and brought the remaining small secondary labels back to the 12 logical pixel type minimum.
- Aligned the native-host HTML client with the dark blue-glow background, Manrope type, compact responsive spacing, transparent blurred bars, rounded cards, readable mobile labels, safe-area spacing, visible keyboard focus, and reduced-motion preferences.
- Added a shared `PlaybackRecoveryOverlay` to both Flutter player screens. It explains likely network, codec, or device/browser causes and offers Retry or Back to library. Connection errors reopen the current stream at the captured/saved position using 2/4/8/16/30-second backoff capped at 30 seconds; pause and route disposal stop further retries.
- Added a Recently played rail to Android TV, mapped through the existing local playback history and current server media list. Continue Watching remains progress-backed, in-progress items are omitted from the recent rail to reduce duplication, and cards retain D-pad focus and playback/resume behavior.
- Added playback error panels, browser `online`/`offline` handling, capped retries, and playback-position restore to the host-served HTML client. Browser error categories use native media error codes where available.

## Validation record

- The previous UI pass's `flutter test --no-pub` run passed all 47 tests, including responsive file-grid behavior, host-browser theme/control contracts, and Android TV HD/4K logical viewport checks. Those results predate the playback-recovery and TV-home follow-up.
- For the browser-template consolidation, the unified inline JavaScript passed `node --check`; the full Flutter suite passed all 73 tests, and focused browser/TV tests passed after the TV key fix. Flutter analysis reports no errors and nine info-level lints elsewhere. Direct Dart formatting remains unavailable because the bundled Dart SDK crashes during macOS CPU-info initialization.
- Android debug and Web release builds in this follow-up stopped before project compilation because Flutter could not write the protected SDK cache at `/Applications/development/flutter/bin/cache`. This is an environment/tooling limit, so platform packaging was not confirmed in this run.
- Earlier review records include successful Android debug and Web release builds. Windows builds require a Windows host; physical phone, TV remote, overscan, and decoder checks were not available here.
- The HD/4K automated checks cover logical viewport layout only. They do not prove physical TV focus, display scaling, or media decoding.
- Playback error categorization is best-effort string/code mapping because MediaKit native and browser errors do not share a structured category API. Verify classifications against real failures on each target before treating a diagnosis as definitive.
