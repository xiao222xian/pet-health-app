import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../shared/services/supabase_service.dart';
import '../../shared/models/pet.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../app/theme.dart';

// ── 品种数据 ──────────────────────────────────────────────
const _dogBreeds = [
  '金毛寻回犬', '拉布拉多', '德国牧羊犬', '贵宾犬', '泰迪',
  '比熊犬', '柴犬', '边境牧羊犬', '哈士奇', '萨摩耶',
  '柯基', '博美犬', '马尔济斯', '约克夏', '法国斗牛犬',
  '英国斗牛犬', '雪纳瑞', '秋田犬', '阿拉斯加', '松狮犬',
  '其他狗狗',
];
const _catBreeds = [
  '英国短毛猫', '美国短毛猫', '布偶猫', '波斯猫', '缅因猫',
  '暹罗猫', '苏格兰折耳猫', '俄罗斯蓝猫', '挪威森林猫', '孟加拉猫',
  '阿比西尼亚猫', '橘猫', '狸花猫', '中华田园猫', '加菲猫',
  '其他猫咪',
];

// ── 预设头像 ──────────────────────────────────────────────
const _dogAvatars = ['🐶', '🐕', '🦮', '🐩', '🐕‍🦺'];
const _catAvatars = ['🐱', '🐈', '🐈‍⬛', '😺', '😸'];
const _otherAvatars = ['🐰', '🐹', '🐾', '🦜', '🐠'];

