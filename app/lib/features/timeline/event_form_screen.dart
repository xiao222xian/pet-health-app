import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';

class EventFormScreen extends StatefulWidget {
  final String petId;
  const EventFormScreen({super.key, required this.petId});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _type = 'note';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() { _saving = true; });
    try {
      await SupabaseService.client.from('timeline_events').insert({
        'pet_id': widget.petId,
        'type': _type,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        'photo_urls': <String>[],
        'event_date': _date.toIso8601String().substring(0, 10),
      });
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('添加记录'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('类型', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _type,
              onValueChanged: (v) => setState(() { _type = v!; }),
              children: const {
                'note': Text('笔记'),
                'photo': Text('照片'),
                'weight': Text('体重'),
                'medical': Text('医疗'),
              },
            ),
            const SizedBox(height: 16),
            const Text('标题', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _titleController,
              placeholder: '标题',
              padding: const EdgeInsets.all(14),
            ),
            const SizedBox(height: 16),
            const Text('内容（可选）', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _contentController,
              placeholder: '内容（可选）',
              maxLines: 3,
              padding: const EdgeInsets.all(14),
            ),
            const SizedBox(height: 16),
            const Text('日期', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => showCupertinoModalPopup<void>(
                context: context,
                builder: (_) => SizedBox(
                  height: 250,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    maximumDate: DateTime.now(),
                    initialDateTime: _date,
                    onDateTimeChanged: (d) => setState(() { _date = d; }),
                  ),
                ),
              ),
              child: Text(
                '${_date.year}年${_date.month}月${_date.day}日',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Local color references to avoid import of AppTheme
class AppColors {
  static const primary = Color(0xFF5B8FF9);
  static const textSecondary = Color(0xFF6B7280);
}
