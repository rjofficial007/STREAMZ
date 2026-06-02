# Redesign TVFileManagerScreen to match Modern Web Interface

The goal is to overhaul `TVFileManagerScreen` to exactly match the look and feel of `kModernWebInterfaceHtml`. This involves moving navigation to the top, adding a persistent player console at the bottom, and making the grid responsive.

## Proposed Changes

### [Presentation Layer]

#### [tv_file_manager.dart](file:///C:/Github/Streamz/lib/presentation/tv/tv_file_manager.dart)

- **Layout Structure**: Change from `Sidebar + Header + Content` to `Header + Content + PlayerConsole`.
- **Top Dashboard**: Implement `_buildTopDashboard` containing:
    - Branding "STREAMZ" and "LIVE BROADCAST STATION" badge.
    - Navigation switches: VIDEOS, AUDIO, PHOTOS, NETWORK, STATIONS.
    - Search box with "CMD>" prefix.
- **Responsive Grid**:
    - Update `_buildContent` to calculate `crossAxisCount` dynamically based on screen width.
    - Width > 1200: 6 cols, > 900: 5 cols, > 600: 4 cols, else 3 cols.
- **Grid Cards**: Update `_TVGridCard` to:
    - Use 78/22 split for poster/info.
    - Apply grayscale filter when not focused.
    - Scale up and use white background when focused.
- **Bottom Player Console**: Implement `_buildPlayerConsole` containing:
    - LCD-style display for now playing info (Art, Title, Status).
    - Progress bar (LCD style).
    - Hardware-style controls: -10S, PLAY/PAUSE, +10S.
- **Logic Updates**:
    - Map HTML-style navigation tabs to existing `ClientViewModel` categories.
    - VIDEOS -> 'video', AUDIO -> 'audio', PHOTOS -> 'image', NETWORK -> 'root', STATIONS -> 'live'.

---

## Verification Plan

### Manual Verification
- **Visual Check**: Run the app and navigate to the TV File Manager. Verify it matches the `kModernWebInterfaceHtml` screenshots/code (Layout, Colors, Fonts).
- **Responsiveness**: Resize the window (if on desktop) or check on different devices/emulators to verify the grid column count adjusts correctly.
- **Navigation**: Click each tab in the top header and verify it loads the correct category.
- **Search**: Type in the search box and verify it filters the grid items.
- **Playback**: Open an item and verify `PlayerScreen` opens and works correctly.
- **Focus Management**: Navigate using arrow keys/D-pad and verify focus highlights and scaling work as expected.
- **Player Console**: Verify the bottom console shows "Idle" or "Awaiting Signal" (or real info if integrated with a global service).

> [!NOTE]
> Since `PlayerViewModel` is currently local to `PlayerScreen`, the bottom console in `TVFileManagerScreen` will primarily show the "Idle" state unless we refactor the player to be global. For this task, we will focus on the UI layout of the console to match the HTML design.
