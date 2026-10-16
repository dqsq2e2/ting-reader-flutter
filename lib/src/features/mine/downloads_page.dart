import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/state/download_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/application_time_zone.dart';
import '../../core/utils/chapter_sort.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/common/media_widgets.dart';

part 'downloaded_book_chapters.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  String? _selectedGroupKey;

  @override
  Widget build(BuildContext context) {
    final onBackValue = widget.onBack;
    final downloads = AppScope.downloadOf(context);

    return AnimatedBuilder(
      animation: downloads,
      builder: (context, _) {
        final groups = <String, List<LocalDownload>>{};
        for (final item in downloads.downloads) {
          groups.putIfAbsent(item.bookGroupKey, () => []).add(item);
        }
        final entries = groups.entries.toList()
          ..sort((a, b) => _downloadBookTitle(context, a.value.first.bookTitle)
              .compareTo(_downloadBookTitle(context, b.value.first.bookTitle)));
        final hasAnything =
            downloads.downloads.isNotEmpty || downloads.activeTasks.isNotEmpty;

        if (_selectedGroupKey != null) {
          final selectedItems = groups[_selectedGroupKey] ?? const [];
          return _DownloadedBookChaptersView(
            items: selectedItems,
            onBack: () => setState(() => _selectedGroupKey = null),
            onDeleteBook: selectedItems.isEmpty
                ? null
                : () async {
                    await _deleteBook(
                      context,
                      selectedItems.first.bookGroupKey,
                      _downloadBookTitle(
                          context, selectedItems.first.bookTitle),
                    );
                    if (mounted) setState(() => _selectedGroupKey = null);
                  },
            onDeleteChapter: (id) => _deleteChapter(context, id),
            onDeleteChapters: (items) => _deleteChapters(context, items),
            onPlay: (item) => _playDownload(context, selectedItems, item),
          );
        }

        return PageListView(
          children: [
            if (onBackValue != null) ...[
              AppBackButton(onPressed: onBackValue),
              const SizedBox(height: 20),
            ],
            _DownloadsHeader(
              downloadedCount: downloads.downloads.length,
              totalSize: downloads.totalSize,
              runningCount: downloads.runningCount,
              queuedCount: downloads.queuedCount,
              pausedCount: downloads.pausedCount,
              failedCount: downloads.failedCount,
              maxConcurrentDownloads: downloads.maxConcurrentDownloads,
              hasItems: hasAnything,
              onOpenSettings: () => _openDownloadSettings(context),
              onClearAll: () => _clearAll(context),
            ),
            if (downloads.activeTasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ActiveTasks(
                tasks: downloads.activeTasks,
                onPause: downloads.pauseTask,
                onResume: downloads.resumeTask,
                onRetry: downloads.retryTask,
                onDelete: (task) => _deleteTask(context, task),
              ),
            ],
            if (downloads.downloads.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DownloadedBookCards(
                entries: entries,
                onOpen: (groupKey) =>
                    setState(() => _selectedGroupKey = groupKey),
              ),
            ] else if (!hasAnything) ...[
              const SizedBox(height: 24),
              EmptyState(
                icon: Icons.download_done_rounded,
                title: context.l10n.downloadsNoTasksTitle,
                message: context.l10n.downloadsNoTasksMessage,
              ),
            ],
            const SafeBottomSpacer(),
          ],
        );
      },
    );
  }

  Future<void> _openDownloadSettings(BuildContext context) async {
    final downloads = AppScope.downloadOf(context);
    var maxConcurrentDownloads = downloads.maxConcurrentDownloads;
    String? cacheDirectory = downloads.customCacheDirectory;
    final result = await showDialog<_DownloadSettingsResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.l10n.downloadsSettingsTitle),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: maxConcurrentDownloads,
                  decoration: InputDecoration(
                    labelText: context.l10n.downloadsConcurrent,
                  ),
                  items: [
                    for (var i = 1; i <= 6; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(context.l10n.downloadsTaskCount(i)),
                      ),
                  ],
                  onChanged: (next) {
                    if (next != null) {
                      setState(() => maxConcurrentDownloads = next);
                    }
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.downloadsCacheLocation,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate800.withValues(alpha: 0.3)
                        : AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.faintBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cacheDirectory == null
                            ? Icons.folder_special_outlined
                            : Icons.folder_rounded,
                        size: 20,
                        color: AppColors.primary600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cacheDirectory ?? downloads.cacheDirectoryPath ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked =
                            await FilePicker.platform.getDirectoryPath(
                          dialogTitle:
                              context.l10n.downloadsChooseCacheLocation,
                          initialDirectory:
                              cacheDirectory ?? downloads.cacheDirectoryPath,
                        );
                        if (picked == null || !dialogContext.mounted) return;
                        setState(() => cacheDirectory = picked);
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(context.l10n.downloadsChooseFolder),
                    ),
                    TextButton.icon(
                      onPressed: cacheDirectory == null
                          ? null
                          : () => setState(() => cacheDirectory = null),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(context.l10n.downloadsUseDefaultLocation),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.downloadsCacheHint,
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _DownloadSettingsResult(
                  maxConcurrentDownloads: maxConcurrentDownloads,
                  cacheDirectory: cacheDirectory,
                ),
              ),
              child: Text(context.l10n.mineSave),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await downloads.setMaxConcurrentDownloads(result.maxConcurrentDownloads);
      await downloads.setCacheDirectory(result.cacheDirectory);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .downloadsSaveSettingsFailed(ApiError.messageFor(error))),
        ),
      );
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: context.l10n.downloadsClearTitle,
      message: context.l10n.downloadsClearMessage,
      action: context.l10n.downloadsClearAction,
    );
    if (!ok || !context.mounted) return;
    await AppScope.downloadOf(context).clearAll();
  }

  Future<void> _deleteTask(BuildContext context, DownloadTask task) async {
    final ok = await _confirm(
      context,
      title: context.l10n.downloadsDeleteTaskTitle,
      message: context.l10n.downloadsDeleteTaskMessage(
        _downloadChapterTitle(context, task.chapterTitle),
      ),
      action: context.l10n.downloadsDeleteAction,
    );
    if (!ok || !context.mounted) return;
    await AppScope.downloadOf(context).deleteTask(task.storageKey);
  }

  Future<void> _deleteBook(
    BuildContext context,
    String bookId,
    String title,
  ) async {
    final ok = await _confirm(
      context,
      title: context.l10n.downloadsDeleteBookTitle,
      message: context.l10n.downloadsDeleteBookMessage(title),
      action: context.l10n.downloadsDeleteAction,
    );
    if (!ok || !context.mounted) return;
    await AppScope.downloadOf(context).deleteBook(bookId);
  }

  Future<void> _deleteChapter(BuildContext context, String chapterId) async {
    final ok = await _confirm(
      context,
      title: context.l10n.downloadsDeleteChapterTitle,
      message: context.l10n.downloadsDeleteChapterMessage,
      action: context.l10n.downloadsDeleteAction,
    );
    if (!ok || !context.mounted) return;
    await AppScope.downloadOf(context).deleteChapter(chapterId);
  }

  Future<void> _deleteChapters(
    BuildContext context,
    List<LocalDownload> items,
  ) async {
    final ids = items.map((item) => item.storageKey).toSet().toList();
    if (ids.isEmpty) return;
    final ok = await _confirm(
      context,
      title: context.l10n.downloadsDeleteChaptersTitle,
      message: context.l10n.downloadsDeleteChaptersMessage(ids.length),
      action: context.l10n.downloadsDeleteAction,
    );
    if (!ok || !context.mounted) return;
    final downloads = AppScope.downloadOf(context);
    for (final id in ids) {
      await downloads.deleteChapter(id);
    }
  }

  Future<void> _playDownload(
    BuildContext context,
    List<LocalDownload> group,
    LocalDownload item,
  ) async {
    final ordered = [...group]..sort(
        (a, b) => compareChapterOrder(
          a.isExtra,
          a.chapterIndex,
          a.chapterId,
          b.isExtra,
          b.chapterIndex,
          b.chapterId,
        ),
      );
    final book = item.toBook(fallbackMetadata: group.first.bookMetadata);
    final chapters = ordered.map((download) => download.chapter).toList();
    final chapter = chapters.firstWhere(
      (chapter) => chapter.id == item.chapterId,
      orElse: () => chapters.first,
    );
    await AppScope.playerOf(context).playChapter(book, chapters, chapter);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

String _downloadBookTitle(BuildContext context, String? title) {
  final trimmed = title?.trim() ?? '';
  return trimmed.isNotEmpty
      ? trimmed
      : context.localeText('未知书籍', 'Unknown Book');
}

String _downloadChapterTitle(BuildContext context, String? title) {
  final trimmed = title?.trim() ?? '';
  return trimmed.isNotEmpty
      ? trimmed
      : context.localeText('未知章节', 'Unknown Chapter');
}

class _DownloadsHeader extends StatelessWidget {
  const _DownloadsHeader({
    required this.downloadedCount,
    required this.totalSize,
    required this.runningCount,
    required this.queuedCount,
    required this.pausedCount,
    required this.failedCount,
    required this.maxConcurrentDownloads,
    required this.hasItems,
    required this.onOpenSettings,
    required this.onClearAll,
  });

  final int downloadedCount;
  final int totalSize;
  final int runningCount;
  final int queuedCount;
  final int pausedCount;
  final int failedCount;
  final int maxConcurrentDownloads;
  final bool hasItems;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final activeCount = runningCount + queuedCount + pausedCount + failedCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final l10n = context.l10n;
        final title = HeaderText(
          icon: Icons.download_rounded,
          title: l10n.downloadsTitle,
          subtitle: downloadedCount == 0 && activeCount == 0
              ? l10n.downloadsSubtitleEmpty
              : l10n.downloadsSubtitle(
                  downloadedCount,
                  formatBytes(totalSize),
                  maxConcurrentDownloads,
                ),
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(l10n.downloadsSettingsAction),
            ),
            TextButton.icon(
              onPressed: hasItems ? onClearAll : null,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(l10n.downloadsClearAction),
            ),
          ],
        );
        final statItems = [
          if (downloadedCount > 0)
            _StatPill(
              icon: Icons.download_done_rounded,
              label: l10n.downloadsDownloadedStatus,
              value: downloadedCount,
              color: AppColors.primary600,
            ),
          if (runningCount > 0)
            _StatPill(
              icon: Icons.downloading_rounded,
              label: l10n.downloadsRunningStatus,
              value: runningCount,
              color: AppColors.primary600,
            ),
          if (queuedCount > 0)
            _StatPill(
              icon: Icons.schedule_rounded,
              label: l10n.downloadsQueuedStatus,
              value: queuedCount,
              color: AppColors.slate600,
            ),
          if (pausedCount > 0)
            _StatPill(
              icon: Icons.pause_circle_outline_rounded,
              label: l10n.downloadsPausedStatus,
              value: pausedCount,
              color: Colors.orange,
            ),
          if (failedCount > 0)
            _StatPill(
              icon: Icons.error_outline_rounded,
              label: l10n.downloadsFailedStatus,
              value: failedCount,
              color: Colors.red,
            ),
        ];
        final stats = statItems.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statItems,
              );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (stats != null) ...[
                const SizedBox(height: 14),
                stats,
              ],
              const SizedBox(height: 12),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                actions,
              ],
            ),
            if (stats != null) ...[
              const SizedBox(height: 14),
              stats,
            ],
          ],
        );
      },
    );
  }
}

