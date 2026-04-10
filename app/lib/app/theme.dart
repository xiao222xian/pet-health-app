import 'package:flutter/cupertino.dart';

class AppTheme {
  // ── 主色：薰衣草紫 ───────────────────────────────
  static const primary = Color(0xFF6B5ECD);
  static const primaryLight = Color(0xFF8B7EE8);
  static const primarySoft = Color(0xFFF0EEFF);
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6B5ECD), Color(0xFF4A90E2)],
  );

  // ── 强调色：暖橙 ─────────────────────────────────
  static const accent = Color(0xFFFF7043);
  static const accentSoft = Color(0xFFFFF0EC);
  static const accentGradient = LinearGradient(
    colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── 背景 ─────────────────────────────────────────
  static const bgTop = Color(0xFFE8E4F5);
  static const bgBottom = Color(0xFFF8F7FC);
  static const background = Color(0xFFF8F7FC);
  static const card = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE0DBF0);

  // ── 语义色 ───────────────────────────────────────
  static const success = Color(0xFF4CAF50);
  static const successSoft = Color(0xFFEDF7EE);
  static const warning = Color(0xFFFFB300);
  static const warningSoft = Color(0xFFFFF8E1);
  static const danger = Color(0xFFF44336);
  static const dangerSoft = Color(0xFFFDECEB);

  // ── 文字 ─────────────────────────────────────────
  static const deepBlue = Color(0xFF1A237E);
  static const textPrimary = Color(0xFF2D2A3E);
  static const textSecondary = Color(0xFF6B6585);
  static const textHint = Color(0xFFB0A9C8);

  // ── 兼容旧引用 ───────────────────────────────────
  static const primaryColor = primary;
  static const dangerColor = danger;
  static const warningColor = warning;
  static const backgroundColor = background;
  static const cardColor = card;
  static const textSecondaryCompat = textSecondary;
  static const gradientOrange = accentGradient;

  // ── CupertinoTheme ───────────────────────────────
  static CupertinoThemeData get theme => const CupertinoThemeData(
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    barBackgroundColor: card,
    textTheme: CupertinoTextThemeData(
      primaryColor: primary,
      textStyle: TextStyle(color: textPrimary, fontSize: 16),
      navTitleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: deepBlue,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
  );

  // ── 阴影 ─────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF6B5ECD).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadowStrong => [
    BoxShadow(
      color: primary.withOpacity(0.28),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
