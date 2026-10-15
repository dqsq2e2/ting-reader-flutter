part of 'downloads_page.dart';

class _DownloadedBookChaptersView extends StatefulWidget {
  const _DownloadedBookChaptersView({
    required this.items,
    required this.onBack,
    required this.onDeleteBook,
    required this.onDeleteChapter,
    required this.onDeleteChapters,
    required this.onPlay,
  });

  final List<LocalDownload> items;
  final VoidCallback onBack;
  final Future<void> Function()? onDeleteBook;
  final ValueChanged<String> onDeleteChapter;
  final Future<void> Function(List<LocalDownload> items) onDeleteChapters;
  final ValueChanged<LocalDownload> onPlay;

  @override
  State<_DownloadedBookChaptersView> createState() =>
      _DownloadedBookChaptersViewState();
}

class _DownloadedBookChaptersViewState
    extends State<_DownloadedBookChaptersView> {
  static const int _chaptersPerGroup = 100;

  bool _selecting = false;
  bool _ascending = true;
  int _groupIndex = 0;
  final Set<String> _selectedIds = {};

  @override
  void didUpdateWidget(covariant _DownloadedBookChaptersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.items.map((item) => item.storageKey).toSet();
    _selectedIds.removeWhere((id) => !ids.contains(id));
    if (_selectedIds.isEmpty && widget.items.isEmpty) _selecting = false;
    final groupCount = _chapterGroups.length;
    if (_groupIndex >= groupCount) {
      _groupIndex = groupCount == 0 ? 0 : groupCount - 1;
      _selectedIds.clear();
    }
  }

  List<LocalDownload> get _baseItems {
    final items = [...widget.items]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return items;
  }

  List<List<LocalDownload>> get _chapterGroups {
    final items = _baseItems;
    return [
      for (var start = 0; start < items.length; start += _chaptersPerGroup)
        items.skip(start).take(_chaptersPerGroup).toList(growable: false),
    ];
  }

  List<LocalDownload> _orderedGroup(List<LocalDownload> group) {
    return _ascending ? group : group.reversed.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _baseItems;
    if (allItems.isEmpty) {
      return PageListView(
        children: [
          AppBackButton(onPressed: widget.onBack),
          const SizedBox(height: 24),
          EmptyState(
            icon: Icons.download_done_rounded,
            title: context.l10n.downloadsNoChaptersTitle,
            message: context.l10n.downloadsNoChaptersMessage,
          ),
          const SafeBottomSpacer(),
        ],
      );
    }

    final groups = _chapterGroups;
    final groupIndex = _groupIndex.clamp(0, groups.length - 1).toInt();
    final visibleItems = _orderedGroup(groups[groupIndex]);
    final first = allItems.first;
    final selectedItems = visibleItems
        .where((item) => _selectedIds.contains(item.storageKey))
        .toList();
    final allSelected =
        visibleItems.isNotEmpty && selectedItems.length == visibleItems.length;
    return PageListView(
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 20),
        HeaderText(
          icon: Icons.download_done_rounded,
          title: _downloadBookTitle(context, first.bookTitle),
          subtitle: context.l10n.downloadsDownloadedAudioCount(allItems.length),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _selecting = !_selecting;
                if (!_selecting) _selectedIds.clear();
              }),
              icon: Icon(
                _selecting
                    ? Icons.close_rounded
                    : Icons.playlist_add_check_rounded,
                size: 18,
              ),
              label: Text(
                _selecting
                    ? context.l10n.downloadsDone
                    : context.l10n.downloadsBatchDelete,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _ascending = !_ascending;
                _selectedIds.clear();
              }),
              icon: Icon(
                _ascending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 18,
              ),
              label: Text(
                _ascending
                    ? context.l10n.downloadsAscending
                    : context.l10n.downloadsDescending,
              ),
            ),
            if (widget.onDeleteBook != null)
              TextButton.icon(
                onPressed: widget.onDeleteBook,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.l10n.downloadsDeleteWholeBook),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (groups.length > 1) ...[
          _DownloadChapterGroups(
            groups: groups,
            groupIndex: groupIndex,
            onChanged: (index) => setState(() {
              _groupIndex = index;
              _selectedIds.clear();
            }),
          ),
          const SizedBox(height: 12),
        ],
        if (_selecting) ...[
          _DownloadSelectionBar(
            selectedCount: selectedItems.length,
            allSelected: allSelected,
            onSelectPage: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds
                    ..clear()
                    ..addAll(visibleItems.map((item) => item.storageKey));
                }
              });
            },
            onDelete: selectedItems.isEmpty
                ? null
                : () async {
                    await widget.onDeleteChapters(selectedItems);
                    if (!mounted) return;
                    setState(() {
                      _selectedIds.removeAll(
                        selectedItems.map((item) => item.storageKey),
                      );
                      if (_selectedIds.isEmpty) _selecting = false;
                    });
                  },
          ),
          const SizedBox(height: 12),
        ],
        TingCard(
          padding: EdgeInsets.zero,
          radius: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                ..._buildChapterRows(context, visibleItems),
              ],
            ),
          ),
        ),
        const SafeBottomSpacer(),
      ],
    );
  }

  List<Widget> _buildChapterRows(
    BuildContext context,
    List<LocalDownload> items,
  ) {
    final mainItems = items.where((item) => !item.isExtra).toList();
    final extraItems = items.where((item) => item.isExtra).toList();
    final sections = <MapEntry<String, List<LocalDownload>>>[
      if (mainItems.isNotEmpty)
        MapEntry(context.l10n.downloadsMainChapters, mainItems),
      if (extraItems.isNotEmpty)
        MapEntry(context.l10n.downloadsExtraChapters, extraItems),
    ];
    final showSectionLabel = sections.length > 1 || extraItems.isNotEmpty;
    final widgets = <Widget>[];
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      if (showSectionLabel) {
        widgets.add(
          _DownloadChapterSectionHeader(
            label: section.key,
            count: section.value.length,
          ),
        );
      }
      for (var i = 0; i < section.value.length; i++) {
        final item = section.value[i];
        widgets.add(
          _DownloadChapterRow(
            item: item,
            selectionMode: _selecting,
            selected: _selectedIds.contains(item.storageKey),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(item.storageKey);
                } else {
                  _selectedIds.remove(item.storageKey);
                }
              });
            },
            onTap: () => widget.onPlay(item),
            onDelete: () => widget.onDeleteChapter(item.storageKey),
          ),
        );
        final isLastRow = sectionIndex == sections.length - 1 &&
            i == section.value.length - 1;
        if (!isLastRow) {
          final compact = MediaQuery.sizeOf(context).width < 640;
          widgets.add(
            Padding(
              padding: EdgeInsets.only(
                left: _selecting ? (compact ? 76 : 104) : (compact ? 50 : 64),
              ),
              child: Divider(height: 1, color: context.faintBorder),
            ),
          );
        }
      }
    }
    return widgets;
  }
}

