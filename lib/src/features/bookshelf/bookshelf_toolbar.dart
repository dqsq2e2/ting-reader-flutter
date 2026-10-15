part of 'bookshelf_page.dart';

class _Header extends StatelessWidget {
  const _Header({
    required this.selectionMode,
    required this.selectedBookCount,
    required this.selectedSeriesCount,
    required this.libraries,
    required this.selectedLibraryId,
    required this.showFilterMenu,
    required this.filterMenuLink,
    required this.deletingItems,
    required this.updatingReadStatus,
    required this.onSearchOpen,
    required this.onLibraryChanged,
    required this.onToggleFilterMenu,
    required this.onSelectionMode,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onCreateSeries,
    required this.onDeleteSelected,
    required this.onMarkRead,
    required this.onMarkUnread,
  });

  final bool selectionMode;
  final int selectedBookCount;
  final int selectedSeriesCount;
  final List<Library> libraries;
  final String selectedLibraryId;
  final bool showFilterMenu;
  final LayerLink filterMenuLink;
  final bool deletingItems;
  final bool updatingReadStatus;
  final VoidCallback onSearchOpen;
  final ValueChanged<String?> onLibraryChanged;
  final VoidCallback onToggleFilterMenu;
  final VoidCallback onSelectionMode;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback? onCreateSeries;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final mobile = constraints.maxWidth < 560;
        final searchWidth = compact ? constraints.maxWidth : 256.0;
        final selectedCount = selectedBookCount + selectedSeriesCount;
        final hasSelection = selectedCount > 0;
        final operationsButton = _BatchOperationsMenuButton(
          compact: mobile,
          hasSelection: hasSelection,
          canCreateSeries: onCreateSeries != null,
          canDelete: onDeleteSelected != null,
          loading: deletingItems || updatingReadStatus,
          onCreateSeries: onCreateSeries,
          onDelete: onDeleteSelected,
          onMarkRead: onMarkRead,
          onMarkUnread: onMarkUnread,
          canManage: onCreateSeries != null || onDeleteSelected != null,
        );
        final desktopToolbar = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth,
              child: _SearchEntry(onTap: onSearchOpen),
            ),
            if (selectionMode) ...[
              BatchCountBadge(
                  label: context.localeText(
                      '已选 $selectedCount', '$selectedCount selected'),
                  compact: mobile),
              BatchActionButton(
                icon: Icons.select_all_rounded,
                label: context.localeText('全选', 'Select All'),
                compact: mobile,
                onPressed: onSelectAll,
              ),
              operationsButton,
              _SquareToolbarButton(
                icon: Icons.close_rounded,
                onPressed: onCancelSelection,
              ),
            ] else
              BatchActionButton(
                icon: Icons.layers_rounded,
                label: context.localeText('选择模式', 'Select Mode'),
                compact: mobile,
                onPressed: onSelectionMode,
              ),
            if (libraries.isNotEmpty)
              SizedBox(
                width: compact ? constraints.maxWidth : 168,
                child: _LibraryDropdown(
                  libraries: libraries,
                  selectedLibraryId: selectedLibraryId,
                  onChanged: onLibraryChanged,
                ),
              ),
            CompositedTransformTarget(
              link: filterMenuLink,
              child: _SquareToolbarButton(
                icon: Icons.filter_list_rounded,
                selected: showFilterMenu,
                onPressed: onToggleFilterMenu,
              ),
            ),
          ],
        );

        final compactFilterButton = CompositedTransformTarget(
          link: filterMenuLink,
          child: _SquareToolbarButton(
            icon: Icons.filter_list_rounded,
            selected: showFilterMenu,
            onPressed: onToggleFilterMenu,
          ),
        );

        Widget compactToolbar() {
          if (selectionMode) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BatchCountBadge(
                    label: context.localeText(
                        '已选 $selectedCount', '$selectedCount selected'),
                    compact: mobile),
                BatchActionButton(
                  icon: Icons.select_all_rounded,
                  label: context.localeText('全选', 'Select All'),
                  compact: mobile,
                  onPressed: onSelectAll,
                ),
                operationsButton,
                _SquareToolbarButton(
                  icon: Icons.close_rounded,
                  onPressed: onCancelSelection,
                ),
                compactFilterButton,
              ],
            );
          }

          final modeButton = BatchActionButton(
            icon: Icons.layers_rounded,
            label: mobile
                ? context.localeText('选择', 'Select')
                : context.localeText('选择模式', 'Select Mode'),
            onPressed: onSelectionMode,
            compact: mobile,
          );
          final libraryDropdown = libraries.isEmpty
              ? const SizedBox.shrink()
              : _LibraryDropdown(
                  libraries: libraries,
                  selectedLibraryId: selectedLibraryId,
                  onChanged: onLibraryChanged,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: double.infinity,
                  child: _SearchEntry(onTap: onSearchOpen)),
              const SizedBox(height: 10),
              Row(
                children: [
                  ...[
                    if (mobile)
                      Flexible(flex: 10, child: modeButton)
                    else
                      SizedBox(width: 136, child: modeButton),
                    const SizedBox(width: 8),
                  ],
                  if (libraries.isNotEmpty)
                    if (mobile)
                      Expanded(flex: 12, child: libraryDropdown)
                    else
                      SizedBox(width: 176, child: libraryDropdown),
                  if (libraries.isNotEmpty) const SizedBox(width: 8),
                  compactFilterButton,
                ],
              ),
            ],
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeaderText(
                        icon: Icons.library_books_rounded,
                        title: context.localeText('我的书架', 'My Bookshelf'),
                        subtitle: context.localeText('发现您收藏的所有有声读物。',
                            'Browse every audiobook in your collection.'),
                      ),
                      const SizedBox(height: 16),
                      compactToolbar(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: HeaderText(
                          icon: Icons.library_books_rounded,
                          title: context.localeText('我的书架', 'My Bookshelf'),
                          subtitle: context.localeText('发现您收藏的所有有声读物。',
                              'Browse every audiobook in your collection.'),
                        ),
                      ),
                      desktopToolbar,
                    ],
                  ),
          ],
        );
      },
    );
  }
}

