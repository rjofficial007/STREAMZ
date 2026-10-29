import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/core/theme/design_tokens.dart';

void main() {
  testWidgets('Android TV keeps the TV layout at HD logical resolution', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 720)),
          child: TVDeviceScope(
            isTelevision: true,
            child: Builder(
              builder: (context) => Text(DS.isTV(context) ? 'tv' : 'non-tv'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('tv'), findsOneWidget);
  });

  testWidgets('wide 4K viewport keeps the TV layout on desktop and web', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(3840, 2160)),
          child: TVDeviceScope(
            isTelevision: false,
            child: Builder(
              builder: (context) => Text(DS.isTV(context) ? 'tv' : 'non-tv'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('tv'), findsOneWidget);
  });
}
