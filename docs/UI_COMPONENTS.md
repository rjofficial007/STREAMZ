# Shared UI Components

This guide describes the shared Flutter UI layer used by STREAMZ screens.

## Component architecture

```text
Design tokens and ThemeExtension
        ↓
App shell and shared primitives
        ↓
Feature widgets (client, server, player, mobile, TV)
        ↓
Routes and screen-level state
```

- **Tokens and theme:** `lib/core/theme/design_tokens.dart` owns spacing, colors, breakpoints, shared content width, dynamic corner geometry, and responsive grid sizing. `lib/core/constants/app_text_styles.dart` owns the user-selectable type families and semantic text roles. `theme_tokens.dart` exposes the active palette through `BuildContext.tokens`.
- **App shell:** `AppBackdrop` paints the app-wide near-black vertical fade and configurable blue glow. `AppLaunchSplash` sits above the routed child without replacing it, while `AppScaffold`, `AppSliverAppBar`, and `AppContentSliver` keep transparent bars and wide-screen alignment consistent. Shared app bars blur the clipped area behind their toolbar as content scrolls underneath.
- **Shared primitives:** `AppBackButton`, `AppButton`, `CompactBtn`, `AppCard`, `AppPanel`, `AppActionGrid`, `AppActionCard`, `AppListTileCard`, `AppLiveStationCard`, `AppSheetHeader`, `AppSheetOption`, `SkeletonBox`, `NetworkImageFade`, and `AppStateView` provide common interaction, responsive layout, and state visuals.
- **Feature widgets:** `ClientLibraryStateView` composes the generic state component for the mobile and TV library. Other domain-specific controls stay beside their feature. Screens and ViewModels own loading, retry, and navigation decisions; widgets receive values and callbacks.

The two native-host browser clients are separate HTML/CSS implementations. Keep their visual tokens, responsive breakpoints, focus-visible treatment, and reduced-motion behavior aligned with this design system while preserving their independent browser playback and network flows.

Shared components should not read a ViewModel, service locator, route, or platform singleton. Pass the data needed to render and callbacks for actions. This keeps components testable and lets mobile, TV, Windows, and Web screens share presentation without sharing feature state.

The Appearance screen uses `ThemeService` to persist font family, title weight, scaffold glow color, and corner radius locally. Theme updates flow through `MaterialApp`, `AppBackdrop`, `ThemeData`, `StreamzThemeExtension`, and `DS`; individual screens should not maintain their own appearance settings.

## Typography and actions

Use a semantic `AppTextStyles` role (`caption`, `supporting`, `body`, `bodyLarge`, `title`, `titleLarge`, `sectionTitle`, or `headline`) and customize it with `copyWith`. `AppTextStyles.style`, `heading`, and `display` cover fluid sizes. System text scaling remains enabled; captions have a 12 logical pixel minimum.

`AppActionGrid` chooses its column count through `DS.responsiveColumns`, using available width and text scale, and grows tile height for larger text. Media grids use the same column helper so category and file cards stay readable at narrow widths and larger text settings. `AppActionCard` supplies a focusable, touch-friendly card with a two-line label and optional active state. Its public inputs are `label`, `icon`, `onTap`, and `isActive`. Use it for repeated action grids; keep feature-specific card composition local when its layout has different information or behavior.

```dart
AppActionGrid(
  minTileWidth: 120,
  maxColumns: 3,
  children: [
    AppActionCard(
      label: 'Browse media',
      icon: LucideIcons.film,
      onTap: openLibrary,
    ),
  ],
)
```

`DS.responsiveColumns` is the lower-level helper for sliver grids that cannot use `AppActionGrid` directly:

| Argument | Type | Purpose |
| --- | --- | --- |
| `context` | `BuildContext` | Reads the current system text scale. |
| `availableWidth` | `double` | Width remaining after screen padding. |
| `spacing` | `double` | Gap between columns. |
| `minTileWidth` | `double` | Minimum readable tile width at the default text scale. |
| `maxColumns` | `int` | Upper bound for the grid. |

The helper returns at least one column and reduces the count as text scale grows. Keep the grid delegate and card behavior in the feature screen; this helper only determines the column count.

`AppPanel` is a non-interactive shared surface for grouped content. Use it when a panel needs the app surface, border, and radius without card activation or focus semantics.

`AppListTileCard` is the shared rounded row for media, history, and stations. It takes `title`, `subtitle`, `icon`, and `onTap`, with an optional `trailingIcon` (defaults to a chevron). It keeps the same spacing, focus ring, hover state, and screen-reader activation across mobile and TV list layouts.

`AppLiveStationCard` is the shared landscape card for live station rails and grids. It takes `title`, `trackTitle`, and `onTap`, plus optional `liveLabel`, `nowPlayingLabel`, `width`, `height`, and `onFocusChanged`. Use it for station discovery surfaces; keep station joining and player navigation in the caller. `AppListTileCard` also accepts `isActive` to highlight the currently selected station with an accent icon and check mark.

`showAppBottomSheet<T>` applies the shared dark surface, rounded top corners, drag handle, safe area, and a maximum readable width. Use `AppSheetHeader` for a title and optional subtitle, icon, or trailing controls; use `AppSheetOption` for focusable touch and remote actions. Keep sheet-specific state and callbacks in the feature that opens the sheet.

