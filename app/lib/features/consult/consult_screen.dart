import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/api_service.dart';
import '../../app/theme.dart';

// ── Chat message model ────────────────────────────────────
class _Msg {
  final bool isUser;
  final String text;
  final List<File> photos;
  final Map<String, dynamic>? consultData;
  const _Msg(
      {required this.isUser,
      required this.text,
      this.photos = const [],
      this.consultData});
}

// ── Risk config ───────────────────────────────────────────
class _RiskCfg {
  final Color color;
  final IconData icon;
  final String label;
  const _RiskCfg(this.color, this.icon, this.label);
}

// ── Suggested starter questions ───────────────────────────
const _starters = [
  '狗狗精神萎靡、不吃饭，怎么回事？',
  '猫咪反复呕吐，需要就医吗？',
  '宠物腹泻，可以先在家处理吗？',
  '狗狗咳嗽打喷嚏要紧吗？',
];

// ─────────────────────────────────────────────────────────
class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key});
  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _disclaimerAccepted = false;
  final List<_Msg> _msgs = [];
  final List<File> _pendingPhotos = [];
  bool _thinking = false;
  bool _ended = false;
  Map<String, dynamic>? _finalAdvice;

  String? _petId, _petName, _petSpecies;
  List<Map<String, dynamic>> _allPets = [];

  @override
  void initState() {
    super.initState();
    _loadPets();
    _inputCtrl.addListener(() => setState(() {}));
    SupabaseService.dataVersion.addListener(_handleDataChanged);
  }

  @override
  void dispose() {
    SupabaseService.dataVersion.removeListener(_handleDataChanged);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (mounted) _loadPets();
  }

  // ── Data ──────────────────────────────────────────────

  Future<void> _loadPets() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    final pets = await SupabaseService.client
        .from('pets')
        .select('id, name, species')
        .eq('user_id', userId);
    if ((pets as List).isEmpty && mounted) {
      setState(() {
        _allPets = [];
        _petId = null;
        _petName = null;
        _petSpecies = null;
      });
      return;
    }
    if (mounted) {
      final petList = pets.cast<Map<String, dynamic>>();
      Map<String, dynamic> activePet = petList.first;
      if (_petId != null) {
        for (final pet in petList) {
          if (pet['id'] == _petId) {
            activePet = pet;
            break;
          }
        }
      }
      setState(() {
        _allPets = petList;
        _petId = activePet['id'] as String;
        _petName = activePet['name'] as String?;
        _petSpecies = activePet['species'] as String?;
      });
    }
  }

  void _selectPet(BuildContext popupContext, Map<String, dynamic> pet) {
    Navigator.pop(popupContext);
    setState(() {
      _petId = pet['id'] as String;
      _petName = pet['name'] as String?;
      _petSpecies = pet['species'] as String?;
      _msgs.clear();
      _pendingPhotos.clear();
      _thinking = false;
      _ended = false;
      _finalAdvice = null;
      _inputCtrl.clear();
    });
  }

  void _showPetPicker() {
    if (_allPets.length <= 1) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              const Text('选择问诊对象',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBlue)),
              const Spacer(),
              CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          ..._allPets.map((p) {
            final sel = p['id'] == _petId;
            final sp = p['species'] as String? ?? 'dog';
            final em = sp == 'cat'
                ? '🐱'
                : sp == 'dog'
                    ? '🐶'
                    : '🐾';
            return GestureDetector(
              onTap: () => _selectPet(popupContext, p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                    color: sel ? AppTheme.primarySoft : Colors.transparent,
                    border: Border(
                        bottom:
                            BorderSide(color: AppTheme.divider, width: 0.5))),
                child: Row(children: [
                  Text(em, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(p['name'] as String? ?? '未命名',
                      style: TextStyle(
                          fontSize: 16,
                          color: sel ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                  const Spacer(),
                  if (sel)
                    const Icon(CupertinoIcons.checkmark,
                        color: AppTheme.primary, size: 16),
                ]),
              ),
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ── Chat logic ────────────────────────────────────────

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _thinking || _ended || _petId == null) return;

    final photos = List<File>.from(_pendingPhotos);
    setState(() {
      _msgs.add(_Msg(isUser: true, text: text, photos: photos));
      _pendingPhotos.clear();
      _inputCtrl.clear();
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final photos64 = await Future.wait(
          photos.map((f) async => base64Encode(await f.readAsBytes())));

      final history = _conversationHistory();
      final prompt = '${history}主人这次补充：$text';

      final res = await ApiService.post('/consult', {
        'pet_id': _petId,
        'symptoms': prompt,
        if (photos64.isNotEmpty) 'photo_data': photos64,
      });

      if (mounted) {
        setState(() {
          _msgs.add(_Msg(isUser: false, text: '', consultData: res));
          _thinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : '网络错误，请稍后重试';
        setState(() {
          _msgs.add(_Msg(isUser: false, text: '抱歉，出现了问题：$msg'));
          _thinking = false;
        });
      }
    }
  }

  String _conversationHistory() {
    if (_msgs.isEmpty) return '';
    final lines =
        _msgs.map((m) => '${m.isUser ? "主人" : "助手"}：${m.text}').join('\n');
    return '【此前对话记录】\n$lines\n\n';
  }

  Future<void> _endSession() async {
    if (_thinking || _ended || _msgs.isEmpty || _petId == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('结束问诊'),
        content: const Text('结束后 AI 将根据本次完整对话\n为你生成综合建议方案'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续问诊'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('结束问诊'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _ended = true;
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final fullHistory = _msgs
          .map((m) => '${m.isUser ? "主人" : "AI助手"}：${m.text}')
          .join('\n\n');

      final prompt = '以下是本次完整问诊对话，请基于全部信息给出一份更完整、更稳妥的综合分诊建议。\n\n'
          '完整问诊记录：\n$fullHistory';

      final res = await ApiService.post('/consult', {
        'pet_id': _petId,
        'symptoms': prompt,
      });

      if (mounted) {
        setState(() {
          _finalAdvice = res;
          _thinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ended = false;
          _thinking = false;
          _msgs.add(const _Msg(isUser: false, text: '生成综合建议时出现问题，请稍后再试'));
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_pendingPhotos.length >= 3) return;
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked != null && mounted) {
      setState(() => _pendingPhotos.add(File(picked.path)));
    }
  }

  Future<void> _showHistory() async {
    if (_petId == null) return;
    final data = await SupabaseService.client
        .from('consult_sessions')
        .select()
        .eq('pet_id', _petId!)
        .order('created_at', ascending: false);
    if (!mounted) return;
    final sessions =
        (data as List).map((e) => e as Map<String, dynamic>).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultHistorySheet(
        petName: _petName ?? '当前宠物',
        sessions: sessions,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_disclaimerAccepted) return _buildDisclaimer();
    return _buildChatScreen();
  }

  // ── Disclaimer ────────────────────────────────────────

  Widget _buildDisclaimer() {
    return CupertinoPageScaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                            gradient: RadialGradient(colors: [
                              AppTheme.primary.withOpacity(0.18),
                              Colors.transparent
                            ]),
                            shape: BoxShape.circle)),
                    const Text('🐾', style: TextStyle(fontSize: 56)),
                  ]),
                  const SizedBox(height: 18),
                  const Text('AI 宠物问诊助手',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepBlue,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('像聊天一样描述症状，随时追问',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 22),
                  _badge('💬', '多轮对话，随时追问'),
                  const SizedBox(height: 8),
                  _badge('🔍', '仅供参考，不构成诊断'),
                  const SizedBox(height: 8),
                  _badge('🏥', '紧急情况请立即就医'),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => setState(() => _disclaimerAccepted = true),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      child: const Center(
                          child: Text('我已了解，开始问诊',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16))),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String emoji, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.deepBlue,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  // ── Chat screen ───────────────────────────────────────

  Widget _buildChatScreen() {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Stack(children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.bgTop, AppTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)))),
        SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ]),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader() {
    final em = _petSpecies == 'cat'
        ? '🐱'
        : _petSpecies == 'dog'
            ? '🐶'
            : '🐾';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: _allPets.length > 1 ? _showPetPicker : null,
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow),
                child: Center(
                    child: Text(em, style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_petName ?? 'AI 问诊',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepBlue)),
                if (_allPets.length > 1) ...[
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.chevron_down,
                      size: 12, color: AppTheme.textHint),
                ],
              ]),
              Text('宠物问诊助手',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
          ]),
        ),
        const Spacer(),
        if (_petId != null)
          GestureDetector(
            onTap: _showHistory,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.time, color: AppTheme.primary, size: 13),
                SizedBox(width: 5),
                Text('历史记录',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        if (_msgs.isNotEmpty && !_ended)
          GestureDetector(
            onTap: _endSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF26C6DA), Color(0xFF00838F)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF26C6DA).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('结束问诊',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        if (_ended)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('已结束',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  // ── Message list ──────────────────────────────────────

  Widget _buildMessageList() {
    if (_msgs.isEmpty && !_thinking && _finalAdvice == null) {
      return CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: _buildWelcome(),
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        ..._msgs.map((m) => m.isUser ? _buildUserBubble(m) : _buildAiBubble(m)),
        if (_thinking) const _ThinkingBubble(),
        if (_finalAdvice != null && !_thinking)
          _buildFinalAdvice(_finalAdvice!),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Welcome / empty state ─────────────────────────────

  Widget _buildWelcome() {
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    ...AppTheme.cardShadow,
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AiAvatar(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _petName != null
                                      ? 'Hi！我是「$_petName」的问诊助手'
                                      : 'Hi！我是你的宠物问诊助手',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '把症状、持续时间、食欲精神和排便情况告诉我，我会先帮你梳理风险，再给你下一步建议。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primarySoft.withOpacity(0.9),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: const [
                        Icon(CupertinoIcons.sparkles,
                            size: 15, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '支持连续追问，也可以上传照片辅助判断。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.deepBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '可以直接点一个示例开始',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _starters
                    .map((q) => GestureDetector(
                          onTap: () {
                            _inputCtrl.text = q;
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.18)),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySoft,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '#',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  q,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bubbles ───────────────────────────────────────────

  Widget _buildUserBubble(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (msg.photos.isNotEmpty) ...[
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: msg.photos
                        .map((f) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(f,
                                  width: 100, height: 100, fit: BoxFit.cover),
                            ))
                        .toList()),
                const SizedBox(height: 6),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Text(msg.text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.5)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
              child: const Center(
                  child: Text('😊', style: TextStyle(fontSize: 16)))),
        ],
      ),
    );
  }

  Widget _buildAiBubble(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: msg.consultData != null
              ? _ConsultStructuredCard(response: msg.consultData!)
              : Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                          bottomLeft: Radius.circular(4)),
                      boxShadow: AppTheme.cardShadow),
                  child: Text(msg.text,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.deepBlue,
                          height: 1.65)),
                ),
        ),
      ]),
    );
  }

  // ── Final advice card ─────────────────────────────────

  Widget _buildFinalAdvice(Map<String, dynamic> res) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: const Color(0xFF26C6DA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(CupertinoIcons.checkmark_seal_fill,
                color: Color(0xFF00838F), size: 14),
            SizedBox(width: 7),
            Text('本次问诊综合建议',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00838F))),
          ]),
        ),
        const SizedBox(height: 10),
        _ConsultStructuredCard(
          response: res,
          showDisclaimer: true,
          emphasizeRisk: true,
        ),
      ]),
    );
  }

  // ── Input bar ─────────────────────────────────────────

  Widget _buildInputBar() {
    final canSend = _inputCtrl.text.trim().isNotEmpty &&
        !_thinking &&
        !_ended &&
        _petId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Pending photo previews
            if (_pendingPhotos.isNotEmpty) ...[
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) =>
                      Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_pendingPhotos[i],
                            width: 58, height: 58, fit: BoxFit.cover)),
                    Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                            onTap: () =>
                                setState(() => _pendingPhotos.removeAt(i)),
                            child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(CupertinoIcons.xmark,
                                    color: Colors.white, size: 10)))),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Input row
            Row(children: [
              if (!_ended) ...[
                GestureDetector(
                    onTap: _pendingPhotos.length < 3 ? _pickPhoto : null,
                    child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(CupertinoIcons.photo,
                            color: AppTheme.primary, size: 18))),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F4FA),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE0DBF0))),
                  child: CupertinoTextField(
                    controller: _inputCtrl,
                    placeholder: _ended ? '问诊已结束' : '描述你家宠物的症状...',
                    enabled: !_ended,
                    maxLines: 4,
                    minLines: 1,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: null,
                    style:
                        const TextStyle(fontSize: 14, color: AppTheme.deepBlue),
                    placeholderStyle:
                        TextStyle(fontSize: 14, color: Colors.grey.shade400),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend ? _send : null,
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: canSend ? AppTheme.primaryGradient : null,
                      color: canSend ? null : const Color(0xFFE8E5F5),
                      shape: BoxShape.circle,
                      boxShadow: canSend
                          ? [
                              BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]
                          : null,
                    ),
                    child: Icon(CupertinoIcons.arrow_up,
                        color: canSend ? Colors.white : Colors.grey.shade400,
                        size: 18)),
              ),
            ]),

            // 结束问诊 bottom action (shown when chat is active)
            if (_msgs.isNotEmpty && !_ended) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _thinking ? null : _endSession,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF26C6DA).withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF26C6DA).withOpacity(0.06)),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal,
                            color: Color(0xFF00838F), size: 15),
                        SizedBox(width: 6),
                        Text('结束问诊，获取综合建议',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00838F))),
                      ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── AI avatar widget ──────────────────────────────────────
