part of '../admin_pages.dart';

class _FolderPickerDialog extends StatefulWidget {
  const _FolderPickerDialog({required this.initialPath});

  final String initialPath;

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  bool _loading = true;
  bool _rootsLoading = true;
  String _selectedRoot = '';
  String _currentPath = '';
  List<_StorageRoot> _roots = [];
  List<_FolderEntry> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  Future<void> _loadRoots() async {
    try {
      final res = await AppScope.appOf(context).api.get('/api/storage/roots');
      if (!mounted) return;
      final roots = asMapList(res.data).map(_StorageRoot.fromJson).toList();
      final matched = _findRootForPath(widget.initialPath, roots);
      setState(() {
        _roots = roots;
        _selectedRoot =
            matched?.path ?? (roots.isNotEmpty ? roots.first.path : '');
        _currentPath = _selectedRoot.isEmpty
            ? widget.initialPath
            : _relativePathFromRoot(widget.initialPath, _selectedRoot);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roots = [];
        _selectedRoot = '';
        _currentPath = widget.initialPath;
      });
    } finally {
      if (mounted) {
        setState(() => _rootsLoading = false);
        _load();
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AppScope.appOf(context).api.get(
        '/api/storage/folders',
        params: {
          'sub_path': _currentPath,
          if (_selectedRoot.isNotEmpty) 'root': _selectedRoot,
        },
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

  void _selectRoot(String root) {
    setState(() {
      _selectedRoot = root;
      _currentPath = '';
    });
    _load();
  }

  String _parentPath() {
    final parts =
        _currentPath.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    parts.removeLast();
    return parts.join('/');
  }

  String _selectedPath() {
    if (_selectedRoot.isEmpty) return _currentPath;
    return _joinRootAndSubPath(_selectedRoot, _currentPath);
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
                  Expanded(
                    child: Text(
                      context.localeText('选择本地目录', 'Choose Local Folder'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_roots.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRoot.isEmpty ? null : _selectedRoot,
                  decoration: InputDecoration(
                    labelText: context.localeText('授权根目录', 'Authorized Root'),
                    prefixIcon: const Icon(Icons.storage_rounded),
                  ),
                  items: [
                    for (final root in _roots)
                      DropdownMenuItem(
                        value: root.path,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              root.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              _localizeStorageSource(context, root.source),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: _loading || _rootsLoading
                      ? null
                      : (value) {
                          if (value == null || value == _selectedRoot) return;
                          _selectRoot(value);
                        },
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
                      _selectedPath().isEmpty
                          ? context.localeText('授权根目录', 'Authorized Root')
                          : _selectedPath(),
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
                      label: context.localeText('选择此目录', 'Choose This Folder'),
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.pop(context, _selectedPath()),
                    ),
                  ),
                  if (_currentPath.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: context.localeText('返回上一级', 'Go up'),
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
                            context.localeText(
                              '当前目录下没有子文件夹',
                              'No subfolders here',
                            ),
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

class _StorageRoot {
  const _StorageRoot({
    required this.path,
    required this.source,
  });

  final String path;
  final String source;

  factory _StorageRoot.fromJson(Map<String, dynamic> json) {
    return _StorageRoot(
      path: json['path']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
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
      name: json['name']?.toString() ?? 'Unnamed folder',
      path: json['path']?.toString() ?? '',
    );
  }
}

String _normalizeComparePath(String value) {
  return value
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '')
      .toLowerCase();
}

String _joinRootAndSubPath(String root, String subPath) {
  final cleanRoot = root.replaceAll(RegExp(r'[\\/]+$'), '');
  final cleanSubPath = subPath.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), '');
  if (cleanRoot.isEmpty) return cleanSubPath;
  return cleanSubPath.isEmpty ? cleanRoot : '$cleanRoot/$cleanSubPath';
}

String _relativePathFromRoot(String path, String root) {
  final normalizedPath = _normalizeComparePath(path);
  final normalizedRoot = _normalizeComparePath(root);
  if (normalizedPath.isEmpty || normalizedRoot.isEmpty) return '';
  if (normalizedPath == normalizedRoot) return '';
  if (!normalizedPath.startsWith('$normalizedRoot/')) return path;
  final cleanRootLength =
      root.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '').length;
  return path.replaceAll('\\', '/').substring(cleanRootLength + 1);
}

_StorageRoot? _findRootForPath(String path, List<_StorageRoot> roots) {
  final normalizedPath = _normalizeComparePath(path);
  if (normalizedPath.isEmpty) return null;
  final matches = roots.where((root) {
    final normalizedRoot = _normalizeComparePath(root.path);
    return normalizedPath == normalizedRoot ||
        normalizedPath.startsWith('$normalizedRoot/');
  }).toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  return matches.isEmpty ? null : matches.first;
}

String _localizeStorageSource(BuildContext context, String source) {
  switch (source) {
    case 'fnos':
      return context.localeText('飞牛 NAS 授权路径', 'FnOS Authorized Path');
    case 'config':
      return context.localeText('配置文件指定路径', 'Config-defined Path');
    case 'legacy_storage':
    default:
      return context.localeText('默认存储路径', 'Default Storage Path');
  }
}
