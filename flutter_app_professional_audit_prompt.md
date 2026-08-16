# Professional Flutter App Audit & Production Improvement Prompt

Use this prompt with an AI coding assistant when you want a complete professional review and safe improvement of a Flutter + Firebase app.

---

## Prompt

Act as a world-class Senior Flutter Developer, Firebase Expert, Performance Engineer, Code Reviewer, and UI/UX Product Designer with 10+ years of experience building production-ready mobile applications.

I want you to review my complete Flutter app professionally and improve it to production quality.

Your role:

- Senior Flutter Developer
- Firebase Architect
- UI/UX Expert
- Performance Optimization Specialist
- Code Quality Reviewer
- Mobile App QA Engineer

## Important Rules

1. Do not break existing functionality.
2. Do not remove existing features.
3. Do not change business logic unless a real bug requires it.
4. Do not rewrite the whole app unnecessarily.
5. Do not introduce unnecessary complexity.
6. Make safe, professional, production-ready improvements.
7. Work step by step and explain every important change.
8. Preserve existing navigation flow unless fixing a confirmed bug.
9. Preserve existing state management approach unless there is a serious issue.
10. Do not change backend APIs or Firebase collections unless required for a bug/security fix.

## Main Goal

Make this Flutter app clean, stable, fast, scalable, secure, maintainable, and production-ready like an app built by an experienced Flutter + Firebase team.

---

# 1. Project Structure Review

Review the complete project structure.

Check:

- Folder organization
- Feature separation
- File naming
- Large files
- Duplicate files
- Unused files
- Poorly placed logic
- Separation of UI, models, services, state, utils, constants, and config

Improve:

- Folder clarity
- Maintainability
- Scalability
- File naming consistency
- Logical grouping of related code

## Comment Requirement

Add comments only where they are useful. Do not over-comment obvious code.

Example:

```dart
// Centralized app spacing values to keep layouts consistent across screens.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
}
```

---

# 2. Flutter Code Quality Review

Review:

- Code readability
- Naming conventions
- Duplicate code
- Large widgets
- Large methods
- Dead code
- Unused imports
- Unused variables
- Magic numbers
- Repeated styles
- Repeated paddings
- Repeated colors
- Repeated decorations
- Improper widget composition
- Business logic inside UI widgets

Improve:

- Code readability
- Maintainability
- Reusability
- Consistency
- Clean separation of concerns

Rules:

- Do not change app behavior unnecessarily.
- Do not rewrite working architecture unless needed.
- Prefer small safe refactors.

## Comment Requirement

Add short comments explaining reusable helpers, design-system values, non-obvious decisions, or bug fixes.

Example:

```dart
// Prevents duplicate Firestore reads when the widget rebuilds.
late final Future<UserProfile> _profileFuture;
```

---

# 3. Clean `Widget build(BuildContext context)` Methods

Review every `Widget build(BuildContext context)` method and clean it professionally.

Goals:

- Keep build methods short, readable, and maintainable.
- Avoid huge nested widget trees inside one build method.
- Extract repeated UI into reusable widgets.
- Extract complex UI sections into private helper widgets or separate components.
- Use clear widget names that describe purpose.
- Use const constructors wherever possible.
- Avoid business logic inside build methods.
- Avoid async calls inside build methods.
- Avoid heavy calculations inside build methods.
- Avoid creating controllers, streams, futures, focus nodes, animation controllers, or providers inside build methods.
- Avoid repeated inline styling.
- Move repeated padding, colors, text styles, and decorations into design-system helpers.
- Prefer composition over deeply nested widgets.
- Keep conditional UI readable.

For every large build method:

1. Audit the widget tree.
2. Identify deeply nested or duplicated UI.
3. Extract safe reusable widgets.
4. Preserve all state, callbacks, keys, controllers, animations, and behavior.
5. Ensure no UI or logic breaks.
6. Run analyzer after refactor.

Preferred clean structure:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: _buildAppBar(context),
    body: _buildBody(context),
    bottomNavigationBar: _buildBottomNav(context),
  );
}

