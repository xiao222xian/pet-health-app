import 'package:flutter/cupertino.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/health_log.dart';
import '../../shared/widgets/app_card.dart';
import '../../app/theme.dart';

class HealthLogScreen extends StatefulWidget {
  const HealthLogScreen({super.key});

  @override
  State<HealthLogScreen> createState() => _HealthLogScreenState();
}

class _HealthLogScreenState extends State<HealthLogScreen> {
  List<HealthLog> _logs = [];
  bool _loading = true;
  String? _petId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      setState(() { _loading = false; });
      return;
    }

    final pets = await SupabaseService.client
        .from('pets')
        .select('id')
        .eq('user_id', userId);

    if ((pets as List).isEmpty) {
      setState(() { _loading = false; });
      return;
    }

    _petId = pets[0]['id'] as String;
    final data = await SupabaseService.client
        .from('health_logs')
        .select()
        .eq('pet_id', _petId!)
        .order('log_date', ascending: false)
        .limit(30);

    setState(() {
      _logs = (data as List).map((e) => HealthLog.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _addTodayLog() async {
    if (_petId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await SupabaseService.client.from('health_logs').upsert({
      'pet_id': _petId,
      'log_date': today,
      'appetite_level': 3,
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('健康记录'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _petId == null ? null : _addTodayLog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('点击 + 添加今日健康记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, i) {
                    final log = _logs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.logDate.month}月${log.logDate.day}日',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if (log.weightKg != null)
                              Text('体重：${log.weightKg} kg'),
                            if (log.appetiteLevel != null)
                              Text(
                                '食欲：${'★' * log.appetiteLevel!}${'☆' * (5 - log.appetiteLevel!)}',
                              ),
                            if (log.notes != null) Text(log.notes!),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
