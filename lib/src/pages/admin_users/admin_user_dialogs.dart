part of 'admin_users_page.dart';

class _ConfirmActionDialog extends StatelessWidget {
  const _ConfirmActionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(context.isDark ? 0.34 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: context.tertiaryText,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: context.mutedText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(confirmLabel),
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

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.user,
    required this.libraries,
  });

  final User? user;
  final List<Library> libraries;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _username;
  late final TextEditingController _password;
  final TextEditingController _bookSearch = TextEditingController();
  Timer? _searchTimer;
  String _role = 'user';
  Set<String> _libraryIds = {};
  Set<String> _bookIds = {};
  List<Book> _selectedBooks = [];
  List<Book> _bookResults = [];
  List<Series> _seriesResults = [];
  bool _saving = false;
  bool _searching = false;
  String? _error;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _username = TextEditingController(text: user?.username ?? '');
    _password = TextEditingController();
    _role = user?.role == 'admin' ? 'admin' : 'user';
    _libraryIds = {...?user?.librariesAccessible};
    _bookIds = {...?user?.booksAccessible};
    _loadSelectedBooks();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _username.dispose();
    _password.dispose();
    _bookSearch.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedBooks() async {
    if (_bookIds.isEmpty) return;
    final api = AppScope.appOf(context).api;
    final books = <Book>[];
    for (final id in _bookIds) {
      try {
        final res = await api.get('/api/books/$id');
        books.add(Book.fromJson(asMap(res.data)));
      } catch (_) {
        books.add(Book(id: id, libraryId: '', title: id));
      }
    }
    if (!mounted) return;
    setState(() => _selectedBooks = books);
  }

  void _queueSearch(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _bookResults = [];
        _seriesResults = [];
        _searching = false;
      });
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchBooks(query);
    });
  }

  Future<void> _searchBooks(String query) async {
    setState(() => _searching = true);
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/books', params: {'search': query}),
        api.get('/api/v1/series'),
      ]);
      final books = asMapList(results[0].data)
          .map(Book.fromJson)
          .where((book) => !_bookIds.contains(book.id))
          .take(10)
          .toList();
      final q = query.toLowerCase();
      final series = asMapList(results[1].data)
          .map(Series.fromJson)
          .where(
            (item) =>
                item.title.toLowerCase().contains(q) ||
                (item.author ?? '').toLowerCase().contains(q),
          )
          .take(5)
          .toList();
      if (!mounted) return;
      setState(() {
        _bookResults = books;
        _seriesResults = series;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addBook(Book book) {
    if (_bookIds.contains(book.id)) return;
    setState(() {
      _bookIds.add(book.id);
      _selectedBooks.add(book);
      _bookSearch.clear();
      _bookResults = [];
      _seriesResults = [];
    });
  }

  void _addSeries(Series series) {
    final newBooks = series.books.where((book) => !_bookIds.contains(book.id));
    if (newBooks.isEmpty) {
      setState(() {
        _bookSearch.clear();
        _bookResults = [];
        _seriesResults = [];
      });
      return;
    }
    setState(() {
      for (final book in newBooks) {
        _bookIds.add(book.id);
        _selectedBooks.add(book);
      }
      _bookSearch.clear();
      _bookResults = [];
      _seriesResults = [];
    });
  }

  void _removeBook(String id) {
    setState(() {
      _bookIds.remove(id);
      _selectedBooks = _selectedBooks.where((book) => book.id != id).toList();
    });
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    if (!_editing && _password.text.isEmpty) {
      setState(() => _error = '请输入初始密码');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = AppScope.appOf(context).api;
    try {
      if (_editing) {
        final user = widget.user!;
        final data = <String, dynamic>{};
        if (username != user.username) data['username'] = username;
        if (_password.text.isNotEmpty) data['password'] = _password.text;
        if (_role != user.role) data['role'] = _role;
        if (_role == 'user') {
          data['librariesAccessible'] = _libraryIds.toList();
          data['booksAccessible'] = _bookIds.toList();
        }
        if (data.isNotEmpty) {
          await api.patch('/api/users/${user.id}', data: data);
        }
      } else {
        final data = <String, dynamic>{
          'username': username,
          'password': _password.text,
          'role': _role,
          if (_role == 'user') 'librariesAccessible': _libraryIds.toList(),
          if (_role == 'user') 'booksAccessible': _bookIds.toList(),
        };
        await api.post('/api/users', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _extractError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractError(Object error) {
    final text = error.toString();
    return text.isEmpty ? '操作失败' : text;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 448, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(context.isDark ? 0.34 : 0.18),
                blurRadius: 34,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editing ? '修改用户信息' : '创建新账号',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.slate400,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _DialogLabel('用户名'),
                const SizedBox(height: 8),
                _DialogTextField(controller: _username),
                const SizedBox(height: 18),
                _DialogLabel(_editing ? '新密码（留空则不修改）' : '初始密码'),
                const SizedBox(height: 8),
                _DialogTextField(
                  controller: _password,
                  obscureText: true,
                ),
                const SizedBox(height: 18),
                const _DialogLabel('权限角色'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _UserRoleChoice(
                        label: '普通用户',
                        selected: _role == 'user',
                        color: AppColors.primary600,
                        onTap: () => setState(() => _role = 'user'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UserRoleChoice(
                        label: '管理员',
                        selected: _role == 'admin',
                        color: const Color(0xff9333ea),
                        onTap: () => setState(() => _role = 'admin'),
                      ),
                    ),
                  ],
                ),
                if (_role == 'user') ...[
                  const SizedBox(height: 20),
                  const _DialogLabel('可访问的库'),
                  const SizedBox(height: 8),
                  _LibraryPermissionBox(
                    libraries: widget.libraries,
                    selectedIds: _libraryIds,
                    onChanged: (id, selected) {
                      setState(() {
                        if (selected) {
                          _libraryIds.add(id);
                        } else {
                          _libraryIds.remove(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const _DialogLabel('特定书籍权限（搜索书名或系列名添加）'),
                  const SizedBox(height: 8),
                  _BookPermissionSearch(
                    controller: _bookSearch,
                    searching: _searching,
                    bookResults: _bookResults,
                    seriesResults: _seriesResults,
                    onChanged: _queueSearch,
                    onBookTap: _addBook,
                    onSeriesTap: _addSeries,
                  ),
                  const SizedBox(height: 10),
                  _SelectedBookChips(
                    books: _selectedBooks,
                    onRemove: _removeBook,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '提示：用户将拥有所选库下的所有书籍权限，以及此处单独添加的特定书籍权限。',
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xffef4444),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary600.withOpacity(0.55),
                      elevation: 8,
                      shadowColor: AppColors.primary500.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _editing ? '保存修改' : '立即创建',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
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
