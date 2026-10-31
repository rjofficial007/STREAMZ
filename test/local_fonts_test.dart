import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/core/constants/app_text_styles.dart';

void main() {
  test('all appearance font choices use bundled variable fonts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    const fontAssets = {
      AppFontFamily.manrope: 'assets/fonts/manrope/Manrope-Variable.ttf',
      AppFontFamily.inter: 'assets/fonts/inter/Inter-Variable.ttf',
      AppFontFamily.roboto: 'assets/fonts/roboto/Roboto-Variable.ttf',
      AppFontFamily.lora: 'assets/fonts/lora/Lora-Variable.ttf',
    };

    for (final entry in fontAssets.entries) {
      await rootBundle.load(entry.value);
      AppTextStyles.fontFamily = entry.key;
      final style = AppTextStyles.style(fontWeight: FontWeight.w600);

      expect(style.fontFamily, entry.key.label);
      expect(style.fontVariations?.single.axis, 'wght');
      expect(style.fontVariations?.single.value, 600);
    }

    AppTextStyles.fontFamily = AppFontFamily.manrope;
  });
}
