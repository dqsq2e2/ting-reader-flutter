import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Ting Reader'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get commonCopy;

  /// No description provided for @commonSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get commonSaved;

  /// No description provided for @commonSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String commonSaveFailed(String error);

  /// No description provided for @commonRetryConnection.
  ///
  /// In zh, this message translates to:
  /// **'重试连接'**
  String get commonRetryConnection;

  /// No description provided for @navMainMenu.
  ///
  /// In zh, this message translates to:
  /// **'主菜单'**
  String get navMainMenu;

  /// No description provided for @navAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理后台'**
  String get navAdmin;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get navBookshelf;

  /// No description provided for @navPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'书单'**
  String get navPlaylists;

  /// No description provided for @navMine.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMine;

  /// No description provided for @navLibraries.
  ///
  /// In zh, this message translates to:
  /// **'库管理'**
  String get navLibraries;

  /// No description provided for @navPlugins.
  ///
  /// In zh, this message translates to:
  /// **'插件管理'**
  String get navPlugins;

  /// No description provided for @navLogs.
  ///
  /// In zh, this message translates to:
  /// **'系统日志'**
  String get navLogs;

  /// No description provided for @navUsers.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get navUsers;

  /// No description provided for @navDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get navDownloads;

  /// No description provided for @navOfflineMode.
  ///
  /// In zh, this message translates to:
  /// **'离线模式'**
  String get navOfflineMode;

  /// No description provided for @navReturnLogin.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get navReturnLogin;

  /// No description provided for @navLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get navLogout;

  /// No description provided for @navNoAdminEntry.
  ///
  /// In zh, this message translates to:
  /// **'没有后台入口'**
  String get navNoAdminEntry;

  /// No description provided for @navMainMenuInBottom.
  ///
  /// In zh, this message translates to:
  /// **'主菜单已在底部导航中。'**
  String get navMainMenuInBottom;

  /// No description provided for @startupConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接服务器'**
  String get startupConnecting;

  /// No description provided for @startupResolving.
  ///
  /// In zh, this message translates to:
  /// **'正在检测局域网和广域网访问地址'**
  String get startupResolving;

  /// No description provided for @startupRestoring.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复登录并同步服务器数据'**
  String get startupRestoring;

  /// No description provided for @startupCancelAndChooseServer.
  ///
  /// In zh, this message translates to:
  /// **'取消并选择服务器'**
  String get startupCancelAndChooseServer;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @connectionFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'连接服务器失败或登录已过期'**
  String get connectionFailedMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'个性化设置'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'定制您的听书体验'**
  String get settingsSubtitle;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号信息'**
  String get settingsAccount;

  /// No description provided for @settingsAccountUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新成功'**
  String get settingsAccountUpdated;

  /// No description provided for @settingsUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get settingsUsername;

  /// No description provided for @settingsPassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码 (留空则不修改)'**
  String get settingsPassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get settingsNewPassword;

  /// No description provided for @settingsUpdateAccount.
  ///
  /// In zh, this message translates to:
  /// **'更新账号信息'**
  String get settingsUpdateAccount;

  /// No description provided for @settingsAccountUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'账号更新失败: {error}'**
  String settingsAccountUpdateFailed(String error);

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观展示'**
  String get settingsAppearance;

  /// No description provided for @settingsLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get settingsDark;

  /// No description provided for @settingsSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsSystem;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In zh, this message translates to:
  /// **'界面语言会同步到当前账号，也会保存在本机。'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsHomeLayout.
  ///
  /// In zh, this message translates to:
  /// **'首页调整'**
  String get settingsHomeLayout;

  /// No description provided for @settingsHomeHero.
  ///
  /// In zh, this message translates to:
  /// **'顶部推荐'**
  String get settingsHomeHero;

  /// No description provided for @settingsHomeHeroDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示继续收听和可点击切换的大封面 Hero'**
  String get settingsHomeHeroDescription;

  /// No description provided for @settingsHomeStats.
  ///
  /// In zh, this message translates to:
  /// **'听书数据'**
  String get settingsHomeStats;

  /// No description provided for @settingsHomeStatsDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示最近已听、收藏、书单和当前播放'**
  String get settingsHomeStatsDescription;

  /// No description provided for @settingsHomeRecommended.
  ///
  /// In zh, this message translates to:
  /// **'为你推荐'**
  String get settingsHomeRecommended;

  /// No description provided for @settingsHomeRecommendedDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示收藏、最近收听和最近上新的综合推荐'**
  String get settingsHomeRecommendedDescription;

  /// No description provided for @settingsHomeRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近收听'**
  String get settingsHomeRecent;

  /// No description provided for @settingsHomeRecentDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示首页内的最近收听卡片'**
  String get settingsHomeRecentDescription;

  /// No description provided for @settingsHomeRecentlyAdded.
  ///
  /// In zh, this message translates to:
  /// **'最近上新'**
  String get settingsHomeRecentlyAdded;

  /// No description provided for @settingsHomeRecentlyAddedDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示最新加入馆藏的作品列表'**
  String get settingsHomeRecentlyAddedDescription;

  /// No description provided for @settingsHomeCollections.
  ///
  /// In zh, this message translates to:
  /// **'书单与系列'**
  String get settingsHomeCollections;

  /// No description provided for @settingsHomeCollectionsDescription.
  ///
  /// In zh, this message translates to:
  /// **'展示我的书单和系列入口'**
  String get settingsHomeCollectionsDescription;

  /// No description provided for @settingsPlayback.
  ///
  /// In zh, this message translates to:
  /// **'播放偏好'**
  String get settingsPlayback;

  /// No description provided for @settingsPlaybackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'默认播放倍速'**
  String get settingsPlaybackSpeed;

  /// No description provided for @settingsPlaybackSpeedDescription.
  ///
  /// In zh, this message translates to:
  /// **'所有书籍开始播放时的初始倍速'**
  String get settingsPlaybackSpeedDescription;

  /// No description provided for @settingsAutoPreload.
  ///
  /// In zh, this message translates to:
  /// **'自动预加载下一章'**
  String get settingsAutoPreload;

  /// No description provided for @settingsAutoPreloadDescription.
  ///
  /// In zh, this message translates to:
  /// **'播放当前章节时，后台自动缓冲下一章节'**
  String get settingsAutoPreloadDescription;

  /// No description provided for @settingsAutoCache.
  ///
  /// In zh, this message translates to:
  /// **'服务端自动缓存 (WebDAV)'**
  String get settingsAutoCache;

  /// No description provided for @settingsAutoCacheDescription.
  ///
  /// In zh, this message translates to:
  /// **'播放当前章节时，通知服务器预先缓存下一章节'**
  String get settingsAutoCacheDescription;

  /// No description provided for @settingsAudioFocus.
  ///
  /// In zh, this message translates to:
  /// **'与其他应用同时播放'**
  String get settingsAudioFocus;

  /// No description provided for @settingsAudioFocusDescription.
  ///
  /// In zh, this message translates to:
  /// **'允许和其他应用声音共存'**
  String get settingsAudioFocusDescription;

  /// No description provided for @settingsWidget.
  ///
  /// In zh, this message translates to:
  /// **'外挂组件 (Widget)'**
  String get settingsWidget;

  /// No description provided for @settingsCustomCss.
  ///
  /// In zh, this message translates to:
  /// **'自定义 CSS 注入'**
  String get settingsCustomCss;

  /// No description provided for @settingsWidgetOnly.
  ///
  /// In zh, this message translates to:
  /// **'针对 Widget 生效'**
  String get settingsWidgetOnly;

  /// No description provided for @settingsSaveCss.
  ///
  /// In zh, this message translates to:
  /// **'保存 CSS'**
  String get settingsSaveCss;

  /// No description provided for @settingsEmbedCode.
  ///
  /// In zh, this message translates to:
  /// **'嵌入代码 (Iframe)'**
  String get settingsEmbedCode;

  /// No description provided for @settingsPrivateEmbed.
  ///
  /// In zh, this message translates to:
  /// **'免登录 (带 Token)'**
  String get settingsPrivateEmbed;

  /// No description provided for @settingsPublicEmbed.
  ///
  /// In zh, this message translates to:
  /// **'需登录 (公开)'**
  String get settingsPublicEmbed;

  /// No description provided for @settingsLayoutCode.
  ///
  /// In zh, this message translates to:
  /// **'布局代码参考 (直接复制)'**
  String get settingsLayoutCode;

  /// No description provided for @settingsFixedBottom.
  ///
  /// In zh, this message translates to:
  /// **'1. 吸底模式 (Fixed Bottom)'**
  String get settingsFixedBottom;

  /// No description provided for @settingsFloatingRight.
  ///
  /// In zh, this message translates to:
  /// **'2. 右下角悬浮 (Floating Right)'**
  String get settingsFloatingRight;

  /// No description provided for @settingsPrivateEmbedWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'注意安全：'**
  String get settingsPrivateEmbedWarningTitle;

  /// No description provided for @settingsPrivateEmbedWarning.
  ///
  /// In zh, this message translates to:
  /// **'此代码包含您的访问凭证。请仅嵌入到您信任的私有页面。'**
  String get settingsPrivateEmbedWarning;

  /// No description provided for @settingsPublicEmbedWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'公开模式：'**
  String get settingsPublicEmbedWarningTitle;

  /// No description provided for @settingsPublicEmbedWarning.
  ///
  /// In zh, this message translates to:
  /// **'此代码不包含凭证，适合嵌入博客或公开网站，访客首次使用时需要登录。'**
  String get settingsPublicEmbedWarning;

  /// No description provided for @settingsCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get settingsCopied;

  /// No description provided for @authTagline.
  ///
  /// In zh, this message translates to:
  /// **'您的私有有声书馆'**
  String get authTagline;

  /// No description provided for @authServers.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get authServers;

  /// No description provided for @authAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get authAdd;

  /// No description provided for @authOfflineLogin.
  ///
  /// In zh, this message translates to:
  /// **'离线登录'**
  String get authOfflineLogin;

  /// No description provided for @authNoServer.
  ///
  /// In zh, this message translates to:
  /// **'还没有服务器'**
  String get authNoServer;

  /// No description provided for @authNoServerDescription.
  ///
  /// In zh, this message translates to:
  /// **'第一次添加服务器会保存并直接登录。'**
  String get authNoServerDescription;

  /// No description provided for @authAddServer.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get authAddServer;

  /// No description provided for @authEditServer.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get authEditServer;

  /// No description provided for @authUnnamedServer.
  ///
  /// In zh, this message translates to:
  /// **'未命名服务器'**
  String get authUnnamedServer;

  /// No description provided for @authEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get authEdit;

  /// No description provided for @authBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get authBack;

  /// No description provided for @authWanAddress.
  ///
  /// In zh, this message translates to:
  /// **'广域网地址'**
  String get authWanAddress;

  /// No description provided for @authWanHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: https://reader.example.com'**
  String get authWanHint;

  /// No description provided for @authLanAddress.
  ///
  /// In zh, this message translates to:
  /// **'局域网地址'**
  String get authLanAddress;

  /// No description provided for @authLanHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: http://192.168.1.134:3000'**
  String get authLanHint;

  /// No description provided for @authRequireAnyServer.
  ///
  /// In zh, this message translates to:
  /// **'请填写广域网地址或局域网地址'**
  String get authRequireAnyServer;

  /// No description provided for @authBothAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'可同时填写两个地址；局域网内优先使用局域网地址。'**
  String get authBothAddressHint;

  /// No description provided for @authOneAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'至少填写一个地址。'**
  String get authOneAddressHint;

  /// No description provided for @authUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get authUsernameHint;

  /// No description provided for @authPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordHint;

  /// No description provided for @authSaveAndLogin.
  ///
  /// In zh, this message translates to:
  /// **'保存并登录'**
  String get authSaveAndLogin;

  /// No description provided for @authLoginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get authLoginFailed;

  /// No description provided for @authLoginFailedFallback.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查服务器、用户名和密码'**
  String get authLoginFailedFallback;

  /// No description provided for @authLanPrefix.
  ///
  /// In zh, this message translates to:
  /// **'局域网 {url}'**
  String authLanPrefix(String url);

  /// No description provided for @authWanPrefix.
  ///
  /// In zh, this message translates to:
  /// **'广域网 {url}'**
  String authWanPrefix(String url);

  /// No description provided for @authNoSavedAddress.
  ///
  /// In zh, this message translates to:
  /// **'未保存地址'**
  String get authNoSavedAddress;

  /// No description provided for @mineDefaultUser.
  ///
  /// In zh, this message translates to:
  /// **'听书用户'**
  String get mineDefaultUser;

  /// No description provided for @mineIntro.
  ///
  /// In zh, this message translates to:
  /// **'管理听书记录、收藏、书单和个人偏好。'**
  String get mineIntro;

  /// No description provided for @mineUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'用户名不能为空'**
  String get mineUsernameRequired;

  /// No description provided for @mineUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败：{error}'**
  String mineUpdateFailed(String error);

  /// No description provided for @mineAccountUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get mineAccountUpdated;

  /// No description provided for @mineChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get mineChangePassword;

  /// No description provided for @minePasswordUnchangedHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则不修改'**
  String get minePasswordUnchangedHint;

  /// No description provided for @mineSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get mineSaving;

  /// No description provided for @mineSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get mineSave;

  /// No description provided for @mineRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get mineRecent;

  /// No description provided for @mineFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get mineFavorites;

  /// No description provided for @minePlaylists.
  ///
  /// In zh, this message translates to:
  /// **'书单'**
  String get minePlaylists;

  /// No description provided for @mineBookUnit.
  ///
  /// In zh, this message translates to:
  /// **'本'**
  String get mineBookUnit;

  /// No description provided for @minePlaylistUnit.
  ///
  /// In zh, this message translates to:
  /// **'个'**
  String get minePlaylistUnit;

  /// No description provided for @mineMyContent.
  ///
  /// In zh, this message translates to:
  /// **'我的内容'**
  String get mineMyContent;

  /// No description provided for @mineHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的历史'**
  String get mineHistoryTitle;

  /// No description provided for @mineHistoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'最近听过 {books} 本 / {chapters} 章，约 {minutes} 分钟'**
  String mineHistoryDescription(int books, int chapters, int minutes);

  /// No description provided for @mineHistoryEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看图文收听记录'**
  String get mineHistoryEmptyDescription;

  /// No description provided for @mineFavoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get mineFavoritesTitle;

  /// No description provided for @mineFavoritesDescription.
  ///
  /// In zh, this message translates to:
  /// **'收藏夹里有 {count} 部作品'**
  String mineFavoritesDescription(int count);

  /// No description provided for @mineDownloadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的下载'**
  String get mineDownloadsTitle;

  /// No description provided for @mineDownloadsDescription.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {count} 个音频'**
  String mineDownloadsDescription(int count);

  /// No description provided for @mineSettingsManagement.
  ///
  /// In zh, this message translates to:
  /// **'设置与管理'**
  String get mineSettingsManagement;

  /// No description provided for @minePersonalizationDescription.
  ///
  /// In zh, this message translates to:
  /// **'外观展示与播放偏好'**
  String get minePersonalizationDescription;

  /// No description provided for @mineNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知与事件'**
  String get mineNotificationTitle;

  /// No description provided for @mineNotificationDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置 Webhook 监听登录、播放、入库和删除'**
  String get mineNotificationDescription;

  /// No description provided for @mineStatisticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据统计'**
  String get mineStatisticsTitle;

  /// No description provided for @mineStatisticsDescription.
  ///
  /// In zh, this message translates to:
  /// **'用户使用情况与馆藏报表'**
  String get mineStatisticsDescription;

  /// No description provided for @mineAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于 Ting Reader'**
  String get mineAboutTitle;

  /// No description provided for @mineCopyright.
  ///
  /// In zh, this message translates to:
  /// **'©2026 Ting Reader. 保留所有权利。'**
  String get mineCopyright;

  /// No description provided for @downloadsNoTasksTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载任务'**
  String get downloadsNoTasksTitle;

  /// No description provided for @downloadsNoTasksMessage.
  ///
  /// In zh, this message translates to:
  /// **'播放界面或书籍详情中加入下载后，会在这里管理本地离线文件。'**
  String get downloadsNoTasksMessage;

  /// No description provided for @downloadsSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载设置'**
  String get downloadsSettingsTitle;

  /// No description provided for @downloadsConcurrent.
  ///
  /// In zh, this message translates to:
  /// **'同时下载'**
  String get downloadsConcurrent;

  /// No description provided for @downloadsTaskCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String downloadsTaskCount(int count);

  /// No description provided for @downloadsCacheLocation.
  ///
  /// In zh, this message translates to:
  /// **'缓存位置'**
  String get downloadsCacheLocation;

  /// No description provided for @downloadsChooseCacheLocation.
  ///
  /// In zh, this message translates to:
  /// **'选择下载缓存位置'**
  String get downloadsChooseCacheLocation;

  /// No description provided for @downloadsChooseFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get downloadsChooseFolder;

  /// No description provided for @downloadsUseDefaultLocation.
  ///
  /// In zh, this message translates to:
  /// **'使用默认位置'**
  String get downloadsUseDefaultLocation;

  /// No description provided for @downloadsCacheHint.
  ///
  /// In zh, this message translates to:
  /// **'新下载的音频、封面和元数据会写入该位置；已下载章节仍保留原文件路径，可继续播放或删除。'**
  String get downloadsCacheHint;

  /// No description provided for @downloadsSaveSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存下载设置失败：{error}'**
  String downloadsSaveSettingsFailed(String error);

  /// No description provided for @downloadsClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空下载管理'**
  String get downloadsClearTitle;

  /// No description provided for @downloadsClearMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除所有下载任务和本地离线文件吗？不会影响服务端文件。'**
  String get downloadsClearMessage;

  /// No description provided for @downloadsClearAction.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get downloadsClearAction;

  /// No description provided for @downloadsDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get downloadsDeleteAction;

  /// No description provided for @downloadsDeleteTaskTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除下载任务'**
  String get downloadsDeleteTaskTitle;

  /// No description provided for @downloadsDeleteTaskMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除“{chapter}”的下载任务吗？未完成的临时文件也会删除。'**
  String downloadsDeleteTaskMessage(String chapter);

  /// No description provided for @downloadsDeleteBookTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除整本下载'**
  String get downloadsDeleteBookTitle;

  /// No description provided for @downloadsDeleteBookMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除《{title}》的本地离线文件吗？'**
  String downloadsDeleteBookMessage(String title);

  /// No description provided for @downloadsDeleteChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除下载章节'**
  String get downloadsDeleteChapterTitle;

  /// No description provided for @downloadsDeleteChapterMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个本地离线文件吗？'**
  String get downloadsDeleteChapterMessage;

  /// No description provided for @downloadsDeleteChaptersTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除章节'**
  String get downloadsDeleteChaptersTitle;

  /// No description provided for @downloadsDeleteChaptersMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个本地离线文件吗？不会影响服务端文件。'**
  String downloadsDeleteChaptersMessage(int count);

  /// No description provided for @downloadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的下载'**
  String get downloadsTitle;

  /// No description provided for @downloadsSubtitleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'管理此设备上的下载任务和本地离线文件'**
  String get downloadsSubtitleEmpty;

  /// No description provided for @downloadsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {downloaded} 章 · {size} · 并发 {maxConcurrent}'**
  String downloadsSubtitle(int downloaded, String size, int maxConcurrent);

  /// No description provided for @downloadsSettingsAction.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get downloadsSettingsAction;

  /// No description provided for @downloadsDownloadedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get downloadsDownloadedStatus;

  /// No description provided for @downloadsRunningStatus.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadsRunningStatus;

  /// No description provided for @downloadsQueuedStatus.
  ///
  /// In zh, this message translates to:
  /// **'排队'**
  String get downloadsQueuedStatus;

  /// No description provided for @downloadsPausedStatus.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get downloadsPausedStatus;

  /// No description provided for @downloadsFailedStatus.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadsFailedStatus;

  /// No description provided for @downloadsTasksTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载任务'**
  String get downloadsTasksTitle;

  /// No description provided for @downloadsDownloadedChapterSize.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章 · {size}'**
  String downloadsDownloadedChapterSize(int count, String size);

  /// No description provided for @downloadsNoChaptersTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载章节'**
  String get downloadsNoChaptersTitle;

  /// No description provided for @downloadsNoChaptersMessage.
  ///
  /// In zh, this message translates to:
  /// **'这本书的本地章节已经被删除。'**
  String get downloadsNoChaptersMessage;

  /// No description provided for @downloadsDownloadedAudioCount.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {count} 个音频'**
  String downloadsDownloadedAudioCount(int count);

  /// No description provided for @downloadsDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get downloadsDone;

  /// No description provided for @downloadsBatchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get downloadsBatchDelete;

  /// No description provided for @downloadsAscending.
  ///
  /// In zh, this message translates to:
  /// **'正序'**
  String get downloadsAscending;

  /// No description provided for @downloadsDescending.
  ///
  /// In zh, this message translates to:
  /// **'逆序'**
  String get downloadsDescending;

  /// No description provided for @downloadsDeleteWholeBook.
  ///
  /// In zh, this message translates to:
  /// **'删除整本'**
  String get downloadsDeleteWholeBook;

  /// No description provided for @downloadsMainChapters.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get downloadsMainChapters;

  /// No description provided for @downloadsExtraChapters.
  ///
  /// In zh, this message translates to:
  /// **'番外'**
  String get downloadsExtraChapters;

  /// No description provided for @downloadsChapterSingle.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 章'**
  String downloadsChapterSingle(int index);

  /// No description provided for @downloadsChapterRange.
  ///
  /// In zh, this message translates to:
  /// **'第 {start}-{end} 章'**
  String downloadsChapterRange(int start, int end);

  /// No description provided for @downloadsCancelSelect.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get downloadsCancelSelect;

  /// No description provided for @downloadsSelectChapter.
  ///
  /// In zh, this message translates to:
  /// **'选择章节'**
  String get downloadsSelectChapter;

  /// No description provided for @downloadsDeleteDownload.
  ///
  /// In zh, this message translates to:
  /// **'删除下载'**
  String get downloadsDeleteDownload;

  /// No description provided for @downloadsUnselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get downloadsUnselectAll;

  /// No description provided for @downloadsSelectPage.
  ///
  /// In zh, this message translates to:
  /// **'全选本页'**
  String get downloadsSelectPage;

  /// No description provided for @downloadsSelectedChapters.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 章'**
  String downloadsSelectedChapters(int count);

  /// No description provided for @downloadsDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除选中'**
  String get downloadsDeleteSelected;

  /// No description provided for @downloadsPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get downloadsPause;

  /// No description provided for @downloadsResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get downloadsResume;

  /// No description provided for @downloadsRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get downloadsRetry;

  /// No description provided for @downloadsStatusQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get downloadsStatusQueued;

  /// No description provided for @downloadsStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadsStatusDownloading;

  /// No description provided for @downloadsStatusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get downloadsStatusPaused;

  /// No description provided for @downloadsStatusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get downloadsStatusCompleted;

  /// No description provided for @downloadsStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadsStatusFailed;

  /// No description provided for @notificationsDeleteWebhookTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 Webhook'**
  String get notificationsDeleteWebhookTitle;

  /// No description provided for @notificationsDeleteWebhookMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？这不会影响历史事件。'**
  String notificationsDeleteWebhookMessage(String name);

  /// No description provided for @notificationsDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get notificationsDeleteAction;

  /// No description provided for @notificationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知与事件'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Webhook 监听与事件推送'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsWebhookCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个配置'**
  String notificationsWebhookCount(int count);

  /// No description provided for @notificationsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get notificationsDisabled;

  /// No description provided for @notificationsListeningEvents.
  ///
  /// In zh, this message translates to:
  /// **'监听事件'**
  String get notificationsListeningEvents;

  /// No description provided for @notificationsWebhookList.
  ///
  /// In zh, this message translates to:
  /// **'Webhook 列表'**
  String get notificationsWebhookList;

  /// No description provided for @notificationsAddWebhook.
  ///
  /// In zh, this message translates to:
  /// **'添加 Webhook'**
  String get notificationsAddWebhook;

  /// No description provided for @notificationsNoWebhook.
  ///
  /// In zh, this message translates to:
  /// **'暂无 Webhook'**
  String get notificationsNoWebhook;

  /// No description provided for @notificationsNoWebhookHint.
  ///
  /// In zh, this message translates to:
  /// **'点击列表右上角添加一个监听配置'**
  String get notificationsNoWebhookHint;

  /// No description provided for @notificationsEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get notificationsEnable;

  /// No description provided for @notificationsDisable.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get notificationsDisable;

  /// No description provided for @notificationsEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get notificationsEdit;

  /// No description provided for @notificationsAddWebhookTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加 Webhook'**
  String get notificationsAddWebhookTitle;

  /// No description provided for @notificationsEditWebhookTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑 Webhook'**
  String get notificationsEditWebhookTitle;

  /// No description provided for @notificationsEventCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个事件'**
  String notificationsEventCount(int count);

  /// No description provided for @notificationsClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get notificationsClose;

  /// No description provided for @notificationsNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置名称'**
  String get notificationsNameLabel;

  /// No description provided for @notificationsNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：企业微信通知'**
  String get notificationsNameHint;

  /// No description provided for @notificationsValidateRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称和 Webhook URL'**
  String get notificationsValidateRequired;

  /// No description provided for @notificationsValidateEvents.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个监听事件'**
  String get notificationsValidateEvents;

  /// No description provided for @notificationsTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试发送失败：{error}'**
  String notificationsTestFailed(String error);

  /// No description provided for @notificationsSelectTemplate.
  ///
  /// In zh, this message translates to:
  /// **'选择模板'**
  String get notificationsSelectTemplate;

  /// No description provided for @notificationsTestSend.
  ///
  /// In zh, this message translates to:
  /// **'测试发送'**
  String get notificationsTestSend;

  /// No description provided for @notificationsCommonTemplates.
  ///
  /// In zh, this message translates to:
  /// **'常见模板'**
  String get notificationsCommonTemplates;

  /// No description provided for @notificationsRequestHeaders.
  ///
  /// In zh, this message translates to:
  /// **'请求头'**
  String get notificationsRequestHeaders;

  /// No description provided for @notificationsAddHeader.
  ///
  /// In zh, this message translates to:
  /// **'添加请求头'**
  String get notificationsAddHeader;

  /// No description provided for @notificationsNoHeaders.
  ///
  /// In zh, this message translates to:
  /// **'未设置请求头'**
  String get notificationsNoHeaders;

  /// No description provided for @notificationsDeleteHeader.
  ///
  /// In zh, this message translates to:
  /// **'删除请求头'**
  String get notificationsDeleteHeader;

  /// No description provided for @notificationsBodyTemplate.
  ///
  /// In zh, this message translates to:
  /// **'Body 模板'**
  String get notificationsBodyTemplate;

  /// No description provided for @notificationsSendSuccess.
  ///
  /// In zh, this message translates to:
  /// **'发送成功 · HTTP {status}'**
  String notificationsSendSuccess(int status);

  /// No description provided for @notificationsSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败 · HTTP {status}'**
  String notificationsSendFailed(int status);

  /// No description provided for @notificationsRenderedBody.
  ///
  /// In zh, this message translates to:
  /// **'实际请求体'**
  String get notificationsRenderedBody;

  /// No description provided for @notificationsEnabledSwitch.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get notificationsEnabledSwitch;

  /// No description provided for @notificationsCommon.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get notificationsCommon;

  /// No description provided for @notificationsSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get notificationsSelectAll;

  /// No description provided for @notificationsClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get notificationsClear;

  /// No description provided for @notificationsSearchEvents.
  ///
  /// In zh, this message translates to:
  /// **'搜索事件'**
  String get notificationsSearchEvents;

  /// No description provided for @notificationsNoMatchedEvents.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配事件'**
  String get notificationsNoMatchedEvents;

  /// No description provided for @notificationsPresetRawJson.
  ///
  /// In zh, this message translates to:
  /// **'原始事件 JSON'**
  String get notificationsPresetRawJson;

  /// No description provided for @notificationsPresetWecomMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'企业微信 Markdown'**
  String get notificationsPresetWecomMarkdown;

  /// No description provided for @notificationsPresetWecomText.
  ///
  /// In zh, this message translates to:
  /// **'企业微信文本'**
  String get notificationsPresetWecomText;

  /// No description provided for @notificationsPresetPlainText.
  ///
  /// In zh, this message translates to:
  /// **'纯文本'**
  String get notificationsPresetPlainText;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get commonLoading;

  /// No description provided for @commonSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get commonSaving;

  /// No description provided for @bookDetailLastListenedChapter.
  ///
  /// In zh, this message translates to:
  /// **'上次收听章节'**
  String get bookDetailLastListenedChapter;

  /// No description provided for @bookDetailWriteMetadataStarted.
  ///
  /// In zh, this message translates to:
  /// **'已开始后台写入元数据，请稍候查看任务进度。'**
  String get bookDetailWriteMetadataStarted;

  /// No description provided for @bookDetailNotFoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'未找到书籍'**
  String get bookDetailNotFoundTitle;

  /// No description provided for @bookDetailNotFoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'这本书可能已被删除或您没有访问权限。'**
  String get bookDetailNotFoundMessage;

  /// No description provided for @bookDetailNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放：{title}'**
  String bookDetailNowPlaying(String title);

  /// No description provided for @bookDetailContinuePlaying.
  ///
  /// In zh, this message translates to:
  /// **'继续播放：{title}'**
  String bookDetailContinuePlaying(String title);

  /// No description provided for @bookDetailPlayNow.
  ///
  /// In zh, this message translates to:
  /// **'立即播放'**
  String get bookDetailPlayNow;

  /// No description provided for @bookDetailUnknownAuthor.
  ///
  /// In zh, this message translates to:
  /// **'未知作者'**
  String get bookDetailUnknownAuthor;

  /// No description provided for @bookDetailUnknownNarrator.
  ///
  /// In zh, this message translates to:
  /// **'未知演播'**
  String get bookDetailUnknownNarrator;

  /// No description provided for @bookDetailChapterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章节'**
  String bookDetailChapterCount(int count);

  /// No description provided for @bookDetailNoDescription.
  ///
  /// In zh, this message translates to:
  /// **'暂无简介'**
  String get bookDetailNoDescription;

  /// No description provided for @bookDetailSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String bookDetailSaveFailed(String error);

  /// No description provided for @bookDetailDeleteBookTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除书籍？'**
  String get bookDetailDeleteBookTitle;

  /// No description provided for @bookDetailDeleteBookMessage.
  ///
  /// In zh, this message translates to:
  /// **'此操作会从书架中移除《{title}》，并清除相关播放进度。'**
  String bookDetailDeleteBookMessage(String title);

  /// No description provided for @bookDetailDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String bookDetailDeleteFailed(String error);

  /// No description provided for @bookDetailGenerateFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败：{error}'**
  String bookDetailGenerateFailed(String error);

  /// No description provided for @bookDetailRegexGeneratorTitle.
  ///
  /// In zh, this message translates to:
  /// **'正则生成器'**
  String get bookDetailRegexGeneratorTitle;

  /// No description provided for @bookDetailSampleFilenameLabel.
  ///
  /// In zh, this message translates to:
  /// **'示例文件名（不含后缀）'**
  String get bookDetailSampleFilenameLabel;

  /// No description provided for @bookDetailSampleFilenameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：书名 第1集 章节名'**
  String get bookDetailSampleFilenameHint;

  /// No description provided for @bookDetailExtractChapterNumber.
  ///
  /// In zh, this message translates to:
  /// **'提取章节号'**
  String get bookDetailExtractChapterNumber;

  /// No description provided for @bookDetailExtractChapterNumberHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：1'**
  String get bookDetailExtractChapterNumberHint;

  /// No description provided for @bookDetailExtractChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'提取章节名'**
  String get bookDetailExtractChapterTitle;

  /// No description provided for @bookDetailExtractChapterTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：章节名'**
  String get bookDetailExtractChapterTitleHint;

  /// No description provided for @bookDetailGenerateRule.
  ///
  /// In zh, this message translates to:
  /// **'生成规则'**
  String get bookDetailGenerateRule;

  /// No description provided for @bookDetailGeneratedRegex.
  ///
  /// In zh, this message translates to:
  /// **'生成正则'**
  String get bookDetailGeneratedRegex;

  /// No description provided for @bookDetailExtractIndex.
  ///
  /// In zh, this message translates to:
  /// **'提取序号'**
  String get bookDetailExtractIndex;

  /// No description provided for @bookDetailExtractTitle.
  ///
  /// In zh, this message translates to:
  /// **'提取标题'**
  String get bookDetailExtractTitle;

  /// No description provided for @bookDetailNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未匹配'**
  String get bookDetailNoMatch;

  /// No description provided for @bookDetailUseThisRule.
  ///
  /// In zh, this message translates to:
  /// **'使用此规则'**
  String get bookDetailUseThisRule;

  /// No description provided for @bookDetailTitleField.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get bookDetailTitleField;

  /// No description provided for @bookDetailAuthorField.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get bookDetailAuthorField;

  /// No description provided for @bookDetailNarratorField.
  ///
  /// In zh, this message translates to:
  /// **'演播者'**
  String get bookDetailNarratorField;

  /// No description provided for @bookDetailTagsField.
  ///
  /// In zh, this message translates to:
  /// **'标签（逗号分隔）'**
  String get bookDetailTagsField;

  /// No description provided for @bookDetailGenreField.
  ///
  /// In zh, this message translates to:
  /// **'流派'**
  String get bookDetailGenreField;

  /// No description provided for @bookDetailYearField.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get bookDetailYearField;

  /// No description provided for @bookDetailYearHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: 2024'**
  String get bookDetailYearHint;

  /// No description provided for @bookDetailChapterRegexRule.
  ///
  /// In zh, this message translates to:
  /// **'章节正则清洗规则'**
  String get bookDetailChapterRegexRule;

  /// No description provided for @bookDetailChapterRegexHelp.
  ///
  /// In zh, this message translates to:
  /// **'用于从文件名提取章节号和标题。修改后需重新扫描生效。'**
  String get bookDetailChapterRegexHelp;

  /// No description provided for @bookDetailAutoGenerate.
  ///
  /// In zh, this message translates to:
  /// **'自动生成'**
  String get bookDetailAutoGenerate;

  /// No description provided for @bookDetailCoverUrlField.
  ///
  /// In zh, this message translates to:
  /// **'封面 URL'**
  String get bookDetailCoverUrlField;

  /// No description provided for @bookDetailSkipIntroField.
  ///
  /// In zh, this message translates to:
  /// **'跳过片头（秒）'**
  String get bookDetailSkipIntroField;

  /// No description provided for @bookDetailSkipOutroField.
  ///
  /// In zh, this message translates to:
  /// **'跳过片尾（秒）'**
  String get bookDetailSkipOutroField;

  /// No description provided for @bookDetailEditMetadataTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑书籍元数据'**
  String get bookDetailEditMetadataTitle;

  /// No description provided for @bookDetailDescriptionField.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get bookDetailDescriptionField;

  /// No description provided for @bookDetailWriteFile.
  ///
  /// In zh, this message translates to:
  /// **'写入文件'**
  String get bookDetailWriteFile;

  /// No description provided for @bookDetailSaveChanges.
  ///
  /// In zh, this message translates to:
  /// **'保存更改'**
  String get bookDetailSaveChanges;

  /// No description provided for @bookDetailLoadingChapterManager.
  ///
  /// In zh, this message translates to:
  /// **'加载章节管理...'**
  String get bookDetailLoadingChapterManager;

  /// No description provided for @bookDetailGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成中...'**
  String get bookDetailGenerating;

  /// No description provided for @bookDetailLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载...'**
  String get bookDetailLoading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
