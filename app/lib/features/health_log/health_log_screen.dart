import 'package:flutter/cupertino.dart';

class HealthLogScreen extends StatelessWidget {
  const HealthLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('健康记录')),
      child: Center(child: Text('Health Log - Coming Soon')),
    );
  }
}
