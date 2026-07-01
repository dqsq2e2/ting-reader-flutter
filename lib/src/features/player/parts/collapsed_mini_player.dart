part of '../mini_player.dart';

class _CollapsedMiniPlayer extends StatelessWidget {
  const _CollapsedMiniPlayer({
    required this.appState,
    required this.player,
    required this.book,
    required this.chapter,
    required this.coverShape,
    required this.accentColor,
    required this.subduedAccent,
    required this.onAccent,
    required this.bgColor,
    required this.borderColor,
  });

  final AppState appState;
  final PlayerState player;
  final Book book;
  final Chapter chapter;
  final CoverShape coverShape;
  final Color accentColor;
  final Color subduedAccent;
  final Color onAccent;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final width = coverShape == CoverShape.square ? 62.0 : 48.0;
    final height = coverShape == CoverShape.square ? 62.0 : 64.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => player.setMiniCollapsed(false),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.9),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.36 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CoverImage(
            url: bookCoverUrl(appState, book),
            radius: 12,
          ),
        ),
      ),
    );
  }
}
