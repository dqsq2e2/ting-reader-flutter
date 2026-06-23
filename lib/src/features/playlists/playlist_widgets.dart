part of 'playlists_page.dart';

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.iconSize,
    required this.coverSeed,
    required this.onTap,
    this.compactOnMobile = false,
  });

  final Playlist playlist;
  final IconSizeSetting iconSize;
  final int coverSeed;
  final VoidCallback onTap;
  final bool compactOnMobile;

  @override
  Widget build(BuildContext context) {
    final coverShape = _playlistCoverShape(context);
    final padding = switch (iconSize) {
      IconSizeSetting.small => compactOnMobile ? 12.0 : 12.0,
      IconSizeSetting.medium => compactOnMobile ? 12.0 : 16.0,
      IconSizeSetting.large => compactOnMobile ? 12.0 : 20.0,
    };
    final titleSize = switch (iconSize) {
      IconSizeSetting.small => compactOnMobile ? 13.0 : 14.0,
      IconSizeSetting.medium => compactOnMobile ? 13.0 : 18.0,
      IconSizeSetting.large => compactOnMobile ? 13.0 : 20.0,
    };
    final bookCount = _playlistBookCount(playlist);
    return TingCard(
      radius: 20,
      padding: EdgeInsets.all(padding),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaylistCoverGrid(
            playlist: playlist,
            coverShape: coverShape,
            coverSeed: coverSeed,
          ),
          SizedBox(height: compactOnMobile ? 10 : 14),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.primary600,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          SizedBox(height: compactOnMobile ? 4 : 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (iconSize == IconSizeSetting.small || compactOnMobile)
                  ? 0
                  : 40,
            ),
            child: Text(
              playlist.description?.isNotEmpty == true
                  ? playlist.description!
                  : '$bookCount 本书',
              maxLines: (iconSize == IconSizeSetting.small || compactOnMobile)
                  ? 1
                  : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: compactOnMobile ? 6 : 10),
          Text(
            '$bookCount 本书',
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    const color = AppColors.primary600;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 58 : 64,
                      height: compact ? 58 : 64,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact
                            ? constraints.maxWidth - 72
                            : math.max(240, constraints.maxWidth * 0.36),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 26 : 30,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playlist.description?.isNotEmpty == true
                                ? playlist.description!
                                : '$itemCount 项',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: compact ? 14 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!compact) const Spacer(),
                SizedBox(height: compact ? 16 : 0, width: compact ? 0 : 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: managing
                      ? [
                          _SoftActionButton(
                            label: '取消',
                            icon: Icons.close_rounded,
                            onPressed: onCancelManage,
                          ),
                          PrimaryButton(
                            label: '保存书单',
                            icon: Icons.save_rounded,
                            onPressed: onSaveManage,
                          ),
                        ]
                      : [
                          _SoftActionButton(
                            label: '编辑信息',
                            icon: Icons.edit_rounded,
                            onPressed: onEdit,
                          ),
                          PrimaryButton(
                            label: '管理内容',
                            icon: Icons.add_rounded,
                            onPressed: onManage,
                          ),
                          _SoftActionButton(
                            label: '删除',
                            icon: Icons.delete_outline_rounded,
                            danger: true,
                            onPressed: onDelete,
                          ),
                        ],
                ),
              ],
            ),
          ],
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
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger ? Colors.red : context.secondaryText;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: danger
            ? Colors.red.withValues(alpha: context.isDark ? 0.14 : 0.08)
            : (context.isDark ? AppColors.slate800 : Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: danger
                ? Colors.red.withValues(alpha: 0.12)
                : context.faintBorder,
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
      message: '显示设置',
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
    return TingCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: hint,
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          Text(
            countText,
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
                  hintText: type == 'series' ? '搜索系列、作者或系列内书籍' : '搜索书名、作者、演播者',
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
            '已选 $selectedCount 项',
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
            label: '书籍',
            onTap: () => onChanged('book'),
          ),
          _PlaylistSegmentButton(
            selected: value == 'series',
            icon: Icons.layers_rounded,
            label: '系列',
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
