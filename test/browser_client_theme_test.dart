import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/data/network/web_interface_html.dart';

void main() {
  test(
    'host browser client uses the modern style and keeps core controls',
    () {
      expect(kWebInterfaceHtml, contains('rgba(12, 58, 168, 0.42)'));
      expect(kWebInterfaceHtml, contains("font-family: 'Manrope', sans-serif"));
      expect(kWebInterfaceHtml, contains("url('/assets/fonts/Manrope-Variable.ttf')"));
      expect(kWebInterfaceHtml, contains("url('/assets/fonts/Inter-Variable.ttf')"));
      expect(kWebInterfaceHtml, contains("url('/assets/fonts/Roboto-Variable.ttf')"));
      expect(kWebInterfaceHtml, contains("url('/assets/fonts/Lora-Variable.ttf')"));
      expect(kWebInterfaceHtml, isNot(contains('fonts.googleapis.com')));
      expect(kWebInterfaceHtml, contains(':focus-visible'));
      expect(kWebInterfaceHtml, contains('(prefers-reduced-motion: reduce)'));
      expect(kWebInterfaceHtml, contains("onclick=\"switchTab('video')\""));
      expect(kWebInterfaceHtml, contains('onclick="toggleMedia()"'));
      expect(kWebInterfaceHtml, contains('class="top-dashboard"'));
      expect(AppStrings.appTitle, 'Hestia');
      expect(kWebInterfaceHtml, contains('<title>Hestia // STUDIO</title>'));
      expect(
        kWebInterfaceHtml,
        contains('src="/assets/images/app_mark.png" alt="Hestia"'),
      );
      expect(kWebInterfaceHtml, isNot(contains('<div class="brand-title">')));
      expect(kWebInterfaceHtml, contains('browse-folder-row'));
      expect(kWebInterfaceHtml, contains('Go to parent folder'));
      expect(kWebInterfaceHtml, isNot(contains('[NODE]')));
      expect(kWebInterfaceHtml, isNot(contains('uiModeToggle')));
      expect(kWebInterfaceHtml, isNot(contains('__STREAMZ_DEFAULT_UI__')));
      expect(kWebInterfaceHtml, isNot(contains('data-ui-mode')));
      expect(
        kWebInterfaceHtml,
        contains('padding-inline: clamp(16px, 2vw, 32px)'),
      );
      expect(
        kWebInterfaceHtml,
        contains('minmax(min(100%, 230px), 1fr)'),
      );
      expect(kWebInterfaceHtml, contains("station: { title: 'Live stations'"));
    },
  );

  test(
    'host browser client waits for ready and retries with heartbeat recovery',
    () {
      expect(kWebInterfaceHtml, contains("cmd.action === 'ready'"));
      expect(kWebInterfaceHtml, contains("cmd.action === 'heartbeat_ack'"));
      expect(kWebInterfaceHtml, contains('wsHeartbeatSequence'));
      expect(kWebInterfaceHtml, contains("fetch('/api/health'"));
      expect(kWebInterfaceHtml, contains("'If-None-Match': mediaEtag"));
      expect(kWebInterfaceHtml, contains('wsHasBeenReady'));
      expect(kWebInterfaceHtml, contains('45000'));
      expect(kWebInterfaceHtml, contains('wsReconnectAttempt'));
      expect(kWebInterfaceHtml, isNot(contains('setTimeout(connectWS, 3000)')));
    },
  );
}