`AppButton` is the shared primary/secondary action. It takes a visible `label`, optional `icon`, required `onTap`, and optional `isPrimary`, `isLoading`, and `height`. Loading disables activation and exposes progress semantics. `CompactBtn` preserves the compact legacy API and delegates to `AppButton`.

`AppCard` handles hover, keyboard activation, TV focus indication, reduced-motion timing, and the semantic button role. Pass callbacks rather than wrapping it in another `Focus`, `Actions`, or tap detector for the same activation.

`AppBackButton` gives app bars a single back-arrow icon, tooltip, and touch target. Keep route-specific pop, disconnect, or section-back behavior in the supplied `onPressed` callback; TV screens may adjust `iconSize` while using the same icon.

`PlaybackRecoveryOverlay` is shared by the mobile/desktop/Web and TV players. Its API accepts a classified `PlaybackIssue`, retry/recovery state, `isTV`, and Retry/Back callbacks. The player ViewModel owns position capture, reconnect policy, error-stream handling, and persistence; the overlay only renders diagnosis and actions. Keep the platform-specific HTML clients' matching recovery panel behavior in both `web_html.dart` and `modern_web_html.dart`.

## `AppStateView` API

`AppStateView` displays a loading, empty, or error state. It centers content, constrains the width, uses theme typography and spacing, and exposes headings and loading/error announcements to assistive technology. Its optional action uses Flutter's themed `OutlinedButton` for native semantics, focus, keyboard, and remote activation.

| Property | Type | Default | Purpose |
| --- | --- | --- | --- |
| `kind` | `AppStateKind` | `empty` | Selects loading, empty, or error presentation. |
| `title` | `String` | required | Short, actionable state heading. |
| `description` | `String?` | `null` | Optional context or recovery detail. |
| `icon` | `IconData?` | state default | Decorative icon for empty/error states. |
| `actionLabel` | `String?` | `null` | Visible and accessible action label. |
| `onAction` | `VoidCallback?` | `null` | Action callback; must be supplied with `actionLabel`. |
| `maxWidth` | `double` | `560` | Maximum readable content width. |

`AppStateSliver(state: ...)` wraps the same component in a non-scroll-body `SliverFillRemaining`, for use inside `CustomScrollView`.

## Usage

Use explicit states so an empty library is never confused with a failed connection:

```dart
if (viewModel.isLoading) {
  return const AppStateSliver(
    state: AppStateView(
      kind: AppStateKind.loading,
      title: 'Loading your library',
    ),
  );
}

if (viewModel.error != null) {
  return AppStateSliver(
    state: AppStateView(
      kind: AppStateKind.error,
      title: 'Could not load the library',
      description: viewModel.error,
      actionLabel: 'Retry',
      onAction: viewModel.retry,
    ),
  );
}

if (viewModel.items.isEmpty) {
  return const AppStateSliver(
    state: AppStateView(
      title: 'No media found',
      description: 'Shared media will appear here.',
    ),
  );
}
```

For a non-sliver screen body, use `AppStateView` directly. Keep async work and error handling in the screen or ViewModel; the component only renders state and invokes the supplied action.

The mobile and TV library share a feature-level state view so the same connection state produces the same recovery UI:

```dart
if (items.isEmpty) {
  return ClientLibraryStateView(
    isLoading: viewModel.isLoading,
    isConnected: viewModel.isConnected,
    error: viewModel.connectionError,
    onReconnect: () => context.go('/client/connect'),
  );
}
```

## Production practices

- Show skeletons when the eventual layout is known and preserving its shape reduces layout shift. Use `AppStateView` for screen-level loading, empty, and recoverable error states.
- Keep empty and error states distinct. Provide a retry or reconnect action only when that action can recover the state.
- Give actions visible text; do not rely on an icon or tooltip alone. Keep actions usable by touch, keyboard, and TV remote, with a visible focus state.
- Keep state descriptions concise. Long server errors should be exposed as selectable detail elsewhere rather than forcing a narrow state panel to carry diagnostic logs.
- Use `DS` tokens for spacing and color. Use `AppContentSliver` for wide layouts instead of repeating viewport-specific centering math.
- Let text wrap and follow system text scaling. Do not truncate state titles or critical recovery details.
- Preserve loading/error/empty distinctions when moving code into shared components. A shared visual should not own navigation, requests, retries, or data mutation.

## Server operation screens

The server dashboard uses the shared type roles, `AppCard`, `AppSheetHeader`, `AppListTileCard`, `AppButton`, and `AppStateView` on traffic, live logs, history, station management, sharing options, and shared-folder browsing. Pairing stays in the shared bottom-sheet shell; remote relay actions use `AppActionGrid` so columns adapt to available width and text scale. Keep network commands, pairing payloads, folder mutations, and station lifecycle callbacks in their existing ViewModels and routes.

For native folder selection, show the current path separately from the screen title, expose parent navigation as a standard focusable row, and distinguish scanning, empty, and access-error states. Directory enumeration must not run in a widget build method.
