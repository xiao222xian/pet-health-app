import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../shared/services/supabase_service.dart';
import '../../shared/models/medical_record.dart';
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
    setState(() => _loading = true);
    final data = await SupabaseService.client
        .from('medical_records')
        .select()
        .eq('pet_id', widget.petId)
        .order('record_date', ascending: false);
    if (!mounted) return;
    setState(() {
      _records = (data as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  void _showForm([MedicalRecord? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordFormSheet(
        petId: widget.petId,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(MedicalRecord r) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Text('删除「${r.title}」后无法恢复'),
        actions: [
          CupertinoDialogAction(
              isDestructiveAction: false,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.client
          .from('medical_records')
          .delete()
          .eq('id', r.id);
      SupabaseService.notifyDataChanged();
      _load();
    }
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
            height: 200,
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
            largeTitle: const Text('医疗记录',
                style: TextStyle(
                    color: AppTheme.deepBlue, fontWeight: FontWeight.w800)),
            trailing: GestureDetector(
              onTap: () => _showForm(),
              child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppTheme.cardShadowStrong),
                  child: const Icon(CupertinoIcons.add,
                      color: Colors.white, size: 17)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator()))
          else if (_records.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                (_, i) => _buildCard(_records[i]),
                childCount: _records.length,
              )),
            ),
        ]),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadowStrong),
            child: const Center(
                child: Text('🩺', style: TextStyle(fontSize: 40)))),
        const SizedBox(height: 18),
        const Text('还没有医疗记录',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepBlue)),
        const SizedBox(height: 8),
        const Text('记录疫苗、驱虫、体检等健康档案',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 28),
        GestureDetector(
            onTap: () => _showForm(),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadowStrong),
                child: const Text('添加第一条记录',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)))),
      ]));

  void _showDetail(MedicalRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordDetailSheet(
        record: r,
        onEdit: () {
          Navigator.pop(context);
          _showForm(r);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(r);
        },
      ),
    );
  }

  Widget _buildCard(MedicalRecord r) {
    final cfg = _typeCfg(r.type);
    final isOverdue =
        r.nextDueDate != null && r.nextDueDate!.isBefore(DateTime.now());
    final isDueSoon = r.nextDueDate != null &&
        !isOverdue &&
        r.nextDueDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
    return GestureDetector(
      onTap: () => _showDetail(r),
      onLongPress: () => _delete(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
          border: (isOverdue || isDueSoon)
              ? Border.all(
                  color: isOverdue ? AppTheme.danger : AppTheme.warning,
                  width: 1.5)
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: cfg.color.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cfg.emoji, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(cfg.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: cfg.color,
                            fontWeight: FontWeight.w700)),
                  ])),
              const Spacer(),
              Text(_fmtDate(r.recordDate),
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textHint)),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue)),
              if (r.notes != null && r.notes!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(r.notes!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              if (r.nextDueDate != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: isOverdue
                          ? AppTheme.danger.withOpacity(0.08)
                          : isDueSoon
                              ? AppTheme.warning.withOpacity(0.08)
                              : AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isOverdue
                            ? CupertinoIcons.exclamationmark_circle_fill
                            : CupertinoIcons.clock_fill,
                        size: 12,
                        color: isOverdue
                            ? AppTheme.danger
                            : isDueSoon
                                ? AppTheme.warning
                                : AppTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                        isOverdue
                            ? '已逾期 · 下次 ${_fmtDate(r.nextDueDate!)}'
                            : '下次 ${_fmtDate(r.nextDueDate!)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? AppTheme.danger
                                : isDueSoon
                                    ? AppTheme.warning
                                    : AppTheme.primary)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  _TypeCfg _typeCfg(String type) {
    switch (type) {
      case 'vaccine':
        return _TypeCfg('💉', '疫苗', AppTheme.primary);
      case 'checkup':
        return _TypeCfg('🔬', '体检', const Color(0xFF26A69A));
      case 'deworming':
        return _TypeCfg('💊', '驱虫', const Color(0xFF7E57C2));
      case 'surgery':
        return _TypeCfg('🏥', '手术', AppTheme.danger);
      default:
        return _TypeCfg('📋', '其他', AppTheme.textSecondary);
    }
  }
}

class _TypeCfg {
  final String emoji, label;
  final Color color;
  const _TypeCfg(this.emoji, this.label, this.color);
}

// ── Add / Edit bottom sheet ──────────────────────────────
class _RecordFormSheet extends StatefulWidget {
  final String petId;
  final MedicalRecord? existing;
  final VoidCallback onSaved;
  const _RecordFormSheet(
      {required this.petId, this.existing, required this.onSaved});
  @override
  State<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<_RecordFormSheet> {
  late String _type;
  late DateTime _date;
  DateTime? _nextDue;
  bool _saving = false;
  final _titleCtrl = TextEditingController();
  final _brandCtrl = TextEditingController(); // 疫苗品牌 / 驱虫品牌
  final _dewormTypeCtrl = TextEditingController(); // 驱虫项目
  final _notesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final List<File> _newPhotos = [];
  late List<String> _existingPhotos;

  static const _types = [
    ('vaccine', '💉', '疫苗'),
    ('checkup', '🔬', '体检'),
    ('deworming', '💊', '驱虫'),
    ('surgery', '🏥', '手术'),
    ('other', '📋', '其他'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'vaccine';
    _date = e?.recordDate ?? DateTime.now();
    _nextDue = e?.nextDueDate;
    _existingPhotos = List<String>.from(e?.photoUrls ?? const []);
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _brandCtrl.text = e.brand ?? '';
      _dewormTypeCtrl.text = e.dewormType ?? '';
      _clinicCtrl.text = e.clinic ?? '';
      _costCtrl.text = e.cost?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _brandCtrl.dispose();
    _dewormTypeCtrl.dispose();
    _notesCtrl.dispose();
    _costCtrl.dispose();
    _clinicCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => true;

  String get _titleLabel {
    switch (_type) {
      case 'vaccine':
        return '疫苗名称';
      case 'checkup':
        return '体检项目';
      case 'deworming':
        return '驱虫记录';
      case 'surgery':
        return '手术名称';
      default:
        return '项目名称';
    }
  }

  String get _nextDueLabel {
    switch (_type) {
      case 'vaccine':
        return '下次疫苗时间提醒';
      case 'checkup':
        return '下次体检时间提醒';
      case 'deworming':
        return '下次驱虫时间提醒';
      default:
        return '下次时间提醒';
    }
  }

  bool get _showNextDue => _type != 'surgery';

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _newPhotos
          .addAll(picked.take(6 - _newPhotos.length).map((e) => File(e.path)));
    });
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_newPhotos.length < 6) _newPhotos.add(File(picked.path));
    });
  }

  Future<List<String>> _uploadPhotos() async {
    if (_newPhotos.isEmpty) return _existingPhotos;
    final urls = List<String>.from(_existingPhotos);
    for (final file in _newPhotos) {
      final fileName =
          '${widget.petId}_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      final bytes = await file.readAsBytes();
      await SupabaseService.client.storage.from('medical-records').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      urls.add(
        SupabaseService.client.storage
            .from('medical-records')
            .getPublicUrl(fileName),
      );
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final photoUrls = await _uploadPhotos();

      final payload = {
        'pet_id': widget.petId,
        'type': _type,
        'title': _titleCtrl.text.trim(),
        'record_date': _date.toIso8601String().substring(0, 10),
        if (_nextDue != null)
          'next_due_date': _nextDue!.toIso8601String().substring(0, 10),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        if (_brandCtrl.text.trim().isNotEmpty) 'brand': _brandCtrl.text.trim(),
        if (_dewormTypeCtrl.text.trim().isNotEmpty)
          'deworm_type': _dewormTypeCtrl.text.trim(),
        if (_clinicCtrl.text.trim().isNotEmpty)
          'clinic': _clinicCtrl.text.trim(),
        if (_costCtrl.text.trim().isNotEmpty)
          'cost': double.tryParse(_costCtrl.text.trim()),
        'photo_urls': photoUrls,
      };
      if (widget.existing != null) {
        await SupabaseService.client
            .from('medical_records')
            .update(payload)
            .eq('id', widget.existing!.id);
      } else {
        await SupabaseService.client.from('medical_records').insert(payload);
      }
      SupabaseService.notifyDataChanged();
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
                  title: const Text('保存失败'),
                  content: Text(e.toString()),
                  actions: [
                    CupertinoDialogAction(
                        child: const Text('确定'),
                        onPressed: () => Navigator.pop(context))
                  ],
                ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickDate(bool isNextDue) {
    DateTime tempDate = isNextDue
        ? (_nextDue ?? DateTime.now().add(const Duration(days: 365)))
        : _date;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context)),
            CupertinoButton(
                child: const Text('完成'),
                onPressed: () {
                  setState(() {
                    if (isNextDue) {
                      _nextDue = tempDate;
                    } else {
                      _date = tempDate;
                    }
                  });
                  Navigator.pop(context);
                }),
          ]),
          SizedBox(
              height: 220,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                minimumDate: isNextDue ? DateTime.now() : null,
                maximumDate: isNextDue ? null : DateTime.now(),
                onDateTimeChanged: (d) => tempDate = d,
              )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2)))),
          // Header
          Row(children: [
            Expanded(
                child: Text(isEdit ? '编辑记录' : '添加医疗记录',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepBlue))),
            GestureDetector(
              onTap: (_saving || !_canSave) ? null : _save,
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                      gradient: _canSave ? AppTheme.primaryGradient : null,
                      color: _canSave ? null : AppTheme.divider,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _canSave ? AppTheme.cardShadowStrong : null),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('保存',
                          style: TextStyle(
                              color:
                                  _canSave ? Colors.white : AppTheme.textHint,
                              fontWeight: FontWeight.w700,
                              fontSize: 14))),
            ),
          ]),
          const SizedBox(height: 22),

          // Type selector
          _label('类型'),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView(
                scrollDirection: Axis.horizontal,
                children: _types.map((t) {
                  final sel = _type == t.$1;
                  final color = _typeColor(t.$1);
                  return GestureDetector(
                    onTap: () => setState(() => _type = t.$1),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: sel ? color.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: sel ? color : AppTheme.divider,
                                width: sel ? 2 : 1),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: color.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3))
                                  ]
                                : AppTheme.cardShadow),
                        child: Row(children: [
                          Text(t.$2, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(t.$3,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? color : AppTheme.textPrimary)),
                        ])),
                  );
                }).toList()),
          ),
          const SizedBox(height: 20),

          // Title
          _label(_titleLabel),
          const SizedBox(height: 8),
          _textField(_titleCtrl, '输入${_titleLabel}',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),

          // 疫苗品牌 (vaccine only)
          if (_type == 'vaccine') ...[
            _label('疫苗品牌'),
            const SizedBox(height: 8),
            _textField(_brandCtrl, '例：英特威、梅里亚、辉瑞'),
            const SizedBox(height: 16),
          ],

          // 驱虫项目 + 驱虫品牌 (deworming only)
          if (_type == 'deworming') ...[
            _label('驱虫项目'),
            const SizedBox(height: 8),
            _textField(_dewormTypeCtrl, '例：体外驱虫、除耳螨、体内驱虫'),
            const SizedBox(height: 16),
            _label('驱虫药品牌'),
            const SizedBox(height: 8),
            _textField(_brandCtrl, '例：福来恩、拜宠清'),
            const SizedBox(height: 16),
          ],

          // Record date
          _label('记录日期'),
          const SizedBox(height: 8),
          _dateTile('记录日期', _date, () => _pickDate(false)),
          const SizedBox(height: 16),

          // Next due date (not shown for surgery)
          if (_showNextDue) ...[
            Row(children: [
              Expanded(child: _label(_nextDueLabel)),
              if (_nextDue != null)
                GestureDetector(
                    onTap: () => setState(() => _nextDue = null),
                    child: const Text('清除',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textHint))),
            ]),
            const SizedBox(height: 8),
            _nextDue != null
                ? _dateTile(_nextDueLabel, _nextDue!, () => _pickDate(true))
                : GestureDetector(
                    onTap: () => _pickDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.divider,
                              style: BorderStyle.solid),
                          boxShadow: AppTheme.cardShadow),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(
                                CupertinoIcons.calendar_badge_plus,
                                color: AppTheme.primary,
                                size: 16)),
                        const SizedBox(width: 12),
                        Text('设置${_nextDueLabel}',
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.textHint)),
                        const Spacer(),
                        const Icon(CupertinoIcons.add_circled,
                            color: AppTheme.primary, size: 18),
                      ]),
                    )),
            const SizedBox(height: 16),
          ],

          // Clinic
          _label('院所'),
          const SizedBox(height: 8),
          _textField(_clinicCtrl, '例：爱宠动物医院'),
          const SizedBox(height: 16),

          // Cost
          _label('费用'),
          const SizedBox(height: 8),
          _textField(_costCtrl, '例：280',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefix: '¥ '),
          const SizedBox(height: 16),

          _label('病历上传'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: (_newPhotos.length + _existingPhotos.length) >= 6
                    ? null
                    : _pickPhotos,
                child: _uploadTile(CupertinoIcons.photo_on_rectangle, '从相册上传'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: (_newPhotos.length + _existingPhotos.length) >= 6
                    ? null
                    : _takePhoto,
                child: _uploadTile(CupertinoIcons.camera, '拍照上传'),
              ),
            ),
          ]),
          if (_existingPhotos.isNotEmpty || _newPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._existingPhotos.asMap().entries.map(
                      (entry) => _remotePhotoThumb(entry.key, entry.value)),
                  ..._newPhotos
                      .asMap()
                      .entries
                      .map((entry) => _localPhotoThumb(entry.key, entry.value)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          _label('备注'),
          const SizedBox(height: 8),
          Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: AppTheme.cardShadow),
              child: CupertinoTextField(
                  controller: _notesCtrl,
                  placeholder: '例：接种后观察24小时，无异常反应',
                  maxLines: 4,
                  minLines: 3,
                  padding: const EdgeInsets.all(14),
                  decoration: null,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.deepBlue, height: 1.6),
                  placeholderStyle:
                      const TextStyle(fontSize: 13, color: AppTheme.textHint))),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.6));

  Widget _textField(TextEditingController ctrl, String hint,
          {TextInputType? keyboardType,
          String? prefix,
          ValueChanged<String>? onChanged}) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow),
        child: Row(children: [
          if (prefix != null)
            Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(prefix,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textSecondary))),
          Expanded(
              child: CupertinoTextField(
                  controller: ctrl,
                  placeholder: hint,
                  keyboardType: keyboardType,
                  padding: const EdgeInsets.all(14),
                  decoration: null,
                  onChanged: onChanged,
                  style:
                      const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
                  placeholderStyle:
                      const TextStyle(fontSize: 14, color: AppTheme.textHint))),
        ]),
      );

  Widget _uploadTile(IconData icon, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(fontSize: 13, color: AppTheme.deepBlue)),
          ],
        ),
      );

  Widget _remotePhotoThumb(int index, String url) => Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 72,
            height: 72,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() => _existingPhotos.removeAt(index)),
              child: _removeDot(),
            ),
          ),
        ],
      );

  Widget _localPhotoThumb(int index, File file) => Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 72,
            height: 72,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Image.file(file, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() => _newPhotos.removeAt(index)),
              child: _removeDot(),
            ),
          ),
        ],
      );

  Widget _removeDot() => Container(
        width: 20,
        height: 20,
        decoration:
            const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
        child: const Icon(CupertinoIcons.xmark, size: 12, color: Colors.white),
      );

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
              boxShadow: AppTheme.cardShadow),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(CupertinoIcons.calendar,
                    color: AppTheme.primary, size: 16)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              Text('${date.year}年${date.month}月${date.day}日',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue)),
            ]),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right,
                color: AppTheme.textHint, size: 14),
          ]),
        ),
      );

  Color _typeColor(String t) {
    switch (t) {
      case 'vaccine':
        return AppTheme.primary;
      case 'checkup':
        return const Color(0xFF26A69A);
      case 'deworming':
        return const Color(0xFF7E57C2);
      case 'surgery':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }
}

