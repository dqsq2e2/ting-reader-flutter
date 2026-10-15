part of 'login_page.dart';

class _LoginPreferencesBar extends StatelessWidget {
  const _LoginPreferencesBar({
    required this.language,
    required this.theme,
    required this.enabled,
    required this.onLanguage,
    required this.onTheme,
  });

  final String language;
  final String theme;
  final bool enabled;
  final ValueChanged<String> onLanguage;
  final ValueChanged<String> onTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageName =
        language == 'en' ? l10n.settingsLanguageEn : l10n.settingsLanguageZh;
    final themeName = switch (theme) {
      'light' => l10n.settingsLight,
      'dark' => l10n.settingsDark,
      _ => l10n.settingsSystem,
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '${l10n.settingsLanguage}: $languageName',
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: enabled
                ? () => onLanguage(language == 'en' ? 'zh' : 'en')
                : null,
            icon: _LoginLanguageIcon(
              reversed: language == 'en',
              color: context.mutedText,
            ),
          ),
          IconButton(
            tooltip: '${l10n.settingsAppearance}: $themeName',
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: enabled
                ? () => onTheme(switch (theme) {
                      'system' => 'light',
                      'light' => 'dark',
                      _ => 'system',
                    })
                : null,
            icon: Icon(
              switch (theme) {
                'light' => Icons.light_mode_rounded,
                'dark' => Icons.dark_mode_rounded,
                _ => Icons.monitor_rounded,
              },
              size: 20,
              color: context.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLanguageIcon extends StatelessWidget {
  const _LoginLanguageIcon({
    required this.reversed,
    required this.color,
  });

  final bool reversed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(20),
      painter: _LoginLanguageIconPainter(
        reversed: reversed,
        color: color,
      ),
    );
  }
}

class _LoginLanguageIconPainter extends CustomPainter {
  const _LoginLanguageIconPainter({
    required this.reversed,
    required this.color,
  });

  final bool reversed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 26;
    final translationOffset = reversed ? const Offset(10, 10) : Offset.zero;
    final letterOffset = reversed ? const Offset(-10, -10) : const Offset(2, 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scale, scale);

    canvas.drawLine(
      const Offset(5, 8) + translationOffset,
      const Offset(11, 14) + translationOffset,
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(4 + translationOffset.dx, 14 + translationOffset.dy)
        ..lineTo(10 + translationOffset.dx, 8 + translationOffset.dy)
        ..lineTo(12 + translationOffset.dx, 5 + translationOffset.dy),
      paint,
    );
    canvas.drawLine(
      const Offset(2, 5) + translationOffset,
      const Offset(14, 5) + translationOffset,
      paint,
    );
    canvas.drawLine(
      const Offset(7, 2) + translationOffset,
      const Offset(8, 2) + translationOffset,
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(22 + letterOffset.dx, 22 + letterOffset.dy)
        ..lineTo(17 + letterOffset.dx, 12 + letterOffset.dy)
        ..lineTo(12 + letterOffset.dx, 22 + letterOffset.dy),
      paint,
    );
    canvas.drawLine(
      const Offset(14, 18) + letterOffset,
      const Offset(20, 18) + letterOffset,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoginLanguageIconPainter oldDelegate) {
    return oldDelegate.reversed != reversed || oldDelegate.color != color;
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', width: 74, height: 74),
        const SizedBox(height: 14),
        const Text(
          'Ting Reader',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.authTagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText),
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          context.localeText('登录即表示您已阅读并同意', 'I agree to'),
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        _LegalLink(
          label: context.localeText('用户协议', 'User Agreement'),
          url: localizedUserAgreementUrl(languageCode),
        ),
        Text(
          context.localeText('和', '&'),
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        _LegalLink(
          label: context.localeText('隐私协议', 'Privacy Policy'),
          url: localizedPrivacyPolicyUrl(languageCode),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openExternalUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary600,
          ),
        ),
      ),
    );
  }
}

class _EmptyServerCard extends StatelessWidget {
  const _EmptyServerCard({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.dns_rounded, size: 30, color: context.mutedText),
          const SizedBox(height: 10),
          Text(
            context.l10n.authNoServer,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.authNoServerDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.l10n.authAddServer),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
