import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

const supportedAppLocales = [
  Locale('zh'),
  Locale('en'),
];

String normalizeLanguage(String? value) {
  if (value == null || value.trim().isEmpty) return 'zh';
  final normalized = value.replaceAll('_', '-').toLowerCase();
  if (normalized.startsWith('en')) return 'en';
  if (normalized.startsWith('zh')) return 'zh';
  return 'zh';
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isEnglishLocale =>
      Localizations.localeOf(this).languageCode.toLowerCase().startsWith('en');

  String localeText(String zh, String en) => isEnglishLocale ? en : zh;
}

extension PluginLocalizationCompat on AppLocalizations {
  bool get _isEn => localeName.toLowerCase().startsWith('en');
  String _text(String zh, String en) => _isEn ? en : zh;

  String get pluginsReloaded => _text('插件已重载', 'Plugin reloaded');
  String get pluginsInstalled => _text('插件已安装', 'Plugin installed');
  String get pluginsInstallFailed => _text('插件安装失败', 'Plugin install failed');
  String get pluginsUninstallTitle => _text('卸载插件？', 'Uninstall plugin?');
  String pluginsUninstallMessage(String name) =>
      _text('确定要卸载 $name 吗？', 'Uninstall $name?');
  String get pluginsUninstallAction => _text('卸载', 'Uninstall');
  String get pluginsUninstalled => _text('插件已卸载', 'Plugin uninstalled');
  String get pluginsLoading => _text('正在加载插件...', 'Loading plugins...');
  String get pluginsAll => _text('全部', 'All');
  String get pluginsInstalledTab => _text('已安装', 'Installed');
  String get pluginsUpdatesTab => _text('可更新', 'Updates');
  String get pluginsRefreshList => _text('刷新列表', 'Refresh');
  String get pluginsUpdateList => _text('更新列表', 'Update List');
  String get pluginsManualInstall => _text('手动安装', 'Manual Install');
  String get pluginsCategoryMetadata => _text('元数据', 'Metadata');
  String get pluginsCategoryFormat => _text('格式', 'Format');
  String get pluginsCategoryUtility => _text('工具', 'Utility');
  String get pluginsSearchHint => _text('搜索插件...', 'Search plugins...');
  String get pluginsNoDescription => _text('暂无插件简介', 'No description');
  String pluginsDependencyCount(int count) =>
      _text('$count 个依赖', '$count dependencies');
  String get pluginsDependencyInstallTitle =>
      _text('安装依赖插件？', 'Install dependencies?');
  String pluginsDependencyInstallMessage(
          String pluginName, List<String> dependencies) =>
      _text(
        '安装 $pluginName 需要以下依赖插件：\n\n'
            '${dependencies.join('\n')}\n\n是否立即安装这些依赖？',
        'Installing $pluginName requires these dependency plugins:\n\n'
            '${dependencies.join('\n')}\n\nInstall them now?',
      );
  String get pluginsDependencyInstallAction =>
      _text('安装依赖', 'Install dependencies');
  String pluginsDependencyInstallFailed(String pluginName) => _text(
        '依赖插件 $pluginName 安装失败',
        'Failed to install dependency $pluginName',
      );
  String pluginsPermissionCount(int count) =>
      _text('$count 个权限', '$count permissions');
  String get pluginsConfigurable => _text('可配置', 'Configurable');
  String get pluginsAutoScrape => _text('自动刮削', 'Auto scrape');
  String pluginsSearchFieldCount(int count) =>
      _text('$count 个搜索项', '$count search fields');
  String pluginsResultFieldCount(int count) =>
      _text('$count 个结果字段', '$count result fields');
  String get pluginsRepository => _text('仓库', 'Repository');
  String get pluginsConfigure => _text('配置', 'Configure');
  String get pluginsReload => _text('重载', 'Reload');
  String get pluginsProcessing => _text('处理中...', 'Processing...');
  String get pluginsUpdate => _text('更新', 'Update');
  String get pluginsInstall => _text('安装', 'Install');
  String get pluginsStateActive => _text('运行中', 'Active');
  String get pluginsStateFailed => _text('失败', 'Failed');
  String get pluginsStateLoading => _text('加载中', 'Loading');
  String get pluginsStateInactive => _text('未启用', 'Inactive');
  String get pluginsAdminOnly => _text('仅管理员', 'Admin only');
  String pluginsCapabilityLabel(String kind) {
    const labels = {
      'metadata_provider': ('元数据刮削', 'Metadata scraping'),
      'format_handler': ('格式扩展', 'Format support'),
      'content_processor': ('内容处理', 'Content processing'),
      'tool_provider': ('工具', 'Tools'),
      'ui_extension': ('界面扩展', 'UI extension'),
      'http_route': ('HTTP 服务', 'HTTP service'),
      'plugin_store': ('插件商店', 'Plugin store'),
      'task_handler': ('后台任务', 'Background tasks'),
      'event_handler': ('事件响应', 'Event handling'),
    };
    final label = labels[kind];
    return label == null ? kind : _text(label.$1, label.$2);
  }

  String pluginsPermissionLabel(String type) {
    const labels = {
      'network_access': ('网络访问', 'Network access'),
      'file_read': ('读取文件', 'Read files'),
      'file_write': ('写入文件', 'Write files'),
      'books_read': ('读取书籍', 'Read books'),
      'books_write': ('修改书籍', 'Modify books'),
      'libraries_read': ('读取存储库', 'Read libraries'),
      'libraries_write': ('修改存储库', 'Modify libraries'),
      'chapters_read': ('读取章节', 'Read chapters'),
      'chapters_write': ('修改章节', 'Modify chapters'),
      'progress_read': ('读取播放进度', 'Read playback progress'),
      'media_read_url': ('获取音源地址', 'Get audio URLs'),
      'plugin_route_sign': ('生成访问签名', 'Sign access URLs'),
      'metadata_write': ('修改元数据', 'Modify metadata'),
      'task_create': ('创建任务', 'Create tasks'),
      'cache_read': ('读取缓存', 'Read cache'),
      'cache_write': ('写入缓存', 'Write cache'),
      'playlists_read': ('读取书单', 'Read playlists'),
      'playlists_write': ('修改书单', 'Modify playlists'),
      'favorites_read': ('读取收藏', 'Read favorites'),
      'favorites_write': ('修改收藏', 'Modify favorites'),
      'user_settings_read': ('读取个人设置', 'Read preferences'),
      'user_settings_write': ('修改个人设置', 'Modify preferences'),
      'event_subscribe': ('订阅事件', 'Subscribe to events'),
      'event_publish': ('发布事件', 'Publish events'),
    };
    final label = labels[type];
    return label == null ? type : _text(label.$1, label.$2);
  }

  String get pluginsUpdateAvailable => _text('有更新', 'Update');
  String get pluginsNoUpdates => _text('暂无可用更新', 'No Updates');
  String get pluginsNoInstalled => _text('还没有安装插件', 'No Installed Plugins');
  String get pluginsNoMatches => _text('没有匹配插件', 'No Matching Plugins');
  String get pluginsInstalledEmptyHint =>
      _text('去插件市场安装一个插件。', 'Install one from the plugin store.');
  String get pluginsFilterEmptyHint =>
      _text('换个关键词或筛选条件试试。', 'Try another keyword or filter.');
  String get pluginsJsonInvalid => _text('JSON 格式不正确', 'Invalid JSON');
  String pluginsConfigTitle(String name) =>
      _text('配置 $name', 'Configure $name');
  String get pluginsUnknownType => _text('未知类型', 'Unknown type');
}
