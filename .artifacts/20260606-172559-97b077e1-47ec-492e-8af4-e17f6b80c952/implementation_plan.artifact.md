# Implementation Plan - Liquid Glass UI for SamsungFileManagerScreen

> Historical planning artifact from June 2026. It records a proposal from that task and is not a statement of current implementation status. Use the [current architecture](../../docs/ARCHITECTURE.md), [UI component guide](../../docs/UI_COMPONENTS.md), and [README](../../README.md) as the source of truth.

Apply a high-end "Liquid Glass" aesthetic to the `SamsungFileManagerScreen` using the `liquid_glass_easy` package. This involves replacing the current Brutalist design with a translucent, refracted, and distorted glass UI over a vibrant background.

## Proposed Changes

### [UI Components]

#### [file_manager.dart](file:///C:/Github/Streamz/lib/presentation/mobile/file_manager.dart)

- **Root Widget Change**: Wrap the `Scaffold` body in `LiquidGlassView`.
- **Background**: Implement a `_GlassBackground` widget featuring a multi-layered radial/linear gradient (Deep Sea / Aurora theme).
- **Glass Header**: Refactor the `SliverAppBar` area to use a `LiquidGlass` lens for the title and search bar.
- **Glass Storage Card**: Convert the `Storage Analysis` card into a `LiquidGlass` component with chromatic aberration and high blur.
- **Glass Categories**: Refactor the `_kCategories` grid items into `LiquidGlass` lenses.
- **Glassy File Items**:
    - For `ListView`, use glass-effect tiles with semi-transparency and blurred backgrounds.
    - For `GridView`, use high-gloss glass cards for folders and files.
- **Interaction**: Maintain existing functionality (navigation, search, sorting) but update feedback to match the glass aesthetic (e.g., subtle light reflection on tap).

### [Logic & Performance]

- **Performance Optimization**: Use `realTimeCapture: true` only when necessary. Set `pixelRatio: 1` for smoother rendering on mobile.
- **Dynamic Positioning**: Since the screen is scrollable, use a combination of `LiquidGlass` for fixed/semi-fixed elements and standard `BackdropFilter` glass for the scrollable list to ensure performance and native scroll behavior.

## Verification Plan

### Automated Tests
- Since this is a UI-heavy change, automated tests will focus on ensuring the screen still loads and navigation works.
- `flutter test` to ensure no regressions in `ClientViewModel` or core logic.

### Manual Verification
- **Visual Inspection**: Run the app and navigate to the File Manager. Verify the "Liquid Glass" refraction and blur effects.
- **Performance Check**: Scroll through a large directory to ensure no significant frame drops.
- **Functionality Check**:
    - Search for a file.
    - Navigate into a directory.
    - Toggle List/Grid view.
    - Sort files.
    - Trigger a download.
- **Layout Check**: Verify the UI looks good on different screen sizes (Mobile/Tablet).
