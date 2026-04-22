import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/pet.dart';
import '../../shared/models/medical_record.dart';
import '../../app/theme.dart';

class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});
  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  List<Pet> _pets = [];
  int _selectedIdx = 0;
  List<MedicalRecord> _upcomingRecords = [];
  bool _loading = true;
  bool _infoExpanded = false;
  Map<String, dynamic>? _stats; // {logs, last_log, weight, appetite}

  Pet? get _pet => _pets.isEmpty ? null : _pets[_selectedIdx];

  @override
  void initState() {
    super.initState();
    _load();
    SupabaseService.dataVersion.addListener(_handleDataChanged);
  }

  @override
  void dispose() {
    SupabaseService.dataVersion.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final petsData = await SupabaseService.client
        .from('pets')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    if (!mounted) return;
    final pets = (petsData as List)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
    if (pets.isEmpty) {
      setState(() {
        _pets = [];
        _loading = false;
      });
      return;
    }
    final idx = _selectedIdx.clamp(0, pets.length - 1);
    await _loadExtras(pets[idx].id);
    if (!mounted) return;
    setState(() {
      _pets = pets;
      _selectedIdx = idx;
      _loading = false;
    });
  }

  Future<void> _loadExtras(String petId) async {
    final results = await Future.wait([
      SupabaseService.client
          .from('medical_records')
          .select()
          .eq('pet_id', petId)
          .not('next_due_date', 'is', null)
          .order('next_due_date'),
      SupabaseService.client
          .from('health_logs')
          .select('log_date, weight_kg, appetite_level')
          .eq('pet_id', petId)
          .order('log_date', ascending: false)
          .limit(30),
    ]);
    if (!mounted) return;
    final records = (results[0] as List)
        .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final logs = results[1] as List;
    setState(() {
      _upcomingRecords = records;
      _stats = {
        'log_count': logs.length,
        'last_log': logs.isNotEmpty ? logs[0]['log_date'] : null,
        'appetite': logs.isNotEmpty ? logs[0]['appetite_level'] : null,
        'weight': logs.isNotEmpty ? logs[0]['weight_kg'] : null,
      };
    });
  }

  Future<void> _selectPet(int idx) async {
    setState(() => _selectedIdx = idx);
    await _loadExtras(_pets[idx].id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const CupertinoPageScaffold(
          backgroundColor: AppTheme.background,
          child: Center(child: CupertinoActivityIndicator()));
    if (_pet == null) return _buildEmpty();
    return _buildProfile(_pet!);
  }

  // ── Empty ────────────────────────────────────────────
  Widget _buildEmpty() => CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.bgTop, AppTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)))),
        SafeArea(
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadowStrong),
                  child: const Center(
                      child: Text('🐾', style: TextStyle(fontSize: 52)))),
              const SizedBox(height: 24),
              const Text('还没有添加宠物',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepBlue)),
              const SizedBox(height: 8),
              const Text('添加你的毛孩子，开始记录它的生活',
                  style:
                      TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              GestureDetector(
                  onTap: () async {
                    await context.push('/pet/new');
                    await _load();
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 14),
                      decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppTheme.cardShadowStrong),
                      child: const Text('添加我的宠物',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)))),
            ]))),
      ]));

  // ── Profile ──────────────────────────────────────────
  Widget _buildProfile(Pet pet) => CupertinoPageScaffold(
        backgroundColor: AppTheme.background,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Stack(children: [
            Container(
                height: 320,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.bgTop, AppTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter))),
            SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar ──
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('我的宠物',
                              style: TextStyle(
                                  color: AppTheme.primary.withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ]),
                    const SizedBox(height: 14),
                    _buildPetSwitcher(),
                    const SizedBox(height: 18),
                    // ── Pet hero ──
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: AppTheme.cardShadowStrong),
                              child: ClipOval(
                                  child: _buildPetAvatar(pet, 78, 38))),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(pet.name,
                                          style: const TextStyle(
                                              color: AppTheme.deepBlue,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5))),
                                  GestureDetector(
                                    onTap: () async {
                                      await context.push('/pet/edit/${pet.id}');
                                      await _load();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.primary
                                                .withOpacity(0.2)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(CupertinoIcons.pencil,
                                                color: AppTheme.primary,
                                                size: 12),
                                            const SizedBox(width: 4),
                                            const Text('编辑',
                                                style: TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ]),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                // 可折叠的详细信息
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _infoExpanded = !_infoExpanded),
                                  child: Row(children: [
                                    Text(_speciesLabel(pet),
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Icon(
                                        _infoExpanded
                                            ? CupertinoIcons.chevron_up
                                            : CupertinoIcons.chevron_down,
                                        size: 11,
                                        color: AppTheme.textHint),
                                  ]),
                                ),
                                if (_infoExpanded) ...[
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, runSpacing: 4, children: [
                                    if (pet.birthDate != null)
                                      _chip(_ageLabel(pet.birthDate!)),
                                    if (_displayWeight(pet) != null)
                                      _chip('${_displayWeight(pet)}kg'),
                                    _chip(pet.gender == 'male'
                                        ? '♂ 弟弟'
                                        : pet.gender == 'female'
                                            ? '♀ 妹妹'
                                            : '性别未知'),
                                    _chip(pet.neutered ? '✓ 已绝育' : '未绝育'),
                                  ]),
                                ],
                              ])),
                        ]),
                    const SizedBox(height: 16),
                    // ── Quick stats ──
                    _buildStatsRow(),
                  ]),
            )),
          ])),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              if (_upcomingRecords.isNotEmpty) ...[
                _sectionLabel('即将到期'),
                const SizedBox(height: 10),
                ..._upcomingRecords.map(_reminderCard),
                const SizedBox(height: 20),
              ],
              _sectionLabel('管理'),
              const SizedBox(height: 10),
              _menuCard(
                  icon: CupertinoIcons.doc_text_fill,
                  color: AppTheme.primary,
                  title: '医疗记录',
                  subtitle: '疫苗、驱虫、就诊',
                  onTap: () async {
                    await context.push('/medical/${pet.id}');
                    await _load();
                  }),
              const SizedBox(height: 10),
              _menuCard(
                  icon: CupertinoIcons.heart_fill,
                  color: const Color(0xFF26A69A),
                  title: '健康日志',
                  subtitle: '每日精力、饮食、体重记录',
                  onTap: () => context.go('/health')),
              const SizedBox(height: 10),
              _menuCard(
                  icon: CupertinoIcons.time,
                  color: AppTheme.primaryLight,
                  title: '生命时光轴',
                  subtitle: '里程碑、成长点滴',
                  onTap: () => context.go('/timeline')),
              const SizedBox(height: 20),
              _sectionLabel('其他'),
              const SizedBox(height: 10),
              _menuCard(
                  icon: CupertinoIcons.delete,
                  color: AppTheme.danger,
                  title: '删除此宠物档案',
                  subtitle: '删除后数据无法恢复',
                  onTap: () => _confirmDelete(pet)),
            ])),
          ),
        ]),
      );

  // Renders pet avatar: network photo > emoji fallback
  Widget _buildPetAvatar(Pet pet, double size, double emojiSize) {
    final url = pet.avatarUrl;
    if (url != null && url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Center(
            child: Text(
                pet.species == 'cat'
                    ? '🐱'
                    : pet.species == 'dog'
                        ? '🐶'
                        : '🐾',
                style: TextStyle(fontSize: emojiSize))),
        errorWidget: (_, __, ___) => Center(
            child: Text(
                pet.species == 'cat'
                    ? '🐱'
                    : pet.species == 'dog'
                        ? '🐶'
                        : '🐾',
                style: TextStyle(fontSize: emojiSize))),
      );
    }
    if (url != null && url.startsWith('data:image/')) {
      final bytes = _decodeDataUrl(url);
      if (bytes != null) {
        return Image.memory(bytes,
            width: size, height: size, fit: BoxFit.cover);
      }
    }
    final emoji = (url != null && url.isNotEmpty)
        ? url
        : (pet.species == 'cat'
            ? '🐱'
            : pet.species == 'dog'
                ? '🐶'
                : '🐾');
    return Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize)));
  }

  Uint8List? _decodeDataUrl(String value) {
    final index = value.indexOf(',');
    if (index == -1) return null;
    try {
      return base64Decode(value.substring(index + 1));
    } catch (_) {
      return null;
    }
  }

  // ── Pet switcher ─────────────────────────────────────
  Widget _buildPetSwitcher() {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pets.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _pets.length) {
            return GestureDetector(
              onTap: () async {
                await context.push('/pet/new');
                await _load();
              },
              child: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.cardShadowStrong),
                          child: const Icon(CupertinoIcons.add,
                              color: Colors.white, size: 20)),
                      const SizedBox(height: 5),
                      Text('添加',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  )),
            );
          }
          final p = _pets[i];
          final sel = i == _selectedIdx;
          return GestureDetector(
            onTap: () => _selectPet(i),
            child: Container(
              width: 64,
              margin: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: sel ? AppTheme.primaryGradient : null,
                        color: sel ? null : AppTheme.primarySoft,
                        shape: BoxShape.circle,
                        border: sel
                            ? null
                            : Border.all(color: AppTheme.divider, width: 1.5),
                        boxShadow: sel ? AppTheme.cardShadowStrong : null,
                      ),
                      child: ClipOval(
                          child: _buildPetAvatar(
                              p, sel ? 52 : 48, sel ? 26 : 24))),
                  const SizedBox(height: 5),
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? AppTheme.primary : AppTheme.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Quick stats row ──────────────────────────────────
  Widget _buildStatsRow() {
    final lastLog = _stats?['last_log'] as String?;
    final nextReminder = _nextReminderRecord();
    final reminderLabel = nextReminder == null
        ? '暂无提醒'
        : _isOverdue(nextReminder)
            ? '已逾期'
            : '下个提醒';
    final reminderValue = nextReminder == null
        ? '-'
        : '${nextReminder.nextDueDate!.month}月${nextReminder.nextDueDate!.day}日${_typeShortLabel(nextReminder.type)}';
    // Latest health log status
    final appetiteLevel = _stats?['appetite'] as int?;
    final statusLabel = _statusStr(appetiteLevel);

    return Row(children: [
      Expanded(child: _statCard('🔔', reminderValue, reminderLabel)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('💬', statusLabel, '最近状态')),
      const SizedBox(width: 8),
      Expanded(
          child: _statCard(
              '📅', lastLog != null ? _shortDate(lastLog) : '-', '最新记录')),
    ]);
  }

  String _typeShortLabel(String type) {
    switch (type) {
      case 'vaccine':
        return '打疫苗';
      case 'checkup':
        return '做体检';
      case 'deworming':
        return '驱虫';
      case 'surgery':
        return '手术复查';
      default:
        return '健康备忘';
    }
  }

  MedicalRecord? _nextReminderRecord() {
    if (_upcomingRecords.isEmpty) return null;
    final overdue = _upcomingRecords.where(_isOverdue).toList();
    if (overdue.isNotEmpty) {
      overdue.sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
      return overdue.first;
    }
    final upcoming = _upcomingRecords.where((record) => !_isOverdue(record)).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    return upcoming.first;
  }

  bool _isOverdue(MedicalRecord record) {
    final due = record.nextDueDate;
    if (due == null) return false;
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    final target = DateTime(due.year, due.month, due.day);
    return target.isBefore(current);
  }

  String _statusStr(int? level) {
    if (level == null) return '-';
    if (level >= 4) return '状态很棒';
    if (level == 3) return '状态正常';
    if (level == 2) return '状态欠佳';
    return '状态很差';
  }

  Widget _statCard(String emoji, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.cardShadow),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepBlue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      );

  // ── Delete ───────────────────────────────────────────
  void _confirmDelete(Pet pet) {
    showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
              title: Text('删除「${pet.name}」?'),
              content: const Text('删除后所有相关数据将无法恢复。'),
              actions: [
                CupertinoDialogAction(
                    child: const Text('取消'),
                    onPressed: () => Navigator.pop(ctx)),
                CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await SupabaseService.client
                          .from('pets')
                          .delete()
                          .eq('id', pet.id);
                      setState(() => _selectedIdx = 0);
                      SupabaseService.notifyDataChanged();
                      await _load();
                    },
                    child: const Text('删除')),
              ],
            ));
  }

  // ── Helpers ──────────────────────────────────────────
  Widget _chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600)));

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8));

  Widget _reminderCard(MedicalRecord r) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.warningSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.warning.withOpacity(0.2))),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.bell_fill,
                color: AppTheme.warning, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary)),
          Text('${r.nextDueDate!.month}月${r.nextDueDate!.day}日到期',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('即将到期',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600))),
      ]));

  Widget _menuCard(
          {required IconData icon,
          required Color color,
          required String title,
          required String subtitle,
          required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.cardShadow),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ])),
                const Icon(CupertinoIcons.chevron_right,
                    color: AppTheme.textHint, size: 16),
              ])));

  String _speciesLabel(Pet pet) {
    final sp = pet.species == 'dog'
        ? '狗狗'
        : pet.species == 'cat'
            ? '猫咪'
            : '宠物';
    return '$sp${pet.breed != null ? " · ${pet.breed}" : ""}';
  }

  String _ageLabel(DateTime birth) {
    final now = DateTime.now();
    final years = now.year -
        birth.year -
        (now.month < birth.month ||
                (now.month == birth.month && now.day < birth.day)
            ? 1
            : 0);
    final months = (now.month - birth.month + 12) % 12;
    if (years == 0) return '$months个月';
    if (months == 0) return '$years岁';
    return '$years岁$months月';
  }

  String _shortDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return '${d.month}/${d.day}';
    } catch (_) {
      return '-';
    }
  }

  String? _displayWeight(Pet pet) {
    final latestWeight = (_stats?['weight'] as num?)?.toDouble();
    final weight = latestWeight ?? pet.weightKg;
    return weight == null
        ? null
        : weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1);
  }
}
