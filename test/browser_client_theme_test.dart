import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/data/network/modern_web_html.dart';
import 'package:streamz/data/network/web_html.dart';

void main() {
  test('host browser clients share premium styling without losing controls', () {
    for (final html in [kWebInterfaceHtml, kModernWebInterfaceHtml]) {
      expect(html, contains('rgba(12, 58, 168, 0.42)'));
      expect(html, contains("font-family: 'Manrope', sans-serif"));
      expect(html, contains(':focus-visible'));
      expect(html, contains('(prefers-reduced-motion: reduce)'));
      expect(html, contains("onclick=\"switchTab('video')\""));
      expect(html, contains('onclick="toggleMedia()"'));
    }
  });
}