Widget _buildBody(BuildContext context) {
  return SafeArea(
    child: CustomScrollView(
      slivers: [
        _buildHeader(context),
        _buildContent(context),
      ],
    ),
  );
}
```

Rules:

- Do not over-extract tiny widgets unnecessarily.
- Do not create too many files unless useful.
- Extract widgets when it improves readability, reuse, or testability.
- Keep private helper methods simple.
- For reusable UI across multiple screens, create separate reusable widgets.
- Do not change business logic while cleaning build methods.
- Do not change navigation or state management behavior.

## Comment Requirement

When extracting widgets, add a short comment only if the purpose is not obvious.

Example:

```dart
// Extracted to keep the parent build method readable and reusable across profile screens.
class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(value),
          Text(label),
        ],
      ),
    );
  }
}
```

Final output for this section:

- List of build methods cleaned
- Widgets extracted
- Reusable components created
- Duplicate UI removed
- Confirmation that behavior was preserved

---

# 4. Bug Detection and Fixing

Find and fix:

- Runtime errors
- Null safety issues
- State management bugs
- Navigation bugs
- UI overflow issues
- Keyboard overflow issues
- Async/await mistakes
- FutureBuilder/StreamBuilder misuse
- Firebase errors
- Permission issues
- Form validation bugs
- Loading state bugs
- Empty state bugs
- Error state bugs
- Edge case bugs
- Memory leaks
- Controller disposal issues

For every bug:

- Explain the issue
- Explain why it matters
- Provide risk level: Low / Medium / High
- Fix safely if possible
- Mention files changed

## Comment Requirement

When fixing a bug, add a short comment if future developers may not understand why the fix exists.

Example:

```dart
// Mounted check prevents calling setState after this screen has been disposed.
if (!mounted) return;
setState(() => _isLoading = false);
```

---

# 5. Firebase Review

Review Firebase usage.

## Firebase Auth

Check:

- Sign in flow
- Sign up flow
- Logout flow
- Auth state persistence
- User session handling
- Error handling
- Edge cases

## Firestore

Check:

- Collection structure
- Document structure
- Queries
- Reads and writes
- Index requirements
- Pagination
- Offline persistence
- Data validation
- Duplicate reads
- Repeated stream subscriptions
- Query performance
- Cost optimization

## Firebase Storage

Check:

- Upload handling
- Download URLs
- Image/file validation
- Storage paths
- Error handling
- Security

## Firebase Cloud Messaging, If Used

Check:

- Token handling
- Permission flow
- Foreground/background notifications
- Duplicate notification issues

## Firebase Security

Check:

- Firestore rules
- Storage rules
- User-level access
- Unauthorized reads/writes
- Sensitive data exposure

Improve:

- Security
- Query efficiency
- Error handling
- Cost efficiency
- Reliability

Do not:

- Change collection names unless absolutely necessary.
- Change production data shape without warning.
- Change backend logic unnecessarily.

## Comment Requirement

Add comments around Firebase helper methods where purpose or cost optimization is important.

Example:

```dart
// Uses a limited query to reduce Firestore reads and avoid loading the full history.
return _firestore
    .collection('users')
    .doc(userId)
    .collection('logs')
    .orderBy('createdAt', descending: true)
    .limit(20)
    .get();
