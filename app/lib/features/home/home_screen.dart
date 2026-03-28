import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/timeline')) return 1;
    if (location.startsWith('/health')) return 2;
    if (location.startsWith('/consult')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _locationToIndex(location),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/timeline');
            case 2:
              context.go('/health');
            case 3:
              context.go('/consult');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: '档案'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.time), label: '时光轴'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: '健康'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chat_bubble), label: '问诊'),
        ],
      ),
      tabBuilder: (context, index) => child,
    );
  }
}
