import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/state/download/download_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/urls.dart';
import '../app_scope.dart';

/// Shared status presentation; the chapter sheet keeps its simpler glyphs.
extension DownloadStatusPresentation on DownloadStatus {
  Color get downloadColor => switch (this) {
        DownloadStatus.queued => AppColors.slate500,
        DownloadStatus.downloading ||
        DownloadStatus.completed =>
          AppColors.primary600,
        DownloadStatus.paused => Colors.orange,
        DownloadStatus.failed => Colors.red,
      };

  IconData downloadIcon({bool simpleMark = false}) => switch (this) {
        DownloadStatus.queued => Icons.schedule_rounded,
        DownloadStatus.downloading => Icons.downloading_rounded,
        DownloadStatus.paused =>
          simpleMark ? Icons.pause_rounded : Icons.pause_circle_outline_rounded,
        DownloadStatus.completed =>
          simpleMark ? Icons.check_rounded : Icons.download_done_rounded,
        DownloadStatus.failed => Icons.error_outline_rounded,
      };
}

extension DownloadTaskPresentation on DownloadTask {
  String downloadLabel(bool english) => status == DownloadStatus.downloading
      ? '${((progress.isFinite ? progress : 0).clamp(0, 1) * 100).round()}%'
      : status.labelForLocale(english);
}

class ScrollingText extends StatefulWidget {
  const ScrollingText({
    super.key,
    this.gap = 44,
    this.millisecondsPerPixel = 38,
    this.minimumDuration = 5200,
    this.maximumDuration = 15000,
    required this.text,
    required this.style,
  });

  final double gap;
  final double millisecondsPerPixel;
  final int minimumDuration;
  final int maximumDuration;
  final String text;
  final TextStyle style;

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );
  String? _lastText;
  double? _lastWidth;
  double? _lastDistance;

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
        painter.dispose();
        final overflowing = textWidth > maxWidth;

        if (!overflowing ||
            maxWidth <= 0 ||
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
          if (_controller.isAnimating) _controller.stop();
          _lastText = widget.text;
          _lastWidth = maxWidth;
          return Center(
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style,
            ),
          );
        }

        final distance = textWidth + widget.gap;
        if (_lastText != widget.text ||
            _lastWidth != maxWidth ||
            _lastDistance != distance) {
          _lastText = widget.text;
          _lastWidth = maxWidth;
          _lastDistance = distance;
          _controller
            ..duration = Duration(
              milliseconds: (distance * widget.millisecondsPerPixel)
                  .round()
                  .clamp(widget.minimumDuration, widget.maximumDuration),
            )
            ..reset()
            ..repeat();
        } else if (!_controller.isAnimating) {
          _controller.repeat();
        }

        return ClipRect(
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
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
                  SizedBox(width: widget.gap),
                  Text(widget.text, maxLines: 1, style: style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PlayingBars extends StatefulWidget {
  const PlayingBars({
    super.key,
    required this.color,
    this.compact = false,
  });

  final Color color;
  final bool compact;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = widget.compact ? 16.0 : 20.0;
    final minHeight = widget.compact ? 5.0 : 6.0;
    return SizedBox(
      width: widget.compact ? 18 : 22,
      height: maxHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++) ...[
                _PlayingBar(
                  color: widget.color,
                  width: widget.compact ? 3 : 4,
                  height: minHeight +
                      (maxHeight - minHeight) *
                          (0.25 +
                              0.75 *
                                  math
                                      .sin(
                                        _controller.value * math.pi * 2 +
                                            i * math.pi / 2,
                                      )
                                      .abs()),
                ),
                if (i != 2) SizedBox(width: widget.compact ? 2 : 3),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlayingBar extends StatelessWidget {
  const _PlayingBar({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
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
  CancelToken? _recoveryToken;

  @override
  void didUpdateWidget(covariant CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _recoveryToken?.cancel('Cover changed');
      _failedUrl = null;
      _recoveredUrl = null;
      _recoveringRedirect = false;
    }
  }

  @override
  void dispose() {
    _recoveryToken?.cancel('Cover disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _recoveredUrl ?? widget.url;
    final localPath = localCoverFilePath(url);
    final localFile = localPath == null ? null : File(localPath);
    // 指向当前服务器的封面需要携带完整认证头（fnos-token cookie /
    // 访问码 x-access-code）；第三方图床 URL 绝不附带，避免凭据外泄。
    final appState = AppScope.appOf(context);
    final imageHeaders =
        localFile == null && url.isNotEmpty && appState.usesActiveOrigin(url)
            ? appState.api.authHeaders
            : const <String, String>{};
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
                  headers: imageHeaders.isEmpty ? null : imageHeaders,
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

  void _recoverRedirectAndRetry(String url) {
    if (_recoveringRedirect || _failedUrl == url) return;
    final appState = AppScope.appOf(context);
    if (!appState.usesActiveOrigin(url)) return;
    _failedUrl = url;
    _recoveringRedirect = true;
    final token = CancelToken();
    _recoveryToken = token;
    Future<void>(() async {
      final recovered =
          await appState.recoverResourceUrl(url, cancelToken: token);
      if (!mounted || token.isCancelled || !identical(_recoveryToken, token)) {
        return;
      }
      setState(() {
        _recoveringRedirect = false;
        if (recovered != null && recovered != url) {
          _recoveredUrl = recovered;
          _retryEpoch++;
        }
      });
    }).catchError((Object _) {
      if (mounted && !token.isCancelled && identical(_recoveryToken, token)) {
        setState(() => _recoveringRedirect = false);
      }
    });
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
