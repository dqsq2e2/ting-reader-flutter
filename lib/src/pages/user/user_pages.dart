import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/urls.dart';
import '../../widgets/app_scope.dart';
import '../../widgets/about_update_dialog.dart';
import '../../widgets/book_card.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/display_filter_menu.dart';

part 'playlist_pages.dart';
part 'playlist_detail_page.dart';
part 'playlist_widgets.dart';
part 'playlist_selection_widgets.dart';
part 'playlist_cover_grid.dart';
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
    required this.openBook,
  });

  final VoidCallback openHistory;
  final VoidCallback openFavorites;
  final VoidCallback openDownloads;
  final VoidCallback openPersonalization;
  final VoidCallback openNotifications;
  final VoidCallback openStatistics;
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
        const SnackBar(content: Text('用户名不能为空')),
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
        SnackBar(content: Text('更新失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AboutUpdateDialog(backendVersion: _version),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final appState = AppScope.appOf(context);
    final downloadCount = AppScope.downloadOf(context).downloads.length;
    final user = appState.user;
    final username = user?.username ?? _usernameController.text;
    final listenedMinutes = (_recent.fold<double>(
              0,
              (total, item) => total + item.position.clamp(0, double.infinity),
            ) /
            60)
        .round();

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
                  recentCount: _recent.length,
                  favoriteCount: _favorites.length,
                  playlistCount: _playlists.length,
                  accountSaved: _accountSaved,
                  saving: _savingAccount,
                  onSave: _saveAccount,
                ),
                const SizedBox(height: 28),
                const _MySectionTitle('我的内容'),
                const SizedBox(height: 12),
                _EntrySection(
                  children: [
                    _EntryRow(
                      icon: Icons.history_rounded,
                      title: '我的历史',
                      description: _recent.isEmpty
                          ? '查看图文收听记录'
                          : '最近听过 ${_recent.length} 本，约 $listenedMinutes 分钟',
                      color: AppColors.primary600,
                      backgroundColor: AppColors.primary50,
                      onTap: widget.openHistory,
                    ),
                    _EntryRow(
                      icon: Icons.favorite_border_rounded,
                      title: '我的收藏',
                      description: '收藏夹里有 ${_favorites.length} 部作品',
                      color: Colors.red.shade500,
                      backgroundColor: Colors.red.shade50,
                      onTap: widget.openFavorites,
                    ),
                    _EntryRow(
                      icon: Icons.download_done_rounded,
                      title: '我的下载',
                      description: '已下载 $downloadCount 个音频',
                      color: Colors.orange.shade600,
                      backgroundColor: const Color(0xfffffbeb),
                      onTap: widget.openDownloads,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _MySectionTitle('设置与管理'),
                const SizedBox(height: 12),
                _EntrySection(
                  children: [
                    _EntryRow(
                      icon: Icons.settings_outlined,
                      title: '个性化设置',
                      description: '外观展示与播放偏好',
                      color: Colors.blue.shade600,
                      backgroundColor: Colors.blue.shade50,
                      onTap: widget.openPersonalization,
                    ),
                    if (appState.isAdmin)
                      _EntryRow(
                        icon: Icons.notifications_none_rounded,
                        title: '通知与事件',
                        description: '配置 Webhook 监听登录、播放、入库和删除',
                        color: Colors.green.shade600,
                        backgroundColor: Colors.green.shade50,
                        onTap: widget.openNotifications,
                      ),
                    if (appState.isAdmin)
                      _EntryRow(
                        icon: Icons.bar_chart_rounded,
                        title: '数据统计',
                        description: '用户使用情况与馆藏报表',
                        color: Colors.purple.shade600,
                        backgroundColor: Colors.purple.shade50,
                        onTap: widget.openStatistics,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _showAboutDialog,
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('关于 Ting Reader'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.mutedText,
                    textStyle: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '©2026 Ting Reader. 保留所有权利。',
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

  final ValueChanged<String> openBook;
  final VoidCallback onBack;
  final VoidCallback openBookshelf;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  List<ProgressItem> _items = [];
  bool _clearing = false;
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
      final settings = asMap(asMap(results[1].data)['settings_json'] ??
          asMap(results[1].data)['settingsJson']);
      if (!mounted) return;
      setState(() {
        _items = asMapList(results[0].data).map(ProgressItem.fromJson).toList();
        _coverShape = coverShapeFromString(
          (settings['bookshelf_cover_shape'] ?? settings['bookshelfCoverShape'])
              ?.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    if (_items.isEmpty || _clearing) return;
    final api = AppScope.appOf(context).api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('清空收听历史'),
        content: const Text('确定清空全部收听历史吗？此操作不会删除书籍和章节。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('清空历史'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    try {
      await api.delete('/api/progress/recent');
      if (!mounted) return;
      setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 28),
        _PageHeaderRow(
          icon: Icons.history_rounded,
          title: '收听历史',
          subtitle: '继续上次停下的位置，共 ${_items.length} 条记录。',
          action: _items.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: _clearing ? null : _clear,
                  icon: _clearing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_clearing ? '清空中...' : '清空历史'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffef4444),
                    backgroundColor: const Color(0xfffff1f2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        if (_items.isEmpty)
          EmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: '暂无收听历史',
            message: '暂无收听历史，去书架开始第一本吧。',
            action: PrimaryButton(
              label: '去书架',
              icon: Icons.library_books_rounded,
              onPressed: widget.openBookshelf,
            ),
          )
        else
          Container(
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
                for (var i = 0; i < _items.length; i++) ...[
                  _ProgressListTile(
                    item: _items[i],
                    coverShape: _coverShape,
                    onTap: () => widget.openBook(_items[i].bookId),
                  ),
                  if (i != _items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.isDark
                          ? AppColors.slate800
                          : AppColors.slate100,
                    ),
                ],
              ],
            ),
          ),
        const SafeBottomSpacer(),
      ],
    );
  }
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
                color: Colors.black.withValues(alpha: context.isDark ? 0.16 : 0.05),
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
                          '我的',
                          style: TextStyle(
                            color: context.isDark
                                ? AppColors.slate300
                                : AppColors.slate600,
                            fontSize: compact ? 13 : 14,
                          ),
                        ),
                        Text(
                          username.isEmpty ? '听书用户' : username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 28 : 32,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '管理听书记录、收藏、书单和个人偏好。',
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
                      label: '用户名',
                      controller: usernameController,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _AccountField(
                      label: '修改密码',
                      controller: passwordController,
                      icon: Icons.key_rounded,
                      hintText: '留空则不修改',
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
                        label: '用户名',
                        controller: usernameController,
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AccountField(
                        label: '修改密码',
                        controller: passwordController,
                        icon: Icons.key_rounded,
                        hintText: '留空则不修改',
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
                      label: '最近',
                      value: recentCount,
                      unit: '本',
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: '收藏',
                      value: favoriteCount,
                      unit: '本',
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: '书单',
                      value: playlistCount,
                      unit: '个',
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
            '已更新',
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
            label: Text(saving ? '保存中' : '保存'),
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

class _PageHeaderRow extends StatelessWidget {
  const _PageHeaderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = HeaderText(icon: icon, title: title, subtitle: subtitle);
        if (constraints.maxWidth < 720 || action == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: header),
            action!,
          ],
        );
      },
    );
  }
}

class _ProgressListTile extends StatelessWidget {
  const _ProgressListTile({
    required this.item,
    required this.coverShape,
    required this.onTap,
  });

  final ProgressItem item;
  final CoverShape coverShape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final duration = (item.chapterDuration ?? item.duration).toDouble();
    final percent =
        duration > 0 ? (item.position / duration).clamp(0.0, 1.0) : 0.0;
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 20,
            vertical: compact ? 14 : 18,
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 64 : 80,
                child: AspectRatio(
                  aspectRatio: coverAspectRatio(coverShape),
                  child: CoverImage(
                    url: coverUrl(
                      appState,
                      url: item.coverUrl,
                      libraryId: item.libraryId,
                      bookId: item.bookId,
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
                    Text(
                      item.bookTitle ?? '未知书籍',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.chapterTitle ?? '未知章节',
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
                            '最后收听：${_formatLastListenedTime(item.updatedAt)}',
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
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 4,
                              color: AppColors.primary500,
                              backgroundColor: context.isDark
                                  ? AppColors.slate800
                                  : AppColors.slate100,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${(percent * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.slate400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.slate300,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatLastListenedTime(String? value) {
  if (value == null || value.isEmpty) return '未知时间';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '未知时间';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return '今天 $time';
  if (diff == 1) return '昨天 $time';
  if (diff > 1 && diff < 7) return '$diff 天前 $time';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} $time';
}
