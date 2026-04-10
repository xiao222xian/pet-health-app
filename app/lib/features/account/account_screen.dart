import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  void dispose() {
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '未知邮箱';

  Future<void> _signOut() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Use pushReplacement to ensure a clean navigation stack to auth
        context.go('/auth');
      }
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
      child: Stack(children: [
        Positioned(
          top: 0, left: 0, right: 0, height: 280,
          child: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgTop, AppTheme.background],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          )),
        ),
        CustomScrollView(slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: Colors.transparent,
            border: null,
            largeTitle: const Text('我的',
              style: TextStyle(color: AppTheme.deepBlue, fontWeight: FontWeight.w800)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── 头像 + 邮箱 ──
              Center(child: Column(children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadowStrong,
                  ),
                  child: const Center(child: Text('宠', style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
                const SizedBox(height: 12),
                Text(_email,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('铲屎官',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ])),
              const SizedBox(height: 28),

              // ── 账号操作 ──
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

              // ── 危险操作 ──
              _sectionLabel('其他'),
              const SizedBox(height: 10),
              _menuCard(
                icon: CupertinoIcons.square_arrow_right,
                color: AppTheme.danger,
                title: '退出登录',
                subtitle: '退出后可重新登录',
                onTap: _signOut,
              ),
            ])),
          ),
        ]),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      color: AppTheme.textSecondary, letterSpacing: 0.8));

  Widget _menuCard({required IconData icon, required Color color,
    required String title, required String subtitle, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ])),
          const Icon(CupertinoIcons.chevron_right, color: AppTheme.textHint, size: 16),
        ])));
}

// ── 修改密码底部弹窗 ────────────────────────────────────────
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
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: pw));
      if (mounted) {
        // Show success dialog first, then dismiss sheet when confirmed
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('修改成功'),
            content: const Text('密码已更新'),
            actions: [CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSaved();
              },
            )],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('same') || msg.contains('identical') || msg.contains('different')) {
          setState(() => _error = '与原密码一致，请重新输入');
        } else {
          setState(() => _error = '修改失败，请重试');
        }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
          const Text('修改密码',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.deepBlue)),
          const SizedBox(height: 20),
          _pwField(_newPwCtrl, '新密码（至少6位）'),
          const SizedBox(height: 12),
          _pwField(_confirmPwCtrl, '确认新密码'),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadowStrong),
              child: Center(child: _saving
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text('确认修改', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String placeholder) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.divider), boxShadow: AppTheme.cardShadow),
    child: CupertinoTextField(
      controller: ctrl,
      placeholder: placeholder,
      obscureText: true,
      padding: const EdgeInsets.all(14),
      decoration: null,
      onChanged: (_) => setState(() => _error = null),
      style: const TextStyle(fontSize: 15, color: AppTheme.deepBlue),
      placeholderStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
    ),
  );
}
