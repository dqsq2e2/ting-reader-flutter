import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

part 'statistics_pages.dart';
part 'notification_pages.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.openHistory,
    required this.openFavorites,
    required this.openDownloads,
    required this.openPersonalization,
    required this.openNotifications,
    required this.openStatistics,
    required this.openAbout,
    required this.openBook,
  });

  final VoidCallback openHistory;
  final VoidCallback openFavorites;
  final VoidCallback openDownloads;
  final VoidCallback openPersonalization;
  final VoidCallback openNotifications;
  final VoidCallback openStatistics;
  final ValueChanged<String?> openAbout;
  final ValueChanged<String> openBook;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _loading = true;
  bool _accountInitialized = false;
  bool _savingAccount = false;
  bool _accountSaved = false;
  List<ProgressItem> _recent = [];
  List<Book> _favorites = [];
  List<Playlist> _playlists = [];
  String? _version;
  Timer? _savedTimer;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accountInitialized) return;
    _usernameController.text = AppScope.appOf(context).user?.username ?? '';
    _accountInitialized = true;
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = AppScope.appOf(context);
    try {
      final results = await Future.wait([
        appState.api.get('/api/progress/recent'),
        appState.api.get('/api/favorites'),
        appState.api.get('/api/playlists'),
        appState.api.get('/api/health'),
      ]);
      final health = asMap(results[3].data);
      setState(() {
        _recent =
            asMapList(results[0].data).map(ProgressItem.fromJson).toList();
        _favorites = asMapList(results[1].data).map(Book.fromJson).toList();
        _playlists = asMapList(results[2].data).map(Playlist.fromJson).toList();
        _version = health['version']?.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAccount() async {
    if (_savingAccount) return;
    final appState = AppScope.appOf(context);
    final currentUser = appState.user;
    final nextUsername = _usernameController.text.trim();
    final nextPassword = _passwordController.text.trim();

    if (nextUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.mineUsernameRequired)),
      );
      return;
    }

    setState(() => _savingAccount = true);
    try {
      final payload = <String, String>{};
      if (currentUser == null || nextUsername != currentUser.username) {
        payload['username'] = nextUsername;
      }
      if (nextPassword.isNotEmpty) payload['password'] = nextPassword;

      if (payload.isNotEmpty) {
        await appState.api.patch('/api/me', data: payload);
        if (currentUser != null && payload.containsKey('username')) {
          await appState.updateCurrentUser(
            User(
              id: currentUser.id,
              username: nextUsername,
              role: currentUser.role,
              createdAt: currentUser.createdAt,
              librariesAccessible: currentUser.librariesAccessible,
              booksAccessible: currentUser.booksAccessible,
            ),
          );
        }
      }

      _passwordController.clear();
      _savedTimer?.cancel();
      if (mounted) {
        setState(() => _accountSaved = true);
        _savedTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _accountSaved = false);
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.mineUpdateFailed(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final appState = AppScope.appOf(context);
    final l10n = context.l10n;
    final downloadCount = AppScope.downloadOf(context).downloads.length;
    final user = appState.user;
    final username = user?.username ?? _usernameController.text;
    final listenedMinutes = (_recent.fold<double>(
              0,
              (total, item) => total + item.position.clamp(0, double.infinity),
            ) /
            60)
        .round();
    final recentBookCount = _recent
        .map((item) => item.bookId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pagePaddingForWidth(MediaQuery.sizeOf(context).width),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountProfileCard(
                  username: username,
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  recentCount: recentBookCount,
                  favoriteCount: _favorites.length,
                  playlistCount: _playlists.length,
                  accountSaved: _accountSaved,
                  saving: _savingAccount,
                  onSave: _saveAccount,
                ),
                const SizedBox(height: 28),
                _MySectionTitle(l10n.mineMyContent),
                const SizedBox(height: 12),
                _EntrySection(
                  children: [
                    _EntryRow(
                      icon: Icons.history_rounded,
                      title: l10n.mineHistoryTitle,
                      description: _recent.isEmpty
                          ? l10n.mineHistoryEmptyDescription
                          : l10n.mineHistoryDescription(
                              recentBookCount, _recent.length, listenedMinutes),
                      color: AppColors.primary600,
                      backgroundColor: AppColors.primary50,
                      onTap: widget.openHistory,
                    ),
                    _EntryRow(
                      icon: Icons.favorite_border_rounded,
                      title: l10n.mineFavoritesTitle,
                      description:
                          l10n.mineFavoritesDescription(_favorites.length),
                      color: Colors.red.shade500,
                      backgroundColor: Colors.red.shade50,
                      onTap: widget.openFavorites,
                    ),
                    _EntryRow(
                      icon: Icons.download_done_rounded,
                      title: l10n.mineDownloadsTitle,
                      description: l10n.mineDownloadsDescription(downloadCount),
                      color: Colors.orange.shade600,
                      backgroundColor: const Color(0xfffffbeb),
                      onTap: widget.openDownloads,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _MySectionTitle(l10n.mineSettingsManagement),
                const SizedBox(height: 12),
                _EntrySection(
                  children: [
                    _EntryRow(
                      icon: Icons.settings_outlined,
                      title: l10n.settingsTitle,
                      description: l10n.minePersonalizationDescription,
                      color: Colors.blue.shade600,
                      backgroundColor: Colors.blue.shade50,
                      onTap: widget.openPersonalization,
                    ),
                    if (appState.isAdmin)
                      _EntryRow(
                        icon: Icons.notifications_none_rounded,
                        title: l10n.mineNotificationTitle,
                        description: l10n.mineNotificationDescription,
                        color: Colors.green.shade600,
                        backgroundColor: Colors.green.shade50,
                        onTap: widget.openNotifications,
                      ),
                    if (appState.isAdmin)
                      _EntryRow(
                        icon: Icons.bar_chart_rounded,
                        title: l10n.mineStatisticsTitle,
                        description: l10n.mineStatisticsDescription,
                        color: Colors.purple.shade600,
                        backgroundColor: Colors.purple.shade50,
                        onTap: widget.openStatistics,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => widget.openAbout(_version),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(l10n.mineAboutTitle),
                  style: TextButton.styleFrom(
                    foregroundColor: context.mutedText,
                    textStyle: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  l10n.mineCopyright,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.mutedText.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
                const SafeBottomSpacer(),
              ],
            ),
          ),
        ),
      ],
    );

    return RefreshIndicator(
      color: AppColors.primary600,
      onRefresh: _load,
      child: content,
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.openBook,
    required this.onBack,
    required this.openBookshelf,
  });

  final void Function(String bookId, String? chapterId) openBook;
  final VoidCallback onBack;
  final VoidCallback openBookshelf;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  List<ProgressItem> _items = [];
  bool _selectionMode = false;
  bool _deleting = false;
  final Set<String> _expandedBookIds = <String>{};
  final Set<String> _selectedIds = <String>{};
  CoverShape _coverShape = CoverShape.rect;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/progress/recent'),
        api.get('/api/settings'),
      ]);
      final settings = asMap(asMap(results[1].data)['settings_json']);
      if (!mounted) return;
      setState(() {
        _items = asMapList(results[0].data).map(ProgressItem.fromJson).toList();
        _coverShape = coverShapeFromString(
          settings['bookshelf_cover_shape']?.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _historyKey(ProgressItem item) {
    return item.id.isNotEmpty
        ? item.id
        : '${item.bookId}:${item.chapterId ?? ''}';
  }

  List<_HistoryBookGroup> get _groups {
    final map = <String, _HistoryBookGroup>{};
    for (final item in _items) {
      if (item.chapterId == null || item.chapterId!.isEmpty) continue;
      final group = map[item.bookId];
      if (group == null) {
        map[item.bookId] = _HistoryBookGroup(
          bookId: item.bookId,
          bookTitle: item.bookTitle ??
              (mounted
                  ? context.localeText('未知书籍', 'Unknown Book')
                  : 'Unknown Book'),
          coverUrl: item.coverUrl,
          libraryId: item.libraryId,
          latest: item,
          chapters: [item],
        );
        continue;
      }
      group.chapters.add(item);
      if (_historyTime(item).isAfter(_historyTime(group.latest))) {
        group.latest = item;
      }
    }
    final groups = map.values.toList();
    for (final group in groups) {
      group.chapters.sort((a, b) => _historyTime(b).compareTo(_historyTime(a)));
    }
    groups.sort(
        (a, b) => _historyTime(b.latest).compareTo(_historyTime(a.latest)));
    return groups;
  }

  bool get _allSelected {
    return _items.isNotEmpty &&
        _items.every((item) => _selectedIds.contains(_historyKey(item)));
  }

  void _setSelectionMode(bool value) {
    setState(() {
      _selectionMode = value;
      _selectedIds.clear();
    });
  }

  void _toggleExpanded(String bookId) {
    setState(() {
      if (_expandedBookIds.contains(bookId)) {
        _expandedBookIds.remove(bookId);
      } else {
        _expandedBookIds.add(bookId);
      }
    });
  }

  void _toggleItem(ProgressItem item) {
    final key = _historyKey(item);
    setState(() {
      if (_selectedIds.contains(key)) {
        _selectedIds.remove(key);
      } else {
        _selectedIds.add(key);
      }
    });
  }

  void _toggleBook(_HistoryBookGroup group) {
    final keys = group.chapters.map(_historyKey).toList(growable: false);
    final selected = keys.every(_selectedIds.contains);
    setState(() {
      for (final key in keys) {
        if (selected) {
          _selectedIds.remove(key);
        } else {
          _selectedIds.add(key);
        }
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map(_historyKey));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _deleting) return;
    final api = AppScope.appOf(context).api;
    final selected = _items
        .where((item) => _selectedIds.contains(_historyKey(item)))
        .toList(growable: false);
    setState(() => _deleting = true);
    try {
      await api.post(
        '/api/progress/recent/delete',
        data: {
          'progress_ids': selected
              .where((item) => item.id.isNotEmpty)
              .map((item) => item.id)
              .toList(),
          'chapter_ids': selected
              .where((item) => item.id.isEmpty && item.chapterId != null)
              .map((item) => item.chapterId!)
              .toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => _selectedIds.contains(_historyKey(item)));
        _selectedIds.clear();
        _selectionMode = false;
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final l10n = context.l10n;
    final groups = _groups;
    final compactActions = MediaQuery.sizeOf(context).width < 420;
    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 28),
        PageHeaderRow(
          icon: Icons.history_rounded,
          title: l10n.mineHistoryTitle,
          subtitle: context.localeText(
            '按书籍整理，共 ${groups.length} 本、${_items.length} 个章节。',
            '${groups.length} books, ${_items.length} chapters grouped by book.',
          ),
          action: _items.isEmpty
              ? null
              : _selectionMode
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BatchSelectButton(
                          checked: _allSelected,
                          label: context.localeText('全选', 'Select All'),
                          compact: compactActions,
                          onPressed: _deleting ? null : _toggleAll,
                        ),
                        _HistoryActionButton(
                          icon: _deleting ? null : Icons.delete_outline_rounded,
                          label: _deleting
                              ? context.localeText('删除中...', 'Deleting...')
                              : compactActions
                                  ? context.localeText('删除', 'Delete')
                                  : context.localeText(
                                      '删除所选${_selectedIds.isEmpty ? '' : ' ${_selectedIds.length}'}',
                                      'Delete selected${_selectedIds.isEmpty ? '' : ' ${_selectedIds.length}'}',
                                    ),
                          danger: true,
                          loading: _deleting,
                          onPressed: _selectedIds.isEmpty || _deleting
                              ? null
                              : _deleteSelected,
                        ),
                        _HistoryActionButton(
                          icon: Icons.close_rounded,
                          label: context.localeText('取消', 'Cancel'),
                          onPressed:
                              _deleting ? null : () => _setSelectionMode(false),
                        ),
                      ],
                    )
                  : TextButton.icon(
                      onPressed: () => _setSelectionMode(true),
                      icon: const Icon(Icons.checklist_rounded, size: 18),
                      label: Text(context.localeText('选择', 'Select')),
                      style: TextButton.styleFrom(
                        foregroundColor: context.secondaryText,
                        backgroundColor:
                            context.isDark ? AppColors.slate800 : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: context.faintBorder),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 24),
        if (groups.isEmpty)
          EmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: context.localeText('暂无我的历史', 'No History Yet'),
            message: context.localeText(
              '暂无我的历史，去书架开始第一本吧。',
              'Go to the bookshelf and start your first book.',
            ),
            action: PrimaryButton(
              label: context.localeText('去书架', 'Go to Bookshelf'),
              icon: Icons.library_books_rounded,
              onPressed: widget.openBookshelf,
            ),
          )
        else ...[
          for (final group in groups) ...[
            _HistoryBookCard(
              group: group,
              coverShape: _coverShape,
              expanded: _expandedBookIds.contains(group.bookId),
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              historyKey: _historyKey,
              onToggleExpanded: () => _toggleExpanded(group.bookId),
              onToggleBook: () => _toggleBook(group),
              onToggleItem: _toggleItem,
              onOpenBook: widget.openBook,
            ),
            const SizedBox(height: 12),
          ],
        ],
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _HistoryBookGroup {
  _HistoryBookGroup({
    required this.bookId,
    required this.bookTitle,
    required this.latest,
    required this.chapters,
    this.coverUrl,
    this.libraryId,
  });

  final String bookId;
  final String bookTitle;
  final String? coverUrl;
  final String? libraryId;
  ProgressItem latest;
  final List<ProgressItem> chapters;
}

class _AccountProfileCard extends StatelessWidget {
  const _AccountProfileCard({
    required this.username,
    required this.usernameController,
    required this.passwordController,
    required this.recentCount,
    required this.favoriteCount,
    required this.playlistCount,
    required this.accountSaved,
    required this.saving,
    required this.onSave,
  });

  final String username;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final int recentCount;
  final int favoriteCount;
  final int playlistCount;
  final bool accountSaved;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final initial =
        username.isEmpty ? 'U' : username.substring(0, 1).toUpperCase();
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(compact ? 22 : 24),
            border: Border.all(
              color: context.isDark ? AppColors.slate800 : AppColors.slate100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.16 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 56 : 64,
                    height: compact ? 56 : 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(compact ? 16 : 18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: AppColors.primary600,
                        fontSize: compact ? 24 : 28,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 14 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navMine,
                          style: TextStyle(
                            color: context.isDark
                                ? AppColors.slate300
                                : AppColors.slate600,
                            fontSize: compact ? 13 : 14,
                          ),
                        ),
                        Text(
                          username.isEmpty ? l10n.mineDefaultUser : username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 28 : 32,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.mineIntro,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: compact ? 13 : 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 18 : 22),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountField(
                      label: l10n.settingsUsername,
                      controller: usernameController,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _AccountField(
                      label: l10n.mineChangePassword,
                      controller: passwordController,
                      icon: Icons.key_rounded,
                      hintText: l10n.minePasswordUnchangedHint,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _SaveAccountButton(
                        saved: accountSaved,
                        saving: saving,
                        onSave: onSave,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _AccountField(
                        label: l10n.settingsUsername,
                        controller: usernameController,
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AccountField(
                        label: l10n.mineChangePassword,
                        controller: passwordController,
                        icon: Icons.key_rounded,
                        hintText: l10n.minePasswordUnchangedHint,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SaveAccountButton(
                      saved: accountSaved,
                      saving: saving,
                      onSave: onSave,
                    ),
                  ],
                ),
              SizedBox(height: compact ? 24 : 24),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: l10n.mineRecent,
                      value: recentCount,
                      unit: l10n.mineBookUnit,
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: l10n.mineFavorites,
                      value: favoriteCount,
                      unit: l10n.mineBookUnit,
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: l10n.minePlaylists,
                      value: playlistCount,
                      unit: l10n.minePlaylistUnit,
                      compact: compact,
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

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.isDark ? AppColors.slate300 : AppColors.slate600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, color: AppColors.slate400, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveAccountButton extends StatelessWidget {
  const _SaveAccountButton({
    required this.saved,
    required this.saving,
    required this.onSave,
  });

  final bool saved;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saved) ...[
          Text(
            context.l10n.mineAccountUpdated,
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
        ],
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label:
                Text(saving ? context.l10n.mineSaving : context.l10n.mineSave),
            style: ElevatedButton.styleFrom(
              elevation: 8,
              shadowColor: AppColors.primary500.withValues(alpha: 0.22),
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    this.compact = false,
  });

  final String label;
  final int value;
  final String unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 88 : 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate800.withValues(alpha: 0.7)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            maxLines: 1,
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$value',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    color: context.primaryText,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MySectionTitle extends StatelessWidget {
  const _MySectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.mutedText,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  const _EntrySection({required this.children});

  final List<_EntryRow> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.16 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: context.isDark ? AppColors.slate800 : AppColors.slate100,
              ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.slate300,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryActionButton extends StatelessWidget {
  const _HistoryActionButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.danger = false,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    return BatchActionButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      danger: danger,
      loading: loading,
      compact: compact,
    );
  }
}

class _HistoryBookCard extends StatelessWidget {
  const _HistoryBookCard({
    required this.group,
    required this.coverShape,
    required this.expanded,
    required this.selectionMode,
    required this.selectedIds,
    required this.historyKey,
    required this.onToggleExpanded,
    required this.onToggleBook,
    required this.onToggleItem,
    required this.onOpenBook,
  });

  final _HistoryBookGroup group;
  final CoverShape coverShape;
  final bool expanded;
  final bool selectionMode;
  final Set<String> selectedIds;
  final String Function(ProgressItem item) historyKey;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleBook;
  final ValueChanged<ProgressItem> onToggleItem;
  final void Function(String bookId, String? chapterId) onOpenBook;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final compact = MediaQuery.sizeOf(context).width < 640;
    final latest = group.latest;
    final percent = _historyPercent(latest);
    final allSelected =
        group.chapters.every((item) => selectedIds.contains(historyKey(item)));
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 20,
                  vertical: compact ? 14 : 18,
                ),
                child: Row(
                  children: [
                    if (selectionMode) ...[
                      _HistoryCheckbox(
                        checked: allSelected,
                        onTap: onToggleBook,
                      ),
                      const SizedBox(width: 12),
                    ],
                    SizedBox(
                      width: compact ? 64 : 80,
                      child: AspectRatio(
                        aspectRatio: coverAspectRatio(coverShape),
                        child: CoverImage(
                          url: coverUrl(
                            appState,
                            url: group.coverUrl,
                            libraryId: group.libraryId,
                            bookId: group.bookId,
                          ),
                          radius: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 14 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.bookTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 15 : 16,
                                    height: 1.18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.localeText(
                                  '${group.chapters.length} 章',
                                  '${group.chapters.length} chapters',
                                ),
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            latest.chapterTitle ??
                                context.localeText('未知章节', 'Unknown Chapter'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: compact ? 12 : 13,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  context.localeText(
                                    '最后收听：${_formatLastListenedTime(context, latest.updatedAt)}',
                                    'Last listened: ${_formatLastListenedTime(context, latest.updatedAt)}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _HistoryProgressBar(percent: percent),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.slate300,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Container(
              color: context.isDark
                  ? AppColors.slate950.withValues(alpha: 0.24)
                  : AppColors.slate50.withValues(alpha: 0.62),
              child: Column(
                children: [
                  for (var i = 0; i < group.chapters.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.isDark
                            ? AppColors.slate800
                            : AppColors.slate100,
                      ),
                    _HistoryChapterTile(
                      item: group.chapters[i],
                      selectionMode: selectionMode,
                      selected:
                          selectedIds.contains(historyKey(group.chapters[i])),
                      onToggle: () => onToggleItem(group.chapters[i]),
                      onTap: () => onOpenBook(
                        group.bookId,
                        group.chapters[i].chapterId,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryChapterTile extends StatelessWidget {
  const _HistoryChapterTile({
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onTap,
  });

  final ProgressItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = _historyPercent(item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selectionMode ? onToggle : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              if (selectionMode) ...[
                _HistoryCheckbox(checked: selected, onTap: onToggle),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.chapterTitle ??
                          context.localeText('未知章节', 'Unknown Chapter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _formatLastListenedTime(context, item.updatedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.slate400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HistoryProgressBar(percent: percent),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.slate300,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCheckbox extends StatelessWidget {
  const _HistoryCheckbox({
    required this.checked,
    required this.onTap,
  });

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BatchCheckbox(
      checked: checked,
      compact: MediaQuery.sizeOf(context).width < 640,
      onChanged: onTap,
    );
  }
}

class _HistoryProgressBar extends StatelessWidget {
  const _HistoryProgressBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              color: percent >= 0.95
                  ? const Color(0xff10b981)
                  : AppColors.primary500,
              backgroundColor:
                  context.isDark ? AppColors.slate800 : AppColors.slate100,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            percent >= 0.95
                ? context.localeText('已播完', 'Done')
                : '${(percent * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.slate400,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

DateTime _historyTime(ProgressItem item) {
  return DateTime.tryParse(item.updatedAt ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

double _historyPercent(ProgressItem item) {
  final duration = (item.chapterDuration ?? item.duration).toDouble();
  if (duration <= 0) return 0;
  return (item.position / duration).clamp(0.0, 1.0).toDouble();
}

String _formatLastListenedTime(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return context.localeText('未知时间', 'Unknown time');
  }
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return context.localeText('未知时间', 'Unknown time');

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return context.localeText('今天 $time', 'Today $time');
  if (diff == 1) return context.localeText('昨天 $time', 'Yesterday $time');
  if (diff > 1 && diff < 7) {
    return context.localeText('$diff 天前 $time', '$diff days ago $time');
  }
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} $time';
}
