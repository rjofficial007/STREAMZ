import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_launch_splash.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';

void main() {
  testWidgets('launch splash keeps its destination mounted and interactive', (
    tester,
  ) async {
    var mounts = 0;
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppBackdrop(
          child: AppLaunchSplash(
            child: _MountProbe(onMount: () => mounts++, onTap: () => taps++),
          ),
        ),
      ),
    );
    expect(mounts, 1);

    await tester.tap(find.text('Destination'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpAndSettle();

    expect(mounts, 1);
    expect(find.text('Destination'), findsOneWidget);
    await tester.tap(find.text('Destination'));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('action grid adapts its columns to larger text settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<int> columnsAt(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: AppActionGrid(
                  children: [SizedBox(), SizedBox(), SizedBox()],
                ),
              ),
            ),
          ),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;
    }

    expect(await columnsAt(1), 2);
    expect(await columnsAt(2), 1);
  });

  testWidgets('responsive file grids reduce columns for larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<int> columnsAt(double scale) async {
      var columns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Builder(
                builder: (scaledContext) {
                  columns = DS.responsiveColumns(
                    scaledContext,
                    availableWidth: 328,
                    spacing: DS.s12,
                    minTileWidth: 124,
                    maxColumns: 3,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      return columns;
    }

    expect(await columnsAt(1), 2);
    expect(await columnsAt(2), 1);
  });

  testWidgets('loading buttons expose progress and do not activate', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: AppButton(
            label: 'Connect',
            isLoading: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('shared list cards keep their label and activation', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 320,
                  child: AppListTileCard(
                    title: 'Kitchen Radio With A Long Station Name',
                    subtitle:
                        'Now playing · A very long morning playlist title',
                    icon: Icons.radio,
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Kitchen Radio With A Long Station Name'), findsOneWidget);
    expect(
      find.text('Now playing · A very long morning playlist title'),
      findsOneWidget,
    );
    await tester.tap(find.byType(AppCard));
    expect(tapped, isTrue);
  });
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount, required this.onTap});

  final VoidCallback onMount;
  final VoidCallback onTap;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  var _taps = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      setState(() => _taps++);
      widget.onTap();
    },
    child: Text(_taps == 0 ? 'Destination' : '$_taps'),
  );
}
