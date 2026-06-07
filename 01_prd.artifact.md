# 01 Product Requirements Document (PRD) — STREAMZ

## 1. Executive Summary
**Project Name:** STREAMZ
**Vision:** To redefine local media consumption through a high-performance, privacy-first streaming ecosystem that bridges the gap between personal media storage and cross-device playback. STREAMZ focuses on a "Brutalist" aesthetic—prioritizing function, high contrast, and raw typography—to provide a distraction-free entertainment experience.

---

## 2. Core Problem Statement
Existing media streaming solutions often require complex cloud configurations, subscription fees, or have bloated interfaces that perform poorly on low-power devices like Smart TVs. Users with personal media collections lack a simple, "it just works" way to broadcast their library from a PC or phone to other screens on their local network without data leaving their house.

---

## 3. Target Audience
- **The Home Labber:** Users with large local media libraries who want a modern interface to browse and play content.
- **The Privacy Conscious:** Users who refuse to upload personal data to cloud services.
- **The Shared Household:** Families who want to stream a movie from the "main PC" to a bedroom TV or a tablet.

---

## 4. Key Features & Functional Requirements

### 4.1. Dual-Role Architecture (Broadcaster/Receiver)
- **Feature:** Users can choose to run the app as a **Server (Broadcaster)** or a **Client (Receiver)**.
- **Requirement:** A single codebase must handle both roles efficiently, sharing core logic for media scanning and networking.

### 4.2. Local Discovery (Zero-Config)
- **Feature:** Automatic server detection using UDP discovery.
- **Requirement:** Clients must find active broadcasters on the same subnet without requiring manual IP entry.

### 4.3. Unified Media Playback
- **Feature:** High-fidelity video and audio playback.
- **Requirement:** Integration with `media_kit` for hardware-accelerated decoding across Windows, Android, and TV.

### 4.4. "Brutalist" Design System
- **Feature:** A high-contrast, zero-radius, typography-heavy UI.
- **Requirement:** Implementation of the `DS` (Design System) tokens for spacing, typography (Barlow Condensed, DM Mono), and colors (OLED Black, Stark White).

### 4.5. Remote Commands
- **Feature:** Control playback on one device from another.
- **Requirement:** Low-latency WebSockets or HTTP endpoints to send "Play/Pause/Seek" commands between devices.

---

## 5. Non-Functional Requirements
- **Performance:** App must launch and be ready for discovery in < 3 seconds.
- **Scalability:** The UI must adapt seamlessly from mobile (portrait) to TV (10-foot interface with D-pad navigation).
- **Reliability:** Background execution support for servers (Broadcasters) to prevent stream interruption.

---

## 6. User Journeys
1. **The Setup:** User opens the app on a PC, selects "Broadcaster" mode, and points it to their "Movies" folder.
2. **The Connection:** User opens the app on an Android TV. It automatically detects the PC server.
3. **The Playback:** User selects a movie using the TV remote. The stream starts instantly over the local network.

---

## 7. Future Scope (V2)
- Multi-user profiles with watch progress sync.
- External subtitle (SRT/VTT) side-loading.
- Transcoding support for low-bandwidth scenarios.

---

**Approval Status:** Pending Review
