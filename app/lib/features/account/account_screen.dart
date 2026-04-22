import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../../shared/services/supabase_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  String? _avatarUrl;
  String? _displayName;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    SupabaseService.profileVersion.addListener(_handleProfileChanged);
  }

  @override
  void dispose() {
    SupabaseService.profileVersion.removeListener(_handleProfileChanged);
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _handleProfileChanged() {
    if (mounted) _loadProfile();
  }

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '未知邮箱';

  String get _nickname =>
      (_displayName?.trim().isNotEmpty ?? false) ? _displayName!.trim() : '铲屎官';

  Future<void> _loadProfile() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    setState(() => _loadingProfile = true);
    final data = await SupabaseService.client
        .from('profiles')
        .select('display_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (!mounted) return;
    setState(() {
      _displayName = data?['display_name'] as String?;
      _avatarUrl = data?['avatar_url'] as String?;
      _loadingProfile = false;
    });
  }

  Future<void> _pickAvatar() async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('更换头像'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _selectAvatar(ImageSource.gallery);
            },
            child: const Text('从相册选择'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _selectAvatar(ImageSource.camera);
            },
            child: const Text('拍照'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _selectAvatar(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 480,
    );
    if (picked == null) return;
    try {
      final bytes = await File(picked.path).readAsBytes();
      final userId = SupabaseService.userId!;
      final avatarValue = _toDataUrl(bytes);
      await SupabaseService.client.from('profiles').upsert({
        'id': userId,
        'avatar_url': avatarValue,
        'display_name': _nickname,
      });
      if (!mounted) return;
      setState(() => _avatarUrl = avatarValue);
      SupabaseService.notifyProfileChanged();
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('头像上传失败'),
          content: Text('头像保存失败，请重试。\n$e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  void _editNickname() {
    final controller =
        TextEditingController(text: _nickname == '铲屎官' ? '' : _nickname);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '修改昵称',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 14),
              CupertinoTextField(
                controller: controller,
                placeholder: '输入新的昵称',
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () async {
                  final nextName = controller.text.trim().isEmpty
                      ? '铲屎官'
                      : controller.text.trim();
                  await SupabaseService.client.from('profiles').upsert({
                    'id': SupabaseService.userId,
                    'display_name': nextName,
                    'avatar_url': _avatarUrl,
                  });
                  if (!mounted) return;
                  setState(() => _displayName = nextName);
                  Navigator.pop(sheetContext);
                  SupabaseService.notifyProfileChanged();
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AppTheme.cardShadowStrong,
                  ),
                  child: const Center(
                    child: Text(
                      '保存昵称',
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
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除账号'),
        content: const Text('此操作不可恢复。删除后，你的账号和所有宠物数据将被永久清除。'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.functions.invoke('delete-account');
      await SupabaseService.signOut();
      if (!mounted) return;
      context.go('/auth');
    } catch (_) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('删除失败'),
          content: const Text('请稍后重试，或联系客服处理。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.signOut();
      if (!mounted) return;
      context.go('/auth');
    }
  }

  void _showChangePassword() {
    _oldPwCtrl.clear();
    _newPwCtrl.clear();
    _confirmPwCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSaved: () => Navigator.pop(context),
      ),
    );
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
            height: 280,
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
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                backgroundColor: Colors.transparent,
                border: null,
                largeTitle: const SizedBox.shrink(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: AppTheme.cardShadowStrong,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: ClipOval(child: _buildAvatar()),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.camera_fill,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _editNickname,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _nickname,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  CupertinoIcons.pencil,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击头像可更换，点击昵称可修改',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _sectionLabel('账号'),
                    const SizedBox(height: 10),
                    _menuCard(
                      icon: CupertinoIcons.lock_rotation,
                      color: AppTheme.primary,
                      title: '修改密码',
                      subtitle: '重置你的登录密码',
                      onTap: _showChangePassword,
                    ),
                    const SizedBox(height: 28),
                    _sectionLabel('其他'),
                    const SizedBox(height: 10),
                    _menuCard(
                      icon: CupertinoIcons.square_arrow_right,
                      color: AppTheme.danger,
                      title: '退出登录',
                      subtitle: '退出后可重新登录',
                      onTap: _signOut,
                    ),
                    const SizedBox(height: 12),
                    _menuCard(
                      icon: CupertinoIcons.trash,
                      color: AppTheme.danger,
                      title: '删除账号',
                      subtitle: '永久删除账号及所有数据',
                      onTap: _deleteAccount,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_loadingProfile) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_avatarUrl != null && _avatarUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: _avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Image.asset('assets/logo.png', fit: BoxFit.cover),
        errorWidget: (_, __, ___) =>
            Image.asset('assets/logo.png', fit: BoxFit.cover),
      );
    }
    if (_avatarUrl != null && _avatarUrl!.startsWith('data:image/')) {
      final bytes = _decodeDataUrl(_avatarUrl!);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
    }
    return Image.asset('assets/logo.png', fit: BoxFit.cover);
  }

  String _toDataUrl(List<int> bytes) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      );

  Widget _menuCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  color: AppTheme.textHint, size: 16),
            ],
          ),
        ),
      );
}

class _ChangePasswordSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _ChangePasswordSheet({required this.onSaved});
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _newPwCtrl.text;
    if (pw.length < 6) {
      setState(() => _error = '密码至少需要6位');
      return;
    }
    if (pw != _confirmPwCtrl.text) {
      setState(() => _error = '两次密码不一致');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('修改成功'),
          content: const Text('密码已更新'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSaved();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('same') ||
          msg.contains('identical') ||
          msg.contains('different')) {
        setState(() => _error = '与原密码一致，请重新输入');
      } else {
        setState(() => _error = '修改失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
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
            const Text(
              '修改密码',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 20),
            _pwField(_newPwCtrl, '新密码（至少6位）'),
            const SizedBox(height: 12),
            _pwField(_confirmPwCtrl, '确认新密码'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppTheme.cardShadowStrong,
                ),
                child: Center(
                  child: _saving
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          '确认修改',
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

  Widget _pwField(TextEditingController ctrl, String placeholder) {
    return CupertinoTextField(
      controller: ctrl,
      placeholder: placeholder,
      obscureText: true,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
    );
  }
}
