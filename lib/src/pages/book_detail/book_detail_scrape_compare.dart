part of 'book_detail_page.dart';

class _ScrapeCoverCompare extends StatelessWidget {
  const _ScrapeCoverCompare({
    required this.label,
    required this.value,
    required this.color,
    this.book,
  });

  final String label;
  final Object? value;
  final Color color;
  final Book? book;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final coverShape = coverShapeFromAppSettings(appState.settings);
    final rawUrl = value?.toString().trim() ?? '';
    final resolvedUrl = coverUrl(
      appState,
      url: rawUrl,
      libraryId: book?.libraryId,
      bookId: book?.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate900 : AppColors.slate100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.faintBorder),
          ),
          child: AspectRatio(
            aspectRatio: coverAspectRatio(coverShape),
            child: CoverImage(
              url: resolvedUrl,
              radius: 9,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrapeValueCompare extends StatelessWidget {
  const _ScrapeValueCompare({
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.foregroundColor,
    this.maxLines,
  });

  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;
  final Color foregroundColor;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            maxLines: maxLines,
            overflow:
                maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedScrapeFieldCard extends StatelessWidget {
  const _SelectedScrapeFieldCard({
    required this.field,
    required this.onChanged,
    required this.onRemove,
  });

  final _SelectedScrapeField field;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final definition = _scrapeFieldDefinitions[field.key];
    final editorValue = _scrapeValueForEditor(field.value);
    final isLongText = field.key == 'description' || field.key == 'tags';
    final isBoolean = field.key == 'explicit' || field.key == 'abridged';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                definition?.icon ?? Icons.check_rounded,
                color: context.tertiaryText,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition?.label ?? field.key,
                      style: const TextStyle(
                        color: AppColors.slate950,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${field.sourceName} · ${field.resultTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xffef4444),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (field.key == 'cover_url')
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 560;
                final preview = SizedBox(
                  width: 160,
                  child: AspectRatio(
                    aspectRatio: coverAspectRatio(
                      coverShapeFromAppSettings(
                        AppScope.appOf(context).settings,
                      ),
                    ),
                    child: CoverImage(url: editorValue, radius: 10),
                  ),
                );
                final input = _ScrapeReviewTextField(
                  value: editorValue,
                  label: '封面 URL',
                  onChanged: onChanged,
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(height: 12),
                      input,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(width: 16),
                    Expanded(child: input),
                  ],
                );
              },
            )
          else if (isBoolean)
            _ScrapeReviewBooleanField(
              value: field.value == true,
              onChanged: onChanged,
            )
          else
            _ScrapeReviewTextField(
              value: editorValue,
              label: field.key == 'tags' ? '应用值（逗号分隔）' : '应用值',
              maxLines: isLongText ? (field.key == 'description' ? 6 : 3) : 1,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _ScrapeReviewTextField extends StatefulWidget {
  const _ScrapeReviewTextField({
    required this.value,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String value;
  final String label;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_ScrapeReviewTextField> createState() => _ScrapeReviewTextFieldState();
}

class _ScrapeReviewTextFieldState extends State<_ScrapeReviewTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ScrapeReviewTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.primary500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          style: const TextStyle(
            color: AppColors.slate950,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.isDark
                ? AppColors.primary950.withOpacity(0.25)
                : AppColors.primary50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary600,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrapeReviewBooleanField extends StatelessWidget {
  const _ScrapeReviewBooleanField({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '应用值',
          style: TextStyle(
            color: AppColors.primary500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.primary950.withOpacity(0.25)
                : AppColors.primary50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value ? 'true' : 'false',
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'true', child: Text('是')),
                DropdownMenuItem(value: 'false', child: Text('否')),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}
