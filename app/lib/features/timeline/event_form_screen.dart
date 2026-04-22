import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../shared/services/supabase_service.dart';
import '../../shared/models/timeline_event.dart';
import '../../app/theme.dart';

class EventFormScreen extends StatefulWidget {
  final String? petId;
  final String? eventId;
  const EventFormScreen({super.key, this.petId, this.eventId});
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  String _type = 'note';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _resolvedPetId;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  List<String> _existingPhotos = [];
  final List<File> _newPhotos = [];

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty && _resolvedPetId != null;

  @override
  void initState() {
    super.initState();
    _resolvedPetId = widget.petId;
    if (widget.eventId != null) _loadExisting();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final data = await SupabaseService.client
        .from('timeline_events')
        .select()
        .eq('id', widget.eventId!)
        .single();
    final event = TimelineEvent.fromJson(data);
    if (!mounted) return;
    setState(() {
      _resolvedPetId = event.petId;
      _type = event.type;
      _date = event.eventDate;
      _titleCtrl.text = event.title;
      _contentCtrl.text = event.content ?? '';
      _existingPhotos = List<String>.from(event.photoUrls);
    });
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _newPhotos
          .addAll(picked.take(8 - _newPhotos.length).map((e) => File(e.path)));
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
      if (_newPhotos.length < 8) _newPhotos.add(File(picked.path));
    });
  }

  Future<List<String>> _uploadPhotos() async {
    if (_newPhotos.isEmpty) return _existingPhotos;
    final urls = List<String>.from(_existingPhotos);
    for (final file in _newPhotos) {
      final fileName =
          '${_resolvedPetId}_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      final bytes = await file.readAsBytes();
      await SupabaseService.client.storage.from('timeline-photos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      urls.add(
        SupabaseService.client.storage
            .from('timeline-photos')
            .getPublicUrl(fileName),
      );
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final title = _titleCtrl.text.trim();
    final content =
        _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim();

    setState(() => _saving = true);
    try {
      final photoUrls = await _uploadPhotos();
      final payload = {
        'pet_id': _resolvedPetId,
        'type': _type,
        'title': title,
        'content': content,
        'photo_urls': photoUrls,
        'event_date': _date.toIso8601String().substring(0, 10),
      };
      if (widget.eventId != null) {
        await SupabaseService.client
            .from('timeline_events')
            .update(payload)
            .eq('id', widget.eventId!);
      } else {
        await SupabaseService.client.from('timeline_events').insert(payload);
      }
      SupabaseService.notifyDataChanged();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('保存失败'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.bgTop, AppTheme.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.xmark,
                              color: AppTheme.primary, size: 16),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.eventId == null
                              ? _typeLabel()
                              : '编辑${_typeName(_type)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: (_saving || !_canSave) ? null : _save,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            gradient:
                                _canSave ? AppTheme.primaryGradient : null,
                            color: _canSave ? null : AppTheme.divider,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow:
                                _canSave ? AppTheme.cardShadowStrong : null,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '保存',
                                  style: TextStyle(
                                    color: _canSave
                                        ? Colors.white
                                        : AppTheme.textHint,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTypePicker(),
                        const SizedBox(height: 20),
                        _buildDatePicker(),
                        const SizedBox(height: 20),
                        _genericForm(
                          key: _type,
                          titleHint:
                              _type == 'growth' ? '例：日常玩耍、春游' : '例：1周岁生日、第一次旅行',
                        ),
                        const SizedBox(height: 18),
                        _label('上传照片'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: (_existingPhotos.length +
                                            _newPhotos.length) >=
                                        8
                                    ? null
                                    : _pickPhotos,
                                child: _uploadTile(
                                    CupertinoIcons.photo_on_rectangle, '从相册添加'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: (_existingPhotos.length +
                                            _newPhotos.length) >=
                                        8
                                    ? null
                                    : _takePhoto,
                                child:
                                    _uploadTile(CupertinoIcons.camera, '拍照添加'),
                              ),
                            ),
                          ],
                        ),
                        if (_existingPhotos.isNotEmpty ||
                            _newPhotos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 84,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ..._existingPhotos.asMap().entries.map(
                                      (entry) => _remotePhotoThumb(
                                          entry.key, entry.value),
                                    ),
                                ..._newPhotos.asMap().entries.map(
                                      (entry) => _localPhotoThumb(
                                          entry.key, entry.value),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePicker() {
    const types = [
      ('note', '⭐', '里程碑', '重要时刻'),
      ('growth', '🌱', '成长点滴', '留存记忆'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '记录类型',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: types.map((t) {
            final sel = _type == t.$1;
            final color = _typeColor(t.$1);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel ? color : AppTheme.divider,
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(t.$2, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 5),
                      Text(
                        t.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sel ? color : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        t.$4,
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              sel ? color.withOpacity(0.7) : AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('完成'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(
                height: 220,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  maximumDate: DateTime.now(),
                  initialDateTime: _date,
                  onDateTimeChanged: (d) => setState(() => _date = d),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.calendar,
                  color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('日期',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                Text(
                  '${_date.year}年${_date.month}月${_date.day}日',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right,
                color: AppTheme.textHint, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _genericForm({required String key, required String titleHint}) =>
      Column(
        key: ValueKey(key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('标题'),
          const SizedBox(height: 8),
          _textField(_titleCtrl, titleHint, onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          _label('描述（可选）'),
          const SizedBox(height: 8),
          _noteField(_contentCtrl),
        ],
      );

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.6,
        ),
      );

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) =>
      Container(
        decoration: _cardDeco(),
        child: CupertinoTextField(
          controller: ctrl,
          placeholder: hint,
          keyboardType: keyboardType,
          padding: const EdgeInsets.all(14),
          decoration: null,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
          placeholderStyle:
              const TextStyle(fontSize: 14, color: AppTheme.textHint),
        ),
      );

  Widget _noteField(TextEditingController ctrl) => Container(
        decoration: _cardDeco(),
        child: CupertinoTextField(
          controller: ctrl,
          placeholder: '添加备注...',
          maxLines: 4,
          minLines: 3,
          padding: const EdgeInsets.all(14),
          decoration: null,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.deepBlue,
            height: 1.6,
          ),
          placeholderStyle:
              const TextStyle(fontSize: 13, color: AppTheme.textHint),
        ),
      );

  Widget _uploadTile(IconData icon, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
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
            width: 84,
            height: 84,
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
            width: 84,
            height: 84,
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

  String _typeLabel() => widget.eventId == null
      ? '添加${_typeName(_type)}'
      : '编辑${_typeName(_type)}';

  String _typeName(String type) {
    switch (type) {
      case 'growth':
        return '成长点滴';
      default:
        return '里程碑';
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'growth':
        return const Color(0xFF4CAF50);
      default:
        return AppTheme.primary;
    }
  }
}
