# Implementation Plan - STREAMZ STATION BROADCASTS

> Historical planning artifact from May 2026. It records a proposal from that task and is not a statement of current implementation status. Use the [current architecture](../../docs/ARCHITECTURE.md), [UI component guide](../../docs/UI_COMPONENTS.md), and [README](../../README.md) as the source of truth.

This feature transforms the local media server into a professional broadcasting station. Users can create "Stations" (playlists) that play linearly in the background on the server. Clients "Tune In" to these stations and watch/listen to the same content at the same time, with perfect synchronization.

## Proposed Changes

### Domain & Services

#### [NEW] [broadcast_station.dart](file:///C:/Github/Streamz/lib/domain/models/broadcast_station.dart)
- Define the `BroadcastStation` model: `id`, `name`, `playlist` (List<MediaItem>), `startTime` (DateTime), `totalDuration` (Duration).

#### [NEW] [station_service.dart](file:///C:/Github/Streamz/lib/domain/services/station_service.dart)
- Core logic to calculate which item is currently playing and at what offset based on the `DateTime.now()` and station's `startTime`.
- Methods: `getCurrentlyPlaying(station)`, `createStation(name, items)`, `deleteStation(id)`.

---

### Data & Network

#### [http_server.dart](file:///C:/Github/Streamz/lib/data/network/http_server.dart)
- Add `/api/stations` endpoint to return list of active stations with their "Currently Playing" metadata.
- Add `/api/stations/join/<id>` which returns the specific item and current offset in milliseconds.

#### [server_viewmodel.dart](file:///C:/Github/Streamz/lib/presentation/server/server_viewmodel.dart)
- Add state management for stations: `List<BroadcastStation> _stations`.
- Persistence: Store station configurations in `ServerRepository` (using shared_preferences).

---

### Presentation (Server)

#### [server_dashboard.dart](file:///C:/Github/Streamz/lib/presentation/server/server_dashboard.dart)
- Add a 4th tab: **STATIONS**.
- UI to create a station:
    - Select a Folder or individual Files.
    - Name the station (e.g., "90s Sci-Fi", "Lofi Chill").
- Display active stations with a "LIVE NOW" progress bar.

---

### Presentation (Client)

#### [tv_selection_screen.dart](file:///C:/Github/Streamz/lib/presentation/tv/tv_selection_screen.dart) & [mobile_selection_screen.dart](file:///C:/Github/Streamz/lib/presentation/mobile/mobile_selection_screen.dart)
- Add a new top-level horizontal rail: **LIVE BROADCASTS**.
- Display station cards with "Live" badges.

#### [player_screen.dart](file:///C:/Github/Streamz/lib/presentation/player/player_screen.dart)
- Logic to detect if a playback is "Live".
- Start playback at the offset provided by the server.
- Disable manual seeking (optional, or show "Back to Live" button).

## Verification Plan

### Automated Tests
- Unit tests for `StationService` to verify offset calculations across loop boundaries.
- Mock server tests for `/api/stations` response.

### Manual Verification
1. **Server Setup**:
   - Create a station "TEST_LIVE" with 3 video files.
   - Verify it appears in the STATIONS tab with a progress bar.
2. **Multi-Client Sync**:
   - Open the app on two different devices (or one device and one Web client).
   - Join "TEST_LIVE" simultaneously.
   - **Verification**: Both devices should be playing the same scene (within ~500ms network jitter).
3. **Looping**:
   - Wait for the playlist to finish.
   - **Verification**: Station should restart from the first item automatically for new joiners.
