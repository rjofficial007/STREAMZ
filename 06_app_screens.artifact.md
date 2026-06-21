# 06 App Screens Overview — STREAMZ

This document provides a comprehensive list of all screens within the STREAMZ application, categorized by their primary role and functionality.

---

## 1. Core & Entry Screens
These screens handle the initial application state and global configurations.

| Screen Name | File Path | Functionality |
| :--- | :--- | :--- |
| **Role Selection** | `role_selection_screen.dart` | The initial entry point. Users choose between **Broadcaster (Server)** and **Receiver (Client)** roles. |
| **Permission Setup** | `permission_screen.dart` | A Samsung-style setup wizard for granting storage, media, and background execution permissions. |
| **Theme Settings** | `theme_settings_screen.dart` | Allows users to toggle between different visual styles (e.g., Brutalist White, OLED Black, Matrix Green). |

---

## 2. Server (Broadcaster) Mode
Screens active when the device is acting as the media source.

| Screen Name | File Path | Functionality |
| :--- | :--- | :--- |
| **Server Dashboard** | `server_dashboard.dart` | The "NOC Dashboard". Shows server status, IP/Port, active stations, connected clients, and provides a pairing QR code. |

---

## 3. Client (Receiver) Mode
Screens used to connect to and browse content from a broadcaster.

| Screen Name | File Path | Functionality |
| :--- | :--- | :--- |
| **Client Connection** | `client_connect_screen.dart` | Handles server discovery. Supports UDP auto-discovery, manual IP input, and QR code pairing. |
| **QR Scanner** | `qr_scanner_screen.dart` | Uses the camera to scan a server's pairing code for instant connection. |
| **Interface Gateway** | `interface_selection_screen.dart` | Appears after connecting. Allows the user to choose their preferred browsing UI (TV vs. Mobile). |

---

## 4. TV-Optimized Interfaces (10-Foot UI)
Designed specifically for D-Pad navigation and large-screen visibility.

| Screen Name | File Path | Functionality |
| :--- | :--- | :--- |
| **TV Home** | `tv_home_screen.dart` | A high-contrast, focus-based home screen for browsing media libraries with a remote. |
| **TV File Manager** | `tv_file_manager.dart` | A technical list view for navigating deep directory structures on the server. |
| **TV Dedicated Player** | `tv_player_screen.dart` | Full-screen media player with oversized controls and focus-management for TV remotes. |

---

## 5. Mobile & Tablet Interfaces
Optimized for touch-first interaction and varying screen orientations.

| Screen Name | File Path | Functionality |
| :--- | :--- | :--- |
| **Modern Mobile UI** | `modern_mobile_ui.dart` | An edge-to-edge, immersive media browser with high-density layouts. |
| **Mobile File Manager** | `file_manager.dart` | Provides quick access to media categories (Images, Videos, Audio) and local/remote file trees. |
| **Universal Player** | `player_screen.dart` | The core media engine for mobile/desktop, supporting gestures, seeking, and volume control. |

---

## Technical Note: Adaptive Layouts & TV Variants
Streamz uses a "Dual-UI" system to ensure a seamless experience across different hardware:

- **Specialized Overrides:** Several screens have companion files ending in `_tv.dart` (e.g., `role_selection_screen_tv.dart`).
- **Logical Unity:** These are not distinct logical screens but rather **specialized layout overrides**.
- **Dynamic Swapping:** The application dynamically swaps between these implementations based on the detected device type (Android TV vs. Mobile) and the active input method (D-Pad/Remote vs. Touch).
- **Focus Management:** The `_tv` variants are specifically engineered for focus-based navigation, ensuring that the "Brutalist" aesthetic remains usable even from 10 feet away.
