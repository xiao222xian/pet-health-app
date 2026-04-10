import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/health_log.dart';
import '../../app/theme.dart';

class HealthLogScreen extends StatefulWidget {
  const HealthLogScreen({super.key});
  @override
  State<HealthLogScreen> createState() => _HealthLogScreenState();
}

class _HealthLogScreenState extends State<HealthLogScreen> {
  List<HealthLog> _logs = [];
  // Keyed by 'yyyy-MM-dd' for O(1) lookup in week trend and today check
  Map<String, HealthLog> _logsByDate = {};
  bool _loading = true;
  String? _petId;
  String? _petName;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  HealthLog? get _todayLog => _logsByDate[_dateKey(DateTime.now())];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final userId = SupabaseService.userId;
    if (userId == null) { if (mounted) setState(() => _loading = false); return; }
    final pets = await SupabaseService.client.from('pets').select('id, name').eq('user_id', userId).limit(1);
    if ((pets as List).isEmpty) { if (mounted) setState(() => _loading = false); return; }
    _petId = pets[0]['id'] as String;
    _petName = pets[0]['name'] as String?;
    final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    final data = await SupabaseService.client
        .from('health_logs').select()
        .eq('pet_id', _petId!)
        .gte('log_date', since)
        .order('log_date', ascending: false)
        .limit(100);
    if (!mounted) return;
    final logs = (data as List).map((e) => HealthLog.fromJson(e as Map<String, dynamic>)).toList();
    setState(() {
      _logs = logs;
      _logsByDate = { for (final l in logs) _dateKey(l.logDate): l };
      _loading = false;
    });
  }

  void _showEntryModal([HealthLog? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EntrySheet(
        petId: _petId!,
        existing: existing,
        onSaved: () { if (mounted) _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: 220,
          child: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.bgTop, AppTheme.background],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ))),
        CustomScrollView(slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: Colors.transparent,
            border: null,
            largeTitle: const Text('健康日志',
              style: TextStyle(color: AppTheme.deepBlue, fontWeight: FontWeight.w800)),
            trailing: _petId == null ? null : GestureDetector(
              onTap: () => _showEntryModal(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.cardShadowStrong,
                ),
                child: const Icon(CupertinoIcons.add, color: Colors.white, size: 17),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else if (_petId == null)
            SliverFillRemaining(child: _buildNoPet())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(delegate: SliverChildListDelegate([
                _buildTodayCard(),
                const SizedBox(height: 14),
                _buildWeekTrend(),
                if (_hasWeightData) ...[
                  const SizedBox(height: 22),
                  _buildWeightChart(),
                ],
                const SizedBox(height: 22),
                if (_logs.isNotEmpty) ...[
                  _sectionLabel('历史记录'),
                  const SizedBox(height: 10),
                  ..._logs.where((l) => _dateKey(l.logDate) != _dateKey(DateTime.now()))
                      .map((l) => _buildHistoryCard(l)),
                ],
              ])),
            ),
        ]),
      ]),
    );
  }

  Widget _buildNoPet() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadowStrong),
      child: const Center(child: Text('宠', style: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)))),
    const SizedBox(height: 16),
    const Text('先去添加你的宠物吧', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.deepBlue)),
    const SizedBox(height: 8),
    const Text('添加宠物后即可记录健康日志', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    const SizedBox(height: 24),
    GestureDetector(
      onTap: () async {
        // Navigate to profile tab (index 0) to add a pet
        context.go('/');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.cardShadowStrong),
        child: const Text('去添加宠物',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
    ),
  ]));

  Widget _buildTodayCard() {
    final log = _todayLog;
    final now = DateTime.now();
    final todayStr = '${now.month}月${now.day}日 · 今天';

    Color statusColor;
    String statusEmoji;
    String statusLabel;
    if (log == null) {
      statusColor = const Color(0xFF78909C);
      statusEmoji = '📋';
      statusLabel = '还未记录';
    } else {
      final level = log.appetiteLevel ?? 3;
      if (level >= 4) { statusColor = AppTheme.success; statusEmoji = '😊'; statusLabel = '状态很棒'; }
      else if (level == 3) { statusColor = const Color(0xFF26A69A); statusEmoji = '😐'; statusLabel = '状态正常'; }
      else if (level == 2) { statusColor = AppTheme.warning; statusEmoji = '😟'; statusLabel = '状态欠佳'; }
      else { statusColor = AppTheme.danger; statusEmoji = '😫'; statusLabel = '状态很差'; }
    }

    return GestureDetector(
      onTap: () => _showEntryModal(log),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.85), statusColor],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: statusColor.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(todayStr, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
              child: Text(log == null ? '去记录 ›' : '点击编辑 ›',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Text(statusEmoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_petName ?? '宝贝', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
          ]),
          if (log != null) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              if (log.waterMl != null) _statBadge('饮水', _waterStr(log.waterMl!)),
              _statBadge('大便', log.stoolStatus != null ? _stoolStr(log.stoolStatus!) : '未记录'),
              if (log.foodType != null) _statBadge('饮食', _foodStr(log.foodType!)),
              if (log.weightKg != null) _statBadge('体重', '${log.weightKg}kg'),
            ]),
          ] else ...[
            const SizedBox(height: 14),
            const Text('记录今日健康状态，了解宝贝的变化趋势',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ]),
      ),
    );
  }

  Widget _statBadge(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.22),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _buildWeekTrend() {
    final today = DateTime.now();
    // Always show Mon–Sun of the current week
    final weekday = today.weekday; // 1=Mon, 7=Sun
    final monday = today.subtract(Duration(days: weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('本周趋势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.deepBlue)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days.map((d) {
            final log = _logsByDate[_dateKey(d)];
            final isToday = d.day == today.day && d.month == today.month && d.year == today.year;
            Color dotColor;
            if (log == null) dotColor = AppTheme.textHint.withOpacity(0.25);
            else {
              final level = log.appetiteLevel ?? 3;
              if (level >= 4) dotColor = AppTheme.success;
              else if (level == 3) dotColor = const Color(0xFF26A69A);
              else if (level == 2) dotColor = AppTheme.warning;
              else dotColor = AppTheme.danger;
            }
            const wds = ['一', '二', '三', '四', '五', '六', '日'];
            return Column(children: [
              Text(isToday ? '今' : wds[d.weekday - 1], style: TextStyle(
                fontSize: 11, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: isToday ? AppTheme.primary : AppTheme.textHint)),
              const SizedBox(height: 7),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: AppTheme.primary, width: 2) : null,
                ),
                child: log != null ? const Center(child: Text('', style: TextStyle(fontSize: 0))) : null,
              ),
              const SizedBox(height: 5),
              Text('${d.day}', style: TextStyle(fontSize: 10, color: isToday ? AppTheme.primary : AppTheme.textHint)),
            ]);
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _legendDot(AppTheme.danger, '很差'), const SizedBox(width: 10),
          _legendDot(AppTheme.warning, '欠佳'), const SizedBox(width: 10),
          _legendDot(const Color(0xFF26A69A), '正常'), const SizedBox(width: 10),
          _legendDot(AppTheme.success, '很棒'), const SizedBox(width: 10),
          _legendDot(AppTheme.textHint.withOpacity(0.25), '未记'),
        ]),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
  ]);

  Widget _buildHistoryCard(HealthLog log) {
    final level = log.appetiteLevel;
    Color statusColor = AppTheme.textHint;
    String emoji = '📋';
    if (level != null) {
      if (level >= 4) { statusColor = AppTheme.success; emoji = '😊'; }
      else if (level == 3) { statusColor = const Color(0xFF26A69A); emoji = '😐'; }
      else if (level == 2) { statusColor = AppTheme.warning; emoji = '😟'; }
      else { statusColor = AppTheme.danger; emoji = '😫'; }
    }

    return GestureDetector(
      onTap: () => _showEntryModal(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
        child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${log.logDate.month}月${log.logDate.day}日',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.deepBlue)),
              const SizedBox(width: 6),
              Text(_weekdayStr(log.logDate.weekday), style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ]),
            const SizedBox(height: 5),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (log.appetiteLevel != null) _miniChip(_energyStr(log.appetiteLevel!), statusColor),
              if (log.waterMl != null) _miniChip('水: ${_waterStr(log.waterMl!)}', AppTheme.primary),
              if (log.stoolStatus != null) _miniChip(_stoolStr(log.stoolStatus!), AppTheme.textSecondary),
              if (log.foodType != null) _miniChip(_foodStr(log.foodType!), AppTheme.primaryLight),
              if (log.weightKg != null) _miniChip('${log.weightKg}kg', AppTheme.textSecondary),
            ]),
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(log.notes!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.textHint),
        ]),
      ),
    );
  }

  Widget _miniChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  bool get _hasWeightData => _logs.any((l) => l.weightKg != null);

  Widget _buildWeightChart() {
    // Collect weight data points (oldest → newest)
    final points = _logs
        .where((l) => l.weightKg != null)
        .toList()
      ..sort((a, b) => a.logDate.compareTo(b.logDate));
    if (points.length < 2) return const SizedBox.shrink();

    final spots = points.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.weightKg!)).toList();
    final weights = points.map((l) => l.weightKg!).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final padding = (maxW - minW).clamp(0.5, 5.0) * 0.3;
    final latest = points.last;
    final prev = points.length >= 2 ? points[points.length - 2] : null;
    final diff = prev != null ? (latest.weightKg! - prev.weightKg!) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(CupertinoIcons.chart_bar_fill, size: 13, color: AppTheme.primary),
              SizedBox(width: 5),
              Text('体重趋势', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${latest.weightKg!.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepBlue)),
            if (diff != 0) Text(
              '${diff > 0 ? "↑" : "↓"} ${diff.abs().toStringAsFixed(1)} kg',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: diff > 0 ? AppTheme.warning : AppTheme.success)),
          ]),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: (spots.length - 1).toDouble().clamp(1, double.infinity),
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                    final d = points[idx].logDate;
                    return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text('${d.month}/${d.day}',
                        style: const TextStyle(fontSize: 9, color: AppTheme.textHint)));
                  },
                )),
              ),
              minY: (minW - padding).clamp(0, double.infinity),
              maxY: maxW + padding,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.spotIndex;
                    if (idx < 0 || idx >= points.length) return null;
                    return LineTooltipItem(
                      '${points[idx].weightKg!.toStringAsFixed(1)} kg',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12));
                  }).toList(),
                ),
              ),
              lineBarsData: [LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppTheme.primary,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: idx == spots.length - 1 ? 5 : 3,
                    color: idx == spots.length - 1 ? AppTheme.primary : Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppTheme.primary)),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [AppTheme.primary.withOpacity(0.18), AppTheme.primary.withOpacity(0.0)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              )],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('共 ${points.length} 条体重记录 · 近30天',
          style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8));

  static String _energyStr(int level) {
    switch (level) {
      case 1: return '状态很差'; case 2: return '状态欠佳'; case 3: return '状态正常';
      case 4: return '状态很棒'; default: return level >= 4 ? '状态很棒' : '状态很差';
    }
  }
  static String _waterStr(int ml) {
    if (ml == 0) return '未饮水'; if (ml <= 100) return '少量'; if (ml <= 300) return '正常'; return '较多';
  }
  static String _stoolStr(int s) {
    switch (s) {
      case 1: return '大便正常'; case 2: return '软便'; case 3: return '腹泻'; case 4: return '便秘'; default: return '未知';
    }
  }
  static String _foodStr(String t) {
    switch (t) {
      case 'dry': return '干粮'; case 'wet': return '湿粮'; case 'mix': return '混合'; case 'none': return '未进食'; default: return t;
    }
  }
  static String _weekdayStr(int w) {
    const d = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return d[w];
  }
}

