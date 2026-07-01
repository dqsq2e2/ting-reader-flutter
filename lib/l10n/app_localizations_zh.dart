// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Ting Reader';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonCopy => '复制';

  @override
  String get commonSaved => '已保存';

  @override
  String commonSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get commonRetryConnection => '重试连接';

  @override
  String get navMainMenu => '主菜单';

  @override
  String get navAdmin => '管理后台';

  @override
  String get navHome => '首页';

  @override
  String get navBookshelf => '书架';

  @override
  String get navPlaylists => '书单';

  @override
  String get navMine => '我的';

  @override
  String get navLibraries => '库管理';

  @override
  String get navPlugins => '插件管理';

  @override
  String get navLogs => '系统日志';

  @override
  String get navUsers => '用户管理';

  @override
  String get navDownloads => '下载';

  @override
  String get navOfflineMode => '离线模式';

  @override
  String get navReturnLogin => '返回登录';

  @override
  String get navLogout => '退出登录';

  @override
  String get navNoAdminEntry => '没有后台入口';

  @override
  String get navMainMenuInBottom => '主菜单已在底部导航中。';

  @override
  String get startupConnecting => '正在连接服务器';

  @override
  String get startupResolving => '正在检测局域网和广域网访问地址';

  @override
  String get startupRestoring => '正在恢复登录并同步服务器数据';

  @override
  String get startupCancelAndChooseServer => '取消并选择服务器';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get connectionFailedMessage => '连接服务器失败或登录已过期';

  @override
  String get settingsTitle => '个性化设置';

  @override
  String get settingsSubtitle => '定制您的听书体验';

  @override
  String get settingsAccount => '账号信息';

  @override
  String get settingsAccountUpdated => '更新成功';

  @override
  String get settingsUsername => '用户名';

  @override
  String get settingsPassword => '修改密码 (留空则不修改)';

  @override
  String get settingsNewPassword => '新密码';

  @override
  String get settingsUpdateAccount => '更新账号信息';

  @override
  String settingsAccountUpdateFailed(String error) {
    return '账号更新失败: $error';
  }

  @override
  String get settingsAppearance => '外观展示';

  @override
  String get settingsLight => '浅色模式';

  @override
  String get settingsDark => '深色模式';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageDescription => '界面语言会同步到当前账号，也会保存在本机。';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsHomeLayout => '首页调整';

  @override
  String get settingsHomeHero => '顶部推荐';

  @override
  String get settingsHomeHeroDescription => '展示继续收听和可点击切换的大封面 Hero';

  @override
  String get settingsHomeStats => '听书数据';

  @override
  String get settingsHomeStatsDescription => '展示最近已听、收藏、书单和当前播放';

  @override
  String get settingsHomeRecommended => '为你推荐';

  @override
  String get settingsHomeRecommendedDescription => '展示收藏、最近收听和最近上新的综合推荐';

  @override
  String get settingsHomeRecent => '最近收听';

  @override
  String get settingsHomeRecentDescription => '展示首页内的最近收听卡片';

  @override
  String get settingsHomeRecentlyAdded => '最近上新';

  @override
  String get settingsHomeRecentlyAddedDescription => '展示最新加入馆藏的作品列表';

  @override
  String get settingsHomeCollections => '书单与系列';

  @override
  String get settingsHomeCollectionsDescription => '展示我的书单和系列入口';

  @override
  String get settingsPlayback => '播放偏好';

  @override
  String get settingsPlaybackSpeed => '默认播放倍速';

  @override
  String get settingsPlaybackSpeedDescription => '所有书籍开始播放时的初始倍速';

  @override
  String get settingsAutoPreload => '自动预加载下一章';

  @override
  String get settingsAutoPreloadDescription => '播放当前章节时，后台自动缓冲下一章节';

  @override
  String get settingsAutoCache => '服务端自动缓存 (WebDAV)';

  @override
  String get settingsAutoCacheDescription => '播放当前章节时，通知服务器预先缓存下一章节';

  @override
  String get settingsAudioFocus => '与其他应用同时播放';

  @override
  String get settingsAudioFocusDescription => '允许和其他应用声音共存';

  @override
  String get settingsWidget => '外挂组件 (Widget)';

  @override
  String get settingsCustomCss => '自定义 CSS 注入';

  @override
  String get settingsWidgetOnly => '针对 Widget 生效';

  @override
  String get settingsSaveCss => '保存 CSS';

  @override
  String get settingsEmbedCode => '嵌入代码 (Iframe)';

  @override
  String get settingsPrivateEmbed => '免登录 (带 Token)';

  @override
  String get settingsPublicEmbed => '需登录 (公开)';

  @override
  String get settingsLayoutCode => '布局代码参考 (直接复制)';

  @override
  String get settingsFixedBottom => '1. 吸底模式 (Fixed Bottom)';

  @override
  String get settingsFloatingRight => '2. 右下角悬浮 (Floating Right)';

  @override
  String get settingsPrivateEmbedWarningTitle => '注意安全：';

  @override
  String get settingsPrivateEmbedWarning => '此代码包含您的访问凭证。请仅嵌入到您信任的私有页面。';

  @override
  String get settingsPublicEmbedWarningTitle => '公开模式：';

  @override
  String get settingsPublicEmbedWarning => '此代码不包含凭证，适合嵌入博客或公开网站，访客首次使用时需要登录。';

  @override
  String get settingsCopied => '已复制';

  @override
  String get authTagline => '您的私有有声书馆';

  @override
  String get authServers => '服务器';

  @override
  String get authAdd => '添加';

  @override
  String get authOfflineLogin => '离线登录';

  @override
  String get authNoServer => '还没有服务器';

  @override
  String get authNoServerDescription => '第一次添加服务器会保存并直接登录。';

  @override
  String get authAddServer => '添加服务器';

  @override
  String get authEditServer => '编辑服务器';

  @override
  String get authUnnamedServer => '未命名服务器';

  @override
  String get authEdit => '编辑';

  @override
  String get authBack => '返回';

  @override
  String get authWanAddress => '广域网地址';

  @override
  String get authWanHint => '例如: https://reader.example.com';

  @override
  String get authLanAddress => '局域网地址';

  @override
  String get authLanHint => '例如: http://192.168.1.134:3000';

  @override
  String get authRequireAnyServer => '请填写广域网地址或局域网地址';

  @override
  String get authBothAddressHint => '可同时填写两个地址；局域网内优先使用局域网地址。';

  @override
  String get authOneAddressHint => '至少填写一个地址。';

  @override
  String get authUsernameHint => '请输入用户名';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordHint => '请输入密码';

  @override
  String get authSaveAndLogin => '保存并登录';

  @override
  String get authLoginFailed => '登录失败';

  @override
  String get authLoginFailedFallback => '登录失败，请检查服务器、用户名和密码';

  @override
  String authLanPrefix(String url) {
    return '局域网 $url';
  }

  @override
  String authWanPrefix(String url) {
    return '广域网 $url';
  }

  @override
  String get authNoSavedAddress => '未保存地址';

  @override
  String get mineDefaultUser => '听书用户';

  @override
  String get mineIntro => '管理听书记录、收藏、书单和个人偏好。';

  @override
  String get mineUsernameRequired => '用户名不能为空';

  @override
  String mineUpdateFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String get mineAccountUpdated => '已更新';

  @override
  String get mineChangePassword => '修改密码';

  @override
  String get minePasswordUnchangedHint => '留空则不修改';

  @override
  String get mineSaving => '保存中';

  @override
  String get mineSave => '保存';

  @override
  String get mineRecent => '最近';

  @override
  String get mineFavorites => '收藏';

  @override
  String get minePlaylists => '书单';

  @override
  String get mineBookUnit => '本';

  @override
  String get minePlaylistUnit => '个';

  @override
  String get mineMyContent => '我的内容';

  @override
  String get mineHistoryTitle => '我的历史';

  @override
  String mineHistoryDescription(int books, int chapters, int minutes) {
    return '最近听过 $books 本 / $chapters 章，约 $minutes 分钟';
  }

  @override
  String get mineHistoryEmptyDescription => '查看图文收听记录';

  @override
  String get mineFavoritesTitle => '我的收藏';

  @override
  String mineFavoritesDescription(int count) {
    return '收藏夹里有 $count 部作品';
  }

  @override
  String get mineDownloadsTitle => '我的下载';

  @override
  String mineDownloadsDescription(int count) {
    return '已下载 $count 个音频';
  }

  @override
  String get mineSettingsManagement => '设置与管理';

  @override
  String get minePersonalizationDescription => '外观展示与播放偏好';

  @override
  String get mineNotificationTitle => '通知与事件';

  @override
  String get mineNotificationDescription => '配置 Webhook 监听登录、播放、入库和删除';

  @override
  String get mineStatisticsTitle => '数据统计';

  @override
  String get mineStatisticsDescription => '用户使用情况与馆藏报表';

  @override
  String get mineAboutTitle => '关于 Ting Reader';

  @override
  String get mineCopyright => '©2026 Ting Reader. 保留所有权利。';

  @override
  String get downloadsNoTasksTitle => '暂无下载任务';

  @override
  String get downloadsNoTasksMessage => '播放界面或书籍详情中加入下载后，会在这里管理本地离线文件。';

  @override
  String get downloadsSettingsTitle => '下载设置';

  @override
  String get downloadsConcurrent => '同时下载';

  @override
  String downloadsTaskCount(int count) {
    return '$count 个任务';
  }

  @override
  String get downloadsCacheLocation => '缓存位置';

  @override
  String get downloadsChooseCacheLocation => '选择下载缓存位置';

  @override
  String get downloadsChooseFolder => '选择文件夹';

  @override
  String get downloadsUseDefaultLocation => '使用默认位置';

  @override
  String get downloadsCacheHint =>
      '新下载的音频、封面和元数据会写入该位置；已下载章节仍保留原文件路径，可继续播放或删除。';

  @override
  String downloadsSaveSettingsFailed(String error) {
    return '保存下载设置失败：$error';
  }

  @override
  String get downloadsClearTitle => '清空下载管理';

  @override
  String get downloadsClearMessage => '确定要删除所有下载任务和本地离线文件吗？不会影响服务端文件。';

  @override
  String get downloadsClearAction => '清空';

  @override
  String get downloadsDeleteAction => '删除';

  @override
  String get downloadsDeleteTaskTitle => '删除下载任务';

  @override
  String downloadsDeleteTaskMessage(String chapter) {
    return '确定要删除“$chapter”的下载任务吗？未完成的临时文件也会删除。';
  }

  @override
  String get downloadsDeleteBookTitle => '删除整本下载';

  @override
  String downloadsDeleteBookMessage(String title) {
    return '确定要删除《$title》的本地离线文件吗？';
  }

  @override
  String get downloadsDeleteChapterTitle => '删除下载章节';

  @override
  String get downloadsDeleteChapterMessage => '确定要删除这个本地离线文件吗？';

  @override
  String get downloadsDeleteChaptersTitle => '批量删除章节';

  @override
  String downloadsDeleteChaptersMessage(int count) {
    return '确定要删除选中的 $count 个本地离线文件吗？不会影响服务端文件。';
  }

  @override
  String get downloadsTitle => '我的下载';

  @override
  String get downloadsSubtitleEmpty => '管理此设备上的下载任务和本地离线文件';

  @override
  String downloadsSubtitle(int downloaded, String size, int maxConcurrent) {
    return '已下载 $downloaded 章 · $size · 并发 $maxConcurrent';
  }

  @override
  String get downloadsSettingsAction => '设置';

  @override
  String get downloadsDownloadedStatus => '已下载';

  @override
  String get downloadsRunningStatus => '下载中';

  @override
  String get downloadsQueuedStatus => '排队';

  @override
  String get downloadsPausedStatus => '暂停';

  @override
  String get downloadsFailedStatus => '失败';

  @override
  String get downloadsTasksTitle => '下载任务';

  @override
  String downloadsDownloadedChapterSize(int count, String size) {
    return '$count 章 · $size';
  }

  @override
  String get downloadsNoChaptersTitle => '暂无下载章节';

  @override
  String get downloadsNoChaptersMessage => '这本书的本地章节已经被删除。';

  @override
  String downloadsDownloadedAudioCount(int count) {
    return '已下载 $count 个音频';
  }

  @override
  String get downloadsDone => '完成';

  @override
  String get downloadsBatchDelete => '批量删除';

  @override
  String get downloadsAscending => '正序';

  @override
  String get downloadsDescending => '逆序';

  @override
  String get downloadsDeleteWholeBook => '删除整本';

  @override
  String get downloadsMainChapters => '正文';

  @override
  String get downloadsExtraChapters => '番外';

  @override
  String downloadsChapterSingle(int index) {
    return '第 $index 章';
  }

  @override
  String downloadsChapterRange(int start, int end) {
    return '第 $start-$end 章';
  }

  @override
  String get downloadsCancelSelect => '取消选择';

  @override
  String get downloadsSelectChapter => '选择章节';

  @override
  String get downloadsDeleteDownload => '删除下载';

  @override
  String get downloadsUnselectAll => '取消全选';

  @override
  String get downloadsSelectPage => '全选本页';

  @override
  String downloadsSelectedChapters(int count) {
    return '已选 $count 章';
  }

  @override
  String get downloadsDeleteSelected => '删除选中';

  @override
  String get downloadsPause => '暂停';

  @override
  String get downloadsResume => '继续';

  @override
  String get downloadsRetry => '重试';

  @override
  String get downloadsStatusQueued => '排队中';

  @override
  String get downloadsStatusDownloading => '下载中';

  @override
  String get downloadsStatusPaused => '已暂停';

  @override
  String get downloadsStatusCompleted => '已下载';

  @override
  String get downloadsStatusFailed => '失败';

  @override
  String get notificationsDeleteWebhookTitle => '删除 Webhook';

  @override
  String notificationsDeleteWebhookMessage(String name) {
    return '确定删除「$name」吗？这不会影响历史事件。';
  }

  @override
  String get notificationsDeleteAction => '删除';

  @override
  String get notificationsTitle => '通知与事件';

  @override
  String get notificationsSubtitle => 'Webhook 监听与事件推送';

  @override
  String notificationsWebhookCount(int count) {
    return '$count 个配置';
  }

  @override
  String get notificationsEnabled => '已开启';

  @override
  String get notificationsDisabled => '已关闭';

  @override
  String get notificationsListeningEvents => '监听事件';

  @override
  String get notificationsWebhookList => 'Webhook 列表';

  @override
  String get notificationsAddWebhook => '添加 Webhook';

  @override
  String get notificationsNoWebhook => '暂无 Webhook';

  @override
  String get notificationsNoWebhookHint => '点击列表右上角添加一个监听配置';

  @override
  String get notificationsEnable => '开启';

  @override
  String get notificationsDisable => '关闭';

  @override
  String get notificationsEdit => '编辑';

  @override
  String get notificationsAddWebhookTitle => '添加 Webhook';

  @override
  String get notificationsEditWebhookTitle => '编辑 Webhook';

  @override
  String notificationsEventCount(int count) {
    return '$count 个事件';
  }

  @override
  String get notificationsClose => '关闭';

  @override
  String get notificationsNameLabel => '配置名称';

  @override
  String get notificationsNameHint => '例如：企业微信通知';

  @override
  String get notificationsValidateRequired => '请填写名称和 Webhook URL';

  @override
  String get notificationsValidateEvents => '请至少选择一个监听事件';

  @override
  String notificationsTestFailed(String error) {
    return '测试发送失败：$error';
  }

  @override
  String get notificationsSelectTemplate => '选择模板';

  @override
  String get notificationsTestSend => '测试发送';

  @override
  String get notificationsCommonTemplates => '常见模板';

  @override
  String get notificationsRequestHeaders => '请求头';

  @override
  String get notificationsAddHeader => '添加请求头';

  @override
  String get notificationsNoHeaders => '未设置请求头';

  @override
  String get notificationsDeleteHeader => '删除请求头';

  @override
  String get notificationsBodyTemplate => 'Body 模板';

  @override
  String notificationsSendSuccess(int status) {
    return '发送成功 · HTTP $status';
  }

  @override
  String notificationsSendFailed(int status) {
    return '发送失败 · HTTP $status';
  }

  @override
  String get notificationsRenderedBody => '实际请求体';

  @override
  String get notificationsEnabledSwitch => '启用';

  @override
  String get notificationsCommon => '常用';

  @override
  String get notificationsSelectAll => '全选';

  @override
  String get notificationsClear => '清空';

  @override
  String get notificationsSearchEvents => '搜索事件';

  @override
  String get notificationsNoMatchedEvents => '没有匹配事件';

  @override
  String get notificationsPresetRawJson => '原始事件 JSON';

  @override
  String get notificationsPresetWecomMarkdown => '企业微信 Markdown';

  @override
  String get notificationsPresetWecomText => '企业微信文本';

  @override
  String get notificationsPresetPlainText => '纯文本';

  @override
  String get commonBack => '返回';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonSaving => '保存中...';

  @override
  String get bookDetailLastListenedChapter => '上次收听章节';

  @override
  String get bookDetailWriteMetadataStarted => '已开始后台写入元数据，请稍候查看任务进度。';

  @override
  String get bookDetailNotFoundTitle => '未找到书籍';

  @override
  String get bookDetailNotFoundMessage => '这本书可能已被删除或您没有访问权限。';

  @override
  String bookDetailNowPlaying(String title) {
    return '正在播放：$title';
  }

  @override
  String bookDetailContinuePlaying(String title) {
    return '继续播放：$title';
  }

  @override
  String get bookDetailPlayNow => '立即播放';

  @override
  String get bookDetailUnknownAuthor => '未知作者';

  @override
  String get bookDetailUnknownNarrator => '未知演播';

  @override
  String bookDetailChapterCount(int count) {
    return '$count 章节';
  }

  @override
  String get bookDetailNoDescription => '暂无简介';

  @override
  String bookDetailSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get bookDetailDeleteBookTitle => '确认删除书籍？';

  @override
  String bookDetailDeleteBookMessage(String title) {
    return '此操作会从书架中移除《$title》，并清除相关播放进度。';
  }

  @override
  String bookDetailDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String bookDetailGenerateFailed(String error) {
    return '生成失败：$error';
  }

  @override
  String get bookDetailRegexGeneratorTitle => '正则生成器';

  @override
  String get bookDetailSampleFilenameLabel => '示例文件名（不含后缀）';

  @override
  String get bookDetailSampleFilenameHint => '例如：书名 第1集 章节名';

  @override
  String get bookDetailExtractChapterNumber => '提取章节号';

  @override
  String get bookDetailExtractChapterNumberHint => '例如：1';

  @override
  String get bookDetailExtractChapterTitle => '提取章节名';

  @override
  String get bookDetailExtractChapterTitleHint => '例如：章节名';

  @override
  String get bookDetailGenerateRule => '生成规则';

  @override
  String get bookDetailGeneratedRegex => '生成正则';

  @override
  String get bookDetailExtractIndex => '提取序号';

  @override
  String get bookDetailExtractTitle => '提取标题';

  @override
  String get bookDetailNoMatch => '未匹配';

  @override
  String get bookDetailUseThisRule => '使用此规则';

  @override
  String get bookDetailTitleField => '书名';

  @override
  String get bookDetailAuthorField => '作者';

  @override
  String get bookDetailNarratorField => '演播者';

  @override
  String get bookDetailTagsField => '标签（逗号分隔）';

  @override
  String get bookDetailGenreField => '流派';

  @override
  String get bookDetailYearField => '年份';

  @override
  String get bookDetailYearHint => '例如: 2024';

  @override
  String get bookDetailChapterRegexRule => '章节正则清洗规则';

  @override
  String get bookDetailChapterRegexHelp => '用于从文件名提取章节号和标题。修改后需重新扫描生效。';

  @override
  String get bookDetailAutoGenerate => '自动生成';

  @override
  String get bookDetailCoverUrlField => '封面 URL';

  @override
  String get bookDetailSkipIntroField => '跳过片头（秒）';

  @override
  String get bookDetailSkipOutroField => '跳过片尾（秒）';

  @override
  String get bookDetailEditMetadataTitle => '编辑书籍元数据';

  @override
  String get bookDetailDescriptionField => '简介';

  @override
  String get bookDetailWriteFile => '写入文件';

  @override
  String get bookDetailSaveChanges => '保存更改';

  @override
  String get bookDetailLoadingChapterManager => '加载章节管理...';

  @override
  String get bookDetailGenerating => '生成中...';

  @override
  String get bookDetailLoading => '正在加载...';
}
