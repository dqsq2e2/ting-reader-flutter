part of 'admin_users_page.dart';

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.isDark ? AppColors.slate800 : AppColors.slate50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.faintBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
      ),
    );
  }
}

class _LibraryPermissionBox extends StatelessWidget {
  const _LibraryPermissionBox({
    required this.libraries,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<Library> libraries;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        border: Border.all(color: context.faintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: libraries.isEmpty
          ? Text(
              context.localeText('暂无库可分配，请先添加库',
                  'No libraries available. Add a library first.'),
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: 12,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  for (final library in libraries)
                    CheckboxListTile(
                      value: selectedIds.contains(library.id),
                      onChanged: (value) =>
                          onChanged(library.id, value ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary600,
                      title: Text(
                        localizedLibraryName(context, library),
                        style: TextStyle(
                          color: context.isDark
                              ? AppColors.slate300
                              : AppColors.slate700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BookPermissionSearch extends StatelessWidget {
  const _BookPermissionSearch({
    required this.controller,
    required this.searching,
    required this.bookResults,
    required this.seriesResults,
    required this.onChanged,
    required this.onBookTap,
    required this.onSeriesTap,
  });

  final TextEditingController controller;
  final bool searching;
  final List<Book> bookResults;
  final List<Series> seriesResults;
  final ValueChanged<String> onChanged;
  final ValueChanged<Book> onBookTap;
  final ValueChanged<Series> onSeriesTap;

  @override
  Widget build(BuildContext context) {
    final hasResults = bookResults.isNotEmpty || seriesResults.isNotEmpty;
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: context.localeText(
                '输入书名或系列名搜索...', 'Search books or series...'),
            hintStyle: TextStyle(
              color: context.tertiaryText,
            ),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: context.isDark ? AppColors.slate800 : AppColors.slate50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary500, width: 2),
            ),
          ),
        ),
        if (hasResults)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.faintBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isDark ? 0.18 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (seriesResults.isNotEmpty) ...[
                    _SearchSectionHeader(context.localeText('系列', 'Series')),
                    for (final series in seriesResults)
                      _SearchResultRow(
                        title: localizedSeriesTitle(context, series),
                        subtitle: context.localeText(
                            '共 ${series.books.length} 本书',
                            '${series.books.length} books'),
                        onTap: () => onSeriesTap(series),
                      ),
                  ],
                  if (bookResults.isNotEmpty) ...[
                    _SearchSectionHeader(context.localeText('书籍', 'Books')),
                    for (final book in bookResults)
                      _SearchResultRow(
                        title: localizedBookTitle(context, book),
                        onTap: () => onBookTap(book),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.isDark
          ? AppColors.slate800.withValues(alpha: 0.55)
          : AppColors.slate50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Text(
        label,
        style: TextStyle(
          color: context.tertiaryText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.add_rounded,
                size: 18, color: AppColors.primary600),
          ],
        ),
      ),
    );
  }
}

class _SelectedBookChips extends StatelessWidget {
  const _SelectedBookChips({
    required this.books,
    required this.onRemove,
  });

  final List<Book> books;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final book in books)
          Container(
            padding:
                const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    localizedBookTitle(context, book),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                InkWell(
                  onTap: () => onRemove(book.id),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

EdgeInsets _userPageHorizontalInset(BuildContext context) {
  return EdgeInsets.symmetric(
    horizontal: MediaQuery.sizeOf(context).width >= 768 ? 8 : 0,
  );
}

String _shortUserId(String id, {bool dotted = true}) {
  if (id.length <= 8) return id;
  return dotted ? '${id.substring(0, 8)}...' : id.substring(0, 8);
}

String _formatUserDate(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return context.localeText('从未', 'Never');
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  if (context.isEnglishLocale) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year} $hour:$minute';
  }
  return '${date.year}年${date.month}月${date.day}日 $hour:$minute';
}
