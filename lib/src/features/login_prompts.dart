part of 'login_page.dart';

class _CredentialPrompt extends StatefulWidget {
  const _CredentialPrompt({required this.builder});
  final Widget Function(BuildContext, TextEditingController) builder;

  @override
  State<_CredentialPrompt> createState() => _CredentialPromptState();
}

class _CredentialPromptState extends State<_CredentialPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

class _GatewayAuthPromptDialog extends StatelessWidget {
  const _GatewayAuthPromptDialog({
    required this.icon,
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.fieldHint,
    required this.fieldIcon,
    required this.controller,
    required this.confirmLabel,
    required this.onConfirm,
    this.descriptionIsError = false,
    this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.fieldSuffix,
    this.belowField,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool descriptionIsError;
  final String fieldLabel;
  final String fieldHint;
  final IconData fieldIcon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscureText;
  final Widget? fieldSuffix;
  final Widget? belowField;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final belowFieldValue = belowField;
    final isDark = context.isDark;
    return Dialog(
      backgroundColor: context.cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary600.withValues(alpha: 0.16)
                          : AppColors.primary50,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isDark
                            ? AppColors.primary600.withValues(alpha: 0.3)
                            : AppColors.primary100,
                      ),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.primary600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PromptMessageBox(
                text: description,
                isError: descriptionIsError,
              ),
              const SizedBox(height: 16),
              Text(
                fieldLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscureText,
                keyboardType: keyboardType,
                maxLength: maxLength,
                onSubmitted: (_) => onConfirm(),
                decoration: InputDecoration(
                  hintText: fieldHint,
                  counterText: '',
                  prefixIcon: Icon(
                    fieldIcon,
                    color: AppColors.slate400,
                    size: 20,
                  ),
                  suffixIcon: fieldSuffix,
                ),
              ),
              if (belowFieldValue != null) ...[
                const SizedBox(height: 4),
                belowFieldValue,
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗内的说明条：普通提示用主色浅底，错误提示用红色浅底。
class _PromptMessageBox extends StatelessWidget {
  const _PromptMessageBox({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final background = isError
        ? Colors.red.withValues(alpha: 0.08)
        : (isDark
            ? AppColors.primary600.withValues(alpha: 0.12)
            : AppColors.primary50);
    final border = isError
        ? Colors.red.withValues(alpha: 0.16)
        : (isDark
            ? AppColors.primary600.withValues(alpha: 0.24)
            : AppColors.primary100);
    final textColor = isError
        ? Colors.red
        : (isDark ? AppColors.slate300 : AppColors.slate600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: isError ? Colors.red : AppColors.primary600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
