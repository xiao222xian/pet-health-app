import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/timeline_event.dart';
import '../../app/theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with TickerProviderStateMixin {
  List<TimelineEvent> _allEvents = [];
  List<TimelineEvent> _filtered = [];
  bool _loading = true;
  String? _petId;
  String _filter = 'all';
  List<bool> _visible = [];

  late final AnimationController _pulseCtrl;
  late final AnimationController _pathCtrl;
  List<Animation<double>> _pathAnims = [];

  static const _filters = [
    ('all', '全部'),
    ('note', '里程碑'),
    ('growth', '成长点滴'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _loadEvents();
    SupabaseService.dataVersion.addListener(_handleDataChanged);
  }

  @override
  void dispose() {
    SupabaseService.dataVersion.removeListener(_handleDataChanged);
    _pulseCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (mounted) _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _visible = [];
      _pathAnims = [];
      _pathCtrl.reset();
    });
    final userId = SupabaseService.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final pets = await SupabaseService.client
        .from('pets')
        .select('id')
        .eq('user_id', userId);
    if ((pets as List).isEmpty) {
      if (mounted) {
        setState(() {
          _petId = null;
          _allEvents = [];
          _filtered = [];
          _loading = false;
        });
      }
      return;
    }
    _petId = pets[0]['id'] as String;
    final data = await SupabaseService.client
        .from('timeline_events')
        .select()
        .eq('pet_id', _petId!)
        .order('event_date', ascending: false);
    if (!mounted) return;
    final events = (data as List)
        .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    _allEvents = events;
    _applyFilter(animate: true);
  }

  void _applyFilter({bool animate = false}) {
    final filtered = _filter == 'all'
        ? List<TimelineEvent>.from(_allEvents)
        : _allEvents.where((e) => e.type == _filter).toList();
    setState(() {
      _filtered = filtered;
      _loading = false;
      _visible = List.filled(filtered.length, false);
    });
    if (animate) _buildPathAnimations(filtered.length);
    // Stagger card reveal
    for (int i = 0; i < filtered.length; i++) {
      Future.delayed(Duration(milliseconds: 60 + i * 70), () {
        if (mounted && i < _visible.length) setState(() => _visible[i] = true);
      });
    }
    if (animate) {
      _pathCtrl.reset();
      _pathCtrl.forward();
    }
  }

  void _buildPathAnimations(int count) {
    _pathAnims = List.generate(count, (i) {
      final start = (i * 0.12).clamp(0.0, 0.88);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
          parent: _pathCtrl,
          curve: Interval(start, end, curve: Curves.easeOut));
    });
  }

  Future<void> _deleteEvent(TimelineEvent event) async {
    await SupabaseService.client
        .from('timeline_events')
        .delete()
        .eq('id', event.id);
    _allEvents.removeWhere((e) => e.id == event.id);
    SupabaseService.notifyDataChanged();
    _applyFilter();
  }

  void _showDetail(TimelineEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimelineDetailSheet(
        event: event,
        cfg: _typeConfig(event.type),
        onEdit: () async {
          Navigator.pop(context);
          await context.push('/timeline/edit/${event.id}');
          _loadEvents();
        },
      ),
    );
  }

  void _showDeleteMenu(TimelineEvent event) {
    showCupertinoModalPopup(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
              title: Text('删除「${event.title}」'),
              message: const Text('此操作无法撤销'),
              actions: [
                CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _deleteEvent(event);
                    },
                    child: const Text('删除')),
              ],
              cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('取消')),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.bgTop, AppTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)))),
        CustomScrollView(slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: Colors.transparent,
            border: null,
            largeTitle: const Text('生命时光轴',
                style: TextStyle(
                    color: AppTheme.deepBlue, fontWeight: FontWeight.w800)),
            trailing: GestureDetector(
                onTap: _petId == null
                    ? null
                    : () async {
                        await context.push('/timeline/new/$_petId');
                        _loadEvents();
                      },
                child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        gradient:
                            _petId != null ? AppTheme.primaryGradient : null,
                        color: _petId == null ? AppTheme.textHint : null,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow:
                            _petId != null ? AppTheme.cardShadowStrong : null),
                    child: const Icon(CupertinoIcons.add,
                        color: Colors.white, size: 17))),
          ),
          // Filter chips
          SliverToBoxAdapter(child: _buildFilterChips()),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator()))
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildRow(i),
                childCount: _filtered.length,
              )),
            ),
        ]),
      ]),
    );
  }

  // ── Filter chips ─────────────────────────────────────
  Widget _buildFilterChips() => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _filters.map((f) {
            final sel = _filter == f.$1;
            final color =
                f.$1 == 'all' ? AppTheme.primary : _typeConfig(f.$1).color;
            return GestureDetector(
              onTap: () {
                if (_filter != f.$1) {
                  setState(() => _filter = f.$1);
                  _applyFilter(animate: true);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? color : AppTheme.divider),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Text(f.$2,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : AppTheme.textSecondary)),
              ),
            );
          }).toList(),
        ),
      );

  // ── Main item builder ────────────────────────────────
  Widget _buildRow(int index) {
    final isEven = index % 2 == 0;
    final isFirst = index == 0;
    final isLast = index == _filtered.length - 1;
    final event = _filtered[index];
    final cfg = _typeConfig(event.type);
    final vis = index < _visible.length && _visible[index];

    // Year header
    Widget? yearHeader;
    if (index == 0 ||
        _filtered[index].eventDate.year !=
            _filtered[index - 1].eventDate.year) {
      yearHeader = _buildYearHeader(event.eventDate.year, isFirst);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (yearHeader != null) yearHeader,

      // Card row with alternating sides
      AnimatedOpacity(
        duration: const Duration(milliseconds: 380),
        opacity: vis ? 1.0 : 0.0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          offset: vis ? Offset.zero : Offset(isEven ? -0.05 : 0.05, 0),
          child: _buildCardRow(index, event, cfg, isFirst, isEven),
        ),
      ),

      // Bezier curve connector — listens to per-curve animation, not parent controller
      if (!isLast)
        LayoutBuilder(builder: (ctx, constraints) {
          final anim = index < _pathAnims.length
              ? _pathAnims[index]
              : const AlwaysStoppedAnimation(0.0);
          final nextCfg = _typeConfig(_filtered[index + 1].type);
          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) => CustomPaint(
              size: Size(constraints.maxWidth, 54),
              painter: _CurvePainter(
                goRight: isEven,
                fromColor: cfg.color,
                toColor: nextCfg.color,
                progress: anim.value,
                dotAreaFraction: 60.0 / constraints.maxWidth,
              ),
            ),
          );
        }),
    ]);
  }

  Widget _buildYearHeader(int year, bool isFirst) => Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadowStrong),
              child: Text('$year',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5))),
          Expanded(
              child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                    AppTheme.primary.withOpacity(0.3),
                    Colors.transparent
                  ])))),
        ]),
      );

  Widget _buildCardRow(int index, TimelineEvent event, _TypeConfig cfg,
      bool isFirst, bool isEven) {
    const dotW = 60.0;

    Widget dot = _buildDot(cfg, isFirst);
    Widget card = GestureDetector(
      onTap: () => _showDetail(event),
      onLongPress: () => _showDeleteMenu(event),
      child: _buildCard(event, cfg, isFirst),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isEven
            ? [
                SizedBox(
                    width: dotW,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(child: dot))),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(right: 4), child: card)),
              ]
            : [
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(left: 4), child: card)),
                SizedBox(
                    width: dotW,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(child: dot))),
              ],
      ),
    );
  }

  Widget _buildDot(_TypeConfig cfg, bool isFirst) {
    if (isFirst) {
      return AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final p = _pulseCtrl.value;
          return Stack(alignment: Alignment.center, children: [
            Container(
                width: 50 + p * 8,
                height: 50 + p * 8,
                decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12 + p * 0.06),
                    shape: BoxShape.circle)),
            _dot(cfg, 40),
          ]);
        },
      );
    }
    return _dot(cfg, 36);
  }

  Widget _dot(_TypeConfig cfg, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [cfg.color.withOpacity(0.85), cfg.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: cfg.color.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]),
      child: Icon(cfg.icon, color: Colors.white, size: size * 0.44));

  Widget _buildCard(TimelineEvent event, _TypeConfig cfg, bool isFirst) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: isFirst
            ? Border.all(color: cfg.color.withOpacity(0.3), width: 1.5)
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header strip
        Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [cfg.color.withOpacity(0.1), Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight)),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.icon, size: 9, color: cfg.color),
                    const SizedBox(width: 3),
                    Text(cfg.label,
                        style: TextStyle(
                            fontSize: 9,
                            color: cfg.color,
                            fontWeight: FontWeight.w700)),
                  ])),
              const Spacer(),
              if (isFirst)
                Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: cfg.color,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('最新',
                        style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700))),
              Text(_formatDate(event.eventDate),
                  style:
                      const TextStyle(fontSize: 10, color: AppTheme.textHint)),
            ])),
        // Body
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _buildCardBody(event, cfg)),
      ]),
    );
  }

  Widget _buildCardBody(TimelineEvent event, _TypeConfig cfg) {
    switch (event.type) {
      case 'weight':
        return _weightBody(event, cfg);
      case 'medical':
        return _medicalBody(event, cfg);
      default:
        return _genericBody(event);
    }
  }

  Widget _weightBody(TimelineEvent event, _TypeConfig cfg) =>
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(event.title,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: cfg.color,
                height: 1.1)),
        const SizedBox(width: 4),
        const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('体重',
                style: TextStyle(fontSize: 11, color: AppTheme.textHint))),
        if (event.content != null && event.content!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
              child: Text(event.content!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ]);

  Widget _medicalBody(TimelineEvent event, _TypeConfig cfg) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.deepBlue)),
        if (event.content != null && event.content!.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...event.content!.split('\n').map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.only(right: 7, top: 1),
                    decoration: BoxDecoration(
                        color: cfg.color.withOpacity(0.5),
                        shape: BoxShape.circle)),
                Expanded(
                    child: Text(l,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4))),
              ]))),
        ],
      ]);

  Widget _genericBody(TimelineEvent event) => Text(event.title,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.deepBlue));

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadowStrong),
            child:
                const Center(child: Text('✨', style: TextStyle(fontSize: 40)))),
        const SizedBox(height: 20),
        Text(_filter == 'all' ? '还没有任何记录' : '暂无${_typeConfig(_filter).label}记录',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepBlue)),
        const SizedBox(height: 8),
        const Text('长按卡片可删除记录',
            style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
      ]));

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  _TypeConfig _typeConfig(String type) {
    switch (type) {
      case 'growth':
        return _TypeConfig(
            CupertinoIcons.heart_circle_fill, const Color(0xFF4CAF50), '成长点滴');
      case 'medical':
        return _TypeConfig(CupertinoIcons.heart_fill, AppTheme.danger, '医疗');
      case 'weight':
        return _TypeConfig(
            CupertinoIcons.chart_bar_fill, AppTheme.primaryLight, '体重');
      case 'photo':
        return _TypeConfig(
            CupertinoIcons.photo_fill, const Color(0xFF7E57C2), '照片');
      default:
        return _TypeConfig(CupertinoIcons.star_fill, AppTheme.primary,
            '里程碑'); // 'note' = milestone
    }
  }
}

