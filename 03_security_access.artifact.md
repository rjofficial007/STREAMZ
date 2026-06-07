# 03 Security & Access Document — STREAMZ

## 1. Security Philosophy
STREAMZ operates on a **Local-First, Privacy-by-Default** model. Since the application is designed for trusted local home networks, the focus is on preventing accidental data exposure and ensuring that only authorized local devices can interact with the Broadcaster.

---

## 2. Network Security

### 2.1. Local Network Isolation
- **No Cloud Tunneling:** By design, STREAMZ does not implement NAT traversal or cloud relaying. Data never leaves the local subnet.
- **Port Management:** The Broadcaster uses a configurable but deterministic port (default: 8080) for the HTTP server.

### 2.2. UDP Discovery Privacy
- **Broadcast Payload:** The UDP discovery packet contains only the device name and IP. No file paths or personal metadata are broadcasted until a direct connection is established.
- **Opt-out:** Users can disable "Discoverability" to keep their Broadcaster hidden from other clients on the network.

---

## 3. Data Privacy

### 3.1. Zero Tracking
- **Telemetry:** No analytics or usage tracking is implemented.
- **Logs:** Application logs remain on-device and are not transmitted to any external server.

### 3.2. Metadata Storage
- **Local Database:** All cached thumbnails, watch progress, and library metadata are stored in the application's private data directory (e.g., `AppData` on Windows, `data/user/0` on Android).

---

## 4. Resource Access & Permissions

### 4.1. File System Access
- **Explicit Scoping:** The Broadcaster only has access to directories explicitly selected by the user.
- **Read-Only Server:** The HTTP server is strictly read-only for media files. There are no "Write" or "Delete" endpoints exposed over the network to prevent remote file manipulation.

### 4.2. OS-Level Permissions
| Platform | Requirement | Purpose |
| :--- | :--- | :--- |
| **Android** | `READ_EXTERNAL_STORAGE` | Accessing media files (older versions). |
| **Android** | `MANAGE_EXTERNAL_STORAGE` | Required for comprehensive media scanning on Android 11+. |
| **Android** | `INTERNET` | Creating the local HTTP server and UDP discovery. |
| **Windows** | Firewall Exception | Allowing incoming TCP/UDP traffic for the local network. |

---

## 5. Client Authentication (Roadmap)
In future versions, a "Pairing Code" system (similar to YouTube on TV) will be implemented to prevent neighbors on shared Wi-Fi networks from accidentally (or maliciously) casting to a STREAMZ Receiver.

---

**Approval Status:** Pending Review
