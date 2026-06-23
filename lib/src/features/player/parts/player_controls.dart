part of '../mini_player.dart';

class _MiniProgressSlider extends StatefulWidget {
  const _MiniProgressSlider({
    required this.player,
    required this.currentTime,
    required this.duration,
    required this.percent,
    required this.accentColor,
  });

  final PlayerState player;
  final double currentTime;
  final double duration;
  final double percent;
  final Color accentColor;

  @override
  State<_MiniProgressSlider> createState() => _MiniProgressSliderState();
}


class _MiniProgressSliderState extends State<_MiniProgressSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration > 0 ? widget.duration : 1.0;
    final value = (_dragValue ?? widget.currentTime).clamp(0, max).toDouble();
    final canSeek = max > 1 || widget.percent > 0;
    return SizedBox(
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: widget.accentColor,
          inactiveTrackColor:
              context.isDark ? AppColors.slate800 : AppColors.slate200,
          thumbColor: widget.accentColor,
          overlayColor: widget.accentColor.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          min: 0,
          max: max,
          value: value,
          onChanged:
              canSeek ? (next) => setState(() => _dragValue = next) : null,
          onChangeStart:
              canSeek ? (_) => setState(() => _dragValue = value) : null,
          onChangeEnd: canSeek
              ? (next) {
                  setState(() => _dragValue = null);
                  widget.player.seek(next);
                }
              : null,
        ),
      ),
    );
  }
}


class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.color,
    this.onPressed,
    this.onPressedWithContext,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final Color color;
  final Future<void> Function()? onPressed;
  final Future<void> Function(BuildContext context)? onPressedWithContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final contextHandler = onPressedWithContext;
          if (contextHandler != null) {
            contextHandler(context);
            return;
          }
          onPressed?.call();
        },
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}


class _MiniCollapseButton extends StatelessWidget {
  const _MiniCollapseButton({
    this.icon = Icons.keyboard_arrow_down_rounded,
    required this.color,
    required this.onPressed,
    this.plain = false,
    this.size,
    this.circleSize,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool plain;
  final double? size;
  final double? circleSize;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final targetSize = size ?? (plain ? 32.0 : 48.0);
    final visualSize = circleSize ?? 38.0;
    final resolvedIconSize = iconSize ?? 22.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: targetSize,
        height: targetSize,
        child: Center(
          child: plain
              ? Icon(icon, color: color, size: resolvedIconSize)
              : Container(
                  width: visualSize,
                  height: visualSize,
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate800.withValues(alpha: 0.52)
                        : AppColors.slate100.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: resolvedIconSize,
                  ),
                ),
        ),
      ),
    );
  }
}


class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final light = _isPlayerThemeLight(color);
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPressed(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: light ? AppColors.slate600 : color,
              decoration: TextDecoration.none,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}


class _PlaybackSettingField extends StatelessWidget {
  const _PlaybackSettingField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: context.mutedText),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: context.isDark ? AppColors.slate800 : AppColors.slate50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary500, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}


class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.ghost = false,
    this.diameter,
    this.iconSize,
    this.fillColor,
    this.filledIconColor,
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final bool filled;
  final bool ghost;
  final double? diameter;
  final double? iconSize;
  final Color? fillColor;
  final Color? filledIconColor;

  @override
  Widget build(BuildContext context) {
    final size = diameter ?? (filled ? 46 : 38);
    final resolvedIconSize = iconSize ?? (filled ? 28 : 22);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: filled
            ? (fillColor ?? AppColors.primary600)
            : ghost
                ? Colors.transparent
                : (context.isDark
                    ? AppColors.slate800.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6)),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onPressed(),
          child: Icon(
            icon,
            color:
                filled ? (filledIconColor ?? Colors.white) : context.mutedText,
            size: resolvedIconSize,
          ),
        ),
      ),
    );
  }
}


class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.onTapWithContext,
    this.active = false,
  }) : assert(onTap != null || onTapWithContext != null);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Future<void> Function(BuildContext context)? onTapWithContext;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary600;
    return InkWell(
      onTap: () {
        final handler = onTapWithContext;
        if (handler != null) {
          handler(context);
        } else {
          onTap?.call();
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 36,
              child: Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: active ? activeColor : context.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? activeColor : context.tertiaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ExpandedDownloadAction {
  const _ExpandedDownloadAction({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
}


class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onPressed(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 31, color: context.mutedText),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