// ── 查看详情底部弹窗 ─────────────────────────────────────────
class _RecordDetailSheet extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RecordDetailSheet(
      {required this.record, required this.onEdit, required this.onDelete});

  String _fmtDate(DateTime d) =>
      '${d.year}年${d.month.toString().padLeft(2, '0')}月${d.day.toString().padLeft(2, '0')}日';

  _TypeCfg _typeCfg(String type) {
    switch (type) {
      case 'vaccine':
        return _TypeCfg('💉', '疫苗', AppTheme.primary);
      case 'checkup':
        return _TypeCfg('🔬', '体检', const Color(0xFF26A69A));
      case 'deworming':
        return _TypeCfg('💊', '驱虫', const Color(0xFF7E57C2));
      case 'surgery':
        return _TypeCfg('🏥', '手术', AppTheme.danger);
      default:
        return _TypeCfg('📋', '其他', AppTheme.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeCfg(record.type);
    final isOverdue = record.nextDueDate != null &&
        record.nextDueDate!.isBefore(DateTime.now());
    return Container(
      decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2)))),
          // 类型标签
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(cfg.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(cfg.label,
                      style: TextStyle(
                          fontSize: 12,
                          color: cfg.color,
                          fontWeight: FontWeight.w700)),
                ])),
            const Spacer(),
            Text(_fmtDate(record.recordDate),
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ]),
          const SizedBox(height: 14),
          // 标题
          Text(record.title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepBlue)),
          const SizedBox(height: 16),
          if (record.brand != null && record.brand!.isNotEmpty) ...[
            _detailRow(CupertinoIcons.tag, '品牌', record.brand!),
            const SizedBox(height: 12),
          ],
          if (record.dewormType != null && record.dewormType!.isNotEmpty) ...[
            _detailRow(CupertinoIcons.layers_alt, '驱虫项目', record.dewormType!),
            const SizedBox(height: 12),
          ],
          if (record.clinic != null && record.clinic!.isNotEmpty) ...[
            _detailRow(CupertinoIcons.building_2_fill, '院所', record.clinic!),
            const SizedBox(height: 12),
          ],
          if (record.cost != null) ...[
            _detailRow(CupertinoIcons.money_yen_circle, '费用',
                '¥${record.cost!.toStringAsFixed(record.cost!.truncateToDouble() == record.cost! ? 0 : 2)}'),
            const SizedBox(height: 12),
          ],
          // 备注
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            _detailRow(CupertinoIcons.doc_text, '备注', record.notes!),
            const SizedBox(height: 12),
          ],
          if (record.photoUrls.isNotEmpty) ...[
            const Text('病历图片',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: record.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: record.photoUrls[i],
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 下次提醒
          if (record.nextDueDate != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: isOverdue
                      ? AppTheme.danger.withOpacity(0.07)
                      : AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(CupertinoIcons.bell_fill,
                    color: isOverdue ? AppTheme.danger : AppTheme.primary,
                    size: 18),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isOverdue ? '已逾期' : '下次提醒',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isOverdue ? AppTheme.danger : AppTheme.primary)),
                  Text(_fmtDate(record.nextDueDate!),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isOverdue ? AppTheme.danger : AppTheme.primary)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          // 操作按钮
          Row(children: [
            Expanded(
                child: GestureDetector(
              onTap: onDelete,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppTheme.danger.withOpacity(0.2))),
                child: const Center(
                    child: Text('删除',
                        style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 15))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.cardShadowStrong),
                    child: const Center(
                        child: Text('编辑',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15))),
                  ),
                )),
          ]),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppTheme.primary, size: 14)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.deepBlue, height: 1.5)),
              ])),
        ],
      );
}
