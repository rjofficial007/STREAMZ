# Hestia

Hestia is a local-network media library and playback app. A native Android or Windows device can host a media library over HTTP, while Flutter clients and ordinary browsers connect over the LAN. Android TV uses the Android app with a Leanback launcher entry and remote-friendly screens.

## Supported targets

| Target | Current implementation | Important limits |
| --- | --- | --- |
| Android phones and tablets | Flutter app; can host or connect as a client; scans configured/shared media sources | Android permissions, device codecs, storage access, and background-service policies affect behavior. |
| Android TV | Android app declares the Leanback launcher feature; TV detection, D-pad/Select shortcuts, focus-aware screens, and a TV banner are present | It is the Android build, not a separate TV binary. Validate navigation and playback on actual TV hardware. |
| Windows | Flutter desktop app; can host or connect as a client; scans configured folders | Media support depends on the bundled MediaKit backend and available system resources. Build and verify on Windows. |
| Flutter Web | Flutter browser build intended for client use | Browser codecs determine playback support. Web media scanning is disabled; local hosting and native LAN discovery are not supported by the current flow. |
| Browser client | The native host serves one responsive modern HTML/JavaScript client at `http://<host-ip>:8080/` | This is separate from the Flutter Web build. Playback uses the browser's media element and codec support. |

The repository has Android, Windows, and Web Flutter targets. That alone does not establish feature parity on every device. See [Architecture and platform notes](docs/ARCHITECTURE.md) for the implemented data flows, known limits, and a verification matrix.

## What the app does

- Scans configured local media on native host platforms and exposes media metadata, thumbnails, files, and byte-range streams over HTTP.
- Discovers native hosts on the LAN with Bonjour/mDNS, keeps the existing UDP fallback, or lets a client connect using the host IP and pairing link/code.
- Uses a WebSocket ready handshake, heartbeat, capped reconnect backoff, and state refresh for playback commands, session status, station/queue updates, and remote control.
- Supports host-managed broadcast stations and synchronized playback flows.
- Saves client playback progress locally, surfaces Continue Watching, and retries interrupted remote streams while retaining the last useful playback position.
- Opens the host's browser client inside Hestia on Android/TV and Windows. Flutter Web embeds it in an iframe, subject to the browser's same-origin and mixed-content rules.
- Uses MediaKit for Flutter playback. Browser playback uses browser-provided media support; supported codecs vary by browser and device.

Streaming sends the original media bytes without server-side transcoding. Playback smoothness and maximum resolution depend on the source file, client decoder, network throughput, and device performance. The app cannot guarantee 4K playback merely because a TV panel is 4K.

## Architecture

The app is organized into presentation/ViewModels, domain models and services, data repositories, and platform/network infrastructure. GetIt registers shared services and the main client/server ViewModels; Provider exposes them to Flutter screens. The host's HTTP/WebSocket service, mDNS/UDP discovery, local scanning, MediaKit playback, and the browser client are described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Shared typography, the blue-glow scaffold, transparent/scroll-blurred app bars, responsive grids, focus handling, and accessible UI primitives are documented in [docs/UI_COMPONENTS.md](docs/UI_COMPONENTS.md). `ThemeService` persists font family, title weight, scaffold glow color, and shared corner radius on the device. The route inventory, UI review, and latest validation record are in [docs/UX_REVIEW.md](docs/UX_REVIEW.md).

## Development

Install Flutter/Dart compatible with the SDK constraint in `pubspec.yaml`, then run:

```sh
flutter pub get
flutter analyze
flutter test
```

Run or build on a supported target:

```sh
flutter run -d <android-device>
flutter run -d windows
flutter run -d chrome

flutter build apk
flutter build windows
flutter build web
```

Windows builds require a Windows development environment and the NuGet CLI on `PATH` for the embedded WebView. Android TV uses the Android APK; validate on a TV or equivalent D-pad device. The browser-served client is provided by a running native host and is not launched by `flutter run -d chrome`.

Latest verification (31 October 2026): all 73 Flutter tests pass, including host-loss reconnect, 32-client WebSocket and eight-file-stream admission, LAN browse capacity, large-library paging/indexing, and reconnect snapshot/catalog revision coverage. The current Android debug APK builds successfully, and the Web release build succeeded in the previous verification. Full analysis has five existing info-level findings in unrelated files; the LAN scanner and integration-test files analyze cleanly. Windows builds and physical Android/TV Wi-Fi interruption checks still require matching hardware/toolchains. See [docs/UX_REVIEW.md](docs/UX_REVIEW.md) for UI-specific review notes.

## LAN and security notes

- The native host listens on TCP port `8080`; native discovery uses Bonjour/mDNS with UDP fallback on port `8888`. Firewalls, guest Wi-Fi isolation, and router multicast settings can prevent discovery or streaming. Flutter Web discovery remains disabled.
- The pairing token is required for the WebSocket control connection. HTTP metadata, file, thumbnail, and stream routes are not protected by that WebSocket pairing check.
- LAN traffic is plain HTTP/WebSocket without TLS. Run Hestia only on a network you trust; do not expose these ports directly to the public internet.
- Streaming is source-bitrate. A high-bitrate file needs sufficient LAN throughput; there is no adaptive bitrate or transcoding fallback.

## TV and responsive behavior

Layouts use Flutter logical viewport dimensions and TV-device detection. The source includes responsive breakpoints and focus/D-pad handling, but physical diagonal size (for example, 32 or 65 inches) is not a layout guarantee. Resolution, density, overscan, viewing distance, remote behavior, and decoder capability vary by device. Validate at HD/1080p and 4K output sizes, with remote-only navigation, before claiming TV-wide compatibility.

## Current player choice

MediaKit remains the app's Flutter playback engine because the player flow relies on its controls, track selection, and thumbnail/screenshot behavior. Replacing it with `video_player` plus another backend would require a parity review, especially for thumbnails, audio/subtitle tracks, TV remote navigation, and the browser path. A prior Android build attempt timed out while fetching a MediaKit native artifact; treat that as a dependency-download/build-environment issue until a runtime playback problem is reproduced.
