# Implementation Plan — Professional Audit & Production Improvement of STREAMZ

This plan outlines the steps to audit and improve the STREAMZ Flutter application to production quality, following the guidelines in [flutter_app_professional_audit_prompt.md](file:///D:/Github/STREAMZ/flutter_app_professional_audit_prompt.md).

## User Review Required

> [!IMPORTANT]
> The server logic in `ServerViewModel` is designed to outlive the UI (it does not stop when the widget is disposed). This is intentional and will be preserved.

## Proposed Changes

### 1. Project Structure & Code Quality [REFACTOR]
- **Extract Server Dashboard Components**: Move large UI sections from `server_dashboard.dart` to dedicated files in `lib/presentation/server/widgets/`.
- **Introduce PlatformService**: Move platform-specific logic (e.g., default folder detection) from `ServerViewModel` to a clean service.

#### [NEW] [server_telemetry_tile.dart](file:///D:/Github/STREAMZ/lib/presentation/server/widgets/server_telemetry_tile.dart)
#### [NEW] [server_engine_card.dart](file:///D:/Github/STREAMZ/lib/presentation/server/widgets/server_engine_card.dart)
#### [NEW] [server_quick_action_grid.dart](file:///D:/Github/STREAMZ/lib/presentation/server/widgets/server_quick_action_grid.dart)
#### [MODIFY] [server_dashboard.dart](file:///D:/Github/STREAMZ/lib/presentation/server/server_dashboard.dart)

### 2. Networking & Server Improvements [PERFORMANCE]
- **Targeted WebSocket Messaging**: Implement `clientId` mapping in `HttpServerService` to avoid unnecessary broadcasting to all nodes when a `targetId` is specified.
- **Enhanced Path Security**: Final review of canonicalization logic in `HttpServerService`.

#### [MODIFY] [http_server.dart](file:///D:/Github/STREAMZ/lib/data/network/http_server.dart)

### 3. Production Readiness & UI/UX [POLISH]
- **Accessibility**: Add `Semantics` and `Tooltip` widgets to icon-only buttons.
- **Code Cleanup**: Ensure `const` usage and remove any dead code.
- **Comments**: Add professional "Why" comments as per the audit rules.

#### [MODIFY] [role_selection_screen.dart](file:///D:/Github/STREAMZ/lib/presentation/home/role_selection_screen.dart)
#### [MODIFY] [client_connect_screen.dart](file:///D:/Github/STREAMZ/lib/presentation/client/client_connect_screen.dart)

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no new warnings.
- Run `dart format .` for consistency.

### Manual Verification
- Verify Broadcaster (Server) starts and stops correctly.
- Verify Client (Receiver) can discover and connect to the server.
- Verify "Remote Control" still works (targeted messaging test).
- Verify UI scales correctly on Mobile and Desktop/TV.
