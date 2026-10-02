import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/application_time_zone.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/fnos_logo.dart';

part 'statistics_pages.dart';
part 'notification_pages.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.openHistory,
    required this.openBookmarks,
    required this.openFavorites,
    required this.openDownloads,
    required this.openPersonalization,
    required this.openFnConnect,
    required this.openNotifications,
    required this.openStatistics,
    required this.openAbout,
    required this.openBook,
  });

  final VoidCallback openHistory;
  final VoidCallback openBookmarks;
  final VoidCallback openFavorites;
  final VoidCallback openDownloads;
  final VoidCallback openPersonalization;
  final VoidCallback openFnConnect;
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
  int _recentBookCount = 0;
  int _recentChapterCount = 0;
  double _recentPositionSeconds = 0;
  List<Book> _favorites = [];
  List<Playlist> _playlists = [];
  String? _version;
  Timer? _savedTimer;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
        appState.api.get('/api/history/summary'),
        appState.api.get('/api/favorites'),
        appState.api.get('/api/playlists'),
        appState.api.get('/api/health'),
      ]);
      final health = asMap(results[3].data);
      final history = asMap(results[0].data);
      if (!mounted) return;
      setState(() {
        _recentBookCount = (history['books'] as num?)?.toInt() ?? 0;
        _recentChapterCount = (history['chapters'] as num?)?.toInt() ?? 0;
        _recentPositionSeconds =
            (history['position_seconds'] as num?)?.toDouble() ?? 0;
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
        final response = await appState.api.patch('/api/me', data: payload);
        await appState.updateCurrentUser(User.fromJson({
          ...?currentUser?.toJson(),
          ...asMap(response.data),
        }));
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
    final listenedMinutes = (_recentPositionSeconds / 60).round();
    final listenedDuration =
        formatMinutesMetricForLocale(context, listenedMinutes);
    final recentBookCount = _recentBookCount;

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
                      description: _recentChapterCount == 0
                          ? l10n.mineHistoryEmptyDescription
                          : context.localeText(
                              '最近听过 $recentBookCount 本 / $_recentChapterCount 章，约 ${listenedDuration.value} ${listenedDuration.unit}',
                              'Recently listened to $recentBookCount books / $_recentChapterCount chapters, about ${listenedDuration.value} ${listenedDuration.unit}',
                            ),
                      color: AppColors.primary600,
                      backgroundColor: AppColors.primary50,
                      onTap: widget.openHistory,
                    ),
                    _EntryRow(
                      icon: Icons.bookmarks_outlined,
                      title: context.localeText('我的书签', 'My Bookmarks'),
                      description: context.localeText('按书籍查看保存的位置和备注',
                          'Saved positions and notes, grouped by book'),
                      color: Colors.amber.shade700,
                      backgroundColor: Colors.amber.shade50,
                      onTap: widget.openBookmarks,
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
                    if (appState.activeProfile?.isFnosGateway == true)
                      _EntryRow(
                        leading: const FnosLogo(width: 28, height: 23),
                        title: context.localeText('FN Connect', 'FN Connect'),
                        description: context.localeText(
                          '连接偏好与候选链路管理',
                          'Connection preferences and link management',
                        ),
                        color: Colors.teal.shade600,
                        backgroundColor: Colors.teal.shade50,
                        onTap: widget.openFnConnect,
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
    this.icon,
    this.leading,
    required this.title,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
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
                child: Center(
                  child: leading ?? Icon(icon, color: color, size: 24),
                ),
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