class _AiAvatar extends StatelessWidget {
  const _AiAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFFCE93D8), Color(0xFF7B1FA2)]),
            shape: BoxShape.circle),
        child: const Center(child: Text('🐾', style: TextStyle(fontSize: 14))));
  }
}

_RiskCfg _riskCfg(String risk) {
  switch (risk) {
    case 'emergency':
      return _RiskCfg(AppTheme.danger,
          CupertinoIcons.exclamationmark_triangle_fill, '🚨 紧急，建议立即就医');
    case 'high':
      return _RiskCfg(const Color(0xFFFF5722),
          CupertinoIcons.exclamationmark_circle_fill, '⚠️ 风险较高，建议尽快就医');
    case 'medium':
      return _RiskCfg(AppTheme.warning, CupertinoIcons.exclamationmark_circle,
          '🔶 中等风险，建议重点观察');
    default:
      return _RiskCfg(AppTheme.success, CupertinoIcons.checkmark_circle_fill,
          '✅ 当前偏轻，可先居家观察');
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

class _ConsultStructuredCard extends StatelessWidget {
  final Map<String, dynamic> response;
  final bool showDisclaimer;
  final bool emphasizeRisk;

  const _ConsultStructuredCard({
    required this.response,
    this.showDisclaimer = false,
    this.emphasizeRisk = false,
  });

  @override
  Widget build(BuildContext context) {
    final risk = response['risk_level'] as String? ?? 'low';
    final cfg = _riskCfg(risk);
    final summary = (response['summary'] as String? ?? '').trim();
    final possibleCauses = _stringList(response['possible_causes']);
    final homeCare = _stringList(response['home_care']);
    final watchPoints = _stringList(response['watch_points']);
    final whenToSeekVet = _stringList(response['when_to_seek_vet']);
    final followUpQuestion =
        (response['follow_up_question'] as String? ?? '').trim();
    final legacyAdvice = _stringList(response['advice']);

    final careItems = homeCare.isNotEmpty ? homeCare : legacyAdvice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: emphasizeRisk
                  ? [cfg.color.withOpacity(0.88), cfg.color]
                  : [Colors.white, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
            border: emphasizeRisk
                ? null
                : Border.all(color: cfg.color.withOpacity(0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: emphasizeRisk
                          ? Colors.white.withOpacity(0.22)
                          : cfg.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cfg.icon,
                      color: emphasizeRisk ? Colors.white : cfg.color,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cfg.label,
                          style: TextStyle(
                            color: emphasizeRisk ? Colors.white : cfg.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            summary,
                            style: TextStyle(
                              color: emphasizeRisk
                                  ? Colors.white
                                  : AppTheme.deepBlue,
                              fontSize: 13,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (possibleCauses.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ConsultSectionCard(
            icon: CupertinoIcons.search,
            title: '可能原因',
            items: possibleCauses,
          ),
        ],
        if (careItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ConsultSectionCard(
            icon: CupertinoIcons.heart,
            title: '居家护理',
            items: careItems,
          ),
        ],
        if (watchPoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ConsultSectionCard(
            icon: CupertinoIcons.eye,
            title: '接下来观察什么',
            items: watchPoints,
          ),
        ],
        if (whenToSeekVet.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ConsultSectionCard(
            icon: CupertinoIcons.exclamationmark_shield_fill,
            title: '这些情况建议就医',
            items: whenToSeekVet,
            accent: const Color(0xFFFFEDEA),
            iconColor: const Color(0xFFE75A4D),
          ),
        ],
        if (followUpQuestion.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4DDF4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.question_circle_fill,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '我还想继续确认',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        followUpQuestion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showDisclaimer) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0DBF0)),
            ),
            child: Text(
              response['disclaimer'] as String? ?? '以上内容仅供参考，不构成专业兽医诊断意见。',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConsultSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color accent;
  final Color iconColor;

  const _ConsultSectionCard({
    required this.icon,
    required this.title,
    required this.items,
    this.accent = const Color(0xFFF8F7FC),
    this.iconColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
            items.length,
            (index) => Padding(
              padding:
                  EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[index],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultHistorySheet extends StatelessWidget {
  final String petName;
  final List<Map<String, dynamic>> sessions;

  const _ConsultHistorySheet({
    required this.petName,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$petName的历史问诊',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ),
                Text(
                  '${sessions.length} 条',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Text(
                      '还没有历史问诊记录',
                      style: TextStyle(fontSize: 14, color: AppTheme.textHint),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final session = sessions[i];
                      final createdAt = DateTime.tryParse(
                        session['created_at'] as String? ?? '',
                      );
                      final symptoms = session['symptoms'] as String? ?? '';
                      final ai =
                          session['ai_response'] as Map<String, dynamic>?;
                      final summary = ai?['summary'] as String? ?? '';
                      return GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _ConsultHistoryDetailSheet(
                            createdAt: createdAt,
                            symptoms: symptoms,
                            ai: ai,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    CupertinoIcons.chat_bubble_2_fill,
                                    color: AppTheme.primary,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      createdAt == null
                                          ? '历史问诊'
                                          : '${createdAt.month}月${createdAt.day}日 ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.deepBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary.isNotEmpty ? summary : symptoms,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(CupertinoIcons.chevron_right,
                                  color: AppTheme.textHint, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConsultHistoryDetailSheet extends StatelessWidget {
  final DateTime? createdAt;
  final String symptoms;
  final Map<String, dynamic>? ai;

  const _ConsultHistoryDetailSheet({
    required this.createdAt,
    required this.symptoms,
    required this.ai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
            Text(
              createdAt == null
                  ? '问诊详情'
                  : '${createdAt!.year}年${createdAt!.month}月${createdAt!.day}日 问诊',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 14),
            _historyBlock('主人提问', symptoms),
            if (ai != null) ...[
              const SizedBox(height: 12),
              _ConsultStructuredCard(
                response: ai!,
                showDisclaimer: true,
                emphasizeRisk: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyBlock(String title, String content) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
}

// ── Animated thinking indicator ───────────────────────────
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const _AiAvatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4)),
              boxShadow: AppTheme.cardShadow),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(0.0),
              const SizedBox(width: 5),
              _dot(0.33),
              const SizedBox(width: 5),
              _dot(0.66),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _dot(double phase) {
    final t = (_ctrl.value + phase) % 1.0;
    final scale = 0.6 + 0.4 * math.sin(t * math.pi);
    final opacity = 0.3 + 0.7 * math.sin(t * math.pi);
    return Transform.scale(
      scale: scale,
      child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(opacity),
              shape: BoxShape.circle)),
    );
  }
}
