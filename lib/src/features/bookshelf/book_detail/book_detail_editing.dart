import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/state/books_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale.dart';
import '../../../core/utils/urls.dart';
import '../../../shared/app_scope.dart';
import '../book_delete_dialog.dart';

part 'book_metadata_fields.dart';

class EditBookDialogResult {
  const EditBookDialogResult.saved(
    this.book, {
    this.reloadGroup = false,
  }) : deleted = false;
  const EditBookDialogResult.deleted()
      : book = null,
        deleted = true,
        reloadGroup = false;

  final Book? book;
  final bool deleted;
  final bool reloadGroup;
}

Future<EditBookDialogResult?> showBookEditorDialog(
    BuildContext context, BookDetailState detail) async {
  Future<void> writeMetadata() async {
    final book = detail.book;
    if (book == null) return;
    try {
      await detail.operations.writeMetadata(book.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bookDetailWriteMetadataStarted)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.bookDetailWriteMetadataFailed(error.toString()),
          ),
        ),
      );
    }
  }

  final book = detail.book;
  if (book == null) return null;
  final title = TextEditingController(text: book.title);
  final author = TextEditingController(text: book.author ?? '');
  final narrator = TextEditingController(text: book.narrator ?? '');
  final tags = TextEditingController(text: book.tags ?? '');
  final genre = TextEditingController(text: book.genre ?? '');
  final year = TextEditingController(text: book.year?.toString() ?? '');
  final cover = TextEditingController(text: book.coverUrl ?? '');
  final skipIntro = TextEditingController(text: book.skipIntro.toString());
  final skipOutro = TextEditingController(text: book.skipOutro.toString());
  final chapterRegex = TextEditingController(text: book.chapterRegex ?? '');
  final description = TextEditingController(text: book.description ?? '');
  final genFilename = TextEditingController();
  final genNum = TextEditingController();
  final genTitle = TextEditingController();
  var selectedGroupOrder = detail.groupsDescending ? 'desc' : 'asc';
  var metadataLocked = book.manualCorrected;
  var metadataLockTouched = false;
  ({String name, Uint8List bytes})? selectedCover;

  final editorRoute = DialogRoute<EditBookDialogResult>(
    context: context,
    builder: (context) {
      var saving = false;
      var deleting = false;
      var generating = false;
      var showRegexGenerator = false;
      var pickingCover = false;
      Map<String, dynamic>? regexResult;
      String? dialogError;

      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            if (saving || pickingCover) return;
            setDialogState(() {
              saving = true;
              dialogError = null;
            });
            try {
              final appState = AppScope.appOf(dialogContext);
              final payload = {
                'title': title.text.trim(),
                'author': author.text.trim(),
                'narrator': narrator.text.trim(),
                'tags': tags.text.trim(),
                'genre': genre.text.trim(),
                'year': int.tryParse(year.text.trim()),
                'cover_url': cover.text.trim(),
                'skip_intro': int.tryParse(skipIntro.text.trim()) ?? 0,
                'skip_outro': int.tryParse(skipOutro.text.trim()) ?? 0,
                'chapter_regex': chapterRegex.text.trim(),
                'description': description.text.trim(),
                'manual_corrected': metadataLockTouched ? metadataLocked : true,
              };

              final groupOrderChanged = selectedGroupOrder !=
                  (detail.groupsDescending ? 'desc' : 'asc');
              final saved = await detail.save(payload,
                  coverBytes: selectedCover?.bytes,
                  coverName: selectedCover?.name,
                  groupOrder: selectedGroupOrder,
                  saveSettings: appState.updateSettings);
              if (selectedCover != null) invalidateBookCover(appState, book.id);
              if (dialogContext.mounted) {
                Navigator.pop(
                  dialogContext,
                  EditBookDialogResult.saved(
                    saved,
                    reloadGroup: groupOrderChanged,
                  ),
                );
              }
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => dialogError =
                  context.l10n.bookDetailSaveFailed(error.toString()));
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          Future<void> pickCover() async {
            if (pickingCover || saving) return;
            setDialogState(() => pickingCover = true);
            try {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                withData: kIsWeb,
              );
              if (!dialogContext.mounted || picked == null) return;
              final file = picked.files.single;
              if (file.size > 10 * 1024 * 1024) {
                if (!dialogContext.mounted) return;
                setDialogState(() => dialogError = context.localeText(
                      '请选择不超过 10 MB 的 JPG、PNG 或 WebP 图片',
                      'Choose a JPG, PNG or WebP image up to 10 MB',
                    ));
                return;
              }
              final path = file.path;
              final bytes = file.bytes ??
                  (path == null ? null : await File(path).readAsBytes());
              if (!dialogContext.mounted) return;
              if (bytes == null ||
                  bytes.isEmpty ||
                  bytes.length > 10 * 1024 * 1024) {
                if (!dialogContext.mounted) return;
                setDialogState(() => dialogError = context.localeText(
                      '无法读取封面图片，或图片超过 10 MB',
                      'The cover could not be read or exceeds 10 MB',
                    ));
                return;
              }
              setDialogState(() {
                selectedCover = (name: file.name, bytes: bytes);
                dialogError = null;
              });
            } catch (error) {
              if (dialogContext.mounted) {
                if (!dialogContext.mounted) return;
                setDialogState(() => dialogError = context.localeText(
                      '无法选择封面：$error',
                      'Could not select a cover: $error',
                    ));
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => pickingCover = false);
              }
            }
          }

          Future<void> deleteBook() async {
            final confirmation = await showDeleteBookConfirmationDialog(
              dialogContext,
              books: [book],
            );
            if (!dialogContext.mounted || confirmation == null || deleting) {
              return;
            }
            setDialogState(() {
              deleting = true;
              dialogError = null;
            });
            try {
              await detail.operations.deleteBooks([book.id],
                  deleteFiles: confirmation.deleteSourceFiles);
              if (dialogContext.mounted) {
                Navigator.pop(
                  dialogContext,
                  const EditBookDialogResult.deleted(),
                );
              }
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => dialogError =
                  context.l10n.bookDetailDeleteFailed(error.toString()));
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => deleting = false);
              }
            }
          }

          Future<void> generateRegex() async {
            if (genFilename.text.trim().isEmpty ||
                genNum.text.trim().isEmpty ||
                genTitle.text.trim().isEmpty ||
                generating) {
              return;
            }
            setDialogState(() {
              generating = true;
              dialogError = null;
            });
            try {
              final result = await detail.operations.generateRegex(
                  genFilename.text.trim(),
                  genNum.text.trim(),
                  genTitle.text.trim());
              if (dialogContext.mounted) {
                setDialogState(() => regexResult = result);
              }
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => dialogError = context.localeText(
                  '生成失败：$error', 'Generation failed: $error'));
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => generating = false);
              }
            }
          }

          final compact = MediaQuery.sizeOf(dialogContext).width < 700;
          final disabled = saving || deleting || pickingCover;

          Widget dialogBody() {
            if (showRegexGenerator) {
              final capturedIndex = regexResult?['captured_index']?.toString();
              final capturedTitle = regexResult?['captured_title']?.toString();
              final generatedRegex = regexResult?['regex']?.toString();
              return Padding(
                padding: EdgeInsets.all(compact ? 20 : 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high_rounded,
                            color: AppColors.primary600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.bookDetailRegexGeneratorTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setDialogState(() {
                            showRegexGenerator = false;
                            regexResult = null;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _EditMetadataField(
                      controller: genFilename,
                      label: context.l10n.bookDetailSampleFilenameLabel,
                      hint: context.l10n.bookDetailSampleFilenameHint,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _EditMetadataField(
                            controller: genNum,
                            label: context.l10n.bookDetailExtractChapterNumber,
                            hint:
                                context.l10n.bookDetailExtractChapterNumberHint,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _EditMetadataField(
                            controller: genTitle,
                            label: context.l10n.bookDetailExtractChapterTitle,
                            hint:
                                context.l10n.bookDetailExtractChapterTitleHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: generating ? null : generateRegex,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        generating
                            ? context.l10n.bookDetailGenerating
                            : context.l10n.bookDetailGenerateRule,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (generatedRegex != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: dialogContext.isDark
                              ? AppColors.slate800.withValues(alpha: 0.5)
                              : AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: dialogContext.faintBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            EditFieldLabel(
                                context.l10n.bookDetailGeneratedRegex),
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: dialogContext.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: dialogContext.faintBorder),
                              ),
                              child: Text(
                                generatedRegex,
                                style: const TextStyle(
                                  color: AppColors.primary600,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _RegexMatchPreview(
                                    label: context.l10n.bookDetailExtractIndex,
                                    value: capturedIndex ??
                                        context.l10n.bookDetailNoMatch,
                                    matched: capturedIndex == genNum.text,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _RegexMatchPreview(
                                    label: context.l10n.bookDetailExtractTitle,
                                    value: capturedTitle ??
                                        context.l10n.bookDetailNoMatch,
                                    matched: capturedTitle == genTitle.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () {
                                chapterRegex.text = generatedRegex;
                                setDialogState(() {
                                  showRegexGenerator = false;
                                  regexResult = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary600,
                                side: const BorderSide(
                                    color: AppColors.primary600, width: 2),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              child: Text(context.l10n.bookDetailUseThisRule),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(compact ? 20 : 30),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 620;
                  final leftColumn = Column(
                    children: [
                      _EditMetadataField(
                          controller: title,
                          label: context.l10n.bookDetailTitleField),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                          controller: author,
                          label: context.l10n.bookDetailAuthorField),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                          controller: narrator,
                          label: context.l10n.bookDetailNarratorField),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                          controller: tags,
                          label: context.l10n.bookDetailTagsField),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                          controller: genre,
                          label: context.l10n.bookDetailGenreField),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                        controller: year,
                        label: context.l10n.bookDetailYearField,
                        hint: context.l10n.bookDetailYearHint,
                        number: true,
                      ),
                      const SizedBox(height: 14),
                      _EditMetadataField(
                        controller: chapterRegex,
                        label: context.l10n.bookDetailChapterRegexRule,
                        mono: true,
                        hint: r'^...(\d+)...(.+)$',
                        helper: context.l10n.bookDetailChapterRegexHelp,
                        trailing: TextButton.icon(
                          onPressed: disabled
                              ? null
                              : () => setDialogState(
                                    () => showRegexGenerator = true,
                                  ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary600,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon:
                              const Icon(Icons.auto_fix_high_rounded, size: 14),
                          label: Text(
                            context.l10n.bookDetailAutoGenerate,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  );
                  final rightColumn = Column(
                    children: [
                      _EditMetadataField(
                        controller: cover,
                        label: context.l10n.bookDetailCoverUrlField,
                        enabled: !saving,
                        onChanged: (_) {
                          if (selectedCover != null) {
                            setDialogState(() => selectedCover = null);
                          }
                        },
                        trailing: TextButton.icon(
                          onPressed:
                              disabled || pickingCover ? null : pickCover,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary600,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.upload_rounded, size: 16),
                          label: Text(
                            context.localeText('上传', 'Upload'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (selectedCover case final coverFile?) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: dialogContext.isDark
                                ? AppColors.slate800
                                : AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  coverFile.bytes,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  cacheWidth: 192,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(coverFile.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                        context.localeText('保存后应用新封面',
                                            'The new cover is applied when saved'),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: dialogContext.mutedText)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: context.localeText(
                                    '取消所选封面', 'Remove selected cover'),
                                onPressed: saving
                                    ? null
                                    : () => setDialogState(
                                        () => selectedCover = null),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _ReadOnlyMetadataField(
                        label: context.localeText('书籍位置', 'Book Location'),
                        value: book.path ?? '',
                        mono: true,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _EditMetadataField(
                              controller: skipIntro,
                              label: context.l10n.bookDetailSkipIntroField,
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _EditMetadataField(
                              controller: skipOutro,
                              label: context.l10n.bookDetailSkipOutroField,
                              number: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ChapterGroupOrderSelector(
                        value: selectedGroupOrder,
                        onChanged: disabled
                            ? null
                            : (value) => setDialogState(
                                  () => selectedGroupOrder = value,
                                ),
                      ),
                    ],
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.bookDetailEditMetadataTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MetadataLockControl(
                        value: metadataLocked,
                        onChanged: disabled
                            ? null
                            : (value) => setDialogState(() {
                                  metadataLocked = value;
                                  metadataLockTouched = true;
                                }),
                      ),
                      const SizedBox(height: 22),
                      if (twoColumns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: leftColumn),
                            const SizedBox(width: 18),
                            Expanded(child: rightColumn),
                          ],
                        )
                      else ...[
                        leftColumn,
                        const SizedBox(height: 14),
                        rightColumn,
                      ],
                      const SizedBox(height: 18),
                      _EditMetadataField(
                        controller: description,
                        label: context.l10n.bookDetailDescriptionField,
                        minLines: 4,
                        maxLines: 6,
                      ),
                    ],
                  );
                },
              ),
            );
          }

          Widget footer() {
            final textStyle = TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
            );
            final deleteButton = TextButton.icon(
              onPressed: disabled ? null : deleteBook,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffef4444),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: compact ? 9 : 12,
                ),
              ),
              icon: deleting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.delete_outline_rounded, size: compact ? 17 : 19),
              label: Text(context.l10n.commonDelete, style: textStyle),
            );
            final writeButton = TextButton.icon(
              onPressed: disabled ? null : writeMetadata,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary600,
                backgroundColor: AppColors.primary50,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 18,
                  vertical: compact ? 9 : 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: Icon(Icons.edit_document, size: compact ? 17 : 19),
              label: Text(context.l10n.bookDetailWriteFile, style: textStyle),
            );
            final cancelButton = TextButton(
              onPressed: disabled ? null : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.mutedText,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 18,
                  vertical: compact ? 9 : 13,
                ),
              ),
              child: Text(context.l10n.commonCancel, style: textStyle),
            );
            final saveButton = ElevatedButton.icon(
              onPressed: disabled ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: AppColors.primary500.withValues(alpha: 0.28),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 22,
                  vertical: compact ? 10 : 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.save_outlined, size: compact ? 17 : 19),
              label: Text(
                saving
                    ? context.l10n.commonSaving
                    : (compact
                        ? context.l10n.commonSave
                        : context.l10n.bookDetailSaveChanges),
                style: textStyle,
              ),
            );
            final actions = Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: compact
                  ? [
                      deleteButton,
                      if (book.libraryType == 'local' ||
                          book.canWriteMetadataFiles)
                        writeButton,
                      cancelButton,
                      saveButton,
                    ]
                  : [
                      if (book.libraryType == 'local' ||
                          book.canWriteMetadataFiles)
                        writeButton,
                      cancelButton,
                      saveButton,
                    ],
            );
            if (compact) {
              return Align(alignment: Alignment.centerRight, child: actions);
            }
            return Row(
              children: [
                deleteButton,
                const Spacer(),
                actions,
              ],
            );
          }

          return PopScope(
            canPop: !disabled,
            child: Dialog(
              insetPadding: EdgeInsets.all(compact ? 8 : 22),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: dialogContext.cardColor,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: dialogContext.isDark ? 0.5 : 0.2),
                        blurRadius: 34,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(child: dialogBody()),
                      ),
                      if (dialogError case final errorText?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Text(
                            errorText,
                            style: const TextStyle(
                              color: Color(0xffef4444),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 30,
                          14,
                          compact ? 18 : 30,
                          compact ? 18 : 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: dialogContext.faintBorder),
                          ),
                        ),
                        child: footer(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  final result = await Navigator.of(context).push(editorRoute);
  // The pop result arrives before the closing animation removes the fields.
  await editorRoute.completed;
  for (final controller in [
    title,
    author,
    narrator,
    tags,
    genre,
    year,
    cover,
    skipIntro,
    skipOutro,
    chapterRegex,
    description,
    genFilename,
    genNum,
    genTitle,
  ]) {
    controller.dispose();
  }

  return result;
}