// ── Bezier curve painter ─────────────────────────────────
class _CurvePainter extends CustomPainter {
  final bool goRight;
  final Color fromColor, toColor;
  final double progress;
  final double dotAreaFraction; // fraction of width used by dot area

  const _CurvePainter({
    required this.goRight,
    required this.fromColor,
    required this.toColor,
    required this.progress,
    required this.dotAreaFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final dotCenterX = size.width * dotAreaFraction * 0.5;
    final fromX = goRight ? dotCenterX : (size.width - dotCenterX);
    final toX = goRight ? (size.width - dotCenterX) : dotCenterX;

    final path = Path()
      ..moveTo(fromX, 0)
      ..cubicTo(
        fromX,
        size.height * 0.42,
        toX,
        size.height * 0.58,
        toX,
        size.height,
      );

    final metrics = path.computeMetrics();
    if (!metrics.iterator.moveNext()) return;
    final metric = metrics.iterator.current;
    final drawn =
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [fromColor, _blend(fromColor, toColor, 0.5), toColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(drawn, paint);

    // Glow layer
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [fromColor.withOpacity(0.2), toColor.withOpacity(0.2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(drawn, glowPaint);
  }

  Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.progress != progress ||
      old.fromColor != fromColor ||
      old.toColor != toColor ||
      old.goRight != goRight;
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  final String label;
  const _TypeConfig(this.icon, this.color, this.label);
}

class _TimelineDetailSheet extends StatelessWidget {
  final TimelineEvent event;
  final _TypeConfig cfg;
  final VoidCallback onEdit;

  const _TimelineDetailSheet({
    required this.event,
    required this.cfg,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 13, color: cfg.color),
                      const SizedBox(width: 6),
                      Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: cfg.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${event.eventDate.year}年${event.eventDate.month}月${event.eventDate.day}日',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepBlue,
              ),
            ),
            if (event.content != null && event.content!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Text(
                  event.content!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            if (event.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '照片',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: event.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      event.photoUrls[i],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppTheme.cardShadowStrong,
                ),
                child: const Center(
                  child: Text(
                    '编辑这个事件',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
