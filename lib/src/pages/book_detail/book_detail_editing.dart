part of 'book_detail_page.dart';

class _EditBookDialogResult {
  const _EditBookDialogResult.saved(this.book) : deleted = false;
  const _EditBookDialogResult.deleted()
      : book = null,
        deleted = true;

  final Book? book;
  final bool deleted;
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
