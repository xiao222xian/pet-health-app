import 'package:flutter/cupertino.dart';

class AppTheme {
  static const primaryColor = Color(0xFF5B8FF9);
  static const secondaryColor = Color(0xFF61D9A5);
  static const dangerColor = Color(0xFFFF6B6B);
  static const warningColor = Color(0xFFFFB347);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const cardColor = CupertinoColors.white;
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);

  static CupertinoThemeData get theme => const CupertinoThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimary,
    ),
  );
}
