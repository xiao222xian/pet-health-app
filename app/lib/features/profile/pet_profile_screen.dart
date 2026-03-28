import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/pet.dart';
import '../../shared/models/medical_record.dart';
import '../../shared/widgets/app_card.dart';
import '../../app/theme.dart';

class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  Pet? _pet;
  List<MedicalRecord> _upcomingRecords = [];
  bool _loading = true;

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
        .select()
        .eq('user_id', userId)
        .limit(1);

    if ((pets as List).isEmpty) {
      setState(() { _loading = false; });
      return;
    }

    final pet = Pet.fromJson(pets[0]);
    final soon = DateTime.now().add(const Duration(days: 30));
    final records = await SupabaseService.client
        .from('medical_records')
        .select()
        .eq('pet_id', pet.id)
        .lte('next_due_date', soon.toIso8601String().substring(0, 10))
        .order('next_due_date');

    setState(() {
      _pet = pet;
      _upcomingRecords = (records as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_pet == null) {
      return CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('还没有添加宠物', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () async {
                  await context.push('/pet/new');
                  await _load();
                },
                child: const Text('添加我的宠物'),
              ),
            ],
          ),
        ),
      );
    }

    final pet = _pet!;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(pet.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await context.push('/pet/edit/${pet.id}');
            await _load();
          },
          child: const Icon(CupertinoIcons.pencil),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(
                      CupertinoIcons.paw,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${pet.species} ${pet.breed ?? ''}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        if (pet.ageYears != null)
                          Text(
                            '${pet.ageYears}岁 · ${pet.neutered ? '已绝育' : '未绝育'}',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        if (pet.weightKg != null)
                          Text(
                            '${pet.weightKg} kg',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_upcomingRecords.isNotEmpty) ...[
              const Text(
                '即将到期提醒',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._upcomingRecords.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.bell, color: AppTheme.warningColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${r.nextDueDate!.month}月${r.nextDueDate!.day}日到期',
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
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              onTap: () async {
                await context.push('/medical/${pet.id}');
                await _load();
              },
              child: const Row(
                children: [
                  Icon(CupertinoIcons.doc_text, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Text('医疗记录', style: TextStyle(fontWeight: FontWeight.w500)),
                  Spacer(),
                  Icon(CupertinoIcons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
