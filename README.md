# STREAMZ — BROADCAST ENGINE v2.0

![Aesthetic](https://img.shields.io/badge/AESTHETIC-STRICT_BRUTALIST-white?style=flat-square)
![Architecture](https://img.shields.io/badge/ARCH-MVVM_SINGLETON-white?style=flat-square)
![Status](https://img.shields.io/badge/STATUS-UPLINK_READY-white?style=flat-square)

**STREAMZ** is a local-network media architecture for the modern curator. One device runs the broadcast host (HTTP + WebSocket server, UDP discovery); every other device — Flutter mobile/TV/desktop or a plain web browser — discovers it, streams the library, and can be controlled remotely through a professional brutalist interface.

---

## ⚡ CORE CAPABILITIES

### 🛰️ NOC COMMAND CENTER
A high-density Command Center on the host: monitor every connected node, control playback remotely over the WebSocket relay, view live sessions, and manage the library and stations from a single dashboard (with a built-in CLI).

### 🌈 VIBE-SYNC
Ambient color feedback across nodes: the active item's palette (keyed per item) plus periodic low-resolution screen snapshots from the playing node are relayed to the other devices' dashboards. It's a fixed palette + snapshot pipeline — not per-frame color analysis of the media.

### 🚀 LAN STREAMING
Source-bitrate streaming over plain HTTP range requests (no transcode, no DRM, no server-side codec work) — a gigabit LAN is recommended for high-bitrate video. There is no adaptive bitrate and no frame-pacing guarantee; playback quality is a function of your network.

### 📡 STATION ENGINE
Host-managed virtual broadcast stations: a curated playlist that auto-advances and loops. Nodes that join are kept in lockstep by a master/slave drift-correction loop (500 ms position sync, ~200 ms correction threshold) — the first node to join becomes the sync master, later joiners follow, including across track boundaries.

---

## 🏗️ ARCHITECTURAL STACK

*   **Frontend**: Flutter (strict black & white theme; TV-optimized variants)
*   **State Management**: Provider with singleton ViewModels (MVVM) + GetIt service locator
*   **Networking**: UDP auto-discovery (port 8888) & WebSocket command relay (port 8080)
*   **Media Engine**: Media Kit (MPV) for decoding; shelf for HTTP
*   **Lifecycle**: Persistent server lifecycle manager (wakelock + background keep-alive)

---

## 🔧 INSTALLATION & SETUP

1.  **HOST CLONE**:
    ```bash
    git clone https://github.com/rjofficial007/STREAMZ.git
    cd STREAMZ
    ```

2.  **DEPENDENCY UPLINK**:
    ```bash
    flutter pub get
    ```

3.  **EXECUTE (HOST)**:
    ```bash
    flutter run -d <host-device>
    ```
    Start the server from the dashboard. The host shows a QR code and an 8-character pairing code.

4.  **EXECUTE (CLIENTS)**:
    Run the app on any other device and either scan the host's QR or enter the host IP + pairing code. Browsers can open the host's URL directly (the pairing code travels in the link).

---

## 📋 SYSTEM SPECIFICATIONS

*   **Protocol**: UDP discovery on port 8888 (multicast `239.1.2.3` + LAN broadcast; announcements carry the pairing code). HTTP + WebSocket on port 8080.
*   **Pairing**: an 8-character pairing code (stable per host) gates the WebSocket **control plane** — presented as the WS subprotocol; wrong or missing code means media-only (read-only) access. There is **no encryption**: everything is plaintext on your LAN by design. Do not expose ports 8080/8888 beyond your own network.
*   **Interface**: Brutalist UI (zero radius, high contrast).
*   **Relay**: Intercom alerts with automatic volume ducking and visual feedback on all nodes.
*   **NO_TRACE mode**: disables the host's connection logging when enabled in the dashboard.

---

## ⚖️ LICENSE

© 2026 BROADCAST ARCHITECTURE. All rights reserved.
