import 'package:flutter/material.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';

/// Shows options as a touch sheet on compact screens and a dialog on TV or
/// wide screens.
Future<T?> showPlayerOptionsSheet<T>({
  required BuildContext context,
  required bool isTV,
  required String title,
  required IconData icon,
  required WidgetBuilder contentBuilder,
  String? subtitle,
  double maxWidth = 560,
}) {
  final tokens = context.tokens;
  final size = MediaQuery.sizeOf(context);
  final useDialog = isTV || size.width >= 700;
  final horizontalInset = isTV ? DS.s48 : DS.s24;
  final width = (size.width - horizontalInset * 2)
      .clamp(0.0, maxWidth)
      .toDouble();

  Widget panel(BuildContext panelContext) => FocusScope(
    autofocus: useDialog,
    child: SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.84),
        child: Material(
          color: tokens.surface1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusLg),
            side: BorderSide(color: tokens.border.withValues(alpha: 0.65)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: DS.s12),
                  child: contentBuilder(panelContext),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (!useDialog) {
    return showAppBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: panel,
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierColor: tokens.background.withValues(alpha: 0.84),
    barrierDismissible: true,
    barrierLabel: 'Close player options',
    pageBuilder: (dialogContext, _, _) => Center(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DS.s24),
          child: panel(dialogContext),
        ),
      ),
    ),
  );
}
