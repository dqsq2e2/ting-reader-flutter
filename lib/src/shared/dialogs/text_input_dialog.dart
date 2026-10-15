import 'package:flutter/material.dart';

import '../../core/utils/locale.dart';

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String action,
  String initialValue = '',
  String? hint,
  int? maxLength,
  int maxLines = 1,
  TextInputType? keyboardType,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: title,
        action: action,
        initialValue: initialValue,
        hint: hint,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.action,
    required this.initialValue,
    this.hint,
    this.maxLength,
    required this.maxLines,
    this.keyboardType,
  });

  final String title;
  final String action;
  final String initialValue;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: widget.maxLines == 1
              ? (value) => Navigator.pop(context, value)
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(widget.action),
          ),
        ],
      );
}
