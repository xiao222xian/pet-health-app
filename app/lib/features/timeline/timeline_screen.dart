import 'package:flutter/cupertino.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('生命时光轴')),
      child: Center(child: Text('Timeline - Coming Soon')),
    );
  }
}
