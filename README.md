# STREAMZ // BROADCAST SYSTEM

**ZERO CONFIGURATION. PURE SIGNAL.**

STREAMZ is a premium, cross-platform local media broadcasting system. Built with Flutter, it seamlessly transforms any device into a high-performance local server or a receiving client node. It features a brutalist, high-contrast UI/UX, unified remote control telemetry, and multi-format media streaming without the need for external cloud infrastructure.

---

## 🚀 CORE CAPABILITIES

### **SERVER NODE (NOC)**
*   **Zero-Config HTTP Engine:** Hosts a local REST API and Web server using `shelf` and `shelf_router`.
*   **UDP Auto-Discovery:** Broadcasts its presence across the local subnet (`239.1.2.3` multicast) for instant client pairing.
*   **Media Indexing:** Deep scans device storage for Videos, Audio, and Images using `photo_manager` and `on_audio_query`.
*   **Live Telemetry:** Real-time dashboard tracking connected nodes, outbound bandwidth (MB/s), and active playback progress via WebSockets.
*   **Universal Remote:** Built-in D-Pad and media controls to hijack and command any connected client screen.

### **CLIENT NODE**
*   **Multi-Modal Interfaces:**
    *   **Modern UI:** A Netflix-style, horizontal-rail interface optimized for both Mobile and TV (10-foot UI).
    *   **System Directory:** A raw, dual-pane file manager for precise directory navigation.
*   **Seamless Handshake:** Connect via UDP Discovery, QR Code scanning (`mobile_scanner`), or manual IPv4 entry.
*   **Universal Playback:** Hardware-accelerated video and audio streaming powered by `media_kit`.
*   **Download Manager:** Background-capable download service to cache payloads locally.

### **WEB STUDIO**
*   **Built-in Web Client:** Access the server from any desktop browser via `http://<SERVER_IP>:8080`.
*   **Crosshair Navigation:** A pure HTML/CSS/JS brutalist web interface synced instantly with the server's WebSocket telemetry.

---

## 🏗️ ARCHITECTURE & STACK

The codebase strictly adheres to **Clean Architecture** principles, decoupling the domain logic from the presentation layer.

*   **Framework:** Flutter (Android, iOS, Windows, macOS, Linux, Web)
*   **State Management:** `Provider` + `ChangeNotifier`
*   **Dependency Injection:** `GetIt` (Service Locator Pattern)
*   **Media Engine:** `media_kit` (libmpv backend)
*   **Local Server:** `shelf`, `shelf_router`, `shelf_web_socket`
*   **Persistence:** `shared_preferences` (Progress caching, IP history)
*   **Network:** `http`, UDP Multicast (`RawDatagramSocket`), WebSockets

### **Directory Structure**
```text
lib/
├── core/
│   ├── di/               # Service Locator (GetIt)
│   ├── theme/            # Brutalist Design Tokens (DS) & AppTheme
│   └── utils/            # FileType parsers, formatters
├── data/
│   ├── local/            # MediaScanner, ProgressStore, ThumbnailCache
│   ├── network/          # HttpServer, UdpDiscovery, MediaApiClient, Web HTML
│   └── repositories/     # MediaRepository, ServerRepository
├── domain/
│   ├── models/           # MediaItem, StreamSession, ConnectionRecord
│   └── services/         # PlayerService, DownloadService, RemoteCommandService
└── presentation/
    ├── client/           # Client Connection, ViewModels
    ├── home/             # Role Selection, Permissions
    ├── mobile/           # Mobile Selection, File Manager, Download Sheet
    ├── player/           # Universal Media Player
    ├── server/           # NOC Dashboard, ViewModels
    ├── shared/           # Shared UI components
    └── tv/               # 10-Foot UI: Rails, File Manager, Selection Gateway
```

---

## 🎨 DESIGN SYSTEM // BRUTALIST

The UI/UX abandons traditional Material Design soft corners and elevations in favor of a **High-Contrast Brutalist Aesthetic**.

*   **Palette:** Absolute Black (`#000000`), Stark White (`#FFFFFF`), and High-Visibility Accents.
*   **Geometry:** Strict zero-radius (`radius0`) borders. Sharp edges only.
*   **Typography:**
    *   **Barlow Condensed:** Used for massive, high-impact display headers.
    *   **DM Mono:** Used for technical data, labels, meta-information, and badges.
    *   **Barlow:** Used for readable body copy.
*   **Focus Engine:** Engineered explicitly for TV remote control (D-Pad). Focus rings utilize scale animations, stark border highlights, and shadow offsets to provide undeniable visual feedback across the room.

---

## ⚙️ SETUP & DEPLOYMENT

### **1. Prerequisites**
*   Flutter SDK `^3.10.4`
*   Android Studio / Xcode / Visual Studio (depending on target platform)

### **2. Installation**
```bash
# Clone the repository
git clone <your-repo-url>
cd streamz

# Fetch dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### **3. Permissions Note**
STREAMZ requires comprehensive storage permissions to function as a server.
*   **Android:** Requests `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES`, and `MANAGE_EXTERNAL_STORAGE`. It also utilizes `FOREGROUND_SERVICE` and `WAKE_LOCK` to keep the broadcast engine alive when the app is backgrounded.
*   **Windows/macOS/Linux:** Automatically inherits the user's filesystem permissions.

---

## 🔒 SECURITY & ROUTING
*   **Path Traversal Prevention:** The internal HTTP server utilizes normalized path resolution (`_isPathAllowed`) to prevent `../` directory traversal attacks.
*   **Network Isolation:** Broadcasts and WebSockets are restricted to the local subnet. Localhost (`127.0.0.1`) accesses are ignored in telemetry to prevent log spam during internal previews.

---