class _DownloadChapterGroups extends StatelessWidget {
  const _DownloadChapterGroups({
    required this.groups,
    required this.groupIndex,
    required this.onChanged,
  });

  final List<List<LocalDownload>> groups;
  final int groupIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return HorizontalScrollControls(
      child: Row(
        children: [
          for (var index = 0; index < groups.length; index++) ...[
            _DownloadChapterGroupChip(
              label: _labelFor(context, groups[index]),
              selected: groupIndex == index,
              onTap: () => onChanged.call(index),
            ),
            if (index != groups.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, List<LocalDownload> items) {
    if (items.isEmpty) return '0';
    final start = items.first.chapterIndex;
    final end = items.last.chapterIndex;
    if (start == end) return context.l10n.downloadsChapterSingle(start);
    return context.l10n.downloadsChapterRange(start, end);
  }
}

class _DownloadChapterGroupChip extends StatelessWidget {
  const _DownloadChapterGroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final foreground = selected ? Colors.white : context.secondaryText;
    return Material(
      color: selected
          ? AppColors.primary600
          : (context.isDark ? AppColors.slate800 : context.cardColor),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 13,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? AppColors.primary600 : context.faintBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadChapterSectionHeader extends StatelessWidget {
  const _DownloadChapterSectionHeader({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.primary600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadChapterRow extends StatelessWidget {
  const _DownloadChapterRow({
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onSelected,
    required this.onTap,
    required this.onDelete,
  });

  final LocalDownload item;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return ListTile(
      onTap: selectionMode ? () => onSelected(!selected) : onTap,
      minLeadingWidth: compact ? 28 : null,
      horizontalTitleGap: compact ? 10 : 16,
      contentPadding: EdgeInsets.fromLTRB(
        selectionMode ? 8 : (compact ? 14 : 28),
        6,
        compact ? 8 : 12,
        6,
      ),
      leading: selectionMode
          ? SizedBox(
              width: compact ? 52 : 68,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BatchCheckbox(
                    checked: selected,
                    compact: compact,
                    tooltip: selected
                        ? context.l10n.downloadsCancelSelect
                        : context.l10n.downloadsSelectChapter,
                    onChanged: () => onSelected(!selected),
                  ),
                  SizedBox(width: compact ? 2 : 6),
                  _DownloadChapterIndex(item: item, compact: compact),
                ],
              ),
            )
          : _DownloadChapterIndex(item: item, compact: compact),
      title: Text(
        _downloadChapterTitle(context, item.chapterTitle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatBytes(item.fileSize)}  ·  ${_formatLocalTime(context, item.createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selectionMode
          ? null
          : IconButton(
              tooltip: context.l10n.downloadsDeleteDownload,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
    );
  }
}

class _DownloadChapterIndex extends StatelessWidget {
  const _DownloadChapterIndex({required this.item, required this.compact});

  final LocalDownload item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 26 : 34,
      height: compact ? 26 : 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.primary700.withValues(alpha: 0.16)
            : AppColors.primary50,
        borderRadius: BorderRadius.circular(compact ? 7 : 9),
      ),
      child: Text(
        '${item.chapterIndex}',
        style: TextStyle(
          color: AppColors.primary600,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}

class _DownloadSelectionBar extends StatelessWidget {
  const _DownloadSelectionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectPage,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectPage;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final selectButton = BatchSelectButton(
          checked: allSelected,
          label: allSelected
              ? context.l10n.downloadsUnselectAll
              : context.l10n.downloadsSelectPage,
          compact: compact,
          onPressed: onSelectPage,
        );
        final trailing = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            BatchCountBadge(
              label: context.l10n.downloadsSelectedChapters(selectedCount),
              compact: compact,
            ),
            BatchActionButton(
              icon: Icons.delete_outline_rounded,
              label: compact
                  ? context.l10n.downloadsDeleteAction
                  : context.l10n.downloadsDeleteSelected,
              danger: true,
              compact: compact,
              onPressed: onDelete == null ? null : () => onDelete?.call(),
            ),
          ],
        );
        final content = compact
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  selectButton,
                  BatchCountBadge(
                    label:
                        context.l10n.downloadsSelectedChapters(selectedCount),
                    compact: compact,
                  ),
                  BatchActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: context.l10n.downloadsDeleteAction,
                    danger: true,
                    compact: compact,
                    onPressed: onDelete == null ? null : () => onDelete?.call(),
                  ),
                ],
              )
            : Row(
                children: [selectButton, const Spacer(), trailing],
              );
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            compact ? 10 : 12,
            compact ? 12 : 16,
            compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.slate900.withValues(alpha: 0.28)
                : Colors.white,
            border: Border(top: BorderSide(color: context.faintBorder)),
          ),
          child: content,
        );
      },
    );
  }
}
