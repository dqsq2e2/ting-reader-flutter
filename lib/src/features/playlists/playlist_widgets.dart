part of 'playlists_page.dart';

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.coverSeed,
    required this.onTap,
  });

  final Playlist playlist;
  final int coverSeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bookCount = _playlistBookCount(playlist);
    final description = playlist.description?.trim() ?? '';
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlaylistCoverStack(
                playlist: playlist,
                coverShape: _playlistCoverShape(context),
                coverSeed: coverSeed,
              ),
              Text(
                localizedPlaylistTitle(context, playlist),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.localeText('$bookCount 本书', '$bookCount books'),
                style: TextStyle(color: context.secondaryText, fontSize: 12),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistHero extends StatelessWidget {
  const _PlaylistHero({
    required this.playlist,
    required this.itemCount,
    required this.onEdit,
    required this.onManage,
    required this.onDelete,
    required this.managing,
    required this.onCancelManage,
    required this.onSaveManage,
  });

  final Playlist playlist;
  final int itemCount;
  final VoidCallback onEdit;
  final VoidCallback onManage;
  final VoidCallback onDelete;
  final bool managing;
  final VoidCallback onCancelManage;
  final VoidCallback onSaveManage;

  @override
  Widget build(BuildContext context) {
    final description = playlist.description?.trim() ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.faintBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.isDark
                  ? [AppColors.slate900, AppColors.slate800]
                  : [AppColors.primary50, Colors.white, AppColors.slate50],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: compact ? 100 : 160,
                    child: _PlaylistCoverStack(
                      playlist: playlist,
                      coverShape: _playlistCoverShape(context),
                      coverSeed: 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedPlaylistTitle(context, playlist),
                          style: TextStyle(
                            color: context.primaryText,
                            fontSize: compact ? 22 : 30,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.localeText(
                            '${_playlistBookCount(playlist)} 本书 · $itemCount 项',
                            '${_playlistBookCount(playlist)} books · $itemCount items',
                          ),
                          style: const TextStyle(
                              color: AppColors.primary600, fontSize: 12),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: managing
                    ? [
                        _SoftActionButton(
                          label: context.localeText('取消', 'Cancel'),
                          icon: Icons.close_rounded,
                          onPressed: onCancelManage,
                        ),
                        PrimaryButton(
                          label: context.localeText('保存书单', 'Save Playlist'),
                          icon: Icons.save_rounded,
                          onPressed: onSaveManage,
                        ),
                      ]
                    : [
                        _SoftActionButton(
                          label: context.localeText('编辑信息', 'Edit Info'),
                          icon: Icons.edit_rounded,
                          onPressed: onEdit,
                        ),
                        PrimaryButton(
                          label: context.localeText('管理内容', 'Manage Content'),
                          icon: Icons.add_rounded,
                          onPressed: onManage,
                        ),
                        IconButton(
                          tooltip: context.localeText('删除', 'Delete'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: onDelete,
                          style: IconButton.styleFrom(
                            foregroundColor: context.mutedText,
                          ),
                        ),
                      ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: context.secondaryText,
        backgroundColor: context.isDark ? AppColors.slate800 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: context.faintBorder,
          ),
        ),
      ),
    );
  }
}

class _PlaylistFilterButton extends StatelessWidget {
  const _PlaylistFilterButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? AppColors.primary500 : context.faintBorder;
    final bg = active
        ? AppColors.primary50
        : (context.isDark ? AppColors.slate900 : Colors.white);
    return Tooltip(
      message: context.localeText('显示设置', 'Display Settings'),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: active ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.filter_list_rounded,
              size: 21,
              color: active ? AppColors.primary600 : context.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSearchBox extends StatelessWidget {
  const _PlaylistSearchBox({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: hint,
      ),
      onChanged: onChanged,
    );
  }
}

class _PlaylistSearchPanel extends StatelessWidget {
  const _PlaylistSearchPanel({
    required this.query,
    required this.hint,
    required this.countText,
    required this.onChanged,
  });

  final String query;
  final String hint;
  final String countText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: hint,
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          countText,
          style: TextStyle(
            color: context.secondaryText,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PlaylistManageSearchPanel extends StatelessWidget {
  const _PlaylistManageSearchPanel({
    required this.type,
    required this.query,
    required this.selectedCount,
    required this.onTypeChanged,
    required this.onQueryChanged,
  });

  final String type;
  final String query;
  final int selectedCount;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return TingCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final switcher = _PlaylistSegmentedSwitch(
                value: type,
                onChanged: onTypeChanged,
              );
              final search = TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: type == 'series'
                      ? context.localeText(
                          '搜索系列、作者或系列内书籍',
                          'Search series, author, or series books',
                        )
                      : context.localeText(
                          '搜索书名、作者、演播者',
                          'Search title, author, or narrator',
                        ),
                ),
                onChanged: onQueryChanged,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switcher,
                    const SizedBox(height: 12),
                    search,
                  ],
                );
              }
              return Row(
                children: [
                  switcher,
                  const SizedBox(width: 12),
                  Expanded(child: search),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.localeText(
              '已选 $selectedCount 项',
              '$selectedCount selected',
            ),
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSegmentedSwitch extends StatelessWidget {
  const _PlaylistSegmentedSwitch({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlaylistSegmentButton(
            selected: value == 'book',
            icon: Icons.playlist_play_rounded,
            label: context.localeText('书籍', 'Books'),
            onTap: () => onChanged('book'),
          ),
          _PlaylistSegmentButton(
            selected: value == 'series',
            icon: Icons.layers_rounded,
            label: context.localeText('系列', 'Series'),
            onTap: () => onChanged('series'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSegmentButton extends StatelessWidget {
  const _PlaylistSegmentButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : icon,
              size: 17,
              color: selected ? AppColors.primary600 : context.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary600 : context.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
