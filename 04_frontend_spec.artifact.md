# 04 Frontend Specification Document — STREAMZ

## 1. Design Philosophy: "Brutalist Digital"
STREAMZ rejects the "softness" of modern SaaS interfaces. The UI is built on the principles of **Rawness, Density, and Contrast**.

- **Zero Radius:** No rounded corners. Every element is a sharp rectangle.
- **High Contrast:** Pure OLED Black (#000000) and Stark White (#FFFFFF).
- **Typography-First:** Information hierarchy is established through font weight and size, not icons or shadows.
- **Micro-Interactions:** Snappy transitions, no bouncy animations. Performance over "eye-candy."

---

## 2. Design Tokens (The "DS" System)

### 2.1. Color Palette
- `Background`: #000000 (OLED Black)
- `Surface`: #111111 (Dark Grey)
- `Primary`: #FFFFFF (Stark White)
- `Accent`: #FF3D00 (Blaze Orange) — Used sparingly for highlights (e.g., active play state).
- `Muted`: #444444 (Grey) — Used for secondary metadata.

### 2.2. Typography
- **Headlines:** `Barlow Condensed` (Heavy weight, All-caps).
- **Body/Metadata:** `DM Mono` (Fixed-width for a technical, raw feel).

### 2.3. Spacing & Borders
- **Grid:** 8px base unit.
- **Borders:** 1px or 2px solid white for buttons and containers. No shadows.

---

## 3. Platform Adaptations

### 3.1. Mobile (Touch)
- Large tap targets (minimum 48x48px).
- Vertical scrolling for media libraries.
- Bottom-sheet for playback controls.

### 3.2. TV (D-Pad / 10-foot UI)
- **Focus System:** High-visibility border around the focused element (Orange border or White fill).
- **Navigation:** Horizontal carousels for categories (Movies, Recent, Series).
- **Input:** Optimized for remote control (Up/Down/Left/Right/Select).

---

## 4. Key UI Components

### 4.1. Media Tile
- A vertical rectangle showing the thumbnail or a placeholder with the file name in `DM Mono`.
- On focus/hover: Show the full title and duration in a sharp overlay.

### 4.2. Control Bar
- Minimalist playback controls: `PLAY/PAUSE`, `SEEK`, `VOLUME`.
- A 2px high progress bar spanning the full width of the screen.

### 4.3. Connection Dashboard
- A technical-looking status screen showing:
    - Current Role (Broadcaster/Receiver)
    - IP Address
    - Number of connected clients
    - Real-time stream bitrate (optional)

---

## 5. View States
- **Empty State:** "NO MEDIA FOUND" in large Barlow Condensed type.
- **Loading State:** A stark, non-animated progress bar or "SCANNING..." text.
- **Error State:** High-contrast Blaze Orange banner with a technical error code.

---

**Approval Status:** Pending Review
