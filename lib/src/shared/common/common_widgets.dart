import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../app_scope.dart';

class TingCard extends StatelessWidget {
  const TingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.faintBorder),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class HorizontalScrollControls extends StatefulWidget {
  const HorizontalScrollControls({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controlsBreakpoint = 640,
    this.scrollFraction = 0.72,
    this.controlInset = 2,
    this.controlSize = 32,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double controlsBreakpoint;
  final double scrollFraction;
  final double controlInset;
  final double controlSize;

  @override
  State<HorizontalScrollControls> createState() =>
      _HorizontalScrollControlsState();
}

class _HorizontalScrollControlsState extends State<HorizontalScrollControls> {
  final _controller = ScrollController();
  bool _canScrollStart = false;
  bool _canScrollEnd = false;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleExtentUpdate);
  }

  @override
  void didUpdateWidget(covariant HorizontalScrollControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleExtentUpdate();
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleExtentUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleExtentUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final canScrollStart = position.pixels > 1;
      final canScrollEnd = position.pixels < position.maxScrollExtent - 1;
      if (canScrollStart == _canScrollStart && canScrollEnd == _canScrollEnd) {
        return;
      }
      setState(() {
        _canScrollStart = canScrollStart;
        _canScrollEnd = canScrollEnd;
      });
    });
  }

  void _scrollBy(double direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final delta = position.viewportDimension * widget.scrollFraction;
    final target = (position.pixels + delta * direction)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleExtentUpdate();
    return LayoutBuilder(
      builder: (context, constraints) {
        final showControls = constraints.maxWidth >= widget.controlsBreakpoint;
        return Stack(
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.centerLeft,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _scheduleExtentUpdate();
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                padding: showControls
                    ? _withHorizontalControlSpace(widget.padding)
                    : widget.padding,
                scrollDirection: Axis.horizontal,
                child: widget.child,
              ),
            ),
            if (showControls && _canScrollStart)
              Positioned.fill(
                right: null,
                child: IgnorePointer(
                  child: Container(
                    width: widget.controlSize + 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.cardColor,
                          context.cardColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (showControls && _canScrollEnd)
              Positioned.fill(
                left: null,
                child: IgnorePointer(
                  child: Container(
                    width: widget.controlSize + 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          context.cardColor,
                          context.cardColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (showControls && _canScrollStart)
              Positioned(
                left: widget.controlInset,
                child: _HorizontalScrollButton(
                  icon: Icons.chevron_left_rounded,
                  size: widget.controlSize,
                  onTap: () => _scrollBy(-1),
                ),
              ),
            if (showControls && _canScrollEnd)
              Positioned(
                right: widget.controlInset,
                child: _HorizontalScrollButton(
                  icon: Icons.chevron_right_rounded,
                  size: widget.controlSize,
                  onTap: () => _scrollBy(1),
                ),
              ),
          ],
        );
      },
    );
  }

  EdgeInsetsGeometry _withHorizontalControlSpace(EdgeInsetsGeometry padding) {
    final resolved = padding.resolve(TextDirection.ltr);
    final extra = widget.controlSize + widget.controlInset + 8;
    return EdgeInsets.fromLTRB(
      resolved.left,
      resolved.top,
      resolved.right + extra,
      resolved.bottom,
    );
  }
}

class _HorizontalScrollButton extends StatelessWidget {
  const _HorizontalScrollButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: context.isDark ? 0.36 : 0.16),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.faintBorder),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: size * 0.68, color: context.secondaryText),
        ),
      ),
    );
  }
}

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.faintBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDark ? 0.24 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

EdgeInsets pagePaddingForWidth(double width) {
  if (width >= 768) return const EdgeInsets.all(32);
  if (width >= 640) return const EdgeInsets.all(24);
  return const EdgeInsets.all(16);
}

