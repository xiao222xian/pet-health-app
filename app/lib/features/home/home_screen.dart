import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';

class HomeScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const HomeScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: Column(
        children: [
          Expanded(child: navigationShell),
          _BottomTabBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(
              i, initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomTabBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _TabItem(icon: CupertinoIcons.house_fill, label: '档案'),
    _TabItem(icon: CupertinoIcons.heart_fill, label: '健康'),
    _TabItem(icon: CupertinoIcons.chat_bubble_2_fill, label: '问诊', isCenter: true),
    _TabItem(icon: CupertinoIcons.time, label: '时光轴'),
    _TabItem(icon: CupertinoIcons.person_fill, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              final item = _items[i];
              if (item.isCenter) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: active
                                ? [AppTheme.primary, const Color(0xFF4A90E2)]
                                : [const Color(0xFFB0A8E8), const Color(0xFF9C8FD4)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(active ? 0.5 : 0.3),
                              blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Icon(item.icon, size: 24, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: active
                            ? BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              )
                            : null,
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: active ? AppTheme.primary : AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? AppTheme.primary : AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final bool isCenter;
  const _TabItem({required this.icon, required this.label, this.isCenter = false});
}
