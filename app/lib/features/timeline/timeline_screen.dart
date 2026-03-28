import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/timeline_event.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_card.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<TimelineEvent> _events = [];
  bool _loading = true;
  String? _petId;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
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
        .from('timeline_events')
        .select()
        .eq('pet_id', _petId!)
        .order('event_date', ascending: false);

    setState(() {
      _events = (data as List).map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('生命时光轴'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _petId == null ? null : () async {
            await context.push('/timeline/new/$_petId');
            await _loadEvents();
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _events.isEmpty
              ? const Center(child: Text('还没有记录，点击 + 添加第一个里程碑'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _iconForType(event.type),
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${event.eventDate.year}年${event.eventDate.month}月${event.eventDate.day}日',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'photo':
        return CupertinoIcons.photo;
      case 'weight':
        return CupertinoIcons.chart_bar;
      case 'medical':
        return CupertinoIcons.heart_circle;
      default:
        return CupertinoIcons.pencil;
    }
  }
}