class PageListView extends StatelessWidget {
  const PageListView({
    super.key,
    required this.children,
    this.onRefresh,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = ListView(
          padding: pagePaddingForWidth(constraints.maxWidth),
          children: children,
        );

        if (onRefresh == null) return list;
        return RefreshIndicator(
          color: AppColors.primary600,
          onRefresh: onRefresh!,
          child: list,
        );
      },
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '加载中...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary600,
            ),
          ),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(color: context.mutedText)),
        ],
      ),
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.label = '返回',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = context.isDark ? AppColors.slate300 : AppColors.slate600;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: context.isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDark ? AppColors.slate800 : AppColors.slate200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BatchCheckbox extends StatelessWidget {
  const BatchCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
    this.compact,
    this.enabled = true,
    this.interactive = true,
    this.tooltip,
    this.visualSize,
  });

  final bool checked;
  final VoidCallback? onChanged;
  final bool? compact;
  final bool enabled;
  final bool interactive;
  final String? tooltip;
  final double? visualSize;

  @override
  Widget build(BuildContext context) {
    final narrow = compact ?? MediaQuery.sizeOf(context).width < 640;
    final active = enabled && onChanged != null;
    final boxSize = visualSize ?? (narrow ? 21.0 : 23.0);
    final tapSize = narrow ? 34.0 : 38.0;
    final borderColor = checked
        ? AppColors.primary600
        : (context.isDark ? AppColors.slate500 : AppColors.slate400);
    final fillColor = checked
        ? AppColors.primary600
        : (context.isDark ? AppColors.slate900 : Colors.white);
    final check = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(narrow ? 5 : 6),
        border: Border.all(
          color: active ? borderColor : borderColor.withValues(alpha: 0.55),
          width: checked ? 0 : 1.8,
        ),
        boxShadow: checked
            ? [
                BoxShadow(
                  color: AppColors.primary600.withValues(alpha: 0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: checked
          ? Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: boxSize * 0.72,
            )
          : null,
    );
    final visual = Opacity(
      opacity: enabled ? 1 : 0.48,
      child: SizedBox.square(
        dimension: interactive ? tapSize : boxSize,
        child: Center(child: check),
      ),
    );

    Widget result = interactive
        ? Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: active ? onChanged : null,
              radius: tapSize / 2,
              child: visual,
            ),
          )
        : visual;
    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return result;
  }
}

class BatchSelectButton extends StatelessWidget {
  const BatchSelectButton({
    super.key,
    required this.checked,
    required this.label,
    this.onPressed,
    this.compact,
  });

  final bool checked;
  final String label;
  final VoidCallback? onPressed;
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final narrow = compact ?? MediaQuery.sizeOf(context).width < 640;
    return BatchActionButton(
      label: label,
      onPressed: onPressed,
      compact: narrow,
      leading: BatchCheckbox(
        checked: checked,
        enabled: onPressed != null,
        interactive: false,
        compact: narrow,
      ),
    );
  }
}

class BatchActionButton extends StatelessWidget {
  const BatchActionButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.onPressed,
    this.compact,
    this.filled = false,
    this.danger = false,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback? onPressed;
  final bool? compact;
  final bool filled;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final narrow = compact ?? MediaQuery.sizeOf(context).width < 640;
    final height = narrow ? 40.0 : 44.0;
    final enabled = onPressed != null && !loading;
    final accent = danger ? const Color(0xffef4444) : AppColors.primary600;
    final background = !enabled
        ? (context.isDark ? AppColors.slate800 : AppColors.slate100)
        : filled
            ? accent
            : danger
                ? (context.isDark
                    ? const Color(0xff3f1d22)
                    : const Color(0xfffff1f2))
                : (context.isDark ? AppColors.slate800 : Colors.white);
    final foreground = !enabled
        ? context.mutedText
        : filled
            ? Colors.white
            : danger
                ? accent
                : context.secondaryText;
    final borderColor = filled
        ? Colors.transparent
        : danger
            ? accent.withValues(alpha: context.isDark ? 0.38 : 0.18)
            : context.faintBorder;
    final loader = SizedBox(
      width: narrow ? 15 : 16,
      height: narrow ? 15 : 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: foreground,
      ),
    );
    final iconWidget = loading
        ? loader
        : leading ??
            (icon == null
                ? null
                : Icon(icon, size: narrow ? 17 : 18, color: foreground));
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(narrow ? 12 : 14),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(narrow ? 12 : 14),
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 12 : 15,
              vertical: narrow ? 8 : 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(narrow ? 12 : 14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconWidget != null) ...[
                  iconWidget,
                  SizedBox(width: narrow ? 6 : 8),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: narrow ? 13 : 14,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BatchCountBadge extends StatelessWidget {
  const BatchCountBadge({
    super.key,
    required this.label,
    this.compact,
  });

  final String label;
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final narrow = compact ?? MediaQuery.sizeOf(context).width < 640;
    return Container(
      constraints: BoxConstraints(minHeight: narrow ? 36 : 40),
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 14,
        vertical: narrow ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(narrow ? 12 : 14),
        border: Border.all(color: context.faintBorder),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.secondaryText,
            fontSize: narrow ? 13 : 14,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.dashed = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.faintBorder,
          style: dashed ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.slate800 : AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary600, size: 38),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary600.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.check_rounded, size: 18),
      label: Text(
        loading ? '处理中...' : label,
      ),
    );
  }
}

