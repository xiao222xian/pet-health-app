import 'package:flutter/cupertino.dart';

class PetProfileScreen extends StatelessWidget {
  const PetProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('档案')),
      child: Center(child: Text('Pet Profile - Coming Soon')),
    );
  }
}
