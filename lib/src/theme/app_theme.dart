import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppColors {
  static const primary50 = Color(0xfff0f9ff);
  static const primary100 = Color(0xffe0f2fe);
  static const primary200 = Color(0xffbae6fd);
  static const primary300 = Color(0xff7dd3fc);
  static const primary400 = Color(0xff38bdf8);
  static const primary500 = Color(0xff0ea5e9);
  static const primary600 = Color(0xff0284c7);
  static const primary700 = Color(0xff0369a1);
  static const primary800 = Color(0xff075985);
  static const primary900 = Color(0xff0c4a6e);
  static const primary950 = Color(0xff082f49);

  static const slate50 = Color(0xfff8fafc);
  static const slate100 = Color(0xfff1f5f9);
  static const slate200 = Color(0xffe2e8f0);
  static const slate300 = Color(0xffcbd5e1);
  static const slate400 = Color(0xff94a3b8);
  static const slate500 = Color(0xff64748b);
  static const slate600 = Color(0xff475569);
  static const slate700 = Color(0xff334155);
  static const slate800 = Color(0xff1e293b);
  static const slate900 = Color(0xff0f172a);
  static const slate950 = Color(0xff020617);
}

class AppTheme {
  static ThemeData get light => _theme(
        brightness: Brightness.light,
        scaffold: AppColors.slate50,
        card: Colors.white,
        text: AppColors.slate900,
      );

  static ThemeData get dark => _theme(
        brightness: Brightness.dark,
        scaffold: AppColors.slate950,
        card: AppColors.slate900,
        text: AppColors.slate50,
      );

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color text,
  }) {
    final isDark = brightness == Brightness.dark;
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final fontFamily = windows ? 'Noto Sans CJK SC' : null;
    final fontFamilyFallback = windows
        ? const <String>[
            'Microsoft YaHei UI',
            'Microsoft YaHei',
            'Segoe UI',
          ]
        : null;
    final baseTextTheme =
        Typography.material2021(platform: defaultTargetPlatform).black;
    final textTheme = _regularTextTheme(baseTextTheme).apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      bodyColor: text,
      displayColor: text,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary600,
      brightness: brightness,
      primary: AppColors.primary600,
      secondary: AppColors.primary500,
      surface: card,
    );

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      cardColor: card,
      dividerColor: isDark ? AppColors.slate800 : AppColors.slate200,
      canvasColor: card,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: card.withValues(alpha: 0.92),
        foregroundColor: text,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.slate300 : AppColors.slate700,
        ),
        floatingLabelStyle: TextStyle(
          color: isDark ? AppColors.slate200 : AppColors.slate700,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.slate300 : AppColors.slate700,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: text,
        iconColor: isDark ? AppColors.slate300 : AppColors.slate600,
        selectedColor: AppColors.primary600,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 15,
        ),
        subtitleTextStyle: TextStyle(
          color: isDark ? AppColors.slate300 : AppColors.slate600,
          fontSize: 13,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: text,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _regularButtonStyle(fontFamily),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _regularButtonStyle(fontFamily),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _regularButtonStyle(fontFamily),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _regularButtonStyle(fontFamily),
      ),
    );
  }

  static ButtonStyle _regularButtonStyle(String? fontFamily) {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static TextTheme _regularTextTheme(TextTheme theme) {
    TextStyle? regular(TextStyle? style) =>
        style?.copyWith(fontWeight: FontWeight.w400);

    return theme.copyWith(
      displayLarge: regular(theme.displayLarge),
      displayMedium: regular(theme.displayMedium),
      displaySmall: regular(theme.displaySmall),
      headlineLarge: regular(theme.headlineLarge),
      headlineMedium: regular(theme.headlineMedium),
      headlineSmall: regular(theme.headlineSmall),
      titleLarge: regular(theme.titleLarge),
      titleMedium: regular(theme.titleMedium),
      titleSmall: regular(theme.titleSmall),
      bodyLarge: regular(theme.bodyLarge),
      bodyMedium: regular(theme.bodyMedium),
      bodySmall: regular(theme.bodySmall),
      labelLarge: regular(theme.labelLarge),
      labelMedium: regular(theme.labelMedium),
      labelSmall: regular(theme.labelSmall),
    );
  }
}

extension ThemeBits on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isCompactWidth => MediaQuery.sizeOf(this).width < 600;
  bool get isPhoneWidth => MediaQuery.sizeOf(this).width < 430;
  Color get cardColor => Theme.of(this).cardColor;
  Color get primaryText => isDark ? AppColors.slate50 : AppColors.slate900;
  Color get mutedText => isDark ? AppColors.slate200 : AppColors.slate700;
  Color get secondaryText => isDark ? AppColors.slate200 : AppColors.slate700;
  Color get tertiaryText => isDark ? AppColors.slate300 : AppColors.slate700;
  Color get faintBorder => isDark ? AppColors.slate800 : AppColors.slate200;
  Color get subtleFill => isDark ? AppColors.slate800 : AppColors.slate50;

  double adaptiveFont(double compact, double regular, {double? wide}) {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 600) return compact;
    if (wide != null && width >= 1100) return wide;
    return regular;
  }
}