class CoverImage extends StatefulWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.menu_book_rounded,
  });

  final String url;
  final double radius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  bool _recoveringRedirect = false;
  int _retryEpoch = 0;
  String? _failedUrl;
  String? _recoveredUrl;

  @override
  void didUpdateWidget(covariant CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failedUrl = null;
      _recoveredUrl = null;
      _recoveringRedirect = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _recoveredUrl ?? widget.url;
    final localFile = _localImageFile(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: url.isEmpty
          ? _placeholder(context)
          : localFile != null
              ? Image.file(
                  localFile,
                  fit: widget.fit,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(context),
                )
              : Image.network(
                  url,
                  key: ValueKey('$url:$_retryEpoch'),
                  fit: widget.fit,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    _recoverRedirectAndRetry(url);
                    return _placeholder(context, loading: _recoveringRedirect);
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _placeholder(context, loading: true);
                  },
                ),
    );
  }

  File? _localImageFile(String url) {
    if (kIsWeb || url.isEmpty || url.startsWith('http')) return null;
    final path =
        url.startsWith('file://') ? Uri.tryParse(url)?.toFilePath() : url;
    if (path == null || path.isEmpty) return null;
    final looksLocal = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) ||
        path.startsWith('/data/') ||
        path.startsWith('/storage/') ||
        path.startsWith('/var/') ||
        path.startsWith('/Users/');
    if (!looksLocal) return null;
    return File(path);
  }

  void _recoverRedirectAndRetry(String url) {
    if (_recoveringRedirect || _failedUrl == url) return;
    final appState = AppScope.appOf(context);
    if (!appState.usesActiveOrigin(url)) return;

    _failedUrl = url;
    _recoveringRedirect = true;
    final previousActiveUrl = appState.activeUrl;

    Future<void>(() async {
      final recoveredActiveUrl = await appState.recoverActiveUrl();
      if (!mounted) return;
      setState(() {
        _recoveringRedirect = false;
        if (recoveredActiveUrl != null &&
            recoveredActiveUrl.isNotEmpty &&
            recoveredActiveUrl != previousActiveUrl) {
          _failedUrl = null;
          _recoveredUrl = _replaceOrigin(
            url,
            from: previousActiveUrl,
            to: recoveredActiveUrl,
          );
          _retryEpoch++;
        }
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _recoveringRedirect = false);
    });
  }

  String _replaceOrigin(String url,
      {required String from, required String to}) {
    final uri = Uri.tryParse(url);
    final fromUri = Uri.tryParse(from);
    if (uri == null || fromUri == null) return url;
    if (uri.scheme != fromUri.scheme ||
        uri.host != fromUri.host ||
        uri.port != fromUri.port) {
      return url;
    }

    final base = to.replaceAll(RegExp(r'/$'), '');
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$base${uri.path}$query$fragment';
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    return Container(
      color: context.isDark ? AppColors.slate800 : AppColors.slate100,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.placeholderIcon, color: AppColors.slate400, size: 32),
    );
  }
}

class SafeBottomSpacer extends StatelessWidget {
  const SafeBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 132);
  }
}

class HeaderText extends StatelessWidget {
  const HeaderText({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor = AppColors.primary600,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 640;
    final phone = width < 430;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: phone ? 24 : 30),
              SizedBox(width: phone ? 8 : 12),
            ],
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: phone
                      ? 22
                      : compact
                          ? 24
                          : width < 1100
                              ? 28
                              : 30,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: phone
                ? 13
                : compact
                    ? 14
                    : 16,
            color: context.mutedText,
          ),
        ),
      ],
    );
  }
}

class PageHeaderRow extends StatelessWidget {
  const PageHeaderRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = HeaderText(
          icon: icon,
          title: title,
          subtitle: subtitle,
        );
        if (constraints.maxWidth < 720 || action == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: header),
            action!,
          ],
        );
      },
    );
  }
}
