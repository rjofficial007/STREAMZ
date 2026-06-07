# 05 Feature Ticket List — STREAMZ

This list breaks down the initial development phase into actionable tickets, categorized by architectural layer.

## [EPIC 01] Core Infrastructure & Design System

### T-101: Initialize Design System (DS) Tokens
- **Description:** Implement the `design_tokens.dart` and `app_theme.dart` with the Brutalist specification.
- **Tasks:**
    - Define color constants (#000000, #FFFFFF, #FF3D00).
    - Configure `ThemeData` with zero corner radius for all widgets.
    - Set up Barlow Condensed and DM Mono font families.
- **Acceptance Criteria:** UI elements show sharp 90-degree corners and high-contrast typography.

### T-102: Service Locator & Dependency Injection
- **Description:** Set up `GetIt` for central service management.
- **Tasks:**
    - Register `NetworkService`, `MediaService`, and `ThemeService`.
    - Implement a basic `Logger` utility for debugging.

---

## [EPIC 02] Networking & Discovery

### T-201: UDP Discovery Service
- **Description:** Implement zero-config broadcaster detection.
- **Tasks:**
    - Create `UDPBroadcaster` to send presence packets every 5 seconds.
    - Create `UDPScanner` to listen for packets and update the available server list.
- **Acceptance Criteria:** A "Receiver" device automatically lists "Broadcaster" devices on the same Wi-Fi.

### T-202: Shelf-based Media Server
- **Description:** Build the local HTTP server to serve media files.
- **Tasks:**
    - Implement `HttpServer` using the `shelf` package.
    - Add support for "Range" headers (essential for video seeking).
    - Create an endpoint `/metadata` that returns the media library in JSON.

---

## [EPIC 03] Media Management

### T-301: Fast Media Scanner
- **Description:** Scan local directories for video and audio files.
- **Tasks:**
    - Implement a recursive file system walker in a separate Isolate.
    - Filter for common extensions (mp4, mkv, mp3).
    - Extract basic metadata (filename, size, path).

### T-302: Thumbnail Generation Engine
- **Description:** Generate and cache video previews.
- **Tasks:**
    - Integrate `video_thumbnail` or native FFmpeg hooks.
    - Implement a local cache store to prevent re-generating thumbnails on every launch.

---

## [EPIC 04] UI & Playback

### T-401: Multi-Role Selection Screen
- **Description:** The entry point where users choose "Broadcaster" or "Receiver".
- **Tasks:**
    - Build a high-contrast split-screen or dual-button layout.
    - Persist the user's choice for the next launch.

### T-402: TV-Optimized Media Browser
- **Description:** A 10-foot UI for browsing content on a TV.
- **Tasks:**
    - Implement a focus-aware GridView or ListView.
    - Ensure D-pad navigation moves focus correctly between tiles.
    - Display "Blaze Orange" border on focused items.

### T-403: MediaKit Player Integration
- **Description:** Core playback engine implementation.
- **Tasks:**
    - Integrate `media_kit` for cross-platform playback.
    - Build a custom "Brutalist" control overlay (Play/Pause/Progress bar).

---

## [EPIC 05] Remote Control

### T-501: Remote Command API
- **Description:** Control a Receiver from a Broadcaster (or another Receiver).
- **Tasks:**
    - Implement `/command` endpoint on the HTTP server.
    - Support `play`, `pause`, and `seek_to` actions.

---

**Approval Status:** Pending Review
