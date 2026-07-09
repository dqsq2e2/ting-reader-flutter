import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';

class DeleteBookConfirmation {
  const DeleteBookConfirmation({required this.deleteSourceFiles});

  final bool deleteSourceFiles;
}

Future<DeleteBookConfirmation?> showDeleteBookConfirmationDialog(
  BuildContext context, {
  required List<Book> books,
}) {
  if (books.isEmpty) return Future.value(null);
  return showDialog<DeleteBookConfirmation>(
    context: context,
    builder: (dialogContext) {
      var deleteSourceFiles = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final localCount =
              books.where((book) => book.libraryType == 'local').length;
          final canDeleteSourceFiles = localCount > 0;
          final bulk = books.length > 1;
          final message = bulk
              ? context.localeText(
                  '此操作会从书架中移除选中的 ${books.length} 本书，并清除相关播放进度。',
                  'Remove ${books.length} selected books from the bookshelf and clear playback progress.',
                )
              : context.l10n.bookDetailDeleteBookMessage(books.first.title);
          final sourceSubtitle = localCount == books.length
              ? context.localeText(
                  '会删除书籍目录内的音频、封面和元数据文件，无法恢复。',
                  'Deletes audio, cover, and metadata files in the book folder. This cannot be undone.',
                )
              : context.localeText(
                  '仅会删除其中 $localCount 本本地书籍的源文件，无法恢复。',
                  'Only local source files for $localCount selected books will be deleted. This cannot be undone.',
                );

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xffef4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xffef4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.bookDetailDeleteBookTitle)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message),
                  if (canDeleteSourceFiles) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setDialogState(
                        () => deleteSourceFiles = !deleteSourceFiles,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? AppColors.slate800.withValues(alpha: 0.55)
                              : AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: deleteSourceFiles
                                ? const Color(0xffef4444)
                                    .withValues(alpha: 0.45)
                                : context.faintBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: deleteSourceFiles,
                              activeColor: const Color(0xffef4444),
                              onChanged: (value) => setDialogState(
                                () => deleteSourceFiles = value ?? false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.localeText(
                                      '同时删除本地源文件',
                                      'Delete local source files too',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sourceSubtitle,
                                    style: TextStyle(
                                      color: context.mutedText,
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  DeleteBookConfirmation(
                    deleteSourceFiles:
                        canDeleteSourceFiles && deleteSourceFiles,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffef4444),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.l10n.commonDelete),
              ),
            ],
          );
        },
      );
    },
  );
}
