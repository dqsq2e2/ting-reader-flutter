part of 'management_pages.dart';

class _FolderPickerDialog extends StatefulWidget {
  const _FolderPickerDialog({required this.initialPath});

  final String initialPath;

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  bool _loading = true;
  String _currentPath = '';
  List<_FolderEntry> _folders = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AppScope.appOf(context).api.get(
        '/api/storage/folders',
        params: {'sub_path': _currentPath},
      );
      if (!mounted) return;
      setState(() {
        _folders = asMapList(res.data).map(_FolderEntry.fromJson).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(String path) {
    setState(() => _currentPath = path);
    _load();
  }

  String _parentPath() {
    final parts =
        _currentPath.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    parts.removeLast();
    return parts.join('/');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选择本地目录',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.slate800 : AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, color: AppColors.primary500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentPath.isEmpty ? 'storage/' : _currentPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: '选择此目录',
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.pop(context, _currentPath),
                    ),
                  ),
                  if (_currentPath.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: '返回上一级',
                      onPressed: () => _go(_parentPath()),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: AppColors.primary600,
                        ),
                      ),
                    )
                  : _folders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(36),
                          child: Text(
                            '当前目录下没有子文件夹',
                            style: TextStyle(color: context.mutedText),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.folder_rounded,
                                color: AppColors.primary500,
                              ),
                              title: Text(
                                folder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _go(folder.path),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: _folders.length,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderEntry {
  const _FolderEntry({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;

  factory _FolderEntry.fromJson(Map<String, dynamic> json) {
    return _FolderEntry(
      name: json['name']?.toString() ?? '未命名目录',
      path: json['path']?.toString() ?? '',
    );
  }
}