```

---

# 6. Performance Optimization

Review and improve:

- Unnecessary widget rebuilds
- Missing const widgets
- Heavy build methods
- Inefficient ListView/GridView usage
- Missing itemBuilder
- Nested scroll performance
- Image loading
- Large images
- Caching
- Animation performance
- Synchronous work on UI thread
- Firebase repeated reads
- Unnecessary stream rebuilds
- Memory leaks
- Controller disposal
- App startup performance

Use:

- const constructors
- ListView.builder
- GridView.builder
- RepaintBoundary where useful
- Cached network images if appropriate
- Memoized futures where appropriate
- Efficient selectors/consumers depending on state management
- Proper disposal of controllers

Do not:

- Prematurely optimize everything.
- Add unnecessary packages without explaining why.
- Change business logic.

## Comment Requirement

Add comments for non-obvious performance decisions.

Example:

```dart
// RepaintBoundary isolates the animated chart from rebuilding the entire page.
RepaintBoundary(
  child: AnimatedChart(data: data),
)
```

---

# 7. State Management Review

Review current state management approach.

Check:

- Provider / Riverpod / Bloc / GetX / setState usage
- Unnecessary rebuilds
- State stored in wrong place
- Business logic inside widgets
- Loading/error/success state handling
- Async state handling
- State reset bugs
- Memory leaks
- Repeated API/Firebase calls

Improve:

- Predictability
- Readability
- Rebuild performance
- Error handling
- Loading state handling

Do not:

- Replace the state management solution unless there is a serious reason.
- Rewrite architecture unnecessarily.

## Comment Requirement

Add comments where state behavior is not obvious.

Example:

```dart
// Keeps the selected filter local because it only affects this screen's UI.
final selectedFilter = useState(FilterType.all);
```

---

# 8. UI/UX Review

Review every screen individually.

Check:

- Spacing
- Padding
- Margins
- Typography
- Visual hierarchy
- Alignment
- Balance
- Icons
- Shadows
- Elevation
- Border radius
- Card design
- Containers
- Dividers
- Empty space
- Color consistency
- Gradients
- Contrast
- Readability
- Button placement
- Tap targets
- Navigation clarity
- Forms
- Search
- Filters
- Lists
- Loading states
- Error states
- Success states
- Empty states

Improve:

- Usability
- Accessibility
- Discoverability
- Visual consistency
- Premium feel
- Interaction clarity

Important:

- Keep the existing design language.
- Do not redesign the entire app.
- Improve only where there is measurable UX value.

## Comment Requirement

Do not comment visual widgets unless the reason is useful.

Example:

```dart
// Minimum height keeps the button accessible and prevents cramped touch targets.
SizedBox(
  height: 48,
  child: ElevatedButton(...),
)
```

---

# 9. Responsive Design Review

Test and improve layouts for:

- Small Android phones
- iPhone SE
- Standard iPhones
- Large iPhones
- Android large screens
- Tablets if supported

Check:

- Overflow issues
- SafeArea usage
- Keyboard handling
- Scroll behavior
- Text scaling
- Orientation if supported
- Adaptive layouts
- Bottom navigation spacing
- App bars
- Dialogs
- Bottom sheets

Improve:

- Responsiveness
- Adaptive spacing
- Scroll safety
- Keyboard safety
- Layout stability

## Comment Requirement

Add comments for responsive layout decisions when useful.

Example:

```dart
// Constrains content width on tablets so forms remain readable.
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 520),
  child: child,
)
```

---

# 10. Accessibility Review

Improve:

- Text contrast
- Font scaling support
- Minimum touch target size: 44x44
- Semantic labels
- Screen reader support
- Button labels
- Icon-only button labels
- Focus order
- Error message clarity
- Color-blind accessibility
- Avoid color-only meaning

Check:

- Text overflow with larger font sizes
- Buttons at accessibility sizes
- Form validation messages
- Images with labels where needed

## Comment Requirement

Add comments only for non-obvious accessibility decisions.

Example:

```dart
// Semantic label is required because this icon-only button has no visible text.
IconButton(
  tooltip: 'Close',
  icon: const Icon(Icons.close),
  onPressed: onClose,
)
```

---

# 11. Design System Improvement

Create or improve reusable design system components.

Standardize:

- Colors
- Typography
- Spacing
- Elevations
- Border radius
- Buttons
- Cards
- Dialogs
- Bottom sheets
- Text fields
- Chips
- Badges
- App bars
- Navigation components
- Loading widgets
- Empty states
- Error states

Use reusable constants/helpers where useful:

- AppColors
- AppTextStyles
- AppSpacing
- AppRadius
- AppShadows
- AppDurations
- AppBreakpoints
- Common buttons
- Common cards
- Common text fields

Do not:

- Change the visual identity unnecessarily.
- Over-engineer the design system.
- Create abstractions that are not used.

## Comment Requirement

Add helpful comments explaining design tokens and reusable components.

Example:

```dart
// App-wide radius scale used to keep cards, sheets, and buttons visually consistent.
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}
```

---

# 12. Micro-Interactions and Animations

Review and improve:

- Button feedback
- Page transitions
- Loading animations
- Skeleton loaders
- Success animations
- Error animations
- Swipe interactions
- Haptic feedback suggestions
- Pull-to-refresh if applicable
- Subtle transitions

Rules:

- Do not overuse animations.
- Keep animations smooth, premium, and purposeful.
- Avoid animations that hurt performance.
- Respect reduced motion where possible.
- Do not change app flow.

## Comment Requirement

Add comments where animation behavior is intentional.

Example:

```dart
// Short duration keeps the success feedback noticeable without slowing the flow.
const successAnimationDuration = Duration(milliseconds: 250);
```

---

# 13. Error, Empty, Loading, and Success States

Review all screens and flows for:

- Loading states
- Skeleton states
- Empty states
- Error states
- Success states
- Retry actions
- Offline states
- Permission denied states
- Firebase failure states
- Form validation states

Improve:

- User-friendly messages
- Clear recovery actions
- Consistent state UI
- Avoid blank screens
- Avoid infinite loading

## Comment Requirement

Add comments for fallback states if needed.

Example:

```dart
// Shows a retry action instead of leaving the user on a dead-end error screen.
ErrorState(
  message: 'Could not load your data.',
  onRetry: _loadData,
)
```

---

# 14. Security and Privacy Review

Review:

- API keys exposure
- Firebase rules
- User data access
- Authentication checks
- Sensitive data storage
- Local storage
- Token handling
- Debug logs with private data
- Firestore document permissions
- Storage permissions

Improve:

- User privacy
- Data safety
- Secure reads/writes
- Remove sensitive logs
- Safer error messages

Do not:

- Remove required Firebase config files.
- Break authentication.
- Change production data without warning.

## Comment Requirement

Add comments where security checks are important.

Example:

```dart
// Ensures users can only access documents that belong to their own account.
allow read, write: if request.auth != null && request.auth.uid == userId;
```

---

# 15. Production Readiness Review

Check:

- `flutter analyze`
- `flutter test` if tests exist
- Debug prints
- Unused packages
- Dependency issues
- Deprecated APIs
- Android config
- iOS config
- Firebase config
- App permissions
- App icon
- Splash screen
- Release build readiness
- Environment config
- Crash handling
- Logging strategy
- Versioning
- App metadata if available

Improve:

- Release stability
- Build quality
- App store readiness
- Crash safety
- Logging quality

## Comment Requirement

Add comments only if configuration or setup needs explanation.

---

# 16. Testing and Verification

Run:

```bash
flutter pub get
flutter analyze
flutter test
dart format .
```

Build check if possible:

```bash
flutter build apk --debug
flutter build ios --no-codesign
```

Verify:

- App still builds
- Core flows still work
- Navigation still works
- Firebase flows still work
- No analyzer errors remain
- No important warnings remain
- UI does not overflow on small screens

If a command cannot run, explain why.

---

# 17. Safe Change Process

Use this process:

1. Inspect the project.
2. Identify frameworks, packages, Firebase usage, and state management.
3. Audit project structure.
4. Audit dependencies.
5. Audit Firebase setup.
6. Audit architecture.
7. Audit screens one by one.
8. Fix safe bugs.
9. Clean build methods.
10. Extract reusable widgets.
11. Improve UI/UX safely.
12. Optimize performance safely.
13. Improve Firebase usage safely.
14. Run formatting and analysis.
15. Run tests/build checks.
16. Provide final report.

Before every change, ask:

- Will this improve the app?
- Will this preserve functionality?
- Will this avoid breaking state/navigation?
- Is this change necessary?
- Is this change safe?

If the answer is no, do not make the change.

---

# 18. Commenting Rules

I want clean, professional comments explaining the use of important code.

Add comments for:

- Reusable design-system classes
- Non-obvious bug fixes
- Performance optimizations
- Firebase query optimizations
- Security rules
- Accessibility decisions
- Complex UI widgets
- Extracted reusable widgets if their purpose is not obvious
- Important edge case handling

Do not add comments for:

- Obvious code
- Every variable
- Every widget
- Simple UI layout
- Self-explanatory functions

Good comment style:

```dart
// Caches the profile request so rebuilding the screen does not trigger extra Firestore reads.
late final Future<UserProfile> _profileFuture;
```

Bad comment style:

```dart
// This is a Container.
Container()
```

Comments should be:

- Short
- Useful
- Professional
- Clear
- Focused on why, not just what

---

# 19. Final Report Format

At the end, provide a professional final report with:

1. Project overview
2. Technologies detected
3. State management detected
4. Firebase services detected
5. Main issues found
6. Bugs fixed
7. Firebase improvements
8. Performance improvements
9. UI/UX improvements
10. Build method cleanup summary
11. Reusable widgets created
12. Design system improvements
13. Security/privacy improvements
14. Files changed
15. Commands run
16. Analyzer/test/build results
17. Remaining risks
18. Recommended next steps
19. Confirmation that existing functionality was preserved

For every file changed, include:

- File path
- What changed
- Why it changed

---

# Final Goal

Transform the Flutter app into a clean, stable, fast, secure, scalable, maintainable, and production-ready product while preserving all existing features, business logic, navigation flow, and user experience.
