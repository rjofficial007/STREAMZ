import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_icons.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/theme/app_theme.dart';

/// Consistent app-bar back action for touch, keyboard, and TV focus flows.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.color,
    this.iconSize = 20,
  });

  final VoidCallback onPressed;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppStrings.back,
    onPressed: onPressed,
    icon: Icon(
      AppIcons.back,
      size: iconSize,
      color: color ?? context.tokens.textPrimary,
    ),
  );
}
