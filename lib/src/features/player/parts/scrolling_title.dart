part of '../mini_player.dart';

class _ScrollingPlayerTitle extends StatefulWidget {
  const _ScrollingPlayerTitle({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_ScrollingPlayerTitle> createState() => _ScrollingPlayerTitleState();
}

class _ScrollingPlayerTitleState extends State<_ScrollingPlayerTitle>
    with SingleTickerProviderStateMixin {
  static const _gap = 44.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
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

        final distance = textWidth + _gap;
        if (_lastText != widget.text || _lastWidth != maxWidth) {
          _lastText = widget.text;
          _lastWidth = maxWidth;
          _controller
            ..duration = Duration(
              milliseconds: (distance * 38).round().clamp(5200, 15000),
            )
            ..reset()
            ..repeat();
        } else if (!_controller.isAnimating) {
          _controller.repeat();
        }

        return ClipRect(
          child: Align(
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
                  const SizedBox(width: _gap),
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
