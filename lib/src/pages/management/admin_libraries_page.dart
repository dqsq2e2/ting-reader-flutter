part of 'management_pages.dart';

class AdminLibrariesPage extends StatefulWidget {
  const AdminLibrariesPage({super.key});

  @override
  State<AdminLibrariesPage> createState() => _AdminLibrariesPageState();
}

class _AdminLibrariesPageState extends State<AdminLibrariesPage> {
  bool _loading = true;
  List<Library> _items = [];
  String? _scanningId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AppScope.appOf(context).api.get('/api/libraries');
      if (!mounted) return;
      final data = res.data;
      final list =
          data is Map ? asMapList(asMap(data)['libraries']) : asMapList(data);
      setState(() => _items = list.map(Library.fromJson).toList());
    } catch (_) {
      if (mounted) _showSnack('获取存储库失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan(String id, {String mode = 'incremental'}) async {
    setState(() => _scanningId = id);
    try {
      await AppScope.appOf(context).api.post(
        '/api/libraries/$id/scan',
        data: {'mode': mode},
      );
      if (!mounted) return;
      _showSnack(mode == 'full' ? '全量同步任务已启动' : '增量同步任务已启动');
    } catch (_) {
      if (!mounted) return;
      _showSnack('同步启动失败');
    } finally {
      if (mounted) setState(() => _scanningId = null);
    }
  }

  Future<void> _delete(Library library) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteLibraryDialog(libraryName: library.name),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.appOf(context).api.delete('/api/libraries/${library.id}');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('存储库已删除')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      _showSnack('删除失败');
    }
  }

  Future<void> _openEditor([Library? library]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _LibraryEditorDialog(library: library),
    );
    if (saved == true) await _load();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PageListView(
      children: [
        _AdminLibrariesHeader(
          onAdd: () => _openEditor(),
        ),
        const SizedBox(height: 32),
        if (_loading)
          const TingCard(
            child: SizedBox(height: 120, child: Center(child: LoadingView())),
          )
        else if (_items.isEmpty)
          const _LibrariesEmptyState()
        else
          Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                _LibraryCard(
                  library: _items[i],
                  scanning: _scanningId == _items[i].id,
                  onScanMode: (mode) => _scan(_items[i].id, mode: mode),
                  onEdit: () => _openEditor(_items[i]),
                  onDelete: () => _delete(_items[i]),
                ),
                if (i != _items.length - 1) const SizedBox(height: 24),
              ],
            ],
          ),
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _AdminLibrariesHeader extends StatelessWidget {
  const _AdminLibrariesHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final addButton = PrimaryButton(
      label: '添加库',
      icon: Icons.add_rounded,
      onPressed: onAdd,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const header = HeaderText(
          icon: Icons.storage_rounded,
          title: '存储库管理',
          subtitle: '配置您的 WebDAV 或本地存储源并同步资源',
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: header),
              const SizedBox(height: 18),
              addButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: header),
            const SizedBox(width: 16),
            addButton,
          ],
        );
      },
    );
  }
}

