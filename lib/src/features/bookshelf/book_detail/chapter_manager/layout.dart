part of '../book_detail_page.dart';

extension _ChapterManagerLayout on _ChapterManagerDialogState {
  Future<void> _jumpToChapter() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('跳转到章节', 'Jump to Chapter')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.tag_rounded),
            hintText: context.localeText('输入章节序号', 'Enter chapter number'),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          PrimaryButton(
            label: context.localeText('跳转', 'Jump'),
            icon: Icons.subdirectory_arrow_right_rounded,
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    final target = int.tryParse((value ?? '').trim());
    if (target == null) return;
    final chapters = _tabChapters;
    if (chapters.isEmpty) return;
    var targetIndex =
        chapters.indexWhere((chapter) => chapter.chapterIndex >= target);
    if (targetIndex < 0) targetIndex = chapters.length - 1;
    _updateState(() {
      _searchController.clear();
      _groupIndex = targetIndex ~/ _ChapterManagerDialogState._groupSize;
    });
  }

  Future<void> _editChapter(Chapter chapter) async {
    final current = _chapters.firstWhere(
      (item) => item.id == chapter.id,
      orElse: () => chapter,
    );
    final result = await showModalBottomSheet<_ChapterEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChapterEditSheet(
        chapter: current,
        libraryName: _pathLibrary?.name ??
            context.localeText('未知存储库', 'Unknown Library'),
        relativePath: _relativeChapterPath(current.path),
      ),
    );
    if (result == null || !mounted) return;
    _replaceChapter(
      current.id,
      (item) => item.copyWith(
        title: result.title,
        chapterIndex: result.chapterIndex,
        isExtra: result.isExtra,
      ),
    );
  }

  Widget _buildResponsiveDialog(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final compact = size.width < 640;
    final filtered = _filteredChapters;
    final allFilteredSelected = filtered.isNotEmpty &&
        filtered.every((item) => _selectedIds.contains(item.id));
    final groupCount = math.max(
      1,
      (filtered.length / _ChapterManagerDialogState._groupSize).ceil(),
    );
    final groupIndex = _groupIndex.clamp(0, groupCount - 1).toInt();
    final start = groupIndex * _ChapterManagerDialogState._groupSize;
    final visible = filtered
        .skip(start)
        .take(_ChapterManagerDialogState._groupSize)
        .toList();
    final showChapterTypeSwitch =
        _mainChapterCount > 0 && _extraChapterCount > 0;
    final showChapterGroups = groupCount > 1;
    final maxHeight = compact ? size.height - safe.top - 24 : size.height * 0.9;
    final maxWidth = compact ? 560.0 : 920.0;
    final insetPadding = compact
        ? EdgeInsets.fromLTRB(8, safe.top + 12, 8, 8)
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    final canSave = _changedIds.isNotEmpty && !_saving;
    final saveButton = ElevatedButton.icon(
      onPressed: canSave ? _save : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate100,
        disabledForegroundColor: context.mutedText,
        elevation: 0,
        minimumSize: Size(0, compact ? 40 : 38),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 11 : 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _saving
          ? SizedBox.square(
              dimension: compact ? 15 : 16,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.save_rounded, size: compact ? 16 : 17),
      label: Text(
        _saving
            ? context.localeText('保存中...', 'Saving...')
            : context.localeText(
                '保存更改 (${_changedIds.length})', 'Save (${_changedIds.length})'),
        style: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Dialog(
        insetPadding: insetPadding,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isDark ? 0.34 : 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    compact ? 18 : 22,
                    compact ? 10 : 18,
                    compact ? 12 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.localeText('章节管理', 'Chapter Manager'),
                            style: TextStyle(
                              fontSize: compact ? 22 : 24,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                              color: context.primaryText,
                            ),
                          ),
                          if (showChapterTypeSwitch) ...[
                            SizedBox(width: compact ? 10 : 12),
                            _ChapterTypeSwitch(
                              activeTab: _activeChapterTab,
                              mainCount: _mainChapterCount,
                              extraCount: _extraChapterCount,
                              compact: compact,
                              onChanged: _setChapterTab,
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            tooltip: context.localeText('关闭', 'Close'),
                            onPressed: _requestClose,
                            color: AppColors.slate500,
                            iconSize: compact ? 26 : 28,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      _ChapterManagerSearchField(
                        controller: _searchController,
                        hintText: context.localeText(
                            '搜索章节、序号', 'Search chapters or index'),
                        onChanged: (_) => _updateState(() => _groupIndex = 0),
                      ),
                      if (showChapterGroups) ...[
                        const SizedBox(height: 12),
                        _ChapterGroups(
                          total: filtered.length,
                          groupSize: _ChapterManagerDialogState._groupSize,
                          groupIndex: groupIndex,
                          onGroupChanged: (index) =>
                              _updateState(() => _groupIndex = index),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 24,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate900
                        : AppColors.slate50.withValues(alpha: 0.9),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: context.faintBorder),
                    ),
                  ),
                  child: _selectionMode
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            BatchActionButton(
                              label: context.localeText('完成', 'Done'),
                              icon: Icons.check_rounded,
                              filled: true,
                              compact: compact,
                              onPressed: () {
                                _updateState(() {
                                  _selectionMode = false;
                                  _selectedIds.clear();
                                });
                              },
                            ),
                            BatchSelectButton(
                              checked: allFilteredSelected,
                              label: context.localeText('全选 ${filtered.length}',
                                  'All ${filtered.length}'),
                              compact: compact,
                              onPressed: filtered.isEmpty ? null : _toggleAll,
                            ),
                            BatchCountBadge(
                              label: context.localeText(
                                  '已选 ${_selectedIds.length}',
                                  'Selected ${_selectedIds.length}'),
                              compact: compact,
                            ),
                            BatchActionButton(
                              label: context.localeText('移动', 'Move'),
                              icon: Icons.arrow_forward_rounded,
                              compact: compact,
                              onPressed: _selectedIds.isEmpty || _moving
                                  ? null
                                  : _moveSelected,
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            BatchActionButton(
                              label: context.localeText('选择', 'Select'),
                              icon: Icons.checklist_rounded,
                              compact: compact,
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () => _updateState(
                                        () => _selectionMode = true,
                                      ),
                            ),
                            BatchActionButton(
                              label: context.localeText('重排', 'Renumber'),
                              icon: Icons.format_list_numbered_rounded,
                              compact: compact,
                              onPressed: _renumber,
                            ),
                            BatchActionButton(
                              label: context.localeText('跳转', 'Jump'),
                              icon: Icons.subdirectory_arrow_right_rounded,
                              compact: compact,
                              onPressed: _jumpToChapter,
                            ),
                          ],
                        ),
                ),
                Expanded(
                  child: Container(
                    color: context.isDark
                        ? AppColors.slate900.withValues(alpha: 0.18)
                        : AppColors.slate50.withValues(alpha: 0.38),
                    child: visible.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: context.localeText(
                                '没有匹配章节', 'No Matching Chapters'),
                            message: context.localeText('换一个关键词或切换正文/番外试试。',
                                'Try another keyword or switch chapter type.'),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 12 : 20,
                              compact ? 10 : 12,
                              compact ? 12 : 20,
                              compact ? 12 : 16,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: compact ? 6 : 7),
                            itemBuilder: (context, index) {
                              final chapter = visible[index];
                              return _ManagerChapterRow(
                                chapter: chapter,
                                selected: _selectedIds.contains(chapter.id),
                                changed: _changedIds.contains(chapter.id),
                                selectionMode: _selectionMode,
                                onSelected: () => _toggleSelection(chapter.id),
                                onEdit: () => _editChapter(chapter),
                              );
                            },
                          ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 24,
                      12,
                      compact ? 18 : 24,
                      compact ? 14 : 18,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      border:
                          Border(top: BorderSide(color: context.faintBorder)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (compact) ...[
                          TextButton(
                            onPressed: _requestClose,
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: saveButton)
                        ] else ...[
                          const Spacer(),
                          TextButton(
                            onPressed: _requestClose,
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 210, child: saveButton),
                        ],
                      ],
                    ),
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
