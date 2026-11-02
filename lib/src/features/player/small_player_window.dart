import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/media_widgets.dart';

class SmallPlayerWindow extends StatefulWidget {
  const SmallPlayerWindow({super.key, required this.openChapters});
  final Future<void> Function() openChapters;

  @override
  State<SmallPlayerWindow> createState() => _SmallPlayerWindowState();
}

class _SmallPlayerWindowState extends State<SmallPlayerWindow> {
  double? _dragPosition;
  String? _chapterId;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.playerOf(context);
    if (_chapterId != player.currentChapter?.id) {
      _chapterId = player.currentChapter?.id;
      _dragPosition = null;
    }
    final book = player.currentBook;
    final duration =
        player.duration.isFinite && player.duration > 0 ? player.duration : 1.0;
    final position = (_dragPosition ?? player.currentTime).isFinite
        ? (_dragPosition ?? player.currentTime).clamp(0.0, duration)
        : 0.0;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Tooltip(
              message: context.localeText('章节列表', 'Chapters'),
              child: InkWell(
                  onTap: player.hasChapter ? widget.openChapters : null,
                  child: SizedBox(
                      width: 56,
                      height: 56,
                      child: CoverImage(
                          url: book == null
                              ? ''
                              : bookCoverUrl(AppScope.appOf(context), book),
                          radius: 8)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(book?.title ?? context.localeText('听悦', 'Ting Reader'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    player.currentChapter?.title ??
                        context.localeText('暂无播放内容', 'Nothing playing'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                SizedBox(
                    height: 26,
                    child: Row(children: [
                      Text(formatDurationShort(position),
                          style: Theme.of(context).textTheme.labelSmall),
                      Expanded(
                          child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10)),
                              child: Slider(
                                  value: position,
                                  max: duration,
                                  onChanged: player.hasChapter
                                      ? (value) =>
                                          setState(() => _dragPosition = value)
                                      : null,
                                  onChangeEnd: player.hasChapter
                                      ? (value) {
                                          setState(() => _dragPosition = null);
                                          player.seek(value);
                                        }
                                      : null))),
                    ])),
              ])),
          const SizedBox(width: 4),
          IconButton(
              tooltip: context.localeText('章节列表', 'Chapters'),
              icon: const Icon(Icons.queue_music_rounded),
              onPressed: player.hasChapter ? widget.openChapters : null),
          IconButton(
              tooltip: context.localeText('上一首', 'Previous'),
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: player.hasChapter ? player.previousChapter : null),
          IconButton.filled(
              tooltip: context.localeText('播放或暂停', 'Play or pause'),
              icon: player.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
              onPressed: player.hasChapter ? player.togglePlay : null),
          IconButton(
              tooltip: context.localeText('下一首', 'Next'),
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: player.hasChapter ? player.nextChapter : null),
        ]),
      ),
    );
  }
}
