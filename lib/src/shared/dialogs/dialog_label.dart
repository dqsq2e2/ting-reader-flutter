import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small bold label above a dialog form field.
///
/// Used by multiple admin/library/playlist dialogs to keep their form layouts
/// visually consistent.
class DialogLabel extends StatelessWidget {
  const DialogLabel(this.text, {super.key, this.fontSize = 13});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.isDark ? AppColors.slate400 : AppColors.slate600,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
