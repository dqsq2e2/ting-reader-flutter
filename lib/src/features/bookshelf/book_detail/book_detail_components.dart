part of 'book_detail_page.dart';

enum CoverShapePreference { rect, square }

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppBackButton(onPressed: onPressed);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary500),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: context.isDark ? AppColors.slate400 : AppColors.slate600,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BookTag extends StatelessWidget {
  const _BookTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.isDark
              ? AppColors.slate700.withValues(alpha: 0.5)
              : AppColors.slate200.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.isDark ? AppColors.slate400 : AppColors.slate600,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BookActionPanel extends StatelessWidget {
  const _BookActionPanel({
    required this.favorite,
    required this.admin,
    required this.resumeLabel,
    required this.themeColor,
    required this.onPlay,
    required this.onFavorite,
    required this.onScrape,
    required this.onEdit,
  });

  final bool favorite;
  final bool admin;
  final String resumeLabel;
  final Color? themeColor;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;
  final VoidCallback onScrape;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final playBackground = themeColor ?? AppColors.primary600;
    final playForeground = themeColor != null && _isThemeLight(themeColor!)
        ? AppColors.slate600
        : Colors.white;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: playBackground,
                foregroundColor: playForeground,
                elevation: 0,
                shadowColor: playBackground.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                minimumSize: const Size(0, 52),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelMaxWidth = (constraints.maxWidth - 28)
                      .clamp(0.0, constraints.maxWidth);
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 20),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: labelMaxWidth),
                          child: _ScrollingButtonLabel(
                            text: resumeLabel,
                            style: const TextStyle(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactActions = constraints.maxWidth < 420;
              final buttons = [
                _DetailActionButton(
                  width: compactActions ? null : (admin ? 132 : 180),
                  label: favorite ? '已收藏' : '收藏',
                  icon: favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  selected: favorite,
                  selectedColor: const Color(0xffef4444),
                  onPressed: onFavorite,
                ),
                if (admin)
                  _DetailActionButton(
                    width: compactActions ? null : 132,
                    label: '刮削',
                    icon: Icons.refresh_rounded,
                    onPressed: onScrape,
                  ),
                if (admin)
                  _DetailActionButton(
                    width: compactActions ? null : 132,
                    label: '编辑',
                    icon: Icons.edit_rounded,
                    onPressed: onEdit,
                  ),
              ];

              if (compactActions) {
                return Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      Expanded(child: buttons[i]),
                      if (i < buttons.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: buttons,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScrollingButtonLabel extends StatefulWidget {
  const _ScrollingButtonLabel({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_ScrollingButtonLabel> createState() => _ScrollingButtonLabelState();
}

class _ScrollingButtonLabelState extends State<_ScrollingButtonLabel>
    with SingleTickerProviderStateMixin {
  static const _gap = 32.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );
  String? _lastText;
  double? _lastWidth;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        final textWidth = painter.width;
        final overflowing = textWidth > maxWidth;

        if (!overflowing || maxWidth <= 0) {
          if (_controller.isAnimating) _controller.stop();
          _lastText = widget.text;
          _lastWidth = maxWidth;
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          );
        }

        final distance = textWidth + _gap;
        if (_lastText != widget.text || _lastWidth != maxWidth) {
          _lastText = widget.text;
          _lastWidth = maxWidth;
          _controller
            ..duration = Duration(
              milliseconds: (distance * 40).round().clamp(4200, 12000),
            )
            ..reset()
            ..repeat();
        } else if (!_controller.isAnimating) {
          _controller.repeat();
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-distance * _controller.value, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.text, maxLines: 1, style: style),
                const SizedBox(width: _gap),
                Text(widget.text, maxLines: 1, style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailActionButton extends StatefulWidget {
  const _DetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.width,
    this.selected = false,
    this.selectedColor = AppColors.primary600,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double? width;
  final bool selected;
  final Color selectedColor;

  @override
  State<_DetailActionButton> createState() => _DetailActionButtonState();
}

class _DetailActionButtonState extends State<_DetailActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? widget.selectedColor
        : (_hovered ? AppColors.primary600 : context.mutedText);
    final bg = widget.selected
        ? (widget.selectedColor == const Color(0xffef4444)
            ? const Color(0xfffff1f2)
            : AppColors.primary50)
        : context.cardColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: widget.width,
        height: 48,
        child: TextButton.icon(
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.selected
                    ? widget.selectedColor.withValues(alpha: 0.22)
                    : context.faintBorder,
              ),
            ),
          ),
          icon: Icon(widget.icon, size: 20),
          label: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _DescriptionPanel extends StatefulWidget {
  const _DescriptionPanel({
    required this.description,
    required this.themeColor,
  });

  final String description;
  final Color? themeColor;

  @override
  State<_DescriptionPanel> createState() => _DescriptionPanelState();
}

class _DescriptionPanelState extends State<_DescriptionPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.themeColor != null && !context.isDark
            ? widget.themeColor!.withValues(alpha: 0.08)
            : (context.isDark
                ? AppColors.slate900.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.74)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? AppColors.slate800.withValues(alpha: 0.5)
              : AppColors.slate200.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: context.isDark ? AppColors.slate400 : AppColors.slate600,
              ),
              const SizedBox(width: 8),
              Text(
                '简介内容',
                style: TextStyle(
                  color:
                      context.isDark ? AppColors.slate300 : AppColors.slate700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: context.isDark ? AppColors.slate400 : AppColors.slate600,
              height: 1.6,
              fontSize: 15,
            ),
          ),
          if (widget.description.length > 80) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary600,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              label: Text(
                _expanded ? '收起详情' : '展开全部',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