class _DownloadSettingsResult {
  const _DownloadSettingsResult({
    required this.maxConcurrentDownloads,
    required this.cacheDirectory,
  });

  final int maxConcurrentDownloads;
  final String? cacheDirectory;
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.16 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              color: context.isDark ? AppColors.slate100 : AppColors.slate700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTasks extends StatelessWidget {
  const _ActiveTasks({
    required this.tasks,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onDelete,
  });

  final List<DownloadTask> tasks;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onRetry;
  final ValueChanged<DownloadTask> onDelete;

  @override
  Widget build(BuildContext context) {
    return TingCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.downloadsTasksTitle,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Text(
                context.l10n.downloadsTaskCount(tasks.length),
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < tasks.length; i++) ...[
            _ActiveTaskRow(
              task: tasks[i],
              onPause: () => onPause(tasks[i].storageKey),
              onResume: () => onResume(tasks[i].storageKey),
              onRetry: () => onRetry(tasks[i].storageKey),
              onDelete: () => onDelete(tasks[i]),
            ),
            if (i != tasks.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ActiveTaskRow extends StatelessWidget {
  const _ActiveTaskRow({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = task.status.downloadColor;
    final value = task.progress.clamp(0.0, 1.0);
    final percent = (value * 100).round();
    final sizeText = task.totalBytes > 0
        ? '${formatBytes(task.receivedBytes)} / ${formatBytes(task.totalBytes)}'
        : formatBytes(task.receivedBytes);
    final error = task.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate800.withValues(alpha: 0.28)
            : AppColors.slate50.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(task.status.downloadIcon(), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _downloadBookTitle(context, task.bookTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _downloadChapterTitle(context, task.chapterTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(status: task.status, percent: percent),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: task.status == DownloadStatus.downloading &&
                      task.totalBytes <= 0
                  ? null
                  : value,
              minHeight: 5,
              color: color,
              backgroundColor:
                  context.isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  error == null || error.isEmpty
                      ? sizeText
                      : '$sizeText · ${_compactError(error)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.status == DownloadStatus.failed
                        ? Colors.red
                        : context.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 2,
                children: [
                  if (task.status == DownloadStatus.downloading ||
                      task.status == DownloadStatus.queued)
                    IconButton(
                      tooltip: context.l10n.downloadsPause,
                      visualDensity: VisualDensity.compact,
                      onPressed: onPause,
                      icon: const Icon(Icons.pause_circle_outline_rounded),
                    ),
                  if (task.status == DownloadStatus.paused)
                    IconButton(
                      tooltip: context.l10n.downloadsResume,
                      visualDensity: VisualDensity.compact,
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  if (task.status == DownloadStatus.failed)
                    IconButton(
                      tooltip: context.l10n.downloadsRetry,
                      visualDensity: VisualDensity.compact,
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  IconButton(
                    tooltip: context.l10n.downloadsDeleteTaskTitle,
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.percent});

  final DownloadStatus status;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = status.downloadColor;
    final text = status == DownloadStatus.downloading
        ? '$percent%'
        : _downloadStatusLabel(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DownloadedBookCards extends StatelessWidget {
  const _DownloadedBookCards({
    required this.entries,
    required this.onOpen,
  });

  final List<MapEntry<String, List<LocalDownload>>> entries;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _DownloadedBookCard(
                items: entries[i].value,
                compact: compact,
                onTap: () => onOpen(entries[i].key),
              ),
              if (i != entries.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _DownloadedBookCard extends StatelessWidget {
  const _DownloadedBookCard({
    required this.items,
    required this.compact,
    required this.onTap,
  });

  final List<LocalDownload> items;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    final first = sorted.first;
    final size = sorted.fold<int>(0, (sum, item) => sum + item.fileSize);
    final appState = AppScope.appOf(context);
    final coverShape = coverShapeFromAppSettings(appState.settings);
    final localCover = first.localCoverPath;
    final cover = localCover != null && localCover.isNotEmpty
        ? localCover
        : appState.offlineMode
            ? ''
            : coverUrl(
                appState,
                url: first.coverUrl,
                libraryId: first.libraryId,
                bookId: first.bookId,
              );
    final coverWidth = compact
        ? (coverShape == CoverShape.square ? 74.0 : 58.0)
        : (coverShape == CoverShape.square ? 86.0 : 68.0);

    return TingCard(
      radius: 16,
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: coverWidth,
              child: AspectRatio(
                aspectRatio: coverAspectRatio(coverShape),
                child: CoverImage(url: cover, radius: 8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _downloadBookTitle(context, first.bookTitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 16 : 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.downloadsDownloadedChapterSize(
                      sorted.length,
                      formatBytes(size),
                    ),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: context.tertiaryText,
            ),
          ],
        ),
      ),
    );
  }
}

String _downloadStatusLabel(BuildContext context, DownloadStatus status) {
  return switch (status) {
    DownloadStatus.queued => context.l10n.downloadsStatusQueued,
    DownloadStatus.downloading => context.l10n.downloadsStatusDownloading,
    DownloadStatus.paused => context.l10n.downloadsStatusPaused,
    DownloadStatus.completed => context.l10n.downloadsStatusCompleted,
    DownloadStatus.failed => context.l10n.downloadsStatusFailed,
  };
}

String _compactError(String value) {
  final line = value.split('\n').first.trim();
  if (line.length <= 60) return line;
  return '${line.substring(0, 60)}...';
}

String _formatLocalTime(BuildContext context, DateTime time) {
  final local = toApplicationTimeZone(
    time,
    AppScope.appOf(context).applicationTimeZone,
  );
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
