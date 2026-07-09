part of '../book_detail_page.dart';

class _ChapterEditResult {
  const _ChapterEditResult({
    required this.title,
    required this.chapterIndex,
    required this.isExtra,
  });

  final String title;
  final int chapterIndex;
  final bool isExtra;
}

class _ChapterEditSheet extends StatefulWidget {
  const _ChapterEditSheet({
    required this.chapter,
    required this.libraryName,
    required this.displayPath,
  });

  final Chapter chapter;
  final String libraryName;
  final String displayPath;

  @override
  State<_ChapterEditSheet> createState() => _ChapterEditSheetState();
}

class _ChapterEditSheetState extends State<_ChapterEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _indexController;
  late bool _isExtra;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chapter.title);
    _indexController =
        TextEditingController(text: widget.chapter.chapterIndex.toString());
    _isExtra = widget.chapter.isExtra;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _indexController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final index = int.tryParse(_indexController.text.trim());
    if (title.isEmpty || index == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.localeText(
                '请填写标题和有效序号', 'Enter a title and valid index'))),
      );
      return;
    }
    Navigator.pop(
      context,
      _ChapterEditResult(
        title: title,
        chapterIndex: index,
        isExtra: _isExtra,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.localeText('编辑章节', 'Edit Chapter'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.localeText('关闭', 'Close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.localeText('标题', 'Title'),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _indexController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.localeText('序号', 'Index'),
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                _ChapterEditTypeSwitch(
                  isExtra: _isExtra,
                  onChanged: (value) => setState(() => _isExtra = value),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        context.isDark ? AppColors.slate900 : AppColors.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.faintBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.localeText('文件来源', 'File Source'),
                        style: TextStyle(
                          color: context.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ChapterEditMetaRow(
                        icon: Icons.storage_rounded,
                        label: context.localeText('存储库', 'Library'),
                        value: widget.libraryName,
                      ),
                      const SizedBox(height: 8),
                      _ChapterEditMetaRow(
                        icon: Icons.folder_rounded,
                        label: context.localeText('存储位置', 'Location'),
                        value: widget.displayPath.isEmpty
                            ? context.localeText('未识别', 'Unknown')
                            : widget.displayPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: context.localeText('保存此章节', 'Save Chapter'),
                        icon: Icons.save_rounded,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterEditTypeSwitch extends StatelessWidget {
  const _ChapterEditTypeSwitch({
    required this.isExtra,
    required this.onChanged,
  });

  final bool isExtra;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChapterEditTypeItem(
              label: context.localeText('正文', 'Main'),
              selected: !isExtra,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ChapterEditTypeItem(
              label: context.localeText('番外', 'Extra'),
              selected: isExtra,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterEditTypeItem extends StatelessWidget {
  const _ChapterEditTypeItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary600 : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : context.secondaryText,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterEditMetaRow extends StatelessWidget {
  const _ChapterEditMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.tertiaryText),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
