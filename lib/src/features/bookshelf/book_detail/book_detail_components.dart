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

class _CollapsibleBookTags extends StatelessWidget {
  const _CollapsibleBookTags({
    required this.tags,
    required this.expanded,
    required this.alignment,
    required this.onExpandedChanged,
  });

  static const double _spacing = 8;
  static const double _runSpacing = 8;
  static const double _tagHorizontalPadding = 20;
  static const double _tagVerticalPadding = 10;
  static const double _layoutTolerance = 2;
  static const TextStyle _tagTextStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  final List<String> tags;
  final bool expanded;
  final WrapAlignment alignment;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return _TagWrap(
            tags: tags,
            alignment: alignment,
          );
        }

        final direction = Directionality.of(context);
        final textStyle =
            DefaultTextStyle.of(context).style.merge(_tagTextStyle);
        final tagWidths = [
          for (final tag in tags)
            _measureText(tag, textStyle, direction) +
                _tagHorizontalPadding +
                _layoutTolerance,
        ];
        final overflowing = _wrapsToMultipleRows(tagWidths, maxWidth);
        final collapseLabel = context.localeText('收起', 'Less');
        final moreLabel = context.localeText('更多', 'More');

        if (!overflowing) {
          return _TagWrap(tags: tags, alignment: alignment);
        }

        if (expanded) {
          return _TagWrap(
            tags: tags,
            alignment: alignment,
            trailing: _BookTagToggle(
              label: collapseLabel,
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: () => onExpandedChanged(false),
            ),
          );
        }

        final rowHeight = _tagRowHeight(textStyle, direction);
        final moreWidth = _toggleWidth(moreLabel, textStyle, direction);
        final availableForTags = math.max(0.0, maxWidth - moreWidth - _spacing);
        final visibleTags =
            tags.take(_visibleTagCount(tagWidths, availableForTags)).toList();

        return SizedBox(
          height: rowHeight,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              child: _TagWrap(
                tags: visibleTags,
                alignment: alignment,
                trailing: _BookTagToggle(
                  label: moreLabel,
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: () => onExpandedChanged(true),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _measureText(
    String text,
    TextStyle style,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  static double _tagRowHeight(TextStyle style, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: 'Tags', style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    return painter.height + _tagVerticalPadding + _layoutTolerance;
  }

  static double _toggleWidth(
    String label,
    TextStyle style,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    return painter.width + 12 + 3 + 18 + _layoutTolerance;
  }

  static bool _wrapsToMultipleRows(List<double> widths, double maxWidth) {
    var rowWidth = 0.0;
    for (final width in widths) {
      final nextWidth = rowWidth == 0 ? width : rowWidth + _spacing + width;
      if (nextWidth > maxWidth && rowWidth > 0) return true;
      rowWidth = width > maxWidth ? maxWidth : nextWidth;
    }
    return false;
  }

  static int _visibleTagCount(List<double> widths, double maxWidth) {
    var rowWidth = 0.0;
    var count = 0;
    for (final width in widths) {
      final nextWidth = rowWidth == 0 ? width : rowWidth + _spacing + width;
      if (nextWidth > maxWidth && rowWidth > 0) break;
      rowWidth = width > maxWidth ? maxWidth : nextWidth;
      count++;
    }
    return count;
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.tags,
    required this.alignment,
    this.trailing,
  });

  final List<String> tags;
  final WrapAlignment alignment;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: _CollapsibleBookTags._runSpacing,
      children: [
        for (final tag in tags) _BookTag(label: tag),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _BookTagToggle extends StatelessWidget {
  const _BookTagToggle({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary600;
    return Material(
      color: context.isDark
          ? AppColors.primary600.withValues(alpha: 0.14)
          : AppColors.primary50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.isDark
                  ? AppColors.primary600.withValues(alpha: 0.24)
                  : AppColors.primary100,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary600.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookActionPanel extends StatefulWidget {
  const _BookActionPanel({
    required this.favorite,
    required this.admin,
    required this.resumeLabel,
    required this.themeColor,
    required this.extensionContext,
    required this.onPlay,
    required this.onFavorite,
    required this.onScrape,
    required this.onEdit,
  });

  final bool favorite;
  final bool admin;
  final String resumeLabel;
  final Color? themeColor;
  final Map<String, Object?> extensionContext;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;
  final VoidCallback onScrape;
  final VoidCallback onEdit;

  @override
  State<_BookActionPanel> createState() => _BookActionPanelState();
}

class _BookActionPanelState extends State<_BookActionPanel> {
  bool _hasBookDetailExtensions = false;
  String? _loadedToken;
  int? _loadedRevision;
  bool _loadingExtensions = false;
  bool _reloadQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.appOf(context);
    final revision = app.pluginExtensionRevision;
    if (app.offlineMode || app.token == null) {
      _loadedToken = null;
      _loadedRevision = null;
      if (_hasBookDetailExtensions) {
        setState(() => _hasBookDetailExtensions = false);
      }
      return;
    }
    if (app.token == _loadedToken && revision == _loadedRevision) return;
    _loadedToken = app.token;
    _loadedRevision = revision;
    _loadBookDetailExtensions();
  }

  Future<void> _loadBookDetailExtensions() async {
    if (_loadingExtensions) {
      _reloadQueued = true;
      return;
    }
    setState(() => _loadingExtensions = true);
    try {
      final api = AppScope.appOf(context).pluginCapabilities;
      final registrations = [
        ...await api.listPluginCapabilities(kind: 'ui_extension'),
        ...await api.listPluginCapabilities(kind: 'client_extension'),
      ];
      if (!mounted) return;
      final registry = buildClientExtensionRegistry(registrations);
      final hasExtensions =
          (registry.bySlot[ClientExtensionSlot.bookDetailAction] ?? const [])
              .isNotEmpty;
      setState(() => _hasBookDetailExtensions = hasExtensions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasBookDetailExtensions = false);
    } finally {
      if (mounted) {
        setState(() => _loadingExtensions = false);
        if (_reloadQueued) {
          _reloadQueued = false;
          _loadBookDetailExtensions();
        }
      }
    }
  }

  static double _measureActionLabelWidth(
    BuildContext context,
    Iterable<String> labels,
    double fontSize,
  ) {
    final direction = Directionality.of(context);
    final style = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
          ),
        );
    var maxWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      maxWidth = math.max(maxWidth, painter.width);
    }
    return maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final playBackground = widget.themeColor ?? AppColors.primary600;
    final playForeground =
        widget.themeColor != null && _isThemeLight(widget.themeColor!)
            ? AppColors.slate600
            : Colors.white;
    final favoriteLabel = context.localeText(
      widget.favorite ? '已收藏' : '收藏',
      widget.favorite ? 'Favorited' : 'Favorite',
    );
    final scrapeLabel = context.localeText('刮削', 'Scrape');
    final editLabel = context.l10n.commonEdit;
    final moreLabel = context.localeText('更多', 'More');
    final widthLabels = <String>[
      context.localeText('收藏', 'Favorite'),
      context.localeText('已收藏', 'Favorited'),
      if (widget.admin) scrapeLabel,
      if (widget.admin) editLabel,
      if (_hasBookDetailExtensions) moreLabel,
    ];
    final actionCount =
        1 + (widget.admin ? 2 : 0) + (_hasBookDetailExtensions ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 448.0;
        final actionGap = maxWidth < 430
            ? 4.0
            : maxWidth < 768
                ? 6.0
                : 12.0;
        final actionFontSize = maxWidth < 430
            ? 11.0
            : maxWidth < 768
                ? 12.0
                : 14.0;
        final actionIconSize = maxWidth < 768 ? 18.0 : 20.0;
        final actionPadding = maxWidth < 430
            ? 6.0
            : maxWidth < 768
                ? 8.0
                : 12.0;
        final actionIconTextGap = maxWidth < 430
            ? 4.0
            : maxWidth < 768
                ? 6.0
                : 8.0;
        final showActionLabels = maxWidth >= 380;
        final labelActionButtonWidth = math.max(
          maxWidth < 430 ? 88.0 : 100.0,
          _measureActionLabelWidth(context, widthLabels, actionFontSize) + 68,
        );
        final actionButtonWidth =
            showActionLabels ? labelActionButtonWidth : 52.0;
        final targetWidth =
            actionButtonWidth * actionCount + actionGap * (actionCount - 1);
        final panelWidth = maxWidth < 768
            ? maxWidth
            : math.min(
                maxWidth,
                math.max(math.min(320.0, maxWidth), targetWidth),
              );

        final actionButtons = <Widget>[
          _DetailActionButton(
            label: favoriteLabel,
            icon: widget.favorite
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            selected: widget.favorite,
            selectedColor: const Color(0xffef4444),
            showLabel: showActionLabels,
            fontSize: actionFontSize,
            iconSize: actionIconSize,
            horizontalPadding: actionPadding,
            iconTextGap: actionIconTextGap,
            onPressed: widget.onFavorite,
          ),
          if (widget.admin)
            _DetailActionButton(
              label: scrapeLabel,
              icon: Icons.refresh_rounded,
              showLabel: showActionLabels,
              fontSize: actionFontSize,
              iconSize: actionIconSize,
              horizontalPadding: actionPadding,
              iconTextGap: actionIconTextGap,
              onPressed: widget.onScrape,
            ),
          if (widget.admin)
            _DetailActionButton(
              label: editLabel,
              icon: Icons.edit_rounded,
              showLabel: showActionLabels,
              fontSize: actionFontSize,
              iconSize: actionIconSize,
              horizontalPadding: actionPadding,
              iconTextGap: actionIconTextGap,
              onPressed: widget.onEdit,
            ),
          if (_hasBookDetailExtensions)
            PluginExtensionSlot(
              slot: ClientExtensionSlot.bookDetailAction,
              extensionContext: widget.extensionContext,
              menuLabel: moreLabel,
              showMenuLabel: showActionLabels,
              buttonHeight: 48,
              iconSize: actionIconSize,
              menuFontSize: actionFontSize,
              menuHorizontalPadding: actionPadding,
              menuIconTextGap: actionIconTextGap,
            ),
        ];

        return SizedBox(
          width: panelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onPlay,
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
                              constraints:
                                  BoxConstraints(maxWidth: labelMaxWidth),
                              child: _ScrollingButtonLabel(
                                text: widget.resumeLabel,
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
              Row(
                children: [
                  for (var index = 0;
                      index < actionButtons.length;
                      index++) ...[
                    if (index > 0) SizedBox(width: actionGap),
                    Expanded(child: actionButtons[index]),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
    this.showLabel = true,
    this.fontSize = 14,
    this.iconSize = 20,
    this.horizontalPadding = 12,
    this.iconTextGap = 8,
    this.selected = false,
    this.selectedColor = AppColors.primary600,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool showLabel;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double iconTextGap;
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
        height: 48,
        child: TextButton(
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: color,
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(widget.icon, size: widget.iconSize),
              if (widget.showLabel) ...[
                SizedBox(width: widget.iconTextGap),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
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
  static const int _collapsedMaxLines = 2;
  static const double _panelPadding = 16;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final descriptionStyle = DefaultTextStyle.of(context).style.merge(
              TextStyle(
                color: context.isDark ? AppColors.slate400 : AppColors.slate600,
                height: 1.6,
                fontSize: 15,
              ),
            );
        final textWidth = constraints.maxWidth.isFinite
            ? math.max(0.0, constraints.maxWidth - _panelPadding * 2)
            : double.infinity;
        final isDescriptionOverflowing = _doesDescriptionOverflow(
          widget.description,
          descriptionStyle,
          Directionality.of(context),
          textWidth,
          MediaQuery.textScalerOf(context),
        );
        final showToggle = isDescriptionOverflowing || _expanded;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_panelPadding),
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
                    color: context.isDark
                        ? AppColors.slate400
                        : AppColors.slate600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.localeText('简介内容', 'Description'),
                    style: TextStyle(
                      color: context.isDark
                          ? AppColors.slate300
                          : AppColors.slate700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                maxLines: _expanded ? null : _collapsedMaxLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: descriptionStyle,
              ),
              if (showToggle) ...[
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
                    context.localeText(
                      _expanded ? '收起详情' : '展开全部',
                      _expanded ? 'Less' : 'More',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static bool _doesDescriptionOverflow(
    String text,
    TextStyle style,
    TextDirection direction,
    double maxWidth,
    TextScaler textScaler,
  ) {
    if (text.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: _collapsedMaxLines,
      ellipsis: '\u2026',
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }
}