// ── 录入底部弹窗 ────────────────────────────────────────
class _EntrySheet extends StatefulWidget {
  final String petId;
  final HealthLog? existing;
  final VoidCallback onSaved;
  const _EntrySheet({required this.petId, this.existing, required this.onSaved});
  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  int _energyLevel = 3;
  DateTime? _selectedDate; // null = today
  int? _stoolStatus;
  int _waterMl = 250;
  String _foodType = 'dry';
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _energyLevel = e.appetiteLevel ?? 3;
      _stoolStatus = e.stoolStatus;
      _waterMl = e.waterMl ?? 250;
      _foodType = e.foodType ?? 'dry';
      _weightController.text = e.weightKg?.toString() ?? '';
      _notesController.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final logDate = widget.existing?.logDate.toIso8601String().substring(0, 10)
        ?? _selectedDate?.toIso8601String().substring(0, 10)
        ?? today;
    final payload = <String, dynamic>{
      'pet_id': widget.petId,
      'log_date': logDate,
      'appetite_level': _energyLevel,
      'water_ml': _waterMl,
      'food_type': _foodType,
      if (_stoolStatus != null) 'stool_status': _stoolStatus,
      if (_weightController.text.isNotEmpty) 'weight_kg': double.tryParse(_weightController.text),
      if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
    };
    try {
      if (widget.existing != null) {
        await SupabaseService.client.from('health_logs').update(payload).eq('id', widget.existing!.id);
      } else {
        await SupabaseService.client.from('health_logs').upsert(payload, onConflict: 'pet_id,log_date');
      }
      if (mounted) { Navigator.of(context).pop(); widget.onSaved(); }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(widget.existing == null ? '记录健康状态' : '编辑记录',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.deepBlue)),
                if (widget.existing != null)
                  Text(
                    '${widget.existing!.logDate.month}月${widget.existing!.logDate.day}日',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textHint))
                else
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(CupertinoIcons.calendar, color: AppTheme.primary, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDate == null ? '今天' :
                            '${_selectedDate!.month}月${_selectedDate!.day}日',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 26),

              _sectionTitle('✨ 今日状态'),
              const SizedBox(height: 12),
              _energySelector(),
              const SizedBox(height: 22),

              _sectionTitle('🍽️ 饮食情况'),
              const SizedBox(height: 12),
              _optionRow4<String>(
                options: const [
                  ('none', '🚫', '未进食'),
                  ('dry', '🥣', '干粮'),
                  ('wet', '🥩', '湿粮'),
                  ('mix', '🍱', '混合'),
                ],
                selected: _foodType,
                onTap: (v) => setState(() => _foodType = v),
                soft: true,
              ),
              const SizedBox(height: 22),

              _sectionTitle('💧 饮水情况'),
              const SizedBox(height: 12),
              _optionRow4<int>(
                options: const [
                  (0, '🚫', '没喝'),
                  (100, '💧', '少量'),
                  (250, '💧💧', '正常'),
                  (500, '💧💧💧', '很多'),
                ],
                selected: _waterMl,
                onTap: (v) => setState(() => _waterMl = v),
                soft: true,
              ),
              const SizedBox(height: 22),

              _sectionTitle('💩 大便情况'),
              const SizedBox(height: 12),
              _stoolSelector(),
              const SizedBox(height: 22),

              _sectionTitle('⚖️ 体重 (kg)  ·  选填'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _weightController,
                placeholder: '例：8.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
              ),
              const SizedBox(height: 22),

              _sectionTitle('📝 备注  ·  选填'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _notesController,
                placeholder: '今天有什么特别的情况吗...',
                maxLines: 3,
                minLines: 3,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
              ),
              const SizedBox(height: 30),

              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF4A90E2)]),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: AppTheme.cardShadowStrong,
                  ),
                  child: Center(child: _saving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('保存记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.3));

  void _pickDate() {
    DateTime tempDate = _selectedDate ?? DateTime.now();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(child: const Text('取消'), onPressed: () => Navigator.pop(context)),
            CupertinoButton(child: const Text('完成'), onPressed: () {
              setState(() => _selectedDate = tempDate);
              Navigator.pop(context);
            }),
          ]),
          SizedBox(height: 220, child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            maximumDate: DateTime.now(),
            initialDateTime: tempDate,
            onDateTimeChanged: (d) => tempDate = d,
          )),
        ]),
      ),
    );
  }

  Widget _energySelector() {
    const options = [
      (1, '😫', '很差'), (2, '😟', '欠佳'), (3, '😐', '正常'), (4, '😊', '很棒'),
    ];
    return Row(
      children: options.map((o) {
        final selected = _energyLevel == o.$1;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _energyLevel = o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider),
              boxShadow: selected ? AppTheme.cardShadow : null,
            ),
            child: Column(children: [
              Text(o.$2, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 5),
              Text(o.$3, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textHint)),
            ]),
          ),
        ));
      }).toList(),
    );
  }

  Widget _optionRow4<T>({
    required List<(T, String, String)> options,
    required T selected,
    required void Function(T) onTap,
    bool soft = false,
  }) {
    return Row(
      children: options.map((o) {
        final isSelected = selected == o.$1;
        return Expanded(child: GestureDetector(
          onTap: () => onTap(o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? (soft ? AppTheme.primarySoft : AppTheme.primary) : AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
            ),
            child: Column(children: [
              Text(o.$2, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(o.$3, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primary : AppTheme.textHint)),
            ]),
          ),
        ));
      }).toList(),
    );
  }

  Widget _stoolSelector() {
    final options = <(int?, String, String)>[
      (null, '❓', '未知'),
      (1, '✅', '正常'),
      (2, '🟡', '软便'),
      (3, '🔴', '腹泻'),
      (4, '🟠', '便秘'),
    ];
    return Wrap(spacing: 8, runSpacing: 8,
      children: options.map((o) {
        final isSelected = _stoolStatus == o.$1;
        return GestureDetector(
          onTap: () => setState(() => _stoolStatus = o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primarySoft : AppTheme.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(o.$2, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(o.$3, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
