// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Ting Reader';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonSaved => 'Saved';

  @override
  String commonSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get commonRetryConnection => 'Retry connection';

  @override
  String get navMainMenu => 'Main Menu';

  @override
  String get navAdmin => 'Admin';

  @override
  String get navHome => 'Home';

  @override
  String get navBookshelf => 'Bookshelf';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navMine => 'Mine';

  @override
  String get navLibraries => 'Libraries';

  @override
  String get navPlugins => 'Plugins';

  @override
  String get navLogs => 'System Logs';

  @override
  String get navUsers => 'Users';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navOfflineMode => 'Offline Mode';

  @override
  String get navReturnLogin => 'Return to Login';

  @override
  String get navLogout => 'Log out';

  @override
  String get navNoAdminEntry => 'No admin entry';

  @override
  String get navMainMenuInBottom =>
      'The main menu is in the bottom navigation.';

  @override
  String get startupConnecting => 'Connecting to server';

  @override
  String get startupResolving => 'Checking LAN and WAN access addresses';

  @override
  String get startupRestoring => 'Restoring login and syncing server data';

  @override
  String get startupCancelAndChooseServer => 'Cancel and choose server';

  @override
  String get connectionFailed => 'Connection Failed';

  @override
  String get connectionFailedMessage =>
      'Failed to connect to the server or your login has expired';

  @override
  String get settingsTitle => 'Personalization';

  @override
  String get settingsSubtitle => 'Customize your listening experience';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountUpdated => 'Updated';

  @override
  String get settingsUsername => 'Username';

  @override
  String get settingsPassword => 'Change password (leave blank to keep)';

  @override
  String get settingsNewPassword => 'New password';

  @override
  String get settingsUpdateAccount => 'Update Account';

  @override
  String settingsAccountUpdateFailed(String error) {
    return 'Account update failed: $error';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDescription =>
      'The interface language syncs to your account and is also saved locally.';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsHomeLayout => 'Home Layout';

  @override
  String get settingsHomeHero => 'Hero Recommendation';

  @override
  String get settingsHomeHeroDescription =>
      'Show continue listening and a large switchable cover hero';

  @override
  String get settingsHomeStats => 'Listening Stats';

  @override
  String get settingsHomeStatsDescription =>
      'Show recent listening, favorites, playlists, and current playback';

  @override
  String get settingsHomeRecommended => 'Recommended';

  @override
  String get settingsHomeRecommendedDescription =>
      'Show a mixed feed from favorites, recent listening, and new additions';

  @override
  String get settingsHomeRecent => 'Recently Listened';

  @override
  String get settingsHomeRecentDescription =>
      'Show recent listening cards on the home page';

  @override
  String get settingsHomeRecentlyAdded => 'Recently Added';

  @override
  String get settingsHomeRecentlyAddedDescription =>
      'Show the newest works added to the library';

  @override
  String get settingsHomeCollections => 'Playlists & Series';

  @override
  String get settingsHomeCollectionsDescription =>
      'Show entries for playlists and series';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsPlaybackSpeed => 'Default Playback Speed';

  @override
  String get settingsPlaybackSpeedDescription =>
      'Initial speed when any book starts playing';

  @override
  String get settingsAutoPreload => 'Preload Next Chapter';

  @override
  String get settingsAutoPreloadDescription =>
      'Buffer the next chapter in the background while playing';

  @override
  String get settingsAutoCache => 'Server Auto Cache (WebDAV)';

  @override
  String get settingsAutoCacheDescription =>
      'Ask the server to cache the next chapter while playing';

  @override
  String get settingsAudioFocus => 'Play Alongside Other Apps';

  @override
  String get settingsAudioFocusDescription =>
      'Allow audio to coexist with other apps';

  @override
  String get settingsWidget => 'Widget';

  @override
  String get settingsCustomCss => 'Custom CSS Injection';

  @override
  String get settingsWidgetOnly => 'Applies to Widget only';

  @override
  String get settingsSaveCss => 'Save CSS';

  @override
  String get settingsEmbedCode => 'Embed Code (Iframe)';

  @override
  String get settingsPrivateEmbed => 'Token Access';

  @override
  String get settingsPublicEmbed => 'Public Login';

  @override
  String get settingsLayoutCode => 'Layout Code Examples';

  @override
  String get settingsFixedBottom => '1. Fixed Bottom';

  @override
  String get settingsFloatingRight => '2. Floating Right';

  @override
  String get settingsPrivateEmbedWarningTitle => 'Security note: ';

  @override
  String get settingsPrivateEmbedWarning =>
      'This code includes your access credential. Only embed it on trusted private pages.';

  @override
  String get settingsPublicEmbedWarningTitle => 'Public mode: ';

  @override
  String get settingsPublicEmbedWarning =>
      'This code does not include credentials. It is suitable for blogs or public sites; visitors need to log in on first use.';

  @override
  String get settingsCopied => 'Copied';

  @override
  String get authTagline => 'Your private audiobook library';

  @override
  String get authServers => 'Servers';

  @override
  String get authAdd => 'Add';

  @override
  String get authOfflineLogin => 'Offline Login';

  @override
  String get authNoServer => 'No servers yet';

  @override
  String get authNoServerDescription =>
      'Add a server once to save it and sign in directly.';

  @override
  String get authAddServer => 'Add Server';

  @override
  String get authEditServer => 'Edit Server';

  @override
  String get authUnnamedServer => 'Unnamed Server';

  @override
  String get authEdit => 'Edit';

  @override
  String get authBack => 'Back';

  @override
  String get authWanAddress => 'WAN Address';

  @override
  String get authWanHint => 'e.g. https://reader.example.com';

  @override
  String get authLanAddress => 'LAN Address';

  @override
  String get authLanHint => 'e.g. http://192.168.1.134:3000';

  @override
  String get authRequireAnyServer => 'Enter a WAN address or LAN address';

  @override
  String get authBothAddressHint =>
      'You can fill both addresses; LAN is preferred while on the local network.';

  @override
  String get authOneAddressHint => 'Enter at least one address.';

  @override
  String get authUsernameHint => 'Enter username';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'Enter password';

  @override
  String get authSaveAndLogin => 'Save and Log In';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authLoginFailedFallback =>
      'Login failed. Check the server, username, and password.';

  @override
  String authLanPrefix(String url) {
    return 'LAN $url';
  }

  @override
  String authWanPrefix(String url) {
    return 'WAN $url';
  }

  @override
  String get authNoSavedAddress => 'No saved address';

  @override
  String get mineDefaultUser => 'Listener';

  @override
  String get mineIntro =>
      'Manage listening history, favorites, playlists, and personal preferences.';

  @override
  String get mineUsernameRequired => 'Username cannot be empty';

  @override
  String mineUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get mineAccountUpdated => 'Updated';

  @override
  String get mineChangePassword => 'Change Password';

  @override
  String get minePasswordUnchangedHint =>
      'Leave blank to keep current password';

  @override
  String get mineSaving => 'Saving';

  @override
  String get mineSave => 'Save';

  @override
  String get mineRecent => 'Recent';

  @override
  String get mineFavorites => 'Favorites';

  @override
  String get minePlaylists => 'Playlists';

  @override
  String get mineBookUnit => 'books';

  @override
  String get minePlaylistUnit => 'items';

  @override
  String get mineMyContent => 'My Content';

  @override
  String get mineHistoryTitle => 'History';

  @override
  String mineHistoryDescription(int books, int chapters, int minutes) {
    return 'Recently listened to $books books / $chapters chapters, about $minutes min';
  }

  @override
  String get mineHistoryEmptyDescription =>
      'View listening history with covers';

  @override
  String get mineFavoritesTitle => 'Favorites';

  @override
  String mineFavoritesDescription(int count) {
    return '$count works in favorites';
  }

  @override
  String get mineDownloadsTitle => 'Downloads';

  @override
  String mineDownloadsDescription(int count) {
    return '$count downloaded audio files';
  }

  @override
  String get mineSettingsManagement => 'Settings & Admin';

  @override
  String get minePersonalizationDescription =>
      'Appearance and playback preferences';

  @override
  String get mineNotificationTitle => 'Notifications & Events';

  @override
  String get mineNotificationDescription =>
      'Configure webhooks for login, playback, library import, and deletion';

  @override
  String get mineStatisticsTitle => 'Statistics';

  @override
  String get mineStatisticsDescription => 'Usage and library reports';

  @override
  String get mineAboutTitle => 'About Ting Reader';

  @override
  String get mineCopyright => '©2026 Ting Reader. All rights reserved.';

  @override
  String get downloadsNoTasksTitle => 'No downloads yet';

  @override
  String get downloadsNoTasksMessage =>
      'Add downloads from the player or book details, then manage local offline files here.';

  @override
  String get downloadsSettingsTitle => 'Download Settings';

  @override
  String get downloadsConcurrent => 'Concurrent downloads';

  @override
  String downloadsTaskCount(int count) {
    return '$count tasks';
  }

  @override
  String get downloadsCacheLocation => 'Cache Location';

  @override
  String get downloadsChooseCacheLocation => 'Choose download cache location';

  @override
  String get downloadsChooseFolder => 'Choose Folder';

  @override
  String get downloadsUseDefaultLocation => 'Use Default Location';

  @override
  String get downloadsCacheHint =>
      'New audio, covers, and metadata will be written here. Existing downloaded chapters keep their current file paths and can still be played or deleted.';

  @override
  String downloadsSaveSettingsFailed(String error) {
    return 'Failed to save download settings: $error';
  }

  @override
  String get downloadsClearTitle => 'Clear Downloads';

  @override
  String get downloadsClearMessage =>
      'Delete all download tasks and local offline files? Server files will not be affected.';

  @override
  String get downloadsClearAction => 'Clear';

  @override
  String get downloadsDeleteAction => 'Delete';

  @override
  String get downloadsDeleteTaskTitle => 'Delete Download Task';

  @override
  String downloadsDeleteTaskMessage(String chapter) {
    return 'Delete the download task for \"$chapter\"? Unfinished temporary files will also be removed.';
  }

  @override
  String get downloadsDeleteBookTitle => 'Delete Book Download';

  @override
  String downloadsDeleteBookMessage(String title) {
    return 'Delete local offline files for \"$title\"?';
  }

  @override
  String get downloadsDeleteChapterTitle => 'Delete Downloaded Chapter';

  @override
  String get downloadsDeleteChapterMessage => 'Delete this local offline file?';

  @override
  String get downloadsDeleteChaptersTitle => 'Delete Chapters';

  @override
  String downloadsDeleteChaptersMessage(int count) {
    return 'Delete the selected $count local offline files? Server files will not be affected.';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsSubtitleEmpty =>
      'Manage download tasks and local offline files on this device';

  @override
  String downloadsSubtitle(int downloaded, String size, int maxConcurrent) {
    return '$downloaded chapters downloaded · $size · concurrency $maxConcurrent';
  }

  @override
  String get downloadsSettingsAction => 'Settings';

  @override
  String get downloadsDownloadedStatus => 'Downloaded';

  @override
  String get downloadsRunningStatus => 'Downloading';

  @override
  String get downloadsQueuedStatus => 'Queued';

  @override
  String get downloadsPausedStatus => 'Paused';

  @override
  String get downloadsFailedStatus => 'Failed';

  @override
  String get downloadsTasksTitle => 'Download Tasks';

  @override
  String downloadsDownloadedChapterSize(int count, String size) {
    return '$count chapters · $size';
  }

  @override
  String get downloadsNoChaptersTitle => 'No downloaded chapters';

  @override
  String get downloadsNoChaptersMessage =>
      'The local chapters for this book have been deleted.';

  @override
  String downloadsDownloadedAudioCount(int count) {
    return '$count audio files downloaded';
  }

  @override
  String get downloadsDone => 'Done';

  @override
  String get downloadsBatchDelete => 'Batch Delete';

  @override
  String get downloadsAscending => 'Ascending';

  @override
  String get downloadsDescending => 'Descending';

  @override
  String get downloadsDeleteWholeBook => 'Delete Book';

  @override
  String get downloadsMainChapters => 'Main';

  @override
  String get downloadsExtraChapters => 'Extras';

  @override
  String downloadsChapterSingle(int index) {
    return 'Chapter $index';
  }

  @override
  String downloadsChapterRange(int start, int end) {
    return 'Ch. $start-$end';
  }

  @override
  String get downloadsCancelSelect => 'Cancel selection';

  @override
  String get downloadsSelectChapter => 'Select chapter';

  @override
  String get downloadsDeleteDownload => 'Delete download';

  @override
  String get downloadsUnselectAll => 'Unselect All';

  @override
  String get downloadsSelectPage => 'Select Page';

  @override
  String downloadsSelectedChapters(int count) {
    return '$count selected';
  }

  @override
  String get downloadsDeleteSelected => 'Delete Selected';

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Resume';

  @override
  String get downloadsRetry => 'Retry';

  @override
  String get downloadsStatusQueued => 'Queued';

  @override
  String get downloadsStatusDownloading => 'Downloading';

  @override
  String get downloadsStatusPaused => 'Paused';

  @override
  String get downloadsStatusCompleted => 'Downloaded';

  @override
  String get downloadsStatusFailed => 'Failed';

  @override
  String get notificationsDeleteWebhookTitle => 'Delete Webhook';

  @override
  String notificationsDeleteWebhookMessage(String name) {
    return 'Delete \"$name\"? Historical events will not be affected.';
  }

  @override
  String get notificationsDeleteAction => 'Delete';

  @override
  String get notificationsTitle => 'Notifications & Events';

  @override
  String get notificationsSubtitle => 'Webhook listeners and event delivery';

  @override
  String notificationsWebhookCount(int count) {
    return '$count configurations';
  }

  @override
  String get notificationsEnabled => 'Enabled';

  @override
  String get notificationsDisabled => 'Disabled';

  @override
  String get notificationsListeningEvents => 'Events';

  @override
  String get notificationsWebhookList => 'Webhooks';

  @override
  String get notificationsAddWebhook => 'Add Webhook';

  @override
  String get notificationsNoWebhook => 'No Webhooks';

  @override
  String get notificationsNoWebhookHint =>
      'Add a listener from the top-right of the list';

  @override
  String get notificationsEnable => 'Enable';

  @override
  String get notificationsDisable => 'Disable';

  @override
  String get notificationsEdit => 'Edit';

  @override
  String get notificationsAddWebhookTitle => 'Add Webhook';

  @override
  String get notificationsEditWebhookTitle => 'Edit Webhook';

  @override
  String notificationsEventCount(int count) {
    return '$count events';
  }

  @override
  String get notificationsClose => 'Close';

  @override
  String get notificationsNameLabel => 'Name';

  @override
  String get notificationsNameHint => 'e.g. WeCom notification';

  @override
  String get notificationsValidateRequired => 'Enter a name and Webhook URL';

  @override
  String get notificationsValidateEvents => 'Select at least one event';

  @override
  String notificationsTestFailed(String error) {
    return 'Test send failed: $error';
  }

  @override
  String get notificationsSelectTemplate => 'Choose Template';

  @override
  String get notificationsTestSend => 'Test Send';

  @override
  String get notificationsCommonTemplates => 'Common Templates';

  @override
  String get notificationsRequestHeaders => 'Request Headers';

  @override
  String get notificationsAddHeader => 'Add Header';

  @override
  String get notificationsNoHeaders => 'No headers configured';

  @override
  String get notificationsDeleteHeader => 'Delete Header';

  @override
  String get notificationsBodyTemplate => 'Body Template';

  @override
  String notificationsSendSuccess(int status) {
    return 'Sent successfully · HTTP $status';
  }

  @override
  String notificationsSendFailed(int status) {
    return 'Send failed · HTTP $status';
  }

  @override
  String get notificationsRenderedBody => 'Rendered Request Body';

  @override
  String get notificationsEnabledSwitch => 'Enabled';

  @override
  String get notificationsCommon => 'Common';

  @override
  String get notificationsSelectAll => 'Select All';

  @override
  String get notificationsClear => 'Clear';

  @override
  String get notificationsSearchEvents => 'Search events';

  @override
  String get notificationsNoMatchedEvents => 'No matching events';

  @override
  String get notificationsPresetRawJson => 'Raw Event JSON';

  @override
  String get notificationsPresetWecomMarkdown => 'WeCom Markdown';

  @override
  String get notificationsPresetWecomText => 'WeCom Text';

  @override
  String get notificationsPresetPlainText => 'Plain Text';

  @override
  String get commonBack => 'Back';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSaving => 'Saving...';

  @override
  String get bookDetailLastListenedChapter => 'Last chapter';

  @override
  String get bookDetailWriteMetadataStarted =>
      'Metadata write started. Check task progress later.';

  @override
  String get bookDetailNotFoundTitle => 'Book not found';

  @override
  String get bookDetailNotFoundMessage =>
      'This book may have been removed or you may not have access.';

  @override
  String bookDetailNowPlaying(String title) {
    return 'Playing: $title';
  }

  @override
  String bookDetailContinuePlaying(String title) {
    return 'Continue: $title';
  }

  @override
  String get bookDetailPlayNow => 'Play';

  @override
  String get bookDetailUnknownAuthor => 'Unknown author';

  @override
  String get bookDetailUnknownNarrator => 'Unknown narrator';

  @override
  String bookDetailChapterCount(int count) {
    return '$count chapters';
  }

  @override
  String get bookDetailNoDescription => 'No description';

  @override
  String bookDetailSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get bookDetailDeleteBookTitle => 'Delete book?';

  @override
  String bookDetailDeleteBookMessage(String title) {
    return 'Remove \"$title\" from the bookshelf and clear playback progress.';
  }

  @override
  String bookDetailDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String bookDetailGenerateFailed(String error) {
    return 'Generate failed: $error';
  }

  @override
  String get bookDetailRegexGeneratorTitle => 'Regex Generator';

  @override
  String get bookDetailSampleFilenameLabel => 'Sample filename';

  @override
  String get bookDetailSampleFilenameHint =>
      'e.g. Book Title Episode 1 Chapter Name';

  @override
  String get bookDetailExtractChapterNumber => 'Chapter number';

  @override
  String get bookDetailExtractChapterNumberHint => 'e.g. 1';

  @override
  String get bookDetailExtractChapterTitle => 'Chapter title';

  @override
  String get bookDetailExtractChapterTitleHint => 'e.g. Chapter Name';

  @override
  String get bookDetailGenerateRule => 'Generate';

  @override
  String get bookDetailGeneratedRegex => 'Generated regex';

  @override
  String get bookDetailExtractIndex => 'Index';

  @override
  String get bookDetailExtractTitle => 'Title';

  @override
  String get bookDetailNoMatch => 'No match';

  @override
  String get bookDetailUseThisRule => 'Use rule';

  @override
  String get bookDetailTitleField => 'Title';

  @override
  String get bookDetailAuthorField => 'Author';

  @override
  String get bookDetailNarratorField => 'Narrator';

  @override
  String get bookDetailTagsField => 'Tags (comma separated)';

  @override
  String get bookDetailGenreField => 'Genre';

  @override
  String get bookDetailYearField => 'Year';

  @override
  String get bookDetailYearHint => 'e.g. 2024';

  @override
  String get bookDetailChapterRegexRule => 'Chapter regex';

  @override
  String get bookDetailChapterRegexHelp =>
      'Extract chapter number and title from filenames. Rescan after editing.';

  @override
  String get bookDetailAutoGenerate => 'Generate';

  @override
  String get bookDetailCoverUrlField => 'Cover URL';

  @override
  String get bookDetailSkipIntroField => 'Skip intro (sec)';

  @override
  String get bookDetailSkipOutroField => 'Skip outro (sec)';

  @override
  String get bookDetailEditMetadataTitle => 'Edit book metadata';

  @override
  String get bookDetailDescriptionField => 'Description';

  @override
  String get bookDetailWriteFile => 'Write';

  @override
  String get bookDetailSaveChanges => 'Save changes';

  @override
  String get bookDetailLoadingChapterManager => 'Loading chapters...';

  @override
  String get bookDetailGenerating => 'Generating...';

  @override
  String get bookDetailLoading => 'Loading...';
}