class _LibrariesEmptyState extends StatelessWidget {
  const _LibrariesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate900.withValues(alpha: 0.5)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.faintBorder,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.storage_rounded,
              size: 48, color: AppColors.slate300),
          const SizedBox(height: 16),
          Text(
            '暂无存储库，点击右上角添加',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.scanning,
    required this.onScanMode,
    required this.onEdit,
    required this.onDelete,
  });

  final Library library;
  final bool scanning;
  final ValueChanged<String> onScanMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.primary700.withValues(alpha: 0.18)
                      : AppColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storage_rounded,
                  size: 28,
                  color: AppColors.primary600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          library.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _LibraryTypeChip(type: library.libraryType),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        if (library.libraryType != 'local')
                          _LibraryInfoLine(
                            icon: Icons.public_rounded,
                            text: library.url ?? '',
                          ),
                        _LibraryInfoLine(
                          icon: Icons.folder_rounded,
                          text: library.libraryType == 'local'
                              ? (library.url?.isNotEmpty ?? false
                                  ? library.url!
                                  : library.rootPath)
                              : library.rootPath,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _LibrarySyncButton(scanning: scanning, onSelected: onScanMode),
              _SoftIconButton(
                icon: Icons.edit_rounded,
                tooltip: '编辑存储库',
                onPressed: onEdit,
              ),
              _SoftIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: '删除存储库',
                danger: true,
                onPressed: onDelete,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 20),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _LibraryTypeChip extends StatelessWidget {
  const _LibraryTypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final local = type == 'local';
    final bg = local
        ? const Color(0xfffffbeb)
        : (context.isDark
            ? AppColors.primary700.withValues(alpha: 0.22)
            : AppColors.primary100);
    final fg = local ? const Color(0xffd97706) : AppColors.primary600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.isDark && local
            ? const Color(0xff78350f).withValues(alpha: 0.22)
            : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        local ? '本地存储' : 'WebDAV',
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LibraryInfoLine extends StatelessWidget {
  const _LibraryInfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.mutedText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.isEmpty ? '-' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: context.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySyncButton extends StatefulWidget {
  const _LibrarySyncButton({
    required this.scanning,
    required this.onSelected,
  });

  final bool scanning;
  final ValueChanged<String> onSelected;

  @override
  State<_LibrarySyncButton> createState() => _LibrarySyncButtonState();
}

class _LibrarySyncButtonState extends State<_LibrarySyncButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeHover = _hovered && !widget.scanning;
    final background = activeHover
        ? (context.isDark
            ? AppColors.primary700.withValues(alpha: 0.2)
            : AppColors.primary50)
        : (context.isDark ? AppColors.slate800 : AppColors.slate100);
    final foreground = activeHover
        ? AppColors.primary600
        : (context.isDark ? AppColors.slate400 : AppColors.slate600);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<String>(
        enabled: !widget.scanning,
        tooltip: '同步',
        onSelected: widget.onSelected,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'incremental',
            child: _SyncModeMenuItem(
              icon: Icons.sync_rounded,
              label: '增量同步',
              description: '只同步新增和变化的资源',
            ),
          ),
          const PopupMenuItem(
            value: 'full',
            child: _SyncModeMenuItem(
              icon: Icons.restart_alt_rounded,
              label: '全量同步',
              description: '重新扫描并校准整个存储库',
            ),
          ),
        ],
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.scanning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.sync_rounded, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                '同步',
                style: TextStyle(
                  color: widget.scanning ? AppColors.slate400 : foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: widget.scanning ? AppColors.slate400 : foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncModeMenuItem extends StatelessWidget {
  const _SyncModeMenuItem({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: context.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoftIconButton extends StatefulWidget {
  const _SoftIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_SoftIconButton> createState() => _SoftIconButtonState();
}

class _SoftIconButtonState extends State<_SoftIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor =
        widget.danger ? const Color(0xffef4444) : AppColors.primary600;
    final hoverBackground = widget.danger
        ? (context.isDark
            ? const Color(0xff7f1d1d).withValues(alpha: 0.2)
            : const Color(0xfffff1f2))
        : (context.isDark
            ? AppColors.primary700.withValues(alpha: 0.2)
            : AppColors.primary50);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hovered ? hoverBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: widget.onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            splashRadius: 20,
            color: _hovered ? hoverColor : AppColors.slate400,
            icon: Icon(widget.icon, size: 20),
          ),
        ),
      ),
    );
  }
}

class _DeleteLibraryDialog extends StatelessWidget {
  const _DeleteLibraryDialog({required this.libraryName});

  final String libraryName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xfffff1f2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xffef4444),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '确认删除？',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '此操作将永久删除“$libraryName”及其所有关联的书籍、章节和播放进度，且不可恢复。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mutedText),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xffef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '确认删除',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Map<String, dynamic> _defaultLibraryScraperConfig = {
  'extractAudioCover': true,
  'preferAudioTitle': true,
  'nfoWritingEnabled': false,
  'metadataWritingEnabled': false,
  'disableWatcher': false,
  'cloudMode': false,
};

String _prettyLibraryJson(Object? value) {
  return const JsonEncoder.withIndent('  ')
      .convert(value ?? _defaultLibraryScraperConfig);
}
