import 'package:flutter/cupertino.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/medical_record.dart';
import '../../shared/widgets/app_card.dart';
import '../../app/theme.dart';

class MedicalRecordsScreen extends StatefulWidget {
  final String petId;
  const MedicalRecordsScreen({super.key, required this.petId});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<MedicalRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SupabaseService.client
        .from('medical_records')
        .select()
        .eq('pet_id', widget.petId)
        .order('record_date', ascending: false);
    setState(() {
      _records = (data as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  Future<void> _addRecord() async {
    final titleCtrl = TextEditingController();
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('添加医疗记录'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: titleCtrl,
              placeholder: '标题（例：狂犬疫苗）',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(context);
              await SupabaseService.client.from('medical_records').insert({
                'pet_id': widget.petId,
                'type': 'vaccine',
                'title': titleCtrl.text.trim(),
                'record_date': DateTime.now().toIso8601String().substring(0, 10),
              });
              nav.pop();
              await _load();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('医疗记录'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addRecord,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _records.isEmpty
              ? const Center(child: Text('暂无医疗记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, i) {
                    final r = _records[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _typeLabel(r.type),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${r.recordDate.year}/${r.recordDate.month}/${r.recordDate.day}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.title,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (r.nextDueDate != null)
                              Text(
                                '下次：${r.nextDueDate!.month}月${r.nextDueDate!.day}日',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'vaccine': '疫苗',
      'checkup': '体检',
      'deworming': '驱虫',
      'allergy': '过敏',
      'disease': '疾病',
    };
    return labels[type] ?? type;
  }
}
