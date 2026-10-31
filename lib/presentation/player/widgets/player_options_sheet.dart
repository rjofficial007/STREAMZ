import 'package:flutter/material.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';

/// Presents playback options in the shared bottom sheet on every platform.
Future<T?> showPlayerOptionsSheet<T>({
  required BuildContext context,
  required bool isTV,
  required String title,
  required IconData icon,
  required WidgetBuilder contentBuilder,
  String? subtitle,
  double maxWidth = 560,
}) {
  final size = MediaQuery.sizeOf(context);
  final constrainWidth = isTV || size.width >= 700;
  final horizontalInset = isTV ? DS.s96 : DS.s48;
  final width = constrainWidth
      ? (size.width - horizontalInset).clamp(0.0, maxWidth).toDouble()
      : size.width;

  return showAppBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Center(
      child: SizedBox(
        width: width,
        child: FocusScope(
          autofocus: isTV,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.84),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(title: title, subtitle: subtitle, icon: icon),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: DS.s12),
                    child: contentBuilder(sheetContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
