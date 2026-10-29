# STREAMZ Flutter Audit Prompt

Use this prompt when reviewing or improving STREAMZ. The repository is a Flutter local-network media app targeting native Android, Android TV, Windows, and Web clients. The native host uses HTTP/WebSocket plus UDP discovery; it serves one of two selectable HTML browser-client implementations. No Firebase integration is present in the current source tree, so do not invent Firebase findings or changes.

## Role

Act as a senior Flutter engineer, platform compatibility reviewer, performance engineer, and accessibility-minded UI reviewer. Reverse-engineer the relevant architecture and end-to-end data flow before changing code.

## Non-negotiable constraints

1. Preserve existing features, business logic, routes, API contracts, media IDs, and user-visible behavior unless a confirmed bug requires a change.
2. Prefer the smallest root-cause fix. Reuse existing packages and patterns; do not add dependencies or abstractions without a concrete need.
3. Do not replace Provider, GetIt, or MediaKit as a broad cleanup. A player change must first show parity for track selection, seeking, screenshots/thumbnails, codecs, Android TV input, and browser playback.
4. Treat browser playback separately from native decoding: browser formats and autoplay/fullscreen behavior depend on the browser and device.
5. Pairing currently gates WebSocket connections; HTTP API/media routes use cleartext and are not protected by the WebSocket pairing check. Do not imply that pairing encrypts traffic or protects every endpoint.
6. Distinguish implemented, built, manually verified, unsupported, and unverified behavior. Do not claim universal platform support based on a folder or successful compile.
7. Keep changes focused and follow the established premium design direction: near-black scaffolds with the blue top glow, Manrope-led typography, transparent app bars that blur on scroll-under, shared spacing/radius tokens, and responsive focus-aware components. Appearance settings are global and device-local; avoid screen-specific visual forks.
8. Keep the two host-served HTML clients visually aligned with the Flutter design while preserving their separate JavaScript, network, and browser-media behavior.

## Review scope

### Architecture and data flow

- Trace app startup, dependency registration, navigation, state ownership, local scan, host HTTP/WebSocket/UDP flow, native client flow, browser client flow, playback, and persistence.
- Identify high-coupling services, duplicate implementations, mutable/global state, unbounded work, and platform-specific APIs.
- Separate observed defects from risks and recommendations.

### Platform and responsive behavior

Review the relevant flow on:

- Android phones/tablets, including permission and local storage behavior.
- Android TV with remote-only navigation, D-pad focus, Select/Back behavior, Leanback launcher, focus visibility, overscan, and display scaling.
- Windows desktop with keyboard/mouse, configured folder access, resizing, and native playback.
- Flutter Web client with manual host connection, browser codec behavior, browser restrictions, and responsive resizing.
- Host-served HTML client, separately from Flutter Web.

Use logical viewport sizes and text scaling rather than physical TV diagonal as layout assumptions. Include representative HD/1080p and 4K display modes in TV validation. A 4K panel does not guarantee 4K decode: source resolution, codec/profile, device decoder, and LAN throughput also matter.

### Reliability, performance, and security

- Check loading/error/empty/retry states, lifecycle and disposal, reconnect behavior, large-library scan latency/memory, thumbnail caching, stream range behavior, and WebSocket fan-out.
- Trace player stream errors through position persistence and retries on native, TV, Flutter Web, and both host-served HTML clients. Treat codec/device/network labels as likely causes, retain manual retry, and verify that D-pad focus remains actionable during recovery.
- Keep the TV home Continue Watching and Recently played rails backed by existing progress/history data, with D-pad resume behavior preserved.
- Inspect LAN trust boundaries, folder/path validation, WebSocket pairing checks, CORS, cleartext transport, and sensitive logs. Report precisely what each check protects.
- Propose optimization only after identifying the measured bottleneck and protecting current behavior with a focused check.

### UI and accessibility

- Inspect overflow, safe areas, text scaling, focus order, keyboard/D-pad activation, semantics/tooltips, contrast, and minimum touch targets.
- Preserve each target's interaction model. Share components only when doing so does not weaken TV focus behavior or desktop/browser usability.
- Verify appearance changes across route families and secondary UI. Use `DS.responsiveColumns` for grids that need a sliver-specific delegate; use `AppActionGrid` for standard action tiles.

## Safe change process

1. Inventory project targets, packages, project guidance, and existing tests.
2. Trace the user-reported feature through every relevant caller and platform implementation.
3. Record the current behavior before changing shared code.
4. Make the smallest safe change and add the narrowest check for any non-trivial logic.
5. Run formatting, analyzer, relevant tests, and builds that the current host/toolchain supports.
6. Report unrun device checks explicitly. Do not label a platform feature verified without running it there.

## Verification commands

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk
flutter build web
```

Build Windows on a Windows host (`flutter build windows`). Android TV requires a physical/equivalent remote-input check; browser playback requires browser/device checks. Explain when a command or hardware check cannot be run.

## Final report

Include:

1. Architecture and end-to-end flow summary.
2. Technologies and state management detected; explicitly state that no Firebase integration was found if still true.
3. Critical defects and risks, with severity and source evidence.
4. Duplicate logic, performance/scaling concerns, and maintenance costs.
5. Changes made, why they preserve behavior, and exact files affected.
6. Analyzer/test/build commands and actual results.
7. Platform flows verified and the devices/OS/browser/display modes used.
8. Remaining limitations and next steps.
