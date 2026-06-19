import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/client_update_service.dart';
import '../theme/app_theme.dart';
import '../utils/external_links.dart';
import 'app_scope.dart';
import 'common_widgets.dart';

const _serverUpdateGuideUrl = 'https://www.tingreader.cn/guide/update';

class AboutUpdateDialog extends StatefulWidget {
  const AboutUpdateDialog({
    super.key,
    required this.backendVersion,
  });

  final String? backendVersion;

  @override
  State<AboutUpdateDialog> createState() => _AboutUpdateDialogState();
}

class _AboutUpdateDialogState extends State<AboutUpdateDialog> {
  final _clientUpdateService = ClientUpdateService();

  String _clientVersion = 'Unknown';
  bool _checkingBackend = false;
  bool _checkingClient = false;
  bool _downloadingClient = false;
  double _clientDownloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadClientVersion();
  }

  Future<void> _loadClientVersion() async {
    try {
      final version = await _clientUpdateService.currentVersionLabel();
      if (mounted) setState(() => _clientVersion = version);
    } catch (_) {
      // Best effort only; the dialog should still be usable.
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
      final currentVersion = _normalizeVersion(widget.backendVersion ?? '');

      if (remoteVersion.isNotEmpty &&
          _normalizeVersion(remoteVersion) != currentVersion) {
        if (!mounted) return;
        final open = await _showUpdateDialog(
          title: '发现服务端新版本 ${_versionLabel(remoteVersion)}',
          date: _firstString(data, const ['date', 'published_at']),
          actionLabel: '前往官网更新',
        );
        if (open == true) {
          await openExternalUrl(_serverUpdateGuideUrl);
        }
      } else {
        _showSnack('服务端已是最新版本');
      }
    } catch (error) {
      _showSnack('检查服务端更新失败: $error');
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
        _showSnack('当前平台请前往官网下载客户端');
        await _clientUpdateService.openDownloadPage();
        return;
      }

      final current = await _clientUpdateService.currentVersion();
      if (!_clientUpdateService.isNewer(latest.version, current)) {
        _showSnack('客户端已是最新版本');
        return;
      }

      if (!mounted) return;
      final confirm = await _showUpdateDialog(
        title: '发现客户端新版本 ${_versionLabel(latest.version)}',
        date: latest.date,
        actionLabel: _clientUpdateService.updateActionLabel,
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
      _showSnack('检查客户端更新失败: $error');
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
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '发布时间：$releaseDate',
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
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
                          child: const Text(
                            '暂不更新',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                                fontWeight: FontWeight.w600,
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
          style: const TextStyle(fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 392),
        child: TingCard(
          radius: 28,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 28 : 32,
            vertical: compact ? 30 : 34,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: compact ? 74 : 78,
                height: compact ? 74 : 78,
              ),
              const SizedBox(height: 22),
              const Text(
                '关于 Ting Reader',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              _AboutVersionRow(
                label: '服务端版本',
                version: _versionLabel(widget.backendVersion ?? ''),
                checking: _checkingBackend,
                onCheckUpdate: _checkBackendUpdate,
              ),
              const SizedBox(height: 12),
              _AboutVersionRow(
                label: '客户端版本',
                version: _clientVersion.isEmpty ? '未知' : _clientVersion,
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
                      ? '准备下载...'
                      : '${(_clientDownloadProgress * 100).clamp(0, 100).round()}%',
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              InkWell(
                onTap: () => openExternalUrl(tingReaderWebsiteUrl),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    children: [
                      Text(
                        '官网地址',
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'www.tingreader.cn',
                        style: TextStyle(
                          color: AppColors.primary600,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.isDark
                        ? AppColors.slate100
                        : AppColors.slate700,
                    backgroundColor: context.isDark
                        ? AppColors.slate800
                        : AppColors.slate100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '关闭',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
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
    final labelWidth = compact ? 86.0 : 92.0;
    final actionWidth = compact ? 74.0 : 82.0;

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
                fontSize: 15,
                fontWeight: FontWeight.w400,
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: actionWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: checking ? null : onCheckUpdate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(
                    checking ? '检查中...' : '检查更新',
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color:
                          checking ? context.mutedText : AppColors.primary600,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
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

String _versionLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.toLowerCase() == 'unknown') return '未知';
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
