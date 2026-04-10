import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../app/theme.dart';

class EventFormScreen extends StatefulWidget {
  final String petId;
  const EventFormScreen({super.key, required this.petId});
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  // 'note' = 里程碑, 'growth' = 成长点滴
  String _type = 'note';
  DateTime _date = DateTime.now();
  bool _saving = false;

  // Form fields for note/growth types
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim();

    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('timeline_events').insert({
        'pet_id': widget.petId,
        'type': _type,
        'title': title,
        'content': content,
        'photo_urls': <String>[],
        'event_date': _date.toIso8601String().substring(0, 10),
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(context: context, builder: (_) => CupertinoAlertDialog(
          title: const Text('保存失败'),
          content: Text(e.toString()),
          actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: 260,
          child: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.bgTop, AppTheme.background],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ))),
        SafeArea(child: Column(children: [
          // ── Nav bar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.xmark, color: AppTheme.primary, size: 16),
                ),
              ),
              Expanded(child: Text(_typeLabel(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.deepBlue))),
              GestureDetector(
                onTap: (_saving || !_canSave) ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _canSave ? AppTheme.primaryGradient : null,
                    color: _canSave ? null : AppTheme.divider,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _canSave ? AppTheme.cardShadowStrong : null,
                  ),
                  child: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('保存', style: TextStyle(color: _canSave ? Colors.white : AppTheme.textHint,
                        fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Type picker ──────────────────────────
              _buildTypePicker(),
              const SizedBox(height: 20),
              // ── Date picker ──────────────────────────
              _buildDatePicker(),
              const SizedBox(height: 20),
              // ── Type-specific form ───────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                    child: child),
                ),
                child: _buildTypeForm(),
              ),
            ]),
          )),
        ])),
      ]),
    );
  }

  // ── Type picker ─────────────────────────────────────
  Widget _buildTypePicker() {
    const types = [
      ('note',   '⭐', '里程碑', '重要时刻'),
      ('growth', '🌱', '成长点滴', '留存记忆'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('记录类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary, letterSpacing: 0.8)),
      const SizedBox(height: 10),
      Row(children: types.map((t) {
        final sel = _type == t.$1;
        final color = _typeColor(t.$1);
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _type = t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? color : AppTheme.divider, width: sel ? 2 : 1),
              boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 12, offset: const Offset(0, 4))] : AppTheme.cardShadow,
            ),
            child: Column(children: [
              Text(t.$2, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 5),
              Text(t.$3, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: sel ? color : AppTheme.textPrimary)),
              const SizedBox(height: 1),
              Text(t.$4, style: TextStyle(fontSize: 9, color: sel ? color.withOpacity(0.7) : AppTheme.textHint)),
            ]),
          ),
        ));
      }).toList()),
    ]);
  }

  // ── Date picker ─────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(child: const Text('完成'), onPressed: () => Navigator.pop(context)),
            ]),
            SizedBox(height: 220, child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              maximumDate: DateTime.now(),
              initialDateTime: _date,
              onDateTimeChanged: (d) => setState(() => _date = d),
            )),
          ]),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider), boxShadow: AppTheme.cardShadow,
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(CupertinoIcons.calendar, color: AppTheme.primary, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('日期', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
            Text('${_date.year}年${_date.month}月${_date.day}日',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.deepBlue)),
          ]),
          const Spacer(),
          const Icon(CupertinoIcons.chevron_right, color: AppTheme.textHint, size: 14),
        ]),
      ),
    );
  }

  // ── Type-specific forms ──────────────────────────────
  Widget _buildTypeForm() {
    switch (_type) {
      case 'growth': return _genericForm(key: 'growth', titleHint: '例：日常玩耍、春游');
      default:      return _genericForm(key: 'note', titleHint: '例：1周岁生日、第一次旅行'); // 'note' = 里程碑
    }
  }


  Widget _genericForm({required String key, required String titleHint}) =>
    Column(key: ValueKey(key), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('标题'),
      const SizedBox(height: 8),
      _textField(_titleCtrl, titleHint, onChanged: (_) => setState(() {})),
      const SizedBox(height: 16),
      _label('描述（可选）'),
      const SizedBox(height: 8),
      _noteField(_contentCtrl),
    ]);

  // ── Helpers ─────────────────────────────────────────
  Widget _label(String t) => Text(t, style: const TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.6));

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppTheme.divider), boxShadow: AppTheme.cardShadow);

  Widget _textField(TextEditingController ctrl, String hint, {
    TextInputType? keyboardType, String? prefix, void Function(String)? onChanged}) =>
    Container(
      decoration: _cardDeco(),
      child: Row(children: [
        if (prefix != null) Padding(padding: const EdgeInsets.only(left: 14),
          child: Text(prefix, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary))),
        Expanded(child: CupertinoTextField(
          controller: ctrl, placeholder: hint, keyboardType: keyboardType,
          padding: const EdgeInsets.all(14), decoration: null, onChanged: onChanged,
          style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
          placeholderStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
        )),
      ]),
    );

  Widget _noteField(TextEditingController ctrl) => Container(
    decoration: _cardDeco(),
    child: CupertinoTextField(
      controller: ctrl, placeholder: '添加备注...', maxLines: 4, minLines: 3,
      padding: const EdgeInsets.all(14), decoration: null,
      style: const TextStyle(fontSize: 14, color: AppTheme.deepBlue, height: 1.6),
      placeholderStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
    ),
  );

  String _typeLabel() {
    switch (_type) {
      case 'growth': return '添加成长点滴';
      default:       return '添加里程碑'; // 'note' type
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'growth': return const Color(0xFF4CAF50);
      default:       return AppTheme.primary; // 'note' = milestone
    }
  }
}
