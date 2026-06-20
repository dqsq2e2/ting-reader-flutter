part of 'user_pages.dart';

class _PlaylistCover {
  const _PlaylistCover({
    required this.id,
    required this.url,
    required this.placeholderIcon,
  });

  final String id;
  final String url;
  final IconData placeholderIcon;
}

CoverShape _playlistCoverShape(BuildContext context) {
  return coverShapeFromAppSettings(AppScope.appOf(context).settings);
}

String _seriesFirstCover(BuildContext context, Series series) {
  final appState = AppScope.appOf(context);
  if (series.coverUrl?.isNotEmpty == true) {
    return seriesCoverUrl(appState, series);
  }
  if (series.books.isNotEmpty) {
    return bookCoverUrl(appState, series.books.first);
  }
  return seriesCoverUrl(appState, series);
}

List<_PlaylistCover> _collectPlaylistCoverCandidates(
  AppState appState,
  Playlist playlist,
) {
  final covers = <_PlaylistCover>[];

  void push(_PlaylistCover cover) {
    covers.add(cover);
  }

  void pushBook(Book book, [String suffix = '']) {
    push(
      _PlaylistCover(
        id: '${book.id}$suffix',
        url: bookCoverUrl(appState, book),
        placeholderIcon: Icons.menu_book_rounded,
      ),
    );
  }

  void pushSeries(Series series) {
    if (series.books.isNotEmpty) {
      for (var i = 0; i < series.books.length; i++) {
        final book = series.books[i];
        push(
          _PlaylistCover(
            id: '${series.id}-${book.id.isEmpty ? i : book.id}',
            url: bookCoverUrl(appState, book),
            placeholderIcon: Icons.menu_book_rounded,
          ),
        );
      }
      return;
    }
    push(
      _PlaylistCover(
        id: series.id,
        url: seriesCoverUrl(appState, series),
        placeholderIcon: Icons.layers_rounded,
      ),
    );
  }

  if (playlist.items.isNotEmpty) {
    for (final item in playlist.items) {
      if (item.itemType == 'series' && item.series != null) {
        pushSeries(item.series!);
      } else if (item.book != null) {
        pushBook(item.book!);
      }
    }
  } else {
    for (final book in playlist.books) {
      pushBook(book);
    }
  }

  if (covers.isEmpty) {
    for (final book in playlist.books) {
      pushBook(book, '-fallback');
    }
  }

  return covers;
}

List<_PlaylistCover> _collectPlaylistCovers(
  AppState appState,
  Playlist playlist, {
  int limit = 1,
  int? seed,
}) {
  final candidates = _collectPlaylistCoverCandidates(appState, playlist);
  if (candidates.isEmpty) return const [];
  if (limit <= 1) {
    return [
      candidates[_playlistCoverIndex(playlist.id, seed ?? 0, candidates.length)]
    ];
  }
  return candidates.take(limit).toList();
}

int _playlistCoverIndex(String playlistId, int seed, int count) {
  if (count <= 1) return 0;
  var hash = seed & 0x7fffffff;
  for (final unit in playlistId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % count;
}

class _PlaylistCoverGrid extends StatelessWidget {
  const _PlaylistCoverGrid({
    required this.playlist,
    required this.coverShape,
    required this.coverSeed,
  });

  final Playlist playlist;
  final CoverShape coverShape;
  final int coverSeed;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final covers = _collectPlaylistCovers(
      appState,
      playlist,
      seed: coverSeed,
    );
    return AspectRatio(
      aspectRatio: coverAspectRatio(coverShape),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                AppColors.primary600.withOpacity(context.isDark ? 0.18 : 0.10),
          ),
          child: covers.isEmpty
              ? const Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.primary600,
                  size: 38,
                )
              : covers.length == 1
                  ? _PlaylistCoverTile(cover: covers.first)
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 1,
                        crossAxisSpacing: 1,
                      ),
                      itemCount: covers.length,
                      itemBuilder: (context, index) =>
                          _PlaylistCoverTile(cover: covers[index]),
                    ),
        ),
      ),
    );
  }
}

class _PlaylistCoverTile extends StatelessWidget {
  const _PlaylistCoverTile({required this.cover});

  final _PlaylistCover cover;

  @override
  Widget build(BuildContext context) {
    return CoverImage(
      key: ValueKey(cover.id),
      url: cover.url,
      radius: 0,
      placeholderIcon: cover.placeholderIcon,
    );
  }
}

Future<Map<String, dynamic>?> _showPlaylistInfoDialog(
  BuildContext context, {
  Playlist? playlist,
}) async {
  final title = TextEditingController(text: playlist?.title ?? '');
  final description = TextEditingController(text: playlist?.description ?? '');
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      final compact = MediaQuery.sizeOf(context).width < 520;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 24,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 24,
              compact ? 20 : 24,
              compact ? 20 : 24,
              compact ? 18 : 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist == null ? '新建书单' : '编辑书单',
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: compact ? 24 : 22,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PlaylistDialogField(
                  label: '名称',
                  child: TextField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '例如：通勤路上',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PlaylistDialogField(
                  label: '描述',
                  child: TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '一句话描述这个书单',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: playlist == null ? '创建' : '保存',
                      icon: Icons.save_rounded,
                      onPressed: () {
                        final trimmed = title.text.trim();
                        if (trimmed.isEmpty) return;
                        Navigator.pop(context, {
                          'title': trimmed,
                          'description': description.text.trim(),
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  title.dispose();
  description.dispose();
  return result;
}

class _PlaylistDialogField extends StatelessWidget {
  const _PlaylistDialogField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
