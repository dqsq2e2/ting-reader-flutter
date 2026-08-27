part of 'book_detail_page.dart';

class _EditBookDialogResult {
  const _EditBookDialogResult.saved(
    this.book, {
    this.reloadGroup = false,
  }) : deleted = false;
  const _EditBookDialogResult.deleted()
      : book = null,
        deleted = true,
        reloadGroup = false;

  final Book? book;
  final bool deleted;
  final bool reloadGroup;
}

class _EditFieldLabel extends StatelessWidget {
  const _EditFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.slate500,
        fontSize: 12,
      ),
    );
  }
}

class _MetadataLockControl extends StatelessWidget {
  const _MetadataLockControl({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.primary50.withValues(
            alpha: context.isDark ? 0.12 : 0.75,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary500.withValues(
              alpha: context.isDark ? 0.28 : 0.2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                activeColor: AppColors.primary600,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged == null
                    ? null
                    : (next) => onChanged!(next ?? false),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.localeText('锁定元数据', 'Lock metadata'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.localeText(
                      '锁定后，自动同步扫描不会覆盖手动刮削或编辑保存的元数据。',
                      'When locked, automatic scans will not overwrite metadata saved by manual scraping or editing.',
                    ),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMetadataField extends StatelessWidget {
  const _EditMetadataField({
    required this.controller,
    required this.label,
    this.number = false,
    this.mono = false,
    this.hint,
    this.helper,
    this.trailing,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final bool mono;
  final String? hint;
  final String? helper;
  final Widget? trailing;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final input = TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: number
          ? TextInputType.number
          : maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
      style: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontFamily: mono ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _EditFieldLabel(label),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 7),
        input,
        if (helper != null) ...[
          const SizedBox(height: 7),
          Text(
            helper!,
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadOnlyMetadataField extends StatefulWidget {
  const _ReadOnlyMetadataField({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  State<_ReadOnlyMetadataField> createState() => _ReadOnlyMetadataFieldState();
}

class _ReadOnlyMetadataFieldState extends State<_ReadOnlyMetadataField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.value.trim().isEmpty
        ? context.localeText('未识别', 'Unknown')
        : widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditFieldLabel(widget.label),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: context.isDark
                    ? AppColors.slate800.withValues(alpha: 0.62)
                    : AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.faintBorder),
              ),
              child: Text(
                value,
                maxLines: _expanded ? null : 1,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 15,
                  height: 1.35,
                  fontFamily: widget.mono ? 'monospace' : null,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegexMatchPreview extends StatelessWidget {
  const _RegexMatchPreview({
    required this.label,
    required this.value,
    required this.matched,
  });

  final String label;
  final String value;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.tertiaryText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: matched ? const Color(0xff16a34a) : const Color(0xffef4444),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ChapterGroupOrderSelector extends StatelessWidget {
  const _ChapterGroupOrderSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String optionValue, String label) {
      final selected = value == optionValue;
      return Expanded(
        child: TextButton(
          onPressed: onChanged == null ? null : () => onChanged!(optionValue),
          style: TextButton.styleFrom(
            foregroundColor:
                selected ? AppColors.primary600 : context.secondaryText,
            backgroundColor: selected ? context.cardColor : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditFieldLabel(context.localeText('分组展示顺序', 'Chapter Group Order')),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              option('asc', context.localeText('从前往后', 'Ascending')),
              const SizedBox(width: 4),
              option('desc', context.localeText('从后往前', 'Descending')),
            ],
          ),
        ),
      ],
    );
  }
}
