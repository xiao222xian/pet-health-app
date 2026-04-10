import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;
  bool _usePhone = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  late final AnimationController _floatCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // 手机号转虚拟邮箱（无需短信验证）
  String _phoneToEmail(String phone) => '${phone.replaceAll(RegExp(r'\s+'), '')}@phone.pet';

  Future<void> _submit() async {
    final pw = _pwCtrl.text;
    String email;
    if (_usePhone) {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty || pw.isEmpty) {
        setState(() => _error = '请填写手机号和密码');
        return;
      }
      if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
        setState(() => _error = '请输入11位手机号');
        return;
      }
      email = _phoneToEmail(phone);
    } else {
      email = _emailCtrl.text.trim();
      if (email.isEmpty || pw.isEmpty) {
        setState(() => _error = '请填写邮箱和密码');
        return;
      }
    }
    if (_isSignUp && pw != _confirmPwCtrl.text) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: pw);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pw);
      }
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login')) return '账号或密码错误，请重试';
    if (raw.contains('already registered')) return '该账号已注册，请直接登录';
    if (raw.contains('password')) return '密码至少需要6位';
    if (raw.contains('email')) return '请输入有效的邮箱地址';
    if (raw.contains('network') || raw.contains('timeout')) return '网络连接失败，请检查网络';
    return '登录失败，请稍后重试';
  }

  void _toggleMode() {
    _slideCtrl.reverse().then((_) {
      setState(() { _isSignUp = !_isSignUp; _error = null; _confirmPwCtrl.clear(); });
      _slideCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Gradient background ──────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        // ── Floating orbs ────────────────────────────────
        _Orb(top: -60, right: -40, size: 220, color: const Color(0xFF6B5ECD), ctrl: _floatCtrl, phase: 0),
        _Orb(bottom: 100, left: -60, size: 180, color: const Color(0xFF4A90E2), ctrl: _floatCtrl, phase: 0.4),
        _Orb(top: 200, right: 20, size: 100, color: const Color(0xFFFF6B9D), ctrl: _floatCtrl, phase: 0.7),
        // ── Floating paw prints ──────────────────────────
        ..._buildPaws(),
        // ── Content ──────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // ── Hero ──────────────────────────────
                    AnimatedBuilder(
                      animation: _floatCtrl,
                      builder: (_, __) {
                        final y = math.sin(_floatCtrl.value * math.pi) * 8;
                        return Transform.translate(
                          offset: Offset(0, y),
                          child: Column(children: [
                            Container(
                              width: 96, height: 96,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6B5ECD), Color(0xFF9C88E8)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: const Color(0xFF6B5ECD).withOpacity(0.5),
                                  blurRadius: 32, offset: const Offset(0, 12))],
                              ),
                              child: Center(child: Text('宠', style: TextStyle(
                                fontSize: 42, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -1)))),
                            const SizedBox(height: 20),
                            const Text('宠不病',
                              style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Text(
                              _isSignUp ? '开始让你的毛孩子少生病' : '欢迎回来，铲屎官 👋',
                              style: TextStyle(fontSize: 14,
                                color: Colors.white.withOpacity(0.6), height: 1.4)),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 44),
                    // ── Form card ─────────────────────────
                    AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, 30 * (1 - _slideAnim.value)),
                        child: Opacity(opacity: _slideAnim.value, child: child)),
                      child: _buildFormCard(),
                    ),
                    const SizedBox(height: 28),
                    // ── Toggle ────────────────────────────
                    GestureDetector(
                      onTap: _loading ? null : _toggleMode,
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: _isSignUp ? '已有账号？' : '还没有账号？',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                          TextSpan(
                            text: _isSignUp ? '立即登录' : '免费注册',
                            style: const TextStyle(
                              color: Color(0xFF9C88E8), fontSize: 14, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 邮箱/手机号切换
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() { _usePhone = false; _error = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_usePhone ? Colors.white.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('邮箱登录',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: !_usePhone ? Colors.white : Colors.white.withOpacity(0.5)))),
              ),
            )),
            Expanded(child: GestureDetector(
              onTap: () => setState(() { _usePhone = true; _error = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _usePhone ? Colors.white.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('手机号登录',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _usePhone ? Colors.white : Colors.white.withOpacity(0.5)))),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        // 账号输入
        if (_usePhone)
          _InputField(
            controller: _phoneCtrl,
            placeholder: '手机号（11位）',
            icon: CupertinoIcons.phone_fill,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => _error = null),
          )
        else
          _InputField(
            controller: _emailCtrl,
            placeholder: '邮箱地址',
            icon: CupertinoIcons.mail_solid,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _error = null),
          ),
        const SizedBox(height: 14),
        // Password
        _InputField(
          controller: _pwCtrl,
          placeholder: '密码（至少6位）',
          icon: CupertinoIcons.lock_fill,
          obscureText: _obscure,
          onChanged: (_) => setState(() => _error = null),
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
              size: 18, color: Colors.white.withOpacity(0.4))),
        ),
        // Confirm Password (signup only)
        if (_isSignUp) ...[
          const SizedBox(height: 14),
          _InputField(
            controller: _confirmPwCtrl,
            placeholder: '再次输入密码',
            icon: CupertinoIcons.lock_shield_fill,
            obscureText: _obscureConfirm,
            onChanged: (_) => setState(() => _error = null),
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(_obscureConfirm ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                size: 18, color: Colors.white.withOpacity(0.4))),
          ),
        ],
        // Error
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(CupertinoIcons.exclamationmark_circle_fill,
                size: 14, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        // Submit button
        GestureDetector(
          onTap: _loading ? null : _submit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient: _loading ? null : const LinearGradient(
                colors: [Color(0xFF6B5ECD), Color(0xFF4A90E2)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              color: _loading ? Colors.white12 : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _loading ? null : [BoxShadow(
                color: const Color(0xFF6B5ECD).withOpacity(0.5),
                blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: _loading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(_isSignUp ? '注册并登录 →' : '登录',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w700, letterSpacing: 0.3))),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildPaws() {
    const paws = [
      [40.0, 280.0, -1.0, -1.0, 18.0, 0.08, -0.3],
      [80.0, 320.0, -1.0, -1.0, 12.0, 0.05, 0.2],
      [-1.0, 400.0, 50.0, -1.0, 20.0, 0.07, 0.5],
      [-1.0, 460.0, 30.0, -1.0, 14.0, 0.05, -0.1],
      [60.0, -1.0, -1.0, 200.0, 16.0, 0.06, 0.8],
    ];
    return paws.map((p) => Positioned(
      left: p[0] >= 0 ? p[0] : null,
      top: p[1] >= 0 ? p[1] : null,
      right: p[2] >= 0 ? p[2] : null,
      bottom: p[3] >= 0 ? p[3] : null,
      child: Transform.rotate(
        angle: p[6],
        child: Opacity(
          opacity: p[5],
          child: Text('🐾', style: TextStyle(fontSize: p[4])))),
    )).toList();
  }
}

// ── Floating orb ─────────────────────────────────────────
class _Orb extends StatelessWidget {
  final double? top, bottom, left, right, size;
  final Color color;
  final AnimationController ctrl;
  final double phase;
  const _Orb({this.top, this.bottom, this.left, this.right,
    required this.size, required this.color, required this.ctrl, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final v = math.sin((ctrl.value + phase) * math.pi);
          return Transform.translate(
            offset: Offset(v * 12, v * 8),
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  color.withOpacity(0.35),
                  color.withOpacity(0.0),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Input field ──────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  const _InputField({
    required this.controller, required this.placeholder,
    required this.icon, this.keyboardType, this.obscureText = false,
    this.onChanged, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 12),
        Expanded(child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
          decoration: null,
          padding: const EdgeInsets.symmetric(vertical: 14),
        )),
        if (suffix != null) suffix!,
      ]),
    );
  }
}
