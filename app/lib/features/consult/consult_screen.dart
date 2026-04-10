import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/api_service.dart';
import '../../shared/models/consult_session.dart';
import '../../app/theme.dart';

// Aliases so existing code compiles without touching every callsite
const _purple = AppTheme.primary;
const _purpleSoft = AppTheme.primarySoft;
const _bgTop = AppTheme.bgTop;
const _bgBottom = AppTheme.background;
const _deepBlue = AppTheme.deepBlue;

class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key});

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen>
    with SingleTickerProviderStateMixin {
  final _symptomsController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _floatController;

  bool _disclaimerAccepted = false;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _petId;
  String? _petName;
  String? _petSpecies;
  List<Map<String, dynamic>> _allPets = [];
  final List<File> _photoFiles = [];
  List<ConsultSession> _history = [];
  bool _historyExpanded = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _loadPet();
    _symptomsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _floatController.dispose();
    _symptomsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPet() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    final pets = await SupabaseService.client
        .from('pets').select('id, name, species').eq('user_id', userId);
    if ((pets as List).isNotEmpty && mounted) {
      setState(() {
        _allPets = pets.cast<Map<String, dynamic>>();
        _petId = pets[0]['id'] as String;
        _petName = pets[0]['name'] as String?;
        _petSpecies = pets[0]['species'] as String?;
      });
      _loadHistory(_petId!);
    }
  }

  void _selectPet(Map<String, dynamic> pet) {
    setState(() {
      _petId = pet['id'] as String;
      _petName = pet['name'] as String?;
      _petSpecies = pet['species'] as String?;
      _result = null;
      _error = null;
    });
    _loadHistory(_petId!);
    Navigator.pop(context);
  }

  void _showPetPicker() {
    if (_allPets.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              const Text('选择问诊对象', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.deepBlue)),
              const Spacer(),
              CupertinoButton(padding: EdgeInsets.zero, child: const Text('取消'),
                onPressed: () => Navigator.pop(context)),
            ]),
          ),
          ..._allPets.map((p) {
            final sel = p['id'] == _petId;
            final sp = p['species'] as String? ?? 'dog';
            final em = sp == 'cat' ? '🐱' : sp == 'dog' ? '🐶' : '🐾';
            return GestureDetector(
              onTap: () => _selectPet(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primarySoft : Colors.transparent,
                  border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))),
                child: Row(children: [
                  Text(em, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(p['name'] as String? ?? '未命名',
                    style: TextStyle(fontSize: 16,
                      color: sel ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                  const Spacer(),
                  if (sel) const Icon(CupertinoIcons.checkmark, color: AppTheme.primary, size: 16),
                ]),
              ),
            );
          }),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _loadHistory(String petId) async {
    final data = await SupabaseService.client
        .from('consult_sessions').select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false)
        .limit(10);
    if (!mounted) return;
    setState(() => _history = (data as List)
        .map((e) => ConsultSession.fromJson(e as Map<String, dynamic>)).toList());
  }

  Future<void> _pickPhoto() async {
    if (_photoFiles.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked == null || !mounted) return;
    setState(() => _photoFiles.add(File(picked.path)));
  }

  void _removePhoto(int i) => setState(() => _photoFiles.removeAt(i));

  Future<void> _consult() async {
    final text = _symptomsController.text.trim();
    if (text.length < 3 || _petId == null) return;
    setState(() { _loading = true; _result = null; _error = null; });
    try {
      // Encode photos as base64 for backend
      final photos = await Future.wait(
        _photoFiles.map((f) async => base64Encode(await f.readAsBytes())));
      final res = await ApiService.post('/consult', {
        'pet_id': _petId,
        'symptoms': text,
        if (photos.isNotEmpty) 'photo_data': photos,
      });
      if (mounted) {
        setState(() => _result = res);
        if (_petId != null) _loadHistory(_petId!);
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '请求失败，请检查网络连接');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _bgBottom,
      child: Stack(
        children: [
          // 渐变背景
          Positioned(
            top: 0, left: 0, right: 0,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bgTop, _bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: !_disclaimerAccepted
                ? _buildDisclaimerSheet()
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: _buildHero()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildInputCard(),
                            const SizedBox(height: 14),
                            _buildSubmitButton(),
                            if (_error != null) ...[const SizedBox(height: 10), _buildError()],
                            if (_loading) ...[const SizedBox(height: 24), _buildLoading()],
                            if (_result != null && !_loading) ...[const SizedBox(height: 20), _buildResult(_result!)],
                            if (_history.isNotEmpty) ...[const SizedBox(height: 24), _buildHistory()],
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── 免责声明弹出层 ─────────────────────────────────
  Widget _buildDisclaimerSheet() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: _purple.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 狗狗 emoji hero
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [_purple.withOpacity(0.2), Colors.transparent]),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Text('🐾', style: TextStyle(fontSize: 56)),
                ],
              ),
              const SizedBox(height: 18),
              const Text('AI 宠物问诊助手',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: _deepBlue, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('智能分析，帮你快速判断症状',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 22),
              _disclaimerBadge('🔍', '仅提供初步参考，不作诊断'),
              const SizedBox(height: 8),
              _disclaimerBadge('🏥', '不能替代专业兽医检查'),
              const SizedBox(height: 8),
              _disclaimerBadge('⚡', '紧急情况请立即前往宠物医院'),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => setState(() => _disclaimerAccepted = true),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_purple, Color(0xFF4A90E2)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Center(
                    child: Text('我已了解，开始问诊',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclaimerBadge(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _purpleSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13, color: _deepBlue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Hero 区域 ──────────────────────────────────────
  Widget _buildHero() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final offset = math.sin(_floatController.value * math.pi) * 8.0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 左侧文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Hi！', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _deepBlue, height: 1)),
                        const SizedBox(width: 4),
                        _sparkleText(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _petName != null ? '正在为「$_petName」服务 🐾' : '让我来帮\n你的毛孩子 🐾',
                      style: const TextStyle(fontSize: 16, color: _deepBlue, height: 1.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // 右侧宠物头像选择器
              GestureDetector(
                onTap: _allPets.length > 1 ? _showPetPicker : null,
                child: Transform.translate(
                  offset: Offset(0, -offset),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [_purple.withOpacity(0.18), Colors.transparent]),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _purple.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Center(child: Text(
                          _petSpecies == 'cat' ? '🐱' : _petSpecies == 'dog' ? '🐶' : '🐾',
                          style: const TextStyle(fontSize: 46))),
                      ),
                      // 切换宠物提示（多宠物时显示）
                      if (_allPets.length > 1)
                        Positioned(
                          bottom: 6, right: 2,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 6)]),
                            child: const Center(child: Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white, size: 13)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sparkleText() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_purple, Color(0xFFFF7043), _purple],
      ).createShader(bounds),
      child: const Text('✨', style: TextStyle(fontSize: 28, color: Colors.white)),
    );
  }

  // ── 输入卡片 ───────────────────────────────────────
  Widget _buildInputCard() {
    final charCount = _symptomsController.text.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFF5722)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('描述宠物的症状',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _deepBlue)),
            ],
          ),
          const SizedBox(height: 14),
          CupertinoTextField(
            controller: _symptomsController,
            placeholder: '越详细越准确\n例如：精神不振、食欲下降、持续咳嗽3天\n体温、大小便情况也很有帮助...',
            maxLines: 5,
            minLines: 4,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0DBF0)),
            ),
            style: const TextStyle(fontSize: 14, color: _deepBlue, height: 1.6),
            placeholderStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.6),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _photoFiles.length >= 3 ? null : _pickPhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _photoFiles.length >= 3 ? Colors.grey.shade200 : _purpleSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(CupertinoIcons.photo, size: 14, color: _purple),
                    const SizedBox(width: 4),
                    Text(
                      _photoFiles.length >= 3 ? '最多3张' : '上传照片${_photoFiles.isNotEmpty ? " (${_photoFiles.length}/3)" : ""}',
                      style: TextStyle(fontSize: 12,
                        color: _photoFiles.length >= 3 ? Colors.grey : _purple,
                        fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              Text(
                '$charCount 字',
                style: TextStyle(fontSize: 11, color: charCount > 10 ? _purple : Colors.grey.shade400),
              ),
            ],
          ),
          if (_photoFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photoFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_photoFiles[i],
                      width: 72, height: 72, fit: BoxFit.cover)),
                  Positioned(top: -6, right: -6,
                    child: GestureDetector(
                      onTap: () => _removePhoto(i),
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 11)))),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 提交按钮 ───────────────────────────────────────
  Widget _buildSubmitButton() {
    final canSubmit = _symptomsController.text.trim().length >= 3 && _petId != null && !_loading;
    return GestureDetector(
      onTap: canSubmit ? _consult : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: canSubmit
              ? const LinearGradient(colors: [_purple, Color(0xFF4A90E2)])
              : null,
          color: canSubmit ? null : const Color(0xFFE0DBF0),
          borderRadius: BorderRadius.circular(28),
          boxShadow: canSubmit
              ? [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✦',
              style: TextStyle(
                fontSize: 18,
                color: canSubmit ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AI 智能分析',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: canSubmit ? Colors.white : Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 加载状态 ───────────────────────────────────────
  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(
              color: _purple,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 14),
          const Text('AI 正在分析症状...',
            style: TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text('请稍候...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  // ── 错误 ───────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle, color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
        ],
      ),
    );
  }

  // ── 分析结果 ───────────────────────────────────────
  Widget _buildResult(Map<String, dynamic> result) {
    final risk = result['risk_level'] as String? ?? 'low';
    final cfg = _riskConfig(risk);
    final advice = result['advice'] as List? ?? [];

    return Column(
      children: [
        // 风险等级卡
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cfg.color.withOpacity(0.85), cfg.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: cfg.color.withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                    child: Icon(cfg.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(cfg.label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result['summary'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.7),
              ),
              if (result['seek_vet'] == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.arrow_right_circle_fill, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('建议尽快就医', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 建议卡
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text('照护建议', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _deepBlue)),
              ]),
              const SizedBox(height: 14),
              ...List.generate(advice.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [_purple, Color(0xFF4A90E2)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(advice[i].toString(),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF3D3560), height: 1.6)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 免责声明
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0DBF0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ℹ️', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result['disclaimer'] as String? ?? '本结果仅供参考，不构成兽医诊断意见。',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _RiskConfig _riskConfig(String risk) {
    switch (risk) {
      case 'emergency':
        return _RiskConfig(AppTheme.danger, CupertinoIcons.exclamationmark_triangle_fill, '🚨 紧急，立即就医');
      case 'high':
        return _RiskConfig(const Color(0xFFFF5722), CupertinoIcons.exclamationmark_circle_fill, '⚠️ 严重，尽快就医');
      case 'medium':
        return _RiskConfig(AppTheme.warning, CupertinoIcons.exclamationmark_circle, '🔶 中等，建议就医');
      default:
        return _RiskConfig(AppTheme.success, CupertinoIcons.checkmark_circle_fill, '✅ 轻微，可在家观察');
    }
  }

  // ── History ─────────────────────────────────────────
  Widget _buildHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _historyExpanded = !_historyExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _purpleSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(CupertinoIcons.clock_fill, size: 15, color: _purple),
            const SizedBox(width: 8),
            Text('历史问诊记录（${_history.length}条）',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _purple)),
            const Spacer(),
            AnimatedRotation(
              turns: _historyExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(CupertinoIcons.chevron_down, size: 14, color: _purple)),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: _historyExpanded
          ? Column(children: _history.map((s) => _buildHistoryCard(s)).toList())
          : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildHistoryCard(ConsultSession s) {
    final risk = s.riskLevel ?? 'low';
    final cfg = _riskConfig(risk);
    final ai = s.aiResponse;
    final summary = ai?['summary'] as String? ?? s.symptoms;
    final now = DateTime.now();
    final diff = now.difference(s.createdAt);
    final timeAgo = diff.inDays > 0 ? '${diff.inDays}天前'
        : diff.inHours > 0 ? '${diff.inHours}小时前' : '刚刚';

    return GestureDetector(
      onTap: () => _showHistoryDetail(s),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cfg.color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(cfg.label, style: TextStyle(fontSize: 10, color: cfg.color, fontWeight: FontWeight.w700))),
            const Spacer(),
            Text(timeAgo, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_right, size: 12, color: AppTheme.textHint),
          ]),
          const SizedBox(height: 8),
          Text(s.symptoms, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (summary != s.symptoms) ...[
            const SizedBox(height: 5),
            Text(summary, style: const TextStyle(fontSize: 13, color: AppTheme.deepBlue, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  void _showHistoryDetail(ConsultSession s) {
    final ai = s.aiResponse;
    if (ai == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('历史问诊详情',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.deepBlue)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppTheme.textHint, size: 22)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('问诊内容', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  const SizedBox(height: 4),
                  Text(s.symptoms, style: const TextStyle(fontSize: 14, color: AppTheme.deepBlue, height: 1.5)),
                ])),
              const SizedBox(height: 12),
              _buildResult(ai),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _RiskConfig {
  final Color color;
  final IconData icon;
  final String label;
  const _RiskConfig(this.color, this.icon, this.label);
}
