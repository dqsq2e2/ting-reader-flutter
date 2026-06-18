import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_scope.dart';

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
            color: Colors.black.withOpacity(context.isDark ? 0.12 : 0.035),
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
        disabledBackgroundColor: AppColors.primary600.withOpacity(0.5),
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