enum _BatchOperation { markRead, markUnread, createSeries, delete }

class _BatchOperationsMenuButton extends StatelessWidget {
  const _BatchOperationsMenuButton({
    required this.compact,
    required this.hasSelection,
    required this.canCreateSeries,
    required this.canDelete,
    required this.loading,
    required this.onCreateSeries,
    required this.onDelete,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.canManage,
  });

  final bool compact;
  final bool hasSelection;
  final bool canCreateSeries;
  final bool canDelete;
  final bool loading;
  final VoidCallback? onCreateSeries;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BatchOperation>(
      enabled: !loading,
      tooltip: context.localeText('批量操作', 'Batch Actions'),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (operation) {
        switch (operation) {
          case _BatchOperation.markRead:
            onMarkRead?.call();
          case _BatchOperation.markUnread:
            onMarkUnread?.call();
          case _BatchOperation.createSeries:
            onCreateSeries?.call();
          case _BatchOperation.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) {
        if (!hasSelection) {
          return [
            PopupMenuItem<_BatchOperation>(
              enabled: false,
              child: SizedBox(
                width: 210,
                child: Text(
                  context.localeText(
                    '请先在下方勾选书籍或系列',
                    'Select books or series first',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ),
            ),
          ];
        }

        return [
          PopupMenuItem<_BatchOperation>(
            value: _BatchOperation.markRead,
            enabled: onMarkRead != null,
            child: _BatchOperationMenuItem(
              icon: Icons.task_alt_rounded,
              label: context.localeText('标记已读', 'Mark as read'),
              enabled: onMarkRead != null,
            ),
          ),
          PopupMenuItem<_BatchOperation>(
            value: _BatchOperation.markUnread,
            enabled: onMarkUnread != null,
            child: _BatchOperationMenuItem(
              icon: Icons.radio_button_unchecked_rounded,
              label: context.localeText('标记未读', 'Mark as unread'),
              enabled: onMarkUnread != null,
            ),
          ),
          if (canManage) ...[
            const PopupMenuDivider(),
            PopupMenuItem<_BatchOperation>(
              value: _BatchOperation.createSeries,
              enabled: canCreateSeries,
              child: _BatchOperationMenuItem(
                icon: Icons.layers_rounded,
                label: context.localeText('创建系列', 'Create Series'),
                enabled: canCreateSeries,
              ),
            ),
            PopupMenuItem<_BatchOperation>(
              value: _BatchOperation.delete,
              enabled: canDelete,
              child: _BatchOperationMenuItem(
                icon: Icons.delete_outline_rounded,
                label: context.localeText('删除', 'Delete'),
                danger: true,
                enabled: canDelete,
              ),
            ),
          ],
        ];
      },
      child: _BatchOperationsButtonSurface(
        compact: compact,
        loading: loading,
      ),
    );
  }
}

class _BatchOperationMenuItem extends StatelessWidget {
  const _BatchOperationMenuItem({
    required this.icon,
    required this.label,
    required this.enabled,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xffef4444) : context.secondaryText;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchOperationsButtonSurface extends StatelessWidget {
  const _BatchOperationsButtonSurface({
    required this.compact,
    required this.loading,
  });

  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 40.0 : 44.0;
    final background = loading
        ? AppColors.primary600.withValues(alpha: 0.55)
        : AppColors.primary600;

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 15,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary600.withValues(alpha: loading ? 0 : 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: compact ? 15 : 16,
              height: compact ? 15 : 16,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(
              Icons.more_horiz_rounded,
              size: compact ? 17 : 18,
              color: Colors.white,
            ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            compact
                ? context.localeText('操作', 'Actions')
                : context.localeText('批量操作', 'Batch Actions'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
          if (!loading) ...[
            SizedBox(width: compact ? 4 : 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: compact ? 17 : 18,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.slate500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.localeText(
                      '搜索书名、作者、演播者', 'Search title, author, narrator'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDropdown extends StatelessWidget {
  const _LibraryDropdown({
    required this.libraries,
    required this.selectedLibraryId,
    required this.onChanged,
  });

  final List<Library> libraries;
  final String selectedLibraryId;
  final ValueChanged<String?> onChanged;

  String _libraryLabel(BuildContext context, String id) {
    if (id.isEmpty) return context.localeText('所有媒体库', 'All Libraries');
    for (final library in libraries) {
      if (library.id == id) return library.name;
    }
    return context.localeText('媒体库', 'Library');
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      DropdownMenuItem(
          value: '', child: Text(context.localeText('所有媒体库', 'All Libraries'))),
      ...libraries.map(
        (lib) => DropdownMenuItem(
          value: lib.id,
          child: Text(
            lib.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      initialValue: selectedLibraryId,
      isExpanded: true,
      icon: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      ),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.library_books_rounded, size: 18),
        prefixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 42),
        contentPadding: EdgeInsets.fromLTRB(2, 8, 8, 8),
      ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _libraryLabel(context, item.value ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _SquareToolbarButton extends StatelessWidget {
  const _SquareToolbarButton({
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary600 : context.faintBorder;
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.primary600 : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
