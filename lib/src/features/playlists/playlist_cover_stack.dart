part of 'playlists_page.dart';

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
      final bookValue = item.book;
      final seriesValue = item.series;
      if (item.itemType == 'series' && seriesValue != null) {
        pushSeries(seriesValue);
      } else if (bookValue != null) {
        pushBook(bookValue);
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
  int limit = 3,
  int? seed,
}) {
  final seen = <String>{};
  final candidates = _collectPlaylistCoverCandidates(appState, playlist)
      .where((cover) => seen.add(cover.url.isEmpty ? cover.id : cover.url))
      .toList();
  if (candidates.isEmpty) return const [];
  final start = _playlistCoverIndex(playlist.id, seed ?? 0, candidates.length);
  return List.generate(math.min(limit, candidates.length),
      (index) => candidates[(start + index) % candidates.length]);
}

int _playlistCoverIndex(String playlistId, int seed, int count) {
  if (count <= 1) return 0;
  var hash = seed & 0x7fffffff;
  for (final unit in playlistId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % count;
}

class _PlaylistCoverStack extends StatelessWidget {
  const _PlaylistCoverStack({
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final radius = (width * 0.065).clamp(6.0, 16.0);
          Widget layer(_PlaylistCover? cover, {bool front = false}) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color:
                    context.isDark ? AppColors.slate800 : AppColors.primary50,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: front ? 0.14 : 0.07),
                    blurRadius: front ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: cover == null
                    ? Center(
                        child: Icon(Icons.playlist_play_rounded,
                            color: AppColors.primary400, size: width * 0.25),
                      )
                    : _PlaylistCoverTile(cover: cover),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                width * 0.12, height * 0.06, width * 0.12, height * 0.18),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (covers.isNotEmpty)
                  Transform.translate(
                    offset: Offset(-width * 0.05, height * 0.04),
                    child: Transform.rotate(
                      angle: -0.14,
                      child: layer(covers.length > 2 ? covers[2] : null),
                    ),
                  ),
                if (covers.length > 1)
                  Transform.translate(
                    offset: Offset(width * 0.065, height * 0.06),
                    child: Transform.rotate(
                      angle: 0.14,
                      child: layer(covers[1]),
                    ),
                  ),
                layer(covers.firstOrNull, front: true),
              ],
            ),
          );
        },
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
                        playlist == null
                            ? context.localeText('新建书单', 'New Playlist')
                            : context.localeText('编辑书单', 'Edit Playlist'),
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: compact ? 24 : 22,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.localeText('关闭', 'Close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PlaylistDialogField(
                  label: context.localeText('名称', 'Name'),
                  child: TextField(
                    controller: title,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.localeText(
                        '例如：通勤路上',
                        'e.g. Commute',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PlaylistDialogField(
                  label: context.localeText('描述', 'Description'),
                  child: TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.localeText(
                        '一句话描述这个书单',
                        'Describe this playlist in one sentence',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.localeText('取消', 'Cancel')),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: playlist == null
                          ? context.localeText('创建', 'Create')
                          : context.localeText('保存', 'Save'),
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