class PetFormScreen extends StatefulWidget {
  final String? petId;
  const PetFormScreen({super.key, this.petId});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _customBreedController = TextEditingController();
  String _species = 'dog';
  String _gender = 'male';
  bool _neutered = false;
  DateTime? _birthDate;
  String? _breed;
  bool _isCustomBreed = false;
  String _avatar = '🐶';
  File? _imageFile; // custom photo picked from gallery
  bool _saving = false;
  Pet? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.petId != null) _loadExisting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _customBreedController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final data = await SupabaseService.client
        .from('pets')
        .select()
        .eq('id', widget.petId!)
        .single();
    final pet = Pet.fromJson(data);
    setState(() {
      _existing = pet;
      _nameController.text = pet.name;
      _weightController.text = pet.weightKg?.toString() ?? '';
      _species = pet.species;
      _gender = pet.gender ?? 'male';
      _neutered = pet.neutered;
      _birthDate = pet.birthDate;
      _breed = pet.breed;
      // Restore saved avatar; fall back to species default only if none saved
      _avatar = pet.avatarUrl ?? _defaultAvatarFor(pet.species);
    });
  }

  String _defaultAvatarFor(String species) {
    if (species == 'dog') return '🐶';
    if (species == 'cat') return '🐱';
    return '🐾';
  }

  Future<void> _pickCustomImage() async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('选择头像来源'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
              if (picked != null && mounted) {
                setState(() => _imageFile = File(picked.path));
              }
            },
            child: const Text('从相册选择'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final picked = await ImagePicker().pickImage(
                source: ImageSource.camera, imageQuality: 80, maxWidth: 512);
              if (picked != null && mounted) {
                setState(() => _imageFile = File(picked.path));
              }
            },
            child: const Text('拍照'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: false,
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('请填写宠物昵称');
      return;
    }
    final userId = SupabaseService.userId;
    if (userId == null) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'user_id': userId,
      'name': _nameController.text.trim(),
      'species': _species,
      'gender': _gender,
      'neutered': _neutered,
    };
    // Use custom breed name if "其他" was selected
    final effectiveBreed = _isCustomBreed
        ? (_customBreedController.text.trim().isNotEmpty ? _customBreedController.text.trim() : null)
        : _breed;
    if (effectiveBreed != null && effectiveBreed.isNotEmpty) payload['breed'] = effectiveBreed;
    if (_weightController.text.isNotEmpty) {
      payload['weight_kg'] = double.tryParse(_weightController.text);
    }
    if (_birthDate != null) {
      payload['birth_date'] = _birthDate!.toIso8601String().substring(0, 10);
    }
    // Upload custom photo if user picked one, otherwise use emoji
    if (_imageFile != null) {
      try {
        final userId = SupabaseService.userId!;
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await _imageFile!.readAsBytes();
        await SupabaseService.client.storage
            .from('pet-avatars')
            .uploadBinary(fileName, bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
        final url = SupabaseService.client.storage.from('pet-avatars').getPublicUrl(fileName);
        payload['avatar_url'] = url;
      } catch (e) {
        if (mounted) _showError('头像上传失败，请先在 Supabase 创建公开 bucket "pet-avatars"');
        if (mounted) setState(() => _saving = false);
        return;
      }
    } else if (_avatar.isNotEmpty) {
      payload['avatar_url'] = _avatar;
    }

    try {
      if (_existing != null) {
        await SupabaseService.client.from('pets').update(payload).eq('id', _existing!.id);
      } else {
        await SupabaseService.client.from('pets').insert(payload);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(msg),
        actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  // ── 品种选择 ──────────────────────────────────────────
  void _pickBreed() {
    final dogs = _dogBreeds;
    final cats = _catBreeds;
    final all = <String, List<String>>{'🐶 狗狗': dogs, '🐱 猫咪': cats};

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Text('选择品种', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.deepBlue)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          SizedBox(
            height: 380,
            child: ListView(padding: const EdgeInsets.only(bottom: 20), children: [
              ...all.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(entry.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ),
                  ...entry.value.map((breed) => GestureDetector(
                    onTap: () {
                      final isdog = entry.key.contains('狗');
                      final isOther = breed == '其他狗狗' || breed == '其他猫咪';
                      setState(() {
                        _breed = breed;
                        _isCustomBreed = isOther;
                        _species = isdog ? 'dog' : 'cat';
                        _avatar = isdog ? '🐶' : '🐱';
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: _breed == breed ? AppTheme.primarySoft : Colors.transparent,
                        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
                      ),
                      child: Row(children: [
                        Text(breed, style: TextStyle(
                          fontSize: 15,
                          color: _breed == breed ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: _breed == breed ? FontWeight.w600 : FontWeight.w400,
                        )),
                        const Spacer(),
                        if (_breed == breed)
                          const Icon(CupertinoIcons.checkmark, color: AppTheme.primary, size: 16),
                      ]),
                    ),
                  )),
                ],
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── 出生日期 ──────────────────────────────────────────
  void _pickDate() {
    DateTime tempDate = _birthDate ?? DateTime.now().subtract(const Duration(days: 365));
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CupertinoButton(child: const Text('取消'), onPressed: () => Navigator.pop(context)),
            CupertinoButton(child: const Text('完成'), onPressed: () {
              setState(() => _birthDate = tempDate);
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

  @override
  Widget build(BuildContext context) {
    final avatarList = _species == 'dog' ? _dogAvatars : _species == 'cat' ? _catAvatars : _otherAvatars;
    return LoadingOverlay(
      isLoading: _saving,
      child: CupertinoPageScaffold(
        backgroundColor: AppTheme.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppTheme.background,
          border: null,
          middle: Text(widget.petId == null ? '添加爱宠' : '编辑档案',
            style: const TextStyle(color: AppTheme.deepBlue, fontWeight: FontWeight.w700)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saving ? null : _save,
            child: Text('保存', style: TextStyle(
              color: _saving ? AppTheme.textHint : AppTheme.primary,
              fontWeight: FontWeight.w700)),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── 头像选择 ──────────────────────────────
              Center(
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickCustomImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.cardShadowStrong,
                          ),
                          child: ClipOval(child: _buildAvatarPreview()),
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(CupertinoIcons.camera_fill,
                              color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: avatarList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final em = avatarList[i];
                        // Emoji is selected only when no custom image is active
                        final sel = _imageFile == null && em == _avatar;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _avatar = em;
                            _imageFile = null; // clear custom image when emoji picked
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primarySoft : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? AppTheme.primary : AppTheme.divider,
                                width: sel ? 2 : 1),
                              boxShadow: sel ? AppTheme.cardShadow : null,
                            ),
                            child: Center(child: Text(em, style: const TextStyle(fontSize: 22))),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _imageFile != null ? '已选择自定义照片' : '点击头像上传照片，或选择图标',
                    style: TextStyle(
                      fontSize: 11,
                      color: _imageFile != null ? AppTheme.primary : AppTheme.textHint,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── 昵称 ──────────────────────────────────
              _sectionCard(children: [
                _label('昵称'),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: '宠物的昵称',
                  padding: const EdgeInsets.all(14),
                  style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
                  placeholderStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // ── 品种 ──────────────────────────────────
              _sectionCard(children: [
                _label('品种'),
                GestureDetector(
                  onTap: _pickBreed,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      Text(
                        _isCustomBreed
                            ? '其他（自定义）'
                            : (_breed ?? '点击选择品种'),
                        style: TextStyle(
                          fontSize: 15,
                          color: _breed != null ? AppTheme.deepBlue : AppTheme.textHint,
                        ),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.chevron_right, color: AppTheme.textHint, size: 14),
                    ]),
                  ),
                ),
                if (_isCustomBreed) ...[
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: _customBreedController,
                    placeholder: '请输入品种名称',
                    padding: const EdgeInsets.all(14),
                    style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
                    placeholderStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 14),

              // ── 性别 ──────────────────────────────────
              _sectionCard(children: [
                _label('性别'),
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: _gender,
                  onValueChanged: (v) => setState(() => _gender = v!),
                  children: const {
                    'male': Text('弟弟'),
                    'female': Text('妹妹'),
                    'unknown': Text('其他'),
                  },
                ),
              ]),
              const SizedBox(height: 14),

              // ── 绝育 + 体重 ────────────────────────────
              _sectionCard(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('已绝育', style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                    CupertinoSwitch(
                      value: _neutered,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _neutered = v),
                    ),
                  ],
                ),
                Divider(color: AppTheme.divider, height: 20),
                _label('体重 (kg)'),
                CupertinoTextField(
                  controller: _weightController,
                  placeholder: '例：8.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  padding: const EdgeInsets.all(14),
                  style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
                  placeholderStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // ── 出生日期 ──────────────────────────────
              _sectionCard(children: [
                _label('出生日期'),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      const Icon(CupertinoIcons.calendar, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _birthDate == null
                            ? '点击选择出生日期'
                            : '${_birthDate!.year}年${_birthDate!.month}月${_birthDate!.day}日',
                        style: TextStyle(
                          fontSize: 15,
                          color: _birthDate != null ? AppTheme.deepBlue : AppTheme.textHint,
                        ),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.chevron_right, color: AppTheme.textHint, size: 14),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // Renders avatar preview: local file > network URL > emoji
  Widget _buildAvatarPreview() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, width: 90, height: 90, fit: BoxFit.cover);
    }
    if (_avatar.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: _avatar, width: 90, height: 90, fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CupertinoActivityIndicator()),
        errorWidget: (_, __, ___) => const Center(child: Text('🐾', style: TextStyle(fontSize: 44))),
      );
    }
    return Center(child: Text(_avatar, style: const TextStyle(fontSize: 44)));
  }

  Widget _sectionCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary, letterSpacing: 0.5)),
  );
}
