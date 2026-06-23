part of 'settings_page.dart';

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return TingCard(
      radius: compact ? 22 : 24,
      padding: EdgeInsets.all(compact ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: compact ? 18 : 22),
          child,
        ],
      ),
    );
  }
}

class _TextSettingField extends StatelessWidget {
  const _TextSettingField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hintText,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData icon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.isDark ? AppColors.slate400 : AppColors.slate600,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 19),
          ),
        ),
      ],
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (context.isDark
              ? AppColors.primary700.withValues(alpha: 0.16)
              : AppColors.primary50)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 14,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary600 : context.faintBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                option.icon,
                color: selected ? AppColors.primary600 : context.mutedText,
                size: compact ? 22 : 24,
              ),
              SizedBox(height: compact ? 6 : 9),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary600 : context.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCopy extends StatelessWidget {
  const _SettingCopy({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
      ],
    );
  }
}

class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({
    required this.speed,
    required this.onSpeed,
    this.expanded = false,
  });

  final double speed;
  final ValueChanged<double> onSpeed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final value in speeds)
            if (expanded)
              Expanded(
                child: _SpeedButton(
                  label: value == 1.0 ? '1x' : '${value}x',
                  selected: (speed - value).abs() < 0.01,
                  onTap: () => onSpeed(value),
                ),
              )
            else
              _SpeedButton(
                label: value == 1.0 ? '1x' : '${value}x',
                selected: (speed - value).abs() < 0.01,
                onTap: () => onSpeed(value),
              ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.cardColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary600 : context.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleSettingRow extends StatelessWidget {
  const _ToggleSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: _SettingCopy(title: title, subtitle: subtitle)),
          const SizedBox(width: 16),
          _CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CustomSwitch extends StatelessWidget {
  const _CustomSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary600
              : (context.isDark ? AppColors.slate700 : AppColors.slate200),
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _EmbedTypeToggle extends StatelessWidget {
  const _EmbedTypeToggle({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmbedButton(
            label: '免登录 (带 Token)',
            selected: value == 'private',
            onTap: () => onChanged('private'),
          ),
          _EmbedButton(
            label: '需登录 (公开)',
            selected: value == 'public',
            onTap: () => onChanged('public'),
          ),
        ],
      ),
    );
  }
}

class _EmbedButton extends StatelessWidget {
  const _EmbedButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (context.isDark
              ? AppColors.primary700.withValues(alpha: 0.18)
              : AppColors.primary50)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary600 : context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.code,
    required this.onCopy,
  });

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 42, 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: SelectableText(
            code,
            style: TextStyle(
              color: context.tertiaryText,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            tooltip: '复制',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
        ),
      ],
    );
  }
}

class _WidgetSecurityHint extends StatelessWidget {
  const _WidgetSecurityHint({required this.embedType});

  final String embedType;

  @override
  Widget build(BuildContext context) {
    final private = embedType == 'private';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          private ? Icons.key_rounded : Icons.person_rounded,
          color: private ? Colors.orange : Colors.blue,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: 12,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: private ? '注意安全：' : '公开模式：',
                  style: TextStyle(
                    color: private ? Colors.orange : Colors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: private
                      ? '此代码包含您的访问凭证。请仅嵌入到您信任的私有页面。'
                      : '此代码不包含凭证，适合嵌入博客或公开网站，访客首次使用时需要登录。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LayoutCodePanel extends StatelessWidget {
  const _LayoutCodePanel({
    required this.title,
    required this.code,
    required this.onCopy,
  });

  final String title;
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 14),
              ),
            ],
          ),
          SelectableText(
            code,
            style: TextStyle(
              color: context.tertiaryText,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedBadge extends StatelessWidget {
  const _SavedBadge({
    required this.visible,
    required this.label,
    this.compact = false,
  });

  final bool visible;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: context.faintBorder);
  }
}
