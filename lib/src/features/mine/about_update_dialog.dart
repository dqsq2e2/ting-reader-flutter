import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/client_update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/external_links.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    required this.backendVersion,
    required this.onBack,
  });

  final String? backendVersion;
  final VoidCallback onBack;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _clientUpdateService = ClientUpdateService();

  String? _backendVersion;
  String _clientVersion = 'Unknown';
  bool _loadingBackend = false;
  bool _checkingBackend = false;
  bool _checkingClient = false;
  bool _downloadingClient = false;
  double _clientDownloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _backendVersion = widget.backendVersion;
    _loadClientVersion();
    if ((_backendVersion ?? '').trim().isEmpty) {
      _loadBackendVersion();
    }
  }

  @override
  void didUpdateWidget(covariant AboutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backendVersion != oldWidget.backendVersion &&
        (widget.backendVersion ?? '').trim().isNotEmpty) {
      _backendVersion = widget.backendVersion;
    }
  }

  Future<void> _loadBackendVersion() async {
    if (_loadingBackend) return;
    setState(() => _loadingBackend = true);
    try {
      final res = await AppScope.appOf(context).api.get('/api/health');
      final data = asMap(res.data);
      if (mounted) {
        setState(() => _backendVersion = data['version']?.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingBackend = false);
    }
  }

  Future<void> _loadClientVersion() async {
    try {
      final version = await _clientUpdateService.currentVersionLabel();
      if (mounted) setState(() => _clientVersion = version);
    } catch (_) {
      // Best effort only; the page should still be usable.
    }
  }

  Future<void> _checkBackendUpdate() async {
    if (_checkingBackend) return;
    setState(() => _checkingBackend = true);
    try {
      final res =
          await AppScope.appOf(context).api.get('/api/system/check-update');
      final data = asMap(res.data);
      final remoteVersion = _firstString(data, const ['version']);
      final currentVersion = _normalizeVersion(_backendVersion ?? '');

      if (remoteVersion.isNotEmpty &&
          _normalizeVersion(remoteVersion) != currentVersion) {
        if (!mounted) return;
        final open = await _showUpdateDialog(
          title: context.localeText(
            '发现服务端新版本 ${_versionLabel(context, remoteVersion)}',
            'Server update ${_versionLabel(context, remoteVersion)} available',
          ),
          date: _firstString(data, const ['date', 'published_at']),
          actionLabel: context.localeText('前往官网更新', 'Open Guide'),
        );
        if (open == true) {
          await openExternalUrl(serverUpdateGuideUrl);
        }
      } else {
        _showLocalizedSnack('服务端已是最新版本', 'Server is up to date');
      }
    } catch (error) {
      _showLocalizedSnack(
        '检查服务端更新失败: $error',
        'Failed to check server update: $error',
      );
    } finally {
      if (mounted) setState(() => _checkingBackend = false);
    }
  }

  Future<void> _checkClientUpdate() async {
    if (_checkingClient) return;
    setState(() => _checkingClient = true);
    try {
      final latest = await _clientUpdateService.fetchLatest();
      if (latest == null || !latest.hasDownload) {
        _showLocalizedSnack(
          '当前平台请前往官网下载客户端',
          'Download the client from the website for this platform',
        );
        await _clientUpdateService.openDownloadPage();
        return;
      }

      final current = await _clientUpdateService.currentVersion();
      if (!_clientUpdateService.isNewer(latest.version, current)) {
        _showLocalizedSnack('客户端已是最新版本', 'Client is up to date');
        return;
      }

      if (!mounted) return;
      final confirm = await _showUpdateDialog(
        title: context.localeText(
          '发现客户端新版本 ${_versionLabel(context, latest.version)}',
          'Client update ${_versionLabel(context, latest.version)} available',
        ),
        date: latest.date,
        actionLabel: _clientUpdateService.canInstallDirectly
            ? context.localeText('下载安装', 'Download')
            : context.localeText('前往浏览器下载', 'Open in Browser'),
      );
      if (confirm != true) return;

      if (_clientUpdateService.canInstallDirectly) {
        setState(() {
          _downloadingClient = true;
          _clientDownloadProgress = 0;
        });
      }
      await _clientUpdateService.openOrInstall(
        latest,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _clientDownloadProgress = progress.clamp(0, 1).toDouble();
          });
        },
      );
      if (mounted) setState(() => _downloadingClient = false);
    } catch (error) {
      if (mounted) setState(() => _downloadingClient = false);
      _showLocalizedSnack(
        '检查客户端更新失败: $error',
        'Failed to check client update: $error',
      );
    } finally {
      if (mounted) setState(() => _checkingClient = false);
    }
  }

  Future<bool?> _showUpdateDialog({
    required String title,
    required String date,
    required String actionLabel,
  }) {
    final releaseDate = _dateOnly(date);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final compact = MediaQuery.sizeOf(context).width < 430;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 22 : 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: TingCard(
              radius: 28,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 32,
                vertical: compact ? 30 : 34,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 74 : 78,
                    height: compact ? 74 : 78,
                    decoration: BoxDecoration(
                      color: AppColors.primary600.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary600,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      context.localeText(
                        '发布时间：$releaseDate',
                        'Published: $releaseDate',
                      ),
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: context.mutedText,
                            backgroundColor: context.isDark
                                ? AppColors.slate800
                                : AppColors.slate100,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            context.localeText('暂不更新', 'Later'),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            elevation: 12,
                            shadowColor:
                                AppColors.primary600.withValues(alpha: 0.28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              actionLabel,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      },
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 480 ? 56.0 : 96.0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate900,
        duration: const Duration(seconds: 2),
        margin:
            EdgeInsets.only(left: horizontal, right: horizontal, bottom: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLocalizedSnack(String zh, String en) {
    if (!mounted) return;
    _showSnack(context.localeText(zh, en));
  }

  @override
  Widget build(BuildContext context) {
    return PageListView(
      onRefresh: _loadBackendVersion,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeaderRow(
                  icon: Icons.info_outline_rounded,
                  title: context.localeText(
                    '关于 Ting Reader',
                    'About Ting Reader',
                  ),
                  subtitle: context.localeText(
                    '官方网站、法律协议、更新日志，以及当前服务端和客户端版本。',
                    'Official website, legal documents, changelog, and current server and client versions.',
                  ),
                ),
                const SizedBox(height: 24),
                TingCard(
                  radius: 24,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 78,
                        height: 78,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Ting Reader',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _AboutVersionRow(
                        label: context.localeText('服务端版本', 'Server Version'),
                        version: _loadingBackend
                            ? context.localeText('加载中...', 'Loading...')
                            : _versionLabel(context, _backendVersion ?? ''),
                        checking: _checkingBackend,
                        onCheckUpdate: _checkBackendUpdate,
                      ),
                      const SizedBox(height: 12),
                      _AboutVersionRow(
                        label: context.localeText('客户端版本', 'Client Version'),
                        version: _clientVersion.isEmpty
                            ? context.localeText('未知', 'Unknown')
                            : _clientVersion,
                        checking: _checkingClient,
                        onCheckUpdate: _checkClientUpdate,
                      ),
                      if (_downloadingClient) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _clientDownloadProgress <= 0
                              ? null
                              : _clientDownloadProgress,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _clientDownloadProgress <= 0
                              ? context.localeText(
                                  '准备下载...',
                                  'Preparing download...',
                                )
                              : '${(_clientDownloadProgress * 100).clamp(0, 100).round()}%',
                          style:
                              TextStyle(color: context.mutedText, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AboutLinksPanel(
                  links: [
                    _AboutLink(
                      icon: Icons.public_rounded,
                      label: context.localeText('官方网站', 'Official Website'),
                      value: tingReaderWebsiteUrl,
                      url: tingReaderWebsiteUrl,
                      iconColor: Colors.blue.shade600,
                      iconBackground: Colors.blue.shade50,
                    ),
                    _AboutLink(
                      icon: Icons.description_outlined,
                      label: context.localeText('用户协议', 'User Agreement'),
                      value: context.localeText(
                        '使用许可与免责声明',
                        'License and disclaimer',
                      ),
                      url: userAgreementUrl,
                      iconColor: Colors.indigo.shade500,
                      iconBackground: Colors.indigo.shade50,
                    ),
                    _AboutLink(
                      icon: Icons.privacy_tip_outlined,
                      label: context.localeText('隐私协议', 'Privacy Policy'),
                      value: context.localeText(
                        '个人信息与隐私说明',
                        'Personal information and privacy',
                      ),
                      url: privacyPolicyUrl,
                      iconColor: Colors.green.shade600,
                      iconBackground: const Color(0xFFEAFBF3),
                    ),
                    _AboutLink(
                      icon: Icons.history_rounded,
                      label: context.localeText('更新日志', 'Changelog'),
                      value: context.localeText(
                        '版本迭代与修复记录',
                        'Versions and fixes',
                      ),
                      url: changelogUrl,
                      iconColor: Colors.orange.shade600,
                      iconBackground: Colors.orange.shade50,
                    ),
                  ],
                ),
                const SafeBottomSpacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutLink {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.value,
    required this.url,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;
  final Color iconColor;
  final Color iconBackground;
}

class _AboutLinksPanel extends StatelessWidget {
  const _AboutLinksPanel({required this.links});

  final List<_AboutLink> links;

  @override
  Widget build(BuildContext context) {
    return TingCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localeText('官方网站', 'Official Website'),
            style: const TextStyle(
              color: AppColors.primary600,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  for (final link in links)
                    SizedBox(
                      width: width,
                      child: _AboutLinkTile(link: link),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({required this.link});

  final _AboutLink link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openExternalUrl(link.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.isDark
                    ? link.iconColor.withValues(alpha: 0.18)
                    : link.iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(link.icon, color: link.iconColor, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    link.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.slate300,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutVersionRow extends StatelessWidget {
  const _AboutVersionRow({
    required this.label,
    required this.version,
    required this.checking,
    required this.onCheckUpdate,
  });

  final String label;
  final String version;
  final bool checking;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final labelWidth = compact ? 86.0 : 104.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              version,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: checking ? null : onCheckUpdate,
            style: TextButton.styleFrom(
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              checking
                  ? context.localeText('检查中...', 'Checking')
                  : context.localeText('检查更新', 'Check'),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

String _firstString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

String _versionLabel(BuildContext context, String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.toLowerCase() == 'unknown') {
    return context.localeText('未知', 'Unknown');
  }
  return value.toLowerCase().startsWith('v') ? value : 'v$value';
}

String _normalizeVersion(String raw) {
  return raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
}

String _dateOnly(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.split('T').first.replaceAll('-', '/');
  return '${parsed.year}/${parsed.month}/${parsed.day}';
}